//
//  BibleChatView.swift
//  SpeakLife
//
//  Topic picker for "Ask the Bible".
//

import SwiftUI
import MessageUI

struct BibleChatView: View {
    @StateObject private var viewModel = BibleChatViewModel()
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var navigator: BibleNavigator
    @Environment(\.bibleSurfaceIsRoot) private var isRootSurface
    @Environment(\.dismiss) private var dismiss
    @Namespace private var topicNamespace
    @State private var showMailSheet = false
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    private let suggestPrefillBody = "Hi SpeakLife team,\n\nI'd love to see a Bible Chat topic about:\n\n"

    var body: some View {
        ZStack {
            Gradients().speakLifeCYOCell
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                searchBar
                topicGrid
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Ask the Bible")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(.white)
            }
            // Only the surface the flow opened on is presented rather than
            // pushed, so only it needs a close button. Pushed surfaces get the
            // stack's back button.
            if isRootSurface {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
        .sheet(isPresented: $showMailSheet) {
            MailView(
                isShowing: $showMailSheet,
                result: $mailResult,
                origin: .bibleChatTopic,
                prefillBody: suggestPrefillBody,
                isSubscribed: subscriptionStore.isPremium
            )
        }
        .onAppear {
            viewModel.load()
            AnalyticsService.shared.trackScreenView("bible_chat")
        }
    }

    private var header: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text("What does the Bible say about…")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Tap a topic for a scripture-rooted answer.")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.65))
        }
        .padding(.top, 8)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.55))
            TextField("", text: $viewModel.searchText, prompt: Text("Search topics").foregroundColor(.white.opacity(0.4)))
                .foregroundColor(.white)
                .autocorrectionDisabled()
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            // Dictate the topic to search by voice.
            VoiceDictationButton(text: $viewModel.searchText, size: 16)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var topicGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(Array(viewModel.filteredTopics.enumerated()), id: \.element.id) { index, topic in
                    TopicCardView(topic: topic, namespace: topicNamespace) {
                        Juice.play(.tapLight)
                        viewModel.select(topic)
                        navigator.open(.answer(topic))
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity
                    ))
                    .animation(.easeOut(duration: 0.35).delay(Double(index) * 0.025), value: viewModel.topics.count)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            suggestTopicButton
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 32)
        }
    }

    private var suggestTopicButton: some View {
        Button {
            Juice.play(.tapLight)
            AnalyticsService.shared.trackUserAction(
                "bible_chat_suggest_topic_tap",
                category: "bible_chat"
            )
            if MFMailComposeViewController.canSendMail() {
                showMailSheet = true
            } else {
                openSuggestTopicMailto()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Constants.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Don't see your topic?")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundColor(.white)
                    Text("Email us your idea — we'll add it.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.65))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Constants.gold.opacity(0.18),
                                Color.black.opacity(0.30)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Constants.gold.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: Constants.gold.opacity(0.20), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    private func openSuggestTopicMailto() {
        let subject = "Bible Chat: Topic Request 🙏"
        let body = suggestPrefillBody
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "speaklife@diosesaqui.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }
}

private struct TopicCardView: View {
    let topic: BibleChatTopic
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                iconBadge

                Text(topic.title)
                    .font(.system(size: 17, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
                    .fixedSize(horizontal: false, vertical: true)

                Text(topic.summary)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 152, alignment: .topLeading)
            .padding(DS.Spacing.md)
            .background(cardBackground)
            .scaleEffect(pressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { isPressing in
            withAnimation(.easeOut(duration: 0.12)) { pressed = isPressing }
        }, perform: {})
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            topic.accentColor,
                            topic.accentColor.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .shadow(color: topic.accentColor.opacity(0.55), radius: 10, x: 0, y: 4)
            Image(systemName: topic.icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        topic.accentColor.opacity(0.30),
                        topic.accentColor.opacity(0.08),
                        Color.black.opacity(0.35)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                topic.accentColor.opacity(0.75),
                                topic.accentColor.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    .blendMode(.plusLighter)
            )
            .shadow(color: topic.accentColor.opacity(0.40), radius: 18, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.45), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Live AI conversation
//
// The tab content. A chat-first screen: empty state sells the feature with
// starter chips drawn from the curated topics; typing or tapping a chip starts
// a live, scripture-rooted conversation through the bibleChat proxy.

struct BibleChatConversationView: View {
    @StateObject private var viewModel = BibleChatConversationViewModel()
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    // Held only to forward into the paywall → OptimizedSubscriptionView sheet,
    // since SwiftUI does not reliably propagate env objects across sheet hops.
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var navigator: BibleNavigator
    @Environment(\.bibleSurfaceIsRoot) private var isRootSurface
    @State private var showPaywall = false
    @State private var showHistory = false
    @State private var heroAppeared = false
    @FocusState private var inputFocused: Bool

    private let starters: [BibleChatTopic] = (try? BibleChatService.shared.loadTopics()) ?? []

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning."
        case 12..<17: return "Good afternoon."
        case 17..<22: return "Good evening."
        default:      return "Peace to you."
        }
    }
    private var greetingPrompt: String {
        let hour = Calendar.current.component(.hour, from: Date())
        return (hour >= 17 || hour < 5) ? "What's weighing on you tonight?" : "What's on your heart today?"
    }

    var body: some View {
        ZStack {
            Gradients().speakLifeCYOCell.ignoresSafeArea()
            // Soft gold aura from the top for depth.
            RadialGradient(
                colors: [Constants.gold.opacity(0.16), .clear],
                center: .top, startRadius: 0, endRadius: 380
            )
            .ignoresSafeArea()
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
            // The input bar is a safe-area inset rather than the second half of
            // a VStack. As a plain sibling it is laid out against the tab's
            // bottom inset, and the floating tab bar's inset does not clear
            // when the keyboard comes up — so the bar was pushed down behind
            // the keys by roughly the tab bar's height and the user could not
            // see what they were typing. An inset participates in safe-area
            // resolution instead of fighting it, so the keyboard moves the bar
            // the whole way. It also insets the transcript's scroll content by
            // the bar's height, which the VStack was doing by consuming layout.
            transcript
                .safeAreaInset(edge: .bottom, spacing: 0) { inputBar }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Persistent entry into the full Bible reader. Lives in the
            // top-left so it stays visible once a conversation starts (the
            // empty-state hero disappears after the first message), and it
            // balances the history button on the right.
            //
            // Only shown at the root: reached the other way round (reader →
            // "Ask the Bible" → answer → chat) the stack's back button already
            // leads to the reader, and a second control pointing there is what
            // let the two screens stack on each other.
            if isRootSurface {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        AnalyticsService.shared.trackUserAction(
                            "bible_reader_opened_from_chat", category: "bible_chat"
                        )
                        navigator.openReader()
                    } label: {
                        Image(systemName: "book.closed.fill")
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel("Read the Bible")
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Bible Chat")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(.white)
            }
            // History (and "New" inside it) lives here.
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.white)
                }
                .accessibilityLabel("Chat history")
            }
        }
        .onChange(of: viewModel.needsPaywall) { newValue in
            if newValue {
                viewModel.needsPaywall = false
                showPaywall = true
            }
        }
        .sheet(isPresented: $showPaywall) {
            BibleChatPaywallSplash { showPaywall = false }
                .environmentObject(appState)
                .environmentObject(declarationStore)
                .environmentObject(subscriptionStore)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showHistory) {
            ChatHistoryView(
                onSelect: { conversation in viewModel.load(conversation) },
                onNewChat: { viewModel.startNewConversation() }
            )
        }
        .onAppear { AnalyticsService.shared.trackScreenView("bible_chat_conversation") }
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if viewModel.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, msg in
                            VStack(alignment: .leading, spacing: 8) {
                                ChatBubble(message: msg).id(msg.id)
                                // The declaration is already written in the
                                // bubble above, so this offers the action and
                                // not a second copy of the words.
                                if let declaration = msg.declaration {
                                    ChatDeclarationSaveCard(
                                        declaration: declaration,
                                        // What the person actually asked. Used
                                        // both to screen the request and as the
                                        // belief text the saved card displays.
                                        askedText: viewModel.messages[..<index]
                                            .last(where: { $0.role == .user })?.text ?? "",
                                        isSaved: viewModel.savedDeclarationIDs.contains(msg.id),
                                        onSaved: { viewModel.savedDeclarationIDs.insert(msg.id) }
                                    )
                                }
                            }
                        }
                    }
                    if viewModel.isSending {
                        typingIndicator.id("typing")
                    }
                    if let err = viewModel.errorMessage {
                        // The question is still in the transcript above, so the
                        // only thing missing was a way to send it again. Without
                        // this the user has to retype what they can still see.
                        VStack(spacing: 10) {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(.red.opacity(0.9))
                                .multilineTextAlignment(.center)

                            Button {
                                viewModel.retryLastMessage(isPremium: subscriptionStore.isPremium)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 13, weight: .semibold))
                                    Text("Retry")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule().fill(Color.white.opacity(0.14))
                                )
                                .overlay(
                                    Capsule().stroke(Color.white.opacity(0.22), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            // A retry while one is already in flight would be
                            // dropped by the view model anyway; hide it so the
                            // button never looks dead.
                            .disabled(viewModel.isSending)
                            .opacity(viewModel.isSending ? 0.4 : 1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
            }
            // Drag the conversation down to dismiss the keyboard.
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _ in
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: viewModel.isSending) { sending in
                if sending { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
        }
    }

    /// The opening question, built from what onboarding already learned.
    ///
    /// Reads `UserPreferencesTracker.primaryCategory`, the same source
    /// `TrialExperienceService` personalizes its trial pushes from, so a user
    /// who never answered lands on `.general` and gets nothing extra rather than
    /// a wrong guess. Phrased as the user would type it, not as a topic label.
    private var seededQuestion: String {
        switch UserPreferencesTracker.shared.primaryCategory {
        case .anxiety:    return "My mind won't stop racing. What does God say about that?"
        case .fear:       return "I keep bracing for bad news. What does God say to that fear?"
        case .health:     return "What does God's Word say over my body right now?"
        case .marriage:   return "Things are hard at home. What does God say about my marriage?"
        case .confidence: return "I don't feel good enough. Who does God say I am?"
        case .hope:       return "I'm having a hard time hoping again. What does God say?"
        case .rest:       return "I can't seem to rest. What does God say about that?"
        case .joy:        return "Everything feels flat lately. What does God say about joy?"
        case .love:       return "What does God's Word say about how He loves me?"
        case .faith:      return "How do I build faith that actually holds?"
        // Not "we never asked" — `primaryCategory` is a `CategoryType` with 11
        // cases, while onboarding records `DeclarationCategory` raw values, of
        // which there are far more. Anyone whose heaviest thing is wealth,
        // grief, purity, parenting or a dozen others falls through here, so
        // `.general` is the COMMON case rather than the empty one. An opener
        // everyone can answer beats a blank screen; it is an invitation, not a
        // wrong guess.
        case .general:    return "What's the heaviest thing on you right now?"
        }
    }

    /// True when the opener came from something the user actually told us.
    private var seedIsPersonal: Bool {
        UserPreferencesTracker.shared.primaryCategory != .general
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Hero
            VStack(spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(Constants.gold.opacity(0.22))
                        .frame(width: 96, height: 96)
                        .blur(radius: 26)
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Constants.gold, Constants.gold.opacity(0.65)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: Constants.gold.opacity(0.5), radius: 14, y: 4)
                }
                Text(greeting)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Constants.gold.opacity(0.9))
                Text(greetingPrompt)
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Bring anything — anxiety, relationships, doubt. Get a warm, scripture-rooted answer in seconds.")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .opacity(heroAppeared ? 1 : 0)
            .offset(y: heroAppeared ? 0 : 10)
            .animation(.easeOut(duration: 0.45), value: heroAppeared)

            // The question they already came in with.
            //
            // Onboarding asks every user what they are carrying and stores the
            // answer, then this screen opened on a generic topic list as though
            // it had never met them. A blank chat is a hard thing to start; a
            // chat that already knows what is heavy is not. Sits above the
            // curated starters because it is the one row aimed at THIS person.
            VStack(alignment: .leading, spacing: 10) {
                Text("START HERE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(Constants.gold.opacity(0.75))
                    .padding(.leading, 4)

                Button {
                    Juice.play(.tapLight)
                    AnalyticsService.shared.track("bible_chat_seeded_starter_tapped", parameters: [
                        "category": UserPreferencesTracker.shared.primaryCategory.rawValue,
                        "is_personal": seedIsPersonal as NSNumber
                    ])
                    viewModel.send(seededQuestion, isPremium: subscriptionStore.isPremium)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Constants.gold)
                        Text(seededQuestion)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.92))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Constants.gold.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Constants.gold.opacity(0.30), lineWidth: 1)
                            )
                    )
                }
            }
            .opacity(heroAppeared ? 1 : 0)
            .offset(y: heroAppeared ? 0 : 12)
            .animation(.easeOut(duration: 0.4).delay(0.05), value: heroAppeared)
            // Paired with the tap event so the row's take-rate is measurable.
            // Without a shown event there was no denominator.
            .onAppear {
                AnalyticsService.shared.track("bible_chat_seeded_starter_shown", parameters: [
                    "category": UserPreferencesTracker.shared.primaryCategory.rawValue,
                    "is_personal": seedIsPersonal as NSNumber
                ])
            }

            // Suggestions
            VStack(alignment: .leading, spacing: 10) {
                Text("TRY ASKING")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.leading, 4)
                ForEach(Array(starters.prefix(5).enumerated()), id: \.element.id) { index, topic in
                    StarterCard(topic: topic) {
                        Juice.play(.tapLight)
                        viewModel.send(topic.question, isPremium: subscriptionStore.isPremium)
                    }
                    .opacity(heroAppeared ? 1 : 0)
                    .offset(y: heroAppeared ? 0 : 14)
                    .animation(.easeOut(duration: 0.4).delay(0.08 + Double(index) * 0.06), value: heroAppeared)
                }
            }

            // Trust line
            HStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.system(size: 10))
                Text("Rooted in Scripture · Private")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white.opacity(0.4))
            .opacity(heroAppeared ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.45), value: heroAppeared)
        }
        .padding(.top, 28)
        .onAppear { heroAppeared = true }
    }

    private var typingIndicator: some View {
        HStack {
            TypingDots()
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            Spacer(minLength: 40)
        }
    }

    private var inputBar: some View {
        // .bottom so the mic/send buttons stay pinned to the bottom as the
        // field grows taller. Sub-views are split out so each modifier chain
        // type-checks on its own (the combined chain was complex enough to time
        // out the SwiftUI type-checker on a clean/archive build).
        HStack(alignment: .bottom, spacing: 10) {
            messageField

            // Dictate the question by voice.
            VoiceDictationButton(text: $viewModel.draft, size: 20)

            sendButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.2))
    }

    private var messageField: some View {
        TextField(
            "",
            text: $viewModel.draft,
            prompt: Text("Ask about life or faith…").foregroundColor(.white.opacity(0.4)),
            axis: .vertical
        )
        .textFieldStyle(.plain)
        .foregroundColor(.white)
        .focused($inputFocused)
        // Grow with the text up to 5 lines, then scroll internally, so the
        // user can see everything they've typed.
        .lineLimit(1...5)
        // A vertical-axis field inserts a newline on Return. For short Q&A
        // that's not wanted, so treat a trailing newline as Send instead.
        .onChange(of: viewModel.draft) { value in
            guard value.hasSuffix("\n") else { return }
            viewModel.draft = String(value.dropLast())
            inputFocused = false
            viewModel.sendDraft(isPremium: subscriptionStore.isPremium)
        }
        // No keyboard-toolbar "Done" button here: inside the tab's TabView the
        // accessory item renders floating over the input bar's mic/send buttons
        // instead of staying in the keyboard row. Dismissal is already covered
        // three ways — drag the conversation down (.scrollDismissesKeyboard),
        // Return (sends and dismisses), and the send button.
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(inputFocused ? Constants.gold.opacity(0.55) : Color.white.opacity(0.10), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.2), value: inputFocused)
    }

    private var sendButton: some View {
        Button {
            inputFocused = false
            viewModel.sendDraft(isPremium: subscriptionStore.isPremium)
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(viewModel.canSend ? Constants.gold : .white.opacity(0.25))
        }
        .disabled(!viewModel.canSend)
    }
}

