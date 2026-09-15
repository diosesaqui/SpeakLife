//
//  StandAuthCoordinator.swift
//  SpeakLife
//
//  Identity for Stand With Me. Full rationale: docs/STAND_TOGETHER_SPEC.md §4.
//
//  Before this, `AppleSignInService` was the only way to get a uid, and uid was
//  "" for everyone who had not signed in. Putting a Sign in with Apple wall at
//  the moment somebody taps a link from their mother is the worst possible
//  place for it, so a stand creates an ANONYMOUS account on demand and upgrades
//  it later, once the person has something to lose.
//
//  ⚠️ THE THING THAT MAKES THIS SAFE LIVES IN firestore.rules, NOT HERE.
//
//  Every Prayer Wall write rule was built on `signedIn()` (`request.auth !=
//  nil`), which meant "a real account" only by accident — because no anonymous
//  path existed. `isFullAccount()` now excludes anonymous providers explicitly.
//  If that helper is ever removed, anonymous users can post free text to
//  strangers on the Prayer Wall the moment this file ships.
//

import Foundation
import AuthenticationServices
import FirebaseAuth
import FirebaseMessaging
import FirebaseFirestore
import FirebaseFunctions
import SpeakLifeCore

@MainActor
final class StandAuthCoordinator: ObservableObject {

    static let shared = StandAuthCoordinator()

    /// Non-empty once there is any Firebase user, anonymous or not.
    @Published private(set) var currentUid: String?

    /// True when the account is anonymous, i.e. tied to this device's Keychain
    /// and lost if the user signs out. Drives the upgrade prompt.
    @Published private(set) var isAnonymous = false

    /// Set when a merge could not be completed in one pass and is waiting for a
    /// retry. Surfaced only in debug; the retry is automatic.
    @Published private(set) var pendingMerge = false

    private lazy var functions = Functions.functions()
    private let db = Firestore.firestore()

    /// Persisted so a merge survives the app being killed between signing in
    /// with Apple and telling the server about it — the exact window where the
    /// user's stand memberships would otherwise be orphaned.
    private let mergeTicketKey = "standPendingMergeTicket"
    private let upgradePromptCountKey = "standUpgradePromptCount"

    /// Asked at most three times, ever. Someone who is not going to sign in
    /// should stop being asked.
    private let maxUpgradePrompts = 3

    private init() {
        refresh()
    }

    // MARK: - State

    func refresh() {
        let user = Auth.auth().currentUser
        currentUid = user?.uid
        isAnonymous = user?.isAnonymous ?? false
    }

    /// Ensure there is SOME account, creating an anonymous one if needed.
    ///
    /// Deliberately never called at launch. Doing so would mint an auth record
    /// for every install that ever opens the app and make every user-count
    /// metric meaningless. It is called at exactly two moments: tapping Invite,
    /// and opening an invite link.
    @discardableResult
    func ensureAccount() async throws -> String {
        if let existing = Auth.auth().currentUser {
            currentUid = existing.uid
            isAnonymous = existing.isAnonymous
            return existing.uid
        }
        let result = try await Auth.auth().signInAnonymously()
        currentUid = result.user.uid
        isAnonymous = true

        // Deliberately NOT AnalyticsService.setUserId. Identifying on an
        // anonymous uid mints a distinct id per device that later has to be
        // aliased, which fragments every funnel in the meantime. Identity is
        // claimed on the Apple link, below.
        AnalyticsService.shared.track("account_anonymous_created", parameters: [
            "trigger": "stand",
        ])
        await registerPushToken(uid: result.user.uid)
        return result.user.uid
    }

    // MARK: - Upgrade prompting

    /// Whether to offer "save your stand" right now.
    ///
    /// Only for anonymous users, and only three times in the life of the
    /// install. An anonymous account is tied to this device's Keychain: it
    /// survives a reinstall but does NOT move to a new phone, which is exactly
    /// what the prompt is warning about.
    var shouldPromptUpgrade: Bool {
        guard isAnonymous else { return false }
        return UserDefaults.standard.integer(forKey: upgradePromptCountKey) < maxUpgradePrompts
    }

    func recordUpgradePromptShown() {
        let n = UserDefaults.standard.integer(forKey: upgradePromptCountKey)
        UserDefaults.standard.set(n + 1, forKey: upgradePromptCountKey)
    }

    // MARK: - Linking anonymous → Apple

