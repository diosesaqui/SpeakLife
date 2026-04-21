//
//  PrayerWallViewModel.swift
//  SpeakLife
//
//  ViewModel for the community Prayer Wall feed.
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

    // MARK: - Prayed Post IDs
    private let prayedPostIdsKey = "prayedPostIds"
    private var prayedPostIds: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: prayedPostIdsKey) ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: prayedPostIdsKey)
        }
    }

    init() {
        self.deviceId = PrayerWallViewModel.getDeviceId()
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

    // MARK: - Add Post

    func addPost(text: String, isSister: Bool) {
        guard networkMonitor.currentPath.status != .unsatisfied else {
            errorMessage = "You are offline. Please connect to the internet to post."
            return
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Prayer request cannot be empty."
            return
        }

        // Rate limit: 1 post per 24 hours
        checkTodaysPostCount { [weak self] count in
            guard let self = self else { return }
            if count >= 1 {
                DispatchQueue.main.async {
                    self.errorMessage = "You've already shared a prayer today. Come back tomorrow!"
                }
                return
            }
            self.submitPost(text: text, isSister: isSister)
        }
    }

    private func submitPost(text: String, isSister: Bool) {
        isSubmitting = true
        let displayName = isSister ? "A sister in Christ" : "A brother in Christ"
        let newPost = PrayerWallPost(text: text, displayName: displayName, deviceId: deviceId)

        do {
            _ = try db.collection(collection).addDocument(from: newPost) { [weak self] error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isSubmitting = false
                    if let error = error {
                        self.errorMessage = "Error posting prayer: \(error.localizedDescription)"
                    } else {
                        self.submissionMessage = "Your prayer has been shared 🙏"
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

    // MARK: - Pray For Post

    func prayForPost(_ post: PrayerWallPost) {
        guard let id = post.id else { return }
        guard !hasPrayed(for: post) else { return }

        var updated = prayedPostIds
        updated.insert(id)
        prayedPostIds = updated

        // Update local state immediately
        if let idx = posts.firstIndex(where: { $0.id == id }) {
            posts[idx].prayerCount += 1
        }
        if let idx = myPosts.firstIndex(where: { $0.id == id }) {
            myPosts[idx].prayerCount += 1
        }

        db.collection(collection).document(id)
            .updateData(["prayerCount": FieldValue.increment(Int64(1))]) { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Error saving prayer: \(error.localizedDescription)"
                    }
                }
            }
    }

    func hasPrayed(for post: PrayerWallPost) -> Bool {
        guard let id = post.id else { return false }
        return prayedPostIds.contains(id)
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
