//
//  SpeakLifeMessagesView.swift
//  SpeakLife
//
//  The "Inbox" — a public timeline of every broadcast message sent through
//  the sendPersonalMessage Cloud Function. The function writes each allUsers
//  broadcast to the `speakLifeMessages` Firestore collection, so the history
//  is visible to every user, including those who installed after a message
//  was sent or never tapped its push notification. Tapping a card opens the
//  same RemoteMessageView sheet (with the Amen CTA) a notification tap shows.
//
//  This used to be a third segment inside the Warrior Room, which buried it
//  two taps deep. It now owns a top-level dashboard tab (SpeakLifeInboxView).
//

import SwiftUI
import FirebaseFirestore

// MARK: - Model

/// Plain Codable (no @DocumentID / Timestamp fields) so the UserDefaults
/// JSON cache actually round-trips — Firestore's @DocumentID throws under
/// JSONEncoder/JSONDecoder, which would silently kill the cache.
struct SpeakLifeMessage: Identifiable, Codable {
    let id: String
    let title: String
    let body: String
    /// Optional: a doc read back in the same instant it was created can
    /// briefly have a nil server timestamp.
    let sentAt: Date?

    init(document: DocumentSnapshot) {
        self.id = document.documentID
        self.title = document.get("title") as? String ?? ""
        self.body = document.get("body") as? String ?? ""
        self.sentAt = (document.get("sentAt") as? Timestamp)?.dateValue()
    }
}

// MARK: - ViewModel

class SpeakLifeMessagesViewModel: ObservableObject {
    @Published var messages: [SpeakLifeMessage] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private let collection = "speakLifeMessages"
    private let batchSize = 25
    private let cacheKey = "cachedSpeakLifeMessages"

    private var lastDocument: DocumentSnapshot?
    /// True once at least one live network fetch has completed this session,
    /// so re-appearing (tab switches, sheet dismissals) doesn't reset the
    /// pagination cursor.
    private(set) var hasFetchedFromNetwork = false
    private var hasLoadedCache = false

    func fetchIfNeeded() {
        // Cache decode is deferred to the first tab open so app launch
        // (PrayerWallView is built with the TabView) doesn't pay for it.
        if !hasLoadedCache {
            hasLoadedCache = true
            loadCachedMessages()
        }
        guard !hasFetchedFromNetwork else { return }
        fetch(reset: true)
    }

    /// Awaitable so pull-to-refresh keeps its indicator up until the data
    /// actually lands instead of dismissing immediately.
    func refresh() async {
        await withCheckedContinuation { continuation in
            fetch(reset: true) { continuation.resume() }
        }
    }

    func fetch(reset: Bool, completion: (() -> Void)? = nil) {
        guard !isLoading else { completion?(); return }
        // A load-more before the initial fetch ever completed would re-run
        // the unanchored first-page query and append duplicates on top of
        // cached data. Bail like the Warrior Room feed does.
        if !reset && lastDocument == nil { completion?(); return }
        isLoading = true
        errorMessage = nil

        var query: Query = db.collection(collection)
            .order(by: "sentAt", descending: true)
            .limit(to: batchSize)
        if !reset, let lastDocument {
            query = query.start(afterDocument: lastDocument)
        }

        query.getDocuments { [weak self] snapshot, error in
            DispatchQueue.main.async {
                defer { completion?() }
                guard let self else { return }
                self.isLoading = false
                guard error == nil, let snapshot else {
                    self.errorMessage = "Error loading messages. Please try again."
                    return
                }

                self.hasFetchedFromNetwork = true
                let batch = snapshot.documents.map(SpeakLifeMessage.init)
                if reset {
                    self.messages = batch
                    // A failed reset leaves the old cursor intact (it is only
                    // replaced here, on success), so pagination stays valid.
                    self.lastDocument = snapshot.documents.last
                    self.cacheMessages()
                } else {
                    // Dedup by id — safety net against any edge case where
                    // the same page arrives twice.
                    let existingIds = Set(self.messages.map(\.id))
                    self.messages += batch.filter { !existingIds.contains($0.id) }
                    // Only advance the cursor when documents actually came
                    // back; an empty page must not reset it to nil.
                    if let last = snapshot.documents.last {
                        self.lastDocument = last
                    }
                }
                self.hasMore = snapshot.documents.count == self.batchSize
            }
        }
    }

    // MARK: - Cache

    /// Only the first page is cached — enough for an instant paint while the
    /// live fetch runs (matches the Warrior Room feed's approach).
    private func cacheMessages() {
        if let encoded = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }

