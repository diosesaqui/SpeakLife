//
//  WeeklyFocusRemoteSelector.swift
//  SpeakLife
//
//  Phase 2: retrieval by model instead of by keyword table.
//
//  Still retrieval, never generation. The model is handed declarations the
//  device already holds and returns which of them to speak, in what order — so
//  there is no hallucinated verse to review and every line still passes the
//  CLAUDE.md rules, exactly as in Phase 1.
//
//  TWO THINGS THIS FILE EXISTS TO PROTECT:
//
//  1. An unanswered week costs zero. Four of the five ladder rungs (carry-over,
//     anchor, profile, behavioral, default) never set `isFreshAnswer`, and the
//     first thing `selectWeek` does is hand those straight to the keyword
//     selector without touching the network. Most users will not answer most
//     weeks, so this is the property that makes weekly personalization viable
//     at all — it is checked before the flag, before entitlement, before
//     anything.
//
//  2. Any failure is invisible. Flag off, offline, 429, paywall, malformed
//     JSON, a week that came back too short — every one of them falls through
//     to `WeeklyFocusContentSelector`, which cannot fail. This mirrors
//     ClaudeDeclarationMatcher → KeywordDeclarationMatcher exactly, and it is
//     why the flag can ship default-off and be turned on without a release.
//

import Foundation

/// The two Phase 2/3 kill switches, in one non-isolated place.
///
/// Both are Remote Config keys mirrored into UserDefaults by
/// `SubscriptionStore.updateConfigValues` and registered FALSE in
/// `AppDelegate`, so an install that has never fetched Remote Config gets
/// Phase 1 behaviour exactly. They live here rather than on the two services
/// because one of those services is `@MainActor` and the mirroring runs off it.
enum WeeklyFocusFlags {
    /// Route an ANSWERED week's selection through the `/weeklyFocus` function.
    static let remoteSelection = "weeklyFocusRemoteSelection"
    /// Show the shared `(needBucket, weekOfYear)` devotional on the overview.
    static let devotionals = "weeklyFocusDevotionalsEnabled"
}

final class WeeklyFocusRemoteSelector: WeeklyFocusSelecting {

    private let fallback: WeeklyFocusContentSelector
    private let session: URLSession
    private let defaults: UserDefaults

    init(fallback: WeeklyFocusContentSelector = WeeklyFocusContentSelector(),
         session: URLSession = .shared,
         defaults: UserDefaults = .standard) {
        self.fallback = fallback
        self.session = session
        self.defaults = defaults
    }

    // MARK: - Endpoint
    //
    // Same host and same local-emulator switch Bible Chat uses, so one scheme
    // env var moves every AI surface at once.

    private static let cloudEndpoint = URL(string: "https://us-central1-speaklife-3e5c4.cloudfunctions.net/weeklyFocus")!
    private static let emulatorEndpoint = URL(string: "http://127.0.0.1:5001/speaklife-3e5c4/us-central1/weeklyFocus")!

    private var endpoint: URL {
        BibleChatLocal.usesEmulator ? Self.emulatorEndpoint : Self.cloudEndpoint
    }

    // MARK: - Tuning

    /// How many declarations the shortlist carries. Bounds the request body and
    /// the prompt; the function caps at 90 regardless, so this is the polite
    /// side of the same number.
    private static let candidateLimit = 90
    /// The floor the function enforces too. Below this it refuses rather than
    /// return a half week.
    private static let candidateMinimum = 14
    private static let timeout: TimeInterval = 25

    // MARK: - WeeklyFocusSelecting

    func selectWeek(input: WeeklyFocusSelectionInput,
                    from pool: [Declaration]) async -> WeeklyFocusSelection {

        // Rung guard, first and unconditional. See the header: this is what
        // keeps every silent week free.
        guard input.isFreshAnswer,
              let needText = input.needText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !needText.isEmpty else {
            return fallback.select(input: input, from: pool)
        }

        guard defaults.bool(forKey: WeeklyFocusFlags.remoteSelection) else {
            return fallback.select(input: input, from: pool)
        }

        let appUserId = RevenueCatManager.shared.appUserID
        guard !appUserId.isEmpty else {
            // Purchases isn't configured yet. Without an identity the function
            // has nothing to check entitlement against or meter on.
            return trackFallback(reason: "no_app_user_id", input: input, pool: pool)
        }

        let candidates = Self.candidates(for: input, from: pool)
        guard candidates.count >= Self.candidateMinimum else {
            return trackFallback(reason: "thin_pool", input: input, pool: pool)
        }

        do {
            let remote = try await call(
                needText: needText,
                input: input,
                appUserId: appUserId,
                candidates: candidates
            )
            guard let selection = Self.selection(from: remote, candidates: candidates, input: input) else {
                return trackFallback(reason: "unusable_selection", input: input, pool: pool)
            }
            AnalyticsService.shared.track("weekly_focus_remote_selection", parameters: [
                "need_bucket": selection.needBucket ?? input.needBucket,
                "count": selection.declarationIDs.count
            ])
            return selection
        } catch RemoteError.needsPaywall {
            // The server disagreed with the client about entitlement. It is
            // authoritative, and the free tier's week is the keyword one.
            return trackFallback(reason: "paywall", input: input, pool: pool)
        } catch RemoteError.rateLimited {
            return trackFallback(reason: "rate_limited", input: input, pool: pool)
        } catch {
            return trackFallback(reason: "\(error)", input: input, pool: pool)
        }
    }