    /// Attach a real Apple identity to the current account.
    ///
    /// The happy path links in place and the uid is preserved, so nothing has
    /// to move. The interesting case is `credentialAlreadyInUse`: the person
    /// already has an Apple-backed account — they used the Prayer Wall on an
    /// old phone, or reinstalled — so linking is impossible and they must sign
    /// in AS that account. Without the merge below, that abandons the anonymous
    /// uid and every stand attached to it.
    func link(with credential: AuthCredential) async throws {
        guard let user = Auth.auth().currentUser else {
            _ = try await signInAndMerge(credential: credential, ticket: nil)
            return
        }

        if !user.isAnonymous {
            refresh()
            return
        }

        do {
            let result = try await user.link(with: credential)
            currentUid = result.user.uid
            isAnonymous = false
            claimAnalyticsIdentity(result.user.uid)
            await registerPushToken(uid: result.user.uid)
            AnalyticsService.shared.track("account_linked_apple", parameters: ["trigger": "stand"])
        } catch let error as NSError where
                    AuthErrorCode(rawValue: error.code) == .credentialAlreadyInUse {
            // Take a server-issued ticket BEFORE the auth state changes. The
            // server reads `fromUid` off the token presented here, so a client
            // can never nominate an account it does not currently hold — which
            // is what stops anyone grafting themselves onto a uid they know.
            let ticket = try await beginMerge()
            let updated = (error.userInfo[AuthErrorUserInfoUpdatedCredentialKey]
                           as? AuthCredential) ?? credential
            _ = try await signInAndMerge(credential: updated, ticket: ticket)
        }
    }

    private func beginMerge() async throws -> String {
        let result = try await functions.httpsCallable("beginAccountMerge").call([:])
        guard let ticket = (result.data as? [String: Any])?["ticket"] as? String else {
            throw StandError.malformedResponse
        }
        // Persisted before the auth swap, not after: if the app dies between
        // signing in and calling completeAccountMerge, this is the only record
        // that a migration is owed.
        UserDefaults.standard.set(ticket, forKey: mergeTicketKey)
        pendingMerge = true
        return ticket
    }

    private func signInAndMerge(credential: AuthCredential, ticket: String?) async throws -> String {
        let result = try await Auth.auth().signIn(with: credential)
        currentUid = result.user.uid
        isAnonymous = false
        claimAnalyticsIdentity(result.user.uid)
        await registerPushToken(uid: result.user.uid)

        if ticket != nil { await completePendingMergeIfNeeded() }
        return result.user.uid
    }

    /// Finish a migration that was started but not confirmed.
    ///
    /// Call at launch as well as inline. `completeAccountMerge` is idempotent
    /// server-side, so retrying is free; the only unrecoverable case is the
    /// ticket expiring (ten minutes), which the server reports as not-found and
    /// which clears the flag rather than retrying forever.
    func completePendingMergeIfNeeded() async {
        guard let ticket = UserDefaults.standard.string(forKey: mergeTicketKey),
              Auth.auth().currentUser != nil else { return }
        do {
            let result = try await functions
                .httpsCallable("completeAccountMerge")
                .call(["ticket": ticket])
            let merged = (result.data as? [String: Any])?["merged"] as? Int ?? 0
            UserDefaults.standard.removeObject(forKey: mergeTicketKey)
            pendingMerge = false
            AnalyticsService.shared.track("account_merge_completed", parameters: ["rooms": merged])
            StandService.shared.startListening()
        } catch let error as NSError {
            let code = FunctionsErrorCode(rawValue: error.code)
            if code == .notFound || code == .deadlineExceeded {
                // Spent or expired. Nothing further will make it work, and
                // retrying every launch forever is worse than stopping.
                UserDefaults.standard.removeObject(forKey: mergeTicketKey)
                pendingMerge = false
            }
            print("⚠️ Stand merge retry failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Sign out

    /// Signing out of an anonymous account is unrecoverable — there is no
    /// credential to sign back in with, so every stand attached to it is gone.
    /// Callers must check this and warn before offering sign-out.
    var signOutWouldLoseStands: Bool {
        isAnonymous && !StandService.shared.rooms.isEmpty
    }

    // MARK: - Plumbing

    private func claimAnalyticsIdentity(_ uid: String) {
        // Aliased at the moment a real identity appears, so events recorded
        // while anonymous stay attached to the same person.
        AnalyticsService.shared.setUserId(uid)
    }

    /// Stand nudges resolve `users/{uid}.fcmToken`, and the token has to move
    /// when the uid does or the push lands on nobody.
    private func registerPushToken(uid: String) async {
        guard let token = try? await Messaging.messaging().token() else { return }
        try? await db.collection("users").document(uid).setData([
            "uid": uid,
            "fcmToken": token,
            "tz": StandDayStamp.currentTimeZoneIdentifier,
            "updatedAt": FieldValue.serverTimestamp(),
        ], merge: true)
    }
}