    private func loadCachedMessages() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([SpeakLifeMessage].self, from: data) {
            self.messages = decoded
        }
    }
}

// MARK: - Unread Tracking

/// Drives the red badge on the dashboard's Inbox tile.
///
/// Two integers, subtracted. The server keeps a monotonic broadcast sequence
/// in one tiny public doc (`speakLifeMessagesMeta/summary`, bumped by the same
/// Cloud Function that publishes a message); the device keeps the sequence it
/// last read. The badge is the difference.
///
/// That shape buys three things a "count the unread documents" approach can't:
/// the count arrives from a **single-document snapshot listener**, so it costs
/// one read rather than a collection scan per dashboard visit; the listener
/// pushes a new badge **live** the instant a broadcast lands, with no polling
/// and nothing to refresh on foreground; and Firestore serves that doc from
/// its **offline cache**, so the badge paints at launch with no network.
///
/// Read state is one small number however long the history grows, and it
/// syncs because its UserDefaults key is whitelisted in `SyncedSettingsStore`
/// under the `.maxInt` strategy — mirrored to the user's other devices through
/// the app's Core Data + CloudKit stack (`NSPersistentCloudKitContainer`,
/// container `iCloud.com.franchiz.speaklife`). Merging by max is exactly the
/// right rule for a read pointer: the furthest-read device wins, so a device
/// that has been offline for a week can never resurrect messages already read
/// somewhere else. No sign-in involved — it follows the iCloud account, same
/// as streaks and favorites.
final class InboxUnreadTracker: ObservableObject {

    static let shared = InboxUnreadTracker()

    @Published private(set) var unreadCount = 0

    /// Whitelisted in SyncedSettingsStore — keep the two in step.
    static let readSeqKey = "inboxReadSeq"

    private let db = Firestore.firestore()
    private let metaCollection = "speakLifeMessagesMeta"
    private let metaDocument = "summary"

    private var listener: ListenerRegistration?
    /// Newest sequence the server has published. 0 until the doc arrives.
    private var publishedSeq = 0
    /// True while the Inbox is on screen, so a message landing mid-read is
    /// counted as read instead of badging the tile the user is looking at.
    private var isViewing = false

    /// Block-based observers deregister by token, not by `self`.
    private var syncObserver: NSObjectProtocol?

    private init() {
        // Another device reading the Inbox arrives as a synced-settings apply,
        // so this device's badge clears without waiting for a relaunch.
        syncObserver = NotificationCenter.default.addObserver(
            forName: SyncedSettingsStore.settingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let keys = notification.userInfo?["keys"] as? Set<String>
            guard keys?.contains(Self.readSeqKey) == true else { return }
            self?.recompute()
        }
    }

    deinit {
        listener?.remove()
        if let syncObserver {
            NotificationCenter.default.removeObserver(syncObserver)
        }
    }

    private var readSeq: Int {
        get { UserDefaults.standard.integer(forKey: Self.readSeqKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.readSeqKey) }
    }

    /// Begin watching the counter. Idempotent — call it from anywhere the
    /// badge is about to be shown.
    func start() {
        guard listener == nil else { return }
        listener = db.collection(metaCollection)
            .document(metaDocument)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self else { return }
                // On error the snapshot is nil: keep the last known sequence
                // rather than collapsing the badge to zero.
                guard let snapshot else { return }
                let seq = (snapshot.get("seq") as? NSNumber)?.intValue ?? 0
                self.publishedSeq = seq
                self.seedReadSeqIfNeeded(to: seq)
                // A broadcast landing while the Inbox is open is already read.
                if self.isViewing {
                    self.markRead()
                } else {
                    self.recompute()
                }
            }
    }

    /// A device with no read history starts caught up, so a brand-new user
    /// isn't greeted by a badge counting the entire broadcast history.
    private func seedReadSeqIfNeeded(to seq: Int) {
        guard UserDefaults.standard.object(forKey: Self.readSeqKey) == nil else { return }
        readSeq = seq
    }

    private func recompute() {
        let unread = max(0, publishedSeq - readSeq)
        guard unread != unreadCount else { return }
        unreadCount = unread
    }

    /// The Inbox is on screen. Everything published so far counts as read, and
    /// so does anything that lands while it stays open — which also covers the
    /// race where the user opens the Inbox before the counter has loaded.
    func beginViewing() {
        isViewing = true
        markRead()
    }

    func endViewing() {
        isViewing = false
    }

    private func markRead() {
        if publishedSeq > readSeq {
            readSeq = publishedSeq
        }
        recompute()
    }
}