    // MARK: - Fallback

    /// Every failure lands here: one analytics counter, then Phase 1's answer.
    /// Nothing is surfaced to the user, because from their side nothing went
    /// wrong — they still get a full, sequenced, on-theme week.
    private func trackFallback(reason: String,
                               input: WeeklyFocusSelectionInput,
                               pool: [Declaration]) -> WeeklyFocusSelection {
        AnalyticsService.shared.track("weekly_focus_remote_fallback", parameters: [
            "reason": reason,
            "need_bucket": input.needBucket
        ])
        return fallback.select(input: input, from: pool)
    }

    // MARK: - Network

    private enum RemoteError: Error {
        case network
        case http(status: Int)
        case rateLimited
        case needsPaywall
        case malformed
    }

    /// The function's success envelope, flat at the top level.
    private struct RemoteSelection: Decodable {
        let needsPaywall: Bool?
        let needBucket: String?
        let categoryRaw: String?
        let declarationIDs: [String]?
        let framingLine: String?
    }

    private func call(needText: String,
                      input: WeeklyFocusSelectionInput,
                      appUserId: String,
                      candidates: [Declaration]) async throws -> RemoteSelection {

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Self.timeout

        // A hint only. The function re-checks with RevenueCat and its answer
        // wins whenever RC responds; this just covers the case where RC is
        // unreachable server-side, so a payer is never locked out mid-week.
        let premiumClaim = await RevenueCatManager.shared.isPremiumActiveNow()

        var payload: [String: Any] = [
            "appUserId": appUserId,
            "isPremiumClaim": premiumClaim,
            "needText": needText,
            "carryOverCount": input.carryOverCount,
            "angle": input.angle.rawValue,
            // Only id and text. The id never enters the prompt — the function
            // re-attaches it by index — so a model that drifts one character
            // cannot corrupt which declaration the user gets.
            "candidates": candidates.map { ["id": $0.id, "text": $0.text] }
        ]

        // Onboarding already learned what this person is carrying. The function
        // renders a whitelisted subset into a second, UNCACHED system block,
        // and — because `soulProfiles` is server-only in firestore.rules — this
        // request is also the write path that persists the profile.
        // `firestorePayload`, not `requestPayload`: appUserId is already a
        // top-level field here.
        if let profile = SoulProfileRepository.loadSync(), !profile.isEmpty,
           let encodedProfile = SoulProfileFirestoreMirror.firestorePayload(for: profile) {
            payload["profile"] = encodedProfile
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw RemoteError.network }
        if http.statusCode == 429 { throw RemoteError.rateLimited }
        guard http.statusCode == 200 else {
            // Status code only. Never log the response body — it can echo
            // request metadata into analytics.
            AnalyticsService.shared.track("weekly_focus_http_error", parameters: [
                "status": http.statusCode
            ])
            throw RemoteError.http(status: http.statusCode)
        }

        guard let decoded = try? JSONDecoder().decode(RemoteSelection.self, from: data) else {
            throw RemoteError.malformed
        }
        if decoded.needsPaywall == true { throw RemoteError.needsPaywall }
        return decoded
    }

    // MARK: - Response → selection