// MARK: - Chat history list
//
// Observes the shared JSON-backed ChatHistoryStore; updates as chats are saved.

struct ChatHistoryView: View {
    @ObservedObject private var store = ChatHistoryStore.shared
    @Environment(\.dismiss) private var dismiss

    let onSelect: (ChatConversation) -> Void
    let onNewChat: () -> Void

    @State private var renamingID: UUID?
    @State private var renameText: String = ""
    @State private var showRename = false

    var body: some View {
        NavigationView {
            ZStack {
                Gradients().speakLifeCYOCell.ignoresSafeArea()
                if store.conversations.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 34))
                            .foregroundColor(.white.opacity(0.5))
                        Text("No past chats yet")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                        Text("Your conversations will appear here.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.45))
                    }
                } else {
                    List {
                        ForEach(store.conversations) { conversation in
                            Button {
                                onSelect(conversation)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(conversation.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.white.opacity(0.05))
                            .swipeActions(edge: .leading) {
                                Button {
                                    renamingID = conversation.id
                                    renameText = conversation.title
                                    showRename = true
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete { store.delete(at: $0) }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Your Chats")
            .navigationBarTitleDisplayMode(.inline)
            // The sheet has its own nav bar that defaults to light mode — force
            // dark so the title/buttons read correctly over the dark gradient.
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onNewChat()
                        dismiss()
                    } label: {
                        Label("New", systemImage: "square.and.pencil")
                    }
                    .tint(Constants.gold)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(.white)
                }
            }
            .alert("Rename chat", isPresented: $showRename) {
                TextField("Title", text: $renameText)
                Button("Save") {
                    if let id = renamingID {
                        store.rename(id, to: renameText)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .navigationViewStyle(.stack)
    }
}

// Accent-tinted suggestion card for the empty state — gradient icon badge,
// soft accent tint + shadow, press feedback. Reuses each topic's accentColor.
private struct StarterCard: View {
    let topic: BibleChatTopic
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [topic.accentColor, topic.accentColor.opacity(0.55)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .shadow(color: topic.accentColor.opacity(0.5), radius: 8, x: 0, y: 3)
                    Image(systemName: topic.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text(topic.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [topic.accentColor.opacity(0.22), Color.white.opacity(0.04)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(topic.accentColor.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: topic.accentColor.opacity(0.18), radius: 10, x: 0, y: 5)
            )
            .scaleEffect(pressed ? 0.98 : 1)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { isPressing in
            withAnimation(.easeOut(duration: 0.12)) { pressed = isPressing }
        }, perform: {})
    }
}

// Animated "typing" indicator — three dots pulsing in a wave.
private struct TypingDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 7, height: 7)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .opacity(animating ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

/// Turns a declaration the chat gave into a real personal declaration.
///
/// Routes through `PersonalDeclarationViewModel.saveAndContinue`, which is the
/// same call the onboarding flow makes, so a declaration saved from a chat is
/// indistinguishable from one written on frame one: same repository, same limit
/// check, same daily notification. Building a second save path would have meant
/// a second definition of what a personal declaration is.
private struct ChatDeclarationSaveCard: View {
    let declaration: ChatDeclaration
    /// The user's own message that produced this reply.
    let askedText: String
    let isSaved: Bool
    let onSaved: () -> Void

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    private enum SaveState: Equatable { case idle, saving, failed(String) }
    @State private var state: SaveState = .idle
    @State private var showPremium = false

    /// The same deterministic screen the onboarding writer runs, for the same
    /// reason its own comment gives: prompt instructions alone were judged
    /// insufficient for a surface that turns model output into scripture-shaped
    /// text the app stands behind. This path is strictly worse without it —
    /// saving does not just render a line, it schedules a repeating daily
    /// notification — so a crisis or harm-to-another request must never reach a
    /// save button, whatever the model chose to write.
    private var isStandable: Bool {
        SituationScreen.screen(askedText) == .standable
    }

    var body: some View {
        Group {
            if !isStandable {
                EmptyView()
            } else if isSaved {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13))
                    Text("Saved. You'll hear this every day.")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(Constants.gold.opacity(0.9))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack(spacing: 8) {
                            if state == .saving {
                                ProgressView().scaleEffect(0.7).tint(Constants.gold)
                            } else {
                                Image(systemName: "hands.sparkles.fill")
                                    .font(.system(size: 13))
                            }
                            Text(state == .saving ? "Saving..." : "Speak this daily")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Constants.gold)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 14)
                        .background(
                            Capsule()
                                .fill(Constants.gold.opacity(0.12))
                                .overlay(Capsule().stroke(Constants.gold.opacity(0.35), lineWidth: 1))
                        )
                    }
                    .disabled(state == .saving)

                    if case .failed(let message) = state {
                        Text(message)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.leading, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.25), value: state)
        .sheet(isPresented: $showPremium) {
            PremiumView()
                .environmentObject(subscriptionStore)
                .environmentObject(appState)
        }
    }

    /// Grammatical and actionable, unlike the shared `PersonalDeclarationLimitError`
    /// text, which interpolates the count into "You can believe for 1 things at
    /// a time." A free user who finished onboarding already carries their one,
    /// so this is the message they hit on their first ever chat save.
    private var limitMessage: String {
        let max = PersonalDeclarationLimits.maxDeclarations(isPremium: subscriptionStore.isPremium)
        let carried = max == 1 ? "one declaration" : "\(max) declarations"
        let base = "You're carrying \(carried) already. Mark one answered in My Declarations to add this."
        return subscriptionStore.isPremium ? base : base + " Premium carries up to \(PersonalDeclarationLimits.premium)."
    }

    private func save() async {
        state = .saving
        let viewModel = DIContainer.shared.makePersonalDeclarationViewModel()
        // The belief is what the PERSON said, not what the model wrote back.
        // Setting this to the declaration made `PersonalDeclarationCard` print
        // the same sentence twice, the second time under "WHAT YOU'RE BELIEVING
        // FOR" as though the user had written it.
        viewModel.inputText = askedText
        viewModel.match = DeclarationMatch(
            category: DeclarationCategory(rawValue: declaration.categoryRaw) ?? .general,
            declarationText: declaration.text,
            verse: declaration.verse,
            verseReference: declaration.reference,
            isConfident: true
        )
        do {
            _ = try await viewModel.saveAndContinue(
                startTimeIndex: appState.personalDeclarationTimeIndex,
                limit: PersonalDeclarationLimits.maxDeclarations(isPremium: subscriptionStore.isPremium)
            )
            appState.hasPersonalDeclaration = true
            UserPreferencesTracker.shared.personalDeclarationBelief = askedText
            AnalyticsService.shared.track("bible_chat_declaration_saved", parameters: [
                "category": (DeclarationCategory(rawValue: declaration.categoryRaw) ?? .general).rawValue
            ])
            state = .idle
            onSaved()
        } catch is PersonalDeclarationLimitError {
            AnalyticsService.shared.track("bible_chat_declaration_save_blocked", parameters: [
                "reason": "limit",
                "is_premium": subscriptionStore.isPremium as NSNumber
            ])
            // `SavePersonalDeclarationUseCase`'s own doc says the limit is a
            // backstop and entry points are expected to gate up front so the
            // user sees the paywall rather than an error. Free users carry one
            // declaration and every onboarding arm saves it, so without this
            // the button's only outcome for them is a red row — under copy that
            // just promised "save it and hear it every day".
            if subscriptionStore.isPremium {
                state = .failed(limitMessage)
            } else {
                state = .idle
                showPremium = true
            }
        } catch {
            state = .failed("Couldn't save that. Try again.")
        }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    // Parse Markdown (bold/italic) while preserving the model's line breaks, so
    // **bold** renders as bold instead of showing literal asterisks. Falls back
    // to plain text if parsing fails.
    private var rendered: AttributedString {
        (try? AttributedString(
            markdown: message.text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(message.text)
    }

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(rendered)
                .font(.system(size: 15, design: message.role == .assistant ? .serif : .default))
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(bubbleBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            message.role == .user ? Constants.gold.opacity(0.4) : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
                .textSelection(.enabled)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.role == .user {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Constants.gold.opacity(0.35), Constants.gold.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        }
    }
}

// MARK: - Benefits splash + paywall
//
// Shown when a non-premium user exhausts their free messages. Sells the value,
// then hands off to the existing OptimizedSubscriptionView for purchase.

struct BibleChatPaywallSplash: View {
    var onClose: () -> Void
    @State private var showSubscription = false
    // OptimizedSubscriptionView requires these; forward them across the sheet hop.
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore

    private let benefits: [(icon: String, text: String)] = [
        ("book.fill", "Scripture-rooted answers to anything you're facing"),
        ("heart.fill", "Warm, biblical guidance for anxiety, relationships, and more"),
        ("infinity", "Unlimited conversations, any time, day or night"),
        ("sparkles", "Private, personal, and always pointing you to Christ")
    ]

    var body: some View {
        ZStack {
            Gradients().speakLifeCYOCell.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 16)
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 46))
                    .foregroundColor(Constants.gold)
                    .padding(.bottom, 14)
                Text("Keep the conversation going")
                    .font(.system(size: 25, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text("You've used your free messages. Unlock Bible Chat to ask anything, anytime.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(benefits, id: \.icon) { item in
                        HStack(spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.system(size: 18))
                                .foregroundColor(Constants.gold)
                                .frame(width: 28)
                            Text(item.text)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 28)

                Spacer(minLength: 0)

                Button {
                    showSubscription = true
                } label: {
                    Text("Unlock Bible Chat")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Constants.gold)
                        )
                }
                .padding(.horizontal, 24)

                Button("Maybe later") { onClose() }
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 12)
                    .padding(.bottom, 22)
            }
        }
        .sheet(isPresented: $showSubscription) {
            OptimizedSubscriptionView {
                showSubscription = false
                onClose()
            }
            .environmentObject(appState)
            .environmentObject(declarationStore)
            .environmentObject(subscriptionStore)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .presentationDetents([.large])
        }
        .onAppear { AnalyticsService.shared.trackScreenView("bible_chat_paywall") }
    }
}
