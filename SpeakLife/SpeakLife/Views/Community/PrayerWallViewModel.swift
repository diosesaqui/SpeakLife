//
//  PrayerWallViewModel.swift
//  SpeakLife
//
//  ViewModel for the community Warrior Room (Prayer Wall) feed.
//

import SwiftUI
import FirebaseFirestore
import FirebaseMessaging
import Network

class PrayerWallViewModel: ObservableObject {
    @Published var posts: [PrayerWallPost] = []
    @Published var myPosts: [PrayerWallPost] = []
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var submissionMessage: String?
    @Published var isShowingPostForm = false
    /// False until we detect the last batch was smaller than batchSize,
    /// meaning there are no more posts to page through.
    @Published var hasMore = true

    /// Active feed filter — nil = "All". Persists for the session only.
    @Published var categoryFilter: WarriorRoomCategory?

    /// Agreements loaded per post, keyed by post.id. Loaded lazily on expand.
    @Published var agreementsByPost: [String: [Agreement]] = [:]
    @Published var loadingAgreementsForPost: Set<String> = []

    private let db = Firestore.firestore()
    private let collection = "prayerWall"
    private let batchSize = 15
    private let reportThreshold = 3
    private let cacheKey = "cachedPrayerWallPosts"
    private let lastFetchKey = "prayerWallLastFetch"
    private let fetchCooldown: TimeInterval = 300
    private let dailyFetchKey = "prayerWallDailyFetch"
    private let dailyCooldown: TimeInterval = 86400

    private var lastDocument: DocumentSnapshot?
    /// True once at least one live network fetch has completed this session.
    /// Used by the view to avoid resetting the pagination cursor on every
    /// onAppear (e.g. after sheet dismissals).
    private(set) var hasFetchedFromNetwork = false
    private let networkMonitor = NWPathMonitor()
    let deviceId: String

    // MARK: - Local user state

    /// Maps post.id → reaction raw value for the current user's chosen reaction.
    /// Backed by UserDefaults so it survives app restarts.
    private let userReactionsKey = "warriorRoomUserReactions"
    private let legacyPrayedPostIdsKey = "prayedPostIds"

