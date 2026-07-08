//
//  SpeakLifeMessagesView.swift
//  SpeakLife
//
//  "Messages" tab in the Community (Warrior Room) section — a public
//  timeline of every broadcast message sent through the sendPersonalMessage
//  Cloud Function. The function writes each allUsers broadcast to the
//  `speakLifeMessages` Firestore collection, so the history is visible to
//  every user, including those who installed after a message was sent or
//  never tapped its push notification. Tapping a card opens the same
//  RemoteMessageView sheet (with the Amen CTA) a notification tap shows.
//

import SwiftUI
import FirebaseFirestore

// MARK: - Model

struct SpeakLifeMessage: Identifiable, Codable {
    @DocumentID var id: String?
    let title: String
    let body: String
    /// Optional: a doc read back in the same instant it was created can
    /// briefly have a nil server timestamp.
    let sentAt: Timestamp?
}

// MARK: - ViewModel

class SpeakLifeMessagesViewModel: ObservableObject {
    @Published var messages: [SpeakLifeMessage] = []
    @Published var isLoading = false
    @Published var hasMore = true

    private let db = Firestore.firestore()
    private let collection = "speakLifeMessages"
    private let batchSize = 25
    private let cacheKey = "cachedSpeakLifeMessages"

    private var lastDocument: DocumentSnapshot?
    /// True once at least one live network fetch has completed this session,
    /// so re-appearing (tab switches, sheet dismissals) doesn't reset the
    /// pagination cursor.
    private(set) var hasFetchedFromNetwork = false

    init() {
        loadCachedMessages()
    }

    func fetchIfNeeded() {
        guard !hasFetchedFromNetwork else { return }
        fetch(reset: true)
    }

    func refresh() {
        fetch(reset: true)
    }

    func fetch(reset: Bool) {
        guard !isLoading else { return }
        isLoading = true
        if reset { lastDocument = nil }

        var query: Query = db.collection(collection)
            .order(by: "sentAt", descending: true)
            .limit(to: batchSize)
        if !reset, let lastDocument {
            query = query.start(afterDocument: lastDocument)
        }

        query.getDocuments { [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                guard error == nil, let snapshot else { return }

                self.hasFetchedFromNetwork = true
                let batch = snapshot.documents.compactMap {
                    try? $0.data(as: SpeakLifeMessage.self)
                }
                self.lastDocument = snapshot.documents.last
                self.hasMore = snapshot.documents.count == self.batchSize
                self.messages = reset ? batch : self.messages + batch
                if reset { self.cacheMessages() }
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

// MARK: - List View

/// Content for the "Messages" tab. Rendered by PrayerWallView below its
/// segmented control; the parent owns the reader sheet via `onSelect` so a
/// single sheet serves every card.
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
                .refreshable { viewModel.refresh() }
            } else {
                messageList
            }
        }
        .onAppear { viewModel.fetchIfNeeded() }
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
        .refreshable { viewModel.refresh() }
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
                        Text(sentAt.dateValue().formatted(date: .abbreviated, time: .omitted))
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
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.dsPressable(feel: .tapSolid))
    }
}