    /// Maps returned IDs back onto real declarations, then sequences them
    /// across the seven days with Phase 1's round-robin.
    ///
    /// Every ID is re-resolved against the candidates we sent rather than
    /// trusted: the content file is remote-updatable, so a response is only as
    /// valid as the pool the device actually has. Anything that no longer
    /// resolves is dropped, and if that leaves less than a full week we return
    /// nil and let the keyword selector build it.
    private static func selection(from remote: RemoteSelection,
                                  candidates: [Declaration],
                                  input: WeeklyFocusSelectionInput) -> WeeklyFocusSelection? {
        guard let ids = remote.declarationIDs, !ids.isEmpty else { return nil }

        var byID: [String: Declaration] = [:]
        byID.reserveCapacity(candidates.count)
        for candidate in candidates where byID[candidate.id] == nil {
            byID[candidate.id] = candidate
        }

        var picked: [Declaration] = []
        var seen = Set<String>()
        for id in ids {
            guard let declaration = byID[id], seen.insert(id).inserted else { continue }
            picked.append(declaration)
        }

        // Must divide evenly by 7 or `declarationIDs(forDay:)` hands out the
        // wrong lines for the rest of the week.
        guard picked.count >= 14 else { return nil }
        picked = Array(picked.prefix(picked.count >= 21 ? 21 : 14))

        let category = remote.categoryRaw.flatMap { DeclarationCategory(rawValue: $0) }
        let bucket = remote.needBucket?.trimmingCharacters(in: .whitespacesAndNewlines)
        let framing = remote.framingLine?.trimmingCharacters(in: .whitespacesAndNewlines)

        return WeeklyFocusSelection(
            declarationIDs: WeeklyFocusContentSelector.sequence(picked).map { $0.id },
            audioCategoryRaw: (category ?? input.primaryCategory).rawValue,
            categoryRaw: category?.rawValue,
            needBucket: (bucket?.isEmpty == false) ? bucket : nil,
            framingLine: (framing?.isEmpty == false) ? framing : nil
        )
    }

    // MARK: - Shortlist

    /// The declarations the model gets to choose from.
    ///
    /// Three sources, in this order, because the model has to be able to
    /// correct us as well as rank us:
    ///   1. the keyword matcher's category — the most likely right answer;
    ///   2. the angle's supporting categories — the week's flavour;
    ///   3. anything in the WHOLE library whose text matches the user's own
    ///      words, whatever its category — this is the escape hatch. Without
    ///      it the model could only re-rank a classification that was already
    ///      made by a keyword table, and a misclassified need would stay
    ///      misclassified.
    ///
    /// Deterministic: no shuffle, no randomness. The same answer produces the
    /// same shortlist, so a retry after a network failure asks the same
    /// question rather than a different one.
    static func candidates(for input: WeeklyFocusSelectionInput,
                           from pool: [Declaration]) -> [Declaration] {
        let usable = pool.filter {
            $0.contentType == .affirmation
                && $0.category != .favorites
                && $0.category != .myOwn
        }
        guard !usable.isEmpty else { return [] }

        var picked: [Declaration] = []
        var seen = Set<String>()

        func take(_ declarations: [Declaration], limit: Int) {
            var added = 0
            for declaration in declarations {
                guard picked.count < candidateLimit, added < limit else { return }
                guard seen.insert(declaration.id).inserted else { continue }
                picked.append(declaration)
                added += 1
            }
        }

        take(usable.filter { $0.category == input.primaryCategory }, limit: 40)

        var support = input.angle.supportCategories.filter { $0 != input.primaryCategory }
        if let variety = input.varietyCategory, !support.contains(variety),
           variety != input.primaryCategory {
            support.append(variety)
        }
        let supportSet = Set(support)
        take(usable.filter { supportSet.contains($0.category) }, limit: 30)

        let keywords = Self.keywords(from: input.needText)
        if !keywords.isEmpty {
            take(usable.filter { declaration in
                let text = declaration.text.lowercased()
                return keywords.contains { text.contains($0) }
            }, limit: 20)
        }

        // A narrow category can leave the shortlist under the function's floor.
        // Topping up from the front of the library is deterministic and keeps
        // the request valid; the model simply has more to reject.
        if picked.count < candidateMinimum {
            take(usable, limit: candidateLimit)
        }

        return picked
    }

    /// Content words from the user's sentence. Same crude rule the keyword
    /// selector uses — this is a reach-widener for the shortlist, not a
    /// classifier.
    private static func keywords(from needText: String?) -> [String] {
        guard let needText, !needText.isEmpty else { return [] }
        let stopWords: Set<String> = [
            "that", "this", "with", "from", "have", "been", "will", "just",
            "about", "what", "when", "they", "them", "there", "their",
            "would", "could", "should", "because", "myself", "really", "going",
            "need", "want", "help", "please", "thing", "things", "lord", "god",
            "jesus", "pray", "prayer", "praying"
        ]
        var seen = Set<String>()
        var result: [String] = []
        for raw in needText.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted) {
            guard raw.count >= 4, !stopWords.contains(raw) else { continue }
            guard seen.insert(raw).inserted else { continue }
            result.append(raw)
            if result.count == 8 { break }
        }
        return result
    }
}