// MARK: - Inbox Screen

/// Top-level "Inbox" tab: every broadcast SpeakLife has sent, newest first.
/// Owns the message list, its view model, and the single reader sheet that
/// serves every card. Also presented as a sheet from the notification
/// reader's "See All SpeakLife Messages" CTA.
struct SpeakLifeInboxView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @StateObject private var viewModel = SpeakLifeMessagesViewModel()
    @State private var selectedMessage: RemoteMessage?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.xs)
                    .padding(.bottom, DS.Spacing.sm)
                    .dsAppear(0)

                SpeakLifeMessagesListView(viewModel: viewModel) { message in
                    selectedMessage = RemoteMessage(title: message.title,
                                                    body: message.body)
                }
            }
            // Seeing the list is reading it. The tracker holds a "viewing"
            // flag rather than taking a one-shot mark, so it doesn't matter
            // whether the counter loads before or after this screen opens.
            .onAppear {
                InboxUnreadTracker.shared.start()
                InboxUnreadTracker.shared.beginViewing()
            }
            .onDisappear { InboxUnreadTracker.shared.endViewing() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The backdrop is a .background modifier rather than a ZStack
            // sibling so only IT bleeds under the status and nav bars. As a
            // sibling its .ignoresSafeArea() grew the whole stack, which
            // pulled the content up until the inline title drew on top of the
            // first card.
            .background(
                ZStack {
                    Image(subscriptionStore.onboardingBGImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: UIScreen.main.bounds.width,
                               height: UIScreen.main.bounds.height)
                        .clipped()

                    Color.black.opacity(0.50)
                }
                .ignoresSafeArea()
            )
            .navigationTitle("Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .navigationViewStyle(.stack)
        .sheet(item: $selectedMessage) { message in
            RemoteMessageView(message: message)
        }
    }

    private var header: some View {
        Text("Every word God has put on our heart for you.")
            .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .body))
            .foregroundColor(.white.opacity(0.65))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - List View

/// The message list itself. Kept separate from `SpeakLifeInboxView` so the
/// owner supplies the reader sheet via `onSelect` — one sheet in the
/// hierarchy serves every card.
struct SpeakLifeMessagesListView: View {
    @ObservedObject var viewModel: SpeakLifeMessagesViewModel
    let onSelect: (SpeakLifeMessage) -> Void

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.messages.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.4)
                    Spacer()
                }
            } else if viewModel.messages.isEmpty {
                ScrollView {
                    emptyState
                        .frame(maxWidth: .infinity)
                }
                .refreshable { await viewModel.refresh() }
            } else {
                messageList
            }
        }
        .onAppear { viewModel.fetchIfNeeded() }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(viewModel.messages) { message in
                    SpeakLifeMessageCard(message: message) {
                        onSelect(message)
                    }
                }

                if viewModel.hasMore {
                    Button {
                        viewModel.fetch(reset: false)
                    } label: {
                        if viewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Load more…")
                                .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .body))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .buttonStyle(.dsPressable(feel: .tapSolid))
                    .disabled(viewModel.isLoading)
                    .padding(.vertical, DS.Spacing.md)
                } else {
                    VStack(spacing: 6) {
                        Text("🕊️")
                            .font(.title2)
                        Text("You're all caught up")
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .body))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.vertical, 20)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.xxs)
            .padding(.bottom, 30)
        }
        .refreshable { await viewModel.refresh() }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Spacer()
            Image(systemName: "envelope.open.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "A78BFA").opacity(0.7))
            Text("Messages from SpeakLife will appear here.\nCheck back soon.")
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 16, relativeTo: .body))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .italic()
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: - Card

struct SpeakLifeMessageCard: View {
    let message: SpeakLifeMessage
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack {
                    Text("Messages from SpeakLife")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
                        .foregroundColor(Color(hex: "A78BFA"))
                    Spacer()
                    if let sentAt = message.sentAt {
                        Text(sentAt.formatted(date: .abbreviated, time: .omitted))
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 12, relativeTo: .caption))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }

                if !message.title.isEmpty {
                    Text(message.title)
                        .font(Font.custom("AppleSDGothicNeo-Bold", size: 17, relativeTo: .headline))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                }

                Text(message.body)
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 15, relativeTo: .body))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(4)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)

                Text("Read & Amen →")
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 13, relativeTo: .caption))
                    .foregroundColor(DS.Palette.gold)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard()
        }
        .buttonStyle(.dsPressable(feel: .tapSolid))
    }
}