    private var userReactions: [String: String] {
        get {
            UserDefaults.standard.dictionary(forKey: userReactionsKey) as? [String: String] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userReactionsKey)
        }
    }

    /// Posts the current user has already added an agreement to.
    private let userAgreementPostIdsKey = "warriorRoomUserAgreements"
    private var userAgreementPostIds: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: userAgreementPostIdsKey) ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: userAgreementPostIdsKey)
        }
    }

    init() {
        self.deviceId = PrayerWallViewModel.getDeviceId()
        migrateLegacyPrayedPostIdsIfNeeded()
        loadCachedPosts()
        monitorNetwork()
        fetchPostsIfNeeded()
    }

    // MARK: - Device ID

    static func getDeviceId() -> String {
        let key = "prayerWallDeviceId"
        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        } else {
            let newId = UUID().uuidString
            UserDefaults.standard.set(newId, forKey: key)
            return newId
        }
    }

    // MARK: - Migration

    /// One-shot migration: every post the user previously prayed for becomes
    /// a "standing" reaction so their selection state survives the upgrade.
    private func migrateLegacyPrayedPostIdsIfNeeded() {
        PrayerWallViewModel.migrateLegacyPrayedPostIds(in: .standard)
    }

    /// Pure-logic migration extracted for testability. Idempotent: subsequent
    /// calls are no-ops once the migration flag is set.
    static func migrateLegacyPrayedPostIds(in defaults: UserDefaults) {
        let migrationFlagKey = "warriorRoomUserReactionsMigrated"
        let legacyKey = "prayedPostIds"
        let reactionsKey = "warriorRoomUserReactions"

        guard !defaults.bool(forKey: migrationFlagKey) else { return }

        let legacyIds = defaults.stringArray(forKey: legacyKey) ?? []
        if !legacyIds.isEmpty {
            var migrated = (defaults.dictionary(forKey: reactionsKey) as? [String: String]) ?? [:]
            for id in legacyIds where migrated[id] == nil {
                migrated[id] = WarriorRoomReaction.standing.rawValue
            }
            defaults.set(migrated, forKey: reactionsKey)
        }
        defaults.set(true, forKey: migrationFlagKey)
    }

    // MARK: - Cache

    private func loadCachedPosts() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([PrayerWallPost].self, from: data) {
            self.posts = decoded
        }
    }

    private func cachePosts() {
        if let encoded = try? JSONEncoder().encode(posts) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastFetchKey)
        }
    }

    // MARK: - Network Monitor

    private func monitorNetwork() {
        networkMonitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status == .unsatisfied {
                    self.errorMessage = "No internet connection. Some features may not work."
                }
            }
        }
        let queue = DispatchQueue(label: "PrayerWallNetworkMonitor")
        networkMonitor.start(queue: queue)
    }

    // MARK: - Fetch Posts

    private func fetchPostsIfNeeded() {
        let lastFetch = UserDefaults.standard.double(forKey: lastFetchKey)
        let lastDailyFetch = UserDefaults.standard.double(forKey: dailyFetchKey)
        let now = Date().timeIntervalSince1970

        if now - lastDailyFetch > dailyCooldown {
            fetchPosts(reset: true)
            UserDefaults.standard.set(now, forKey: dailyFetchKey)
        } else if now - lastFetch > fetchCooldown {
            fetchPosts(reset: true)
        }
    }

    func fetchPosts(reset: Bool = false, retryCount: Int = 3) {
        if isLoading { return }
        isLoading = true
        errorMessage = nil

        if reset {
            lastDocument = nil
            hasMore = true
        }

        // Guard: if there is no cursor and this is a "load more" request,
        // the initial fetch hasn't completed yet. Bail out to avoid querying
        // from the beginning and appending duplicates on top of cached data.
        if !reset && lastDocument == nil {
            isLoading = false
            return
        }

        var query: Query = db.collection(collection)
            .whereField("isHidden", isEqualTo: false)
            .order(by: "timestamp", descending: true)
            .limit(to: batchSize)

        if let lastDoc = lastDocument, !reset {
            query = query.start(afterDocument: lastDoc)
        }

        query.getDocuments { [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                if let error = error as NSError? {
                    if error.code == FirestoreErrorCode.resourceExhausted.rawValue && retryCount > 0 {
                        let retryDelay = pow(2.0, Double(3 - retryCount))
                        DispatchQueue.global().asyncAfter(deadline: .now() + retryDelay) {
                            self.fetchPosts(reset: reset, retryCount: retryCount - 1)
                        }
                        return
                    }
                    if error.domain == NSURLErrorDomain && retryCount > 0 {
                        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                            self.fetchPosts(reset: reset, retryCount: retryCount - 1)
                        }
                        return
                    }
                    self.errorMessage = "Error loading prayers. Please try again."
                    return
                }

                guard let documents = snapshot?.documents else {
                    return
                }

                let newPosts = documents.compactMap { try? $0.data(as: PrayerWallPost.self) }

                if reset {
                    self.posts = newPosts
                } else {
                    // Deduplicate before appending — safety net against any
                    // edge case where the same page could be fetched twice.
                    let existingIds = Set(self.posts.compactMap { $0.id })
                    let uniqueNew = newPosts.filter { $0.id == nil || !existingIds.contains($0.id!) }
                    self.posts.append(contentsOf: uniqueNew)
                }

                self.cachePosts()
                // Only advance the cursor when documents actually came back.
                if let last = documents.last {
                    self.lastDocument = last
                }
                // If we got fewer documents than batchSize we've hit the end.
                self.hasMore = documents.count >= self.batchSize
                self.hasFetchedFromNetwork = true
            }
        }
    }

    func fetchMyPosts() {
        db.collection(collection)
            .whereField("deviceId", isEqualTo: deviceId)
            .order(by: "timestamp", descending: true)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if let error = error {
                        self.errorMessage = "Error loading your prayers: \(error.localizedDescription)"
                        return
                    }
                    self.myPosts = (snapshot?.documents ?? []).compactMap {
                        try? $0.data(as: PrayerWallPost.self)
                    }
                }
            }
    }

    // MARK: - Filtered feed

    /// `posts` filtered by the active category. Returns all posts if no filter
    /// is selected. Posts without a category are only shown under "All".
    var filteredPosts: [PrayerWallPost] {
        guard let filter = categoryFilter else { return posts }
        return posts.filter { $0.category == filter.rawValue }
    }

    // MARK: - Add Post

    func addPost(text: String, isSister: Bool, category: WarriorRoomCategory) {
        guard networkMonitor.currentPath.status != .unsatisfied else {
            errorMessage = "You are offline. Please connect to the internet to post."
            return
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Declaration cannot be empty."
            return
        }

        // Rate limit: 1 post per 24 hours
        checkTodaysPostCount { [weak self] count in
            guard let self = self else { return }
            if count >= 1 {
                DispatchQueue.main.async {
                    self.errorMessage = "You've already declared today. Come back tomorrow to take more ground."
                }
                return
            }
            self.submitPost(text: text, isSister: isSister, category: category)
        }
    }

    private func submitPost(text: String, isSister: Bool, category: WarriorRoomCategory) {
        isSubmitting = true
        let displayName = isSister ? "A sister in Christ" : "A brother in Christ"
        let newPost = PrayerWallPost(text: text,
                                     displayName: displayName,
                                     deviceId: deviceId,
                                     category: category)

        do {
            _ = try db.collection(collection).addDocument(from: newPost) { [weak self] error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isSubmitting = false
                    if let error = error {
                        self.errorMessage = "Error posting declaration: \(error.localizedDescription)"
                    } else {
                        self.submissionMessage = "Your declaration is on the wall \u{1F525}"
                        self.fetchPosts(reset: true)
                        self.fetchMyPosts()
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isSubmitting = false
                self.errorMessage = "Unexpected error occurred."
            }
        }
    }

    private func checkTodaysPostCount(completion: @escaping (Int) -> Void) {
        let localStartOfDay = Calendar.current.startOfDay(for: Date())
        let utcStartOfDay = Calendar(identifier: .gregorian).date(
            byAdding: .second,
            value: -TimeZone.current.secondsFromGMT(),
            to: localStartOfDay
        ) ?? localStartOfDay

        db.collection(collection)
            .whereField("deviceId", isEqualTo: deviceId)
            .whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: utcStartOfDay))
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking post count: \(error.localizedDescription)")
                    completion(0)
                    return
                }
                completion(snapshot?.documents.count ?? 0)
            }
    }

    // MARK: - Legacy compatibility shims
    //
    // Kept so the existing PrayerWallView (single 🙏 button, no category)
    // continues to compile and run while the v2 UI is built out. Both shims
    // delegate to the new reaction / category APIs and are safe to remove
    // once the View has been migrated.

    /// Old single-reaction API. Treats a tap as a "standing" reaction.
    /// Idempotent — does nothing if the user already reacted.
    func prayForPost(_ post: PrayerWallPost) {
        guard reaction(for: post) == nil else { return }
        toggleReaction(.standing, on: post)
    }

    /// Old composer API — defaults the category to `.faith` for posts created
    /// before the category selector ships in the UI.
    func addPost(text: String, isSister: Bool) {
        addPost(text: text, isSister: isSister, category: .faith)
    }

    // MARK: - Reactions

    /// The current user's reaction on a post, if any.
    func reaction(for post: PrayerWallPost) -> WarriorRoomReaction? {
        guard let id = post.id, let raw = userReactions[id] else { return nil }
        return WarriorRoomReaction(rawValue: raw)
    }

    /// Backwards-compat shim for any caller that still asks "did the user pray
    /// for this post?". Returns true if any reaction is set.
    func hasPrayed(for post: PrayerWallPost) -> Bool {
        reaction(for: post) != nil
    }

    /// Toggle a reaction on a post. Tapping the currently-selected reaction
    /// clears it; tapping a different reaction switches to it.
    func toggleReaction(_ reaction: WarriorRoomReaction, on post: PrayerWallPost) {
        guard let id = post.id else { return }
        let existing = self.reaction(for: post)

        if existing == reaction {
            // Toggle off
            applyReactionDelta(postId: id, remove: existing, add: nil)
        } else {
            // Switch / add
            applyReactionDelta(postId: id, remove: existing, add: reaction)
        }
    }

    /// Mutates local state, persists user state, and writes denormalised
    /// counts to Firestore. `prayerCount` is kept in sync with the running
    /// total so the existing milestone Cloud Function continues to fire.
    private func applyReactionDelta(postId: String,
                                    remove: WarriorRoomReaction?,
                                    add: WarriorRoomReaction?) {
        // Local state
        var reactions = userReactions
        if add != nil {
            reactions[postId] = add!.rawValue
        } else {
            reactions.removeValue(forKey: postId)
        }
        userReactions = reactions

        let mutate: (inout PrayerWallPost) -> Void = { post in
            var counts = post.reactionCounts ?? [:]

            // Migrate legacy posts: hydrate counts from the old prayerCount
            // before we start mutating, so we don't lose existing taps.
            if post.reactionCounts == nil && post.prayerCount > 0 {
                counts[WarriorRoomReaction.standing.rawValue] = post.prayerCount
            }

            if let r = remove {
                counts[r.rawValue] = max(0, (counts[r.rawValue] ?? 0) - 1)
            }
            if let a = add {
                counts[a.rawValue] = (counts[a.rawValue] ?? 0) + 1
            }
            post.reactionCounts = counts
            post.prayerCount = counts.values.reduce(0, +)
        }

        if let idx = posts.firstIndex(where: { $0.id == postId }) {
            mutate(&posts[idx])
        }
        if let idx = myPosts.firstIndex(where: { $0.id == postId }) {
            mutate(&myPosts[idx])
        }

        // Firestore: denormalised increment per reaction key + total prayerCount.
        // Using FieldValue.increment keeps writes commutative and conflict-free.
        var updates: [String: Any] = [:]
        var totalDelta: Int64 = 0
        if let r = remove {
            updates["reactionCounts.\(r.rawValue)"] = FieldValue.increment(Int64(-1))
            totalDelta -= 1
        }
        if let a = add {
            updates["reactionCounts.\(a.rawValue)"] = FieldValue.increment(Int64(1))
            totalDelta += 1
        }
        if totalDelta != 0 {
            updates["prayerCount"] = FieldValue.increment(totalDelta)
        }

        guard !updates.isEmpty else { return }
        db.collection(collection).document(postId)
            .updateData(updates) { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Error saving reaction: \(error.localizedDescription)"
                    }
                }
            }
    }

    // MARK: - Mark As Answered

    func markAsAnswered(_ post: PrayerWallPost) {
        guard let id = post.id else { return }

        // Update local state
        if let idx = myPosts.firstIndex(where: { $0.id == id }) {
            myPosts[idx].isAnswered = true
        }
        if let idx = posts.firstIndex(where: { $0.id == id }) {
            posts[idx].isAnswered = true
        }

        db.collection(collection).document(id)
            .updateData(["isAnswered": true]) { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Error updating prayer: \(error.localizedDescription)"
                    }
                }
            }
    }

    // MARK: - Report Post

    func reportPost(_ post: PrayerWallPost) {
        guard let id = post.id else { return }
        let ref = db.collection(collection).document(id)

        ref.updateData(["reports": FieldValue.increment(Int64(1))]) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let error = error {
                    self.errorMessage = "Error reporting prayer: \(error.localizedDescription)"
                } else {
                    let newReports = post.reports + 1
                    if newReports >= self.reportThreshold {
                        ref.updateData(["isHidden": true]) { _ in
                            DispatchQueue.main.async {
                                self.fetchPosts(reset: true)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Agreements

    /// Whether the current user has already added an agreement to this post.
    func hasAgreed(on post: PrayerWallPost) -> Bool {
        guard let id = post.id else { return false }
        return userAgreementPostIds.contains(id)
    }

    /// Lazily load the agreements subcollection for a post on expand.
    func loadAgreements(for post: PrayerWallPost) {
        guard let id = post.id else { return }
        guard !loadingAgreementsForPost.contains(id) else { return }
        loadingAgreementsForPost.insert(id)

        db.collection(collection).document(id).collection("agreements")
            .order(by: "timestamp", descending: false)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.loadingAgreementsForPost.remove(id)
                    if let error = error {
                        print("⚠️ WarriorRoom: Failed to load agreements: \(error.localizedDescription)")
                        return
                    }
                    let items = (snapshot?.documents ?? []).compactMap {
                        try? $0.data(as: Agreement.self)
                    }
                    self.agreementsByPost[id] = items
                }
            }
    }

    /// Add an agreement to a post. Enforces one per user per post and 150-char cap.
    /// Fire-and-forget per spec — caller treats this as non-blocking.
    func addAgreement(to post: PrayerWallPost,
                      reaction: WarriorRoomReaction,
                      text: String,
                      userId: String,
                      displayName: String) {
        guard let postId = post.id else { return }
        // userId becomes the document id, so an empty userId would write to
        // an invalid Firestore path. Treat sign-out races as a no-op.
        guard !userId.isEmpty else { return }
        guard !userAgreementPostIds.contains(postId) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let capped = String(trimmed.prefix(Agreement.maxLength))

        // Mark locally first so the UI reflects the action immediately.
        var ids = userAgreementPostIds
        ids.insert(postId)
        userAgreementPostIds = ids

        let agreement = Agreement(
            id: nil,
            userId: userId,
            displayName: displayName,
            reactionType: reaction.rawValue,
            text: capped,
            timestamp: Timestamp()
        )

        // Optimistic local insert
        var existing = agreementsByPost[postId] ?? []
        existing.append(agreement)
        agreementsByPost[postId] = existing

        do {
            // Document id = userId enforces "max 1 agreement per user per post".
            try db.collection(collection).document(postId)
                .collection("agreements").document(userId)
                .setData(from: agreement) { [weak self] error in
                    if let error = error {
                        DispatchQueue.main.async {
                            self?.errorMessage = "Error saving agreement: \(error.localizedDescription)"
                        }
                    }
                }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Unexpected error saving agreement."
            }
        }
    }

    // MARK: - FCM Registration

    func registerForPrayerWallNotifications(uid: String, fcmToken: String) {
        guard !uid.isEmpty else { return }

        Messaging.messaging().subscribe(toTopic: "prayerWall") { error in
            if let error = error {
                print("⚠️ PrayerWall: Failed to subscribe to FCM topic: \(error.localizedDescription)")
            }
        }

        // 2. Persist FCM token to Firestore so Cloud Functions can look it up.
        //    Save under BOTH the auth uid AND the local deviceId.
        //    The milestone Cloud Function looks up users/{deviceId}, while
        //    other auth-based lookups use users/{uid}.
        guard !fcmToken.isEmpty else { return }
        let tokenData: [String: Any] = [
            "fcmToken": fcmToken,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        db.collection("users").document(uid).setData(tokenData, merge: true) { error in
            if let error = error {
                print("⚠️ PrayerWall: Failed to save FCM token (uid): \(error.localizedDescription)")
            }
        }
        db.collection("users").document(deviceId).setData(tokenData, merge: true) { error in
            if let error = error {
                print("⚠️ PrayerWall: Failed to save FCM token (deviceId): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Refresh

    func refresh() {
        lastDocument = nil
        hasMore = true
        fetchPosts(reset: true)
        fetchMyPosts()
    }

    deinit {
        networkMonitor.cancel()
    }
}
