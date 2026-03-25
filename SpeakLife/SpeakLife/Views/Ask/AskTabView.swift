//
//  AskTabView.swift
//  SpeakLife
//
//  "Ask" tab — AI-powered Bible verse companion.
//  Users select topics + optionally add a personal message,
//  then receive a curated Scripture verse with warm encouragement.
//
//  Premium-gated feature. Free users see the paywall.
//

import SwiftUI

struct AskTabView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @StateObject private var viewModel = AskViewModel()
    
    @State private var showChips = true
    @FocusState private var inputFocused: Bool
    @Namespace private var scrollAnchor
    
    var body: some View {
        ZStack {
            // Background — matches app theme
            backgroundLayer
            
            if subscriptionStore.isPremium {
                mainContent
            } else {
                AskPaywallTeaser()
            }
        }
        .ignoresSafeArea(edges: .top)
        .environment(\.colorScheme, .dark)
    }
    
    // MARK: - Background
    
    @ViewBuilder
    var backgroundLayer: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.15)
                .ignoresSafeArea()
            
            // Soft radial glow at top
            RadialGradient(
                colors: [Constants.DADarkBlue.opacity(0.35), Color.clear],
                center: .top,
                startRadius: 10,
                endRadius: 380
            )
            .ignoresSafeArea()
            
            // Second glow from bottom
            RadialGradient(
                colors: [Color(red: 0.15, green: 0.08, blue: 0.3).opacity(0.4), Color.clear],
                center: .bottom,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Main Content
    
    var mainContent: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar
            
            // Chat area
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 16) {
                        // Empty state
                        if viewModel.viewState == .empty, viewModel.messages.isEmpty {
                            emptyState
                                .padding(.top, 20)
                        }
                        
                        // Messages
                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message, viewModel: viewModel)
                                .padding(.horizontal, 16)
                                .id(message.id)
                        }
                        
                        // Typing indicator
                        if viewModel.viewState == .loading {
                            HStack {
                                TypingIndicatorView()
                                    .padding(.leading, 16)
                                Spacer()
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .id("typing")
                        }
                        
                        // Error banner
                        if case .error(let msg) = viewModel.viewState {
                            ErrorBannerView(message: msg) {
                                viewModel.clearError()
                            }
                            .padding(.horizontal, 16)
                            .transition(.opacity)
                        }
                        
                        // Scroll anchor
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.bottom, 12)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.viewState) { _, newState in
                    if case .loading = newState {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
            }
            
            // Bottom composer
            bottomComposer
        }
    }
    
    // MARK: - Top Bar
    
    var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ask")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("Find Scripture for what's on your heart")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer()
            
            // Reset button (only when conversation active)
            if !viewModel.messages.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.resetConversation()
                        showChips = true
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .padding(.bottom, 14)
    }
    
    // MARK: - Empty State
    
    var emptyState: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Constants.DAMidBlue.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Constants.DAMidBlue, Constants.gold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("What's on your heart?")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Select topics below and let God's Word speak\ndirectly to your moment.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - Bottom Composer
    
    var bottomComposer: some View {
        VStack(spacing: 0) {
            // Gradient fade above composer
            LinearGradient(
                colors: [Color.clear, Color(red: 0.05, green: 0.07, blue: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)
            .allowsHitTesting(false)
            
            VStack(spacing: 12) {
                // Topic chips toggle
                if showChips || viewModel.messages.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(viewModel.selectedTopics.isEmpty
                                 ? "Select up to 3 topics"
                                 : "\(viewModel.selectedTopics.count)/3 selected")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        TopicChipGridView(viewModel: viewModel)
                            .frame(maxHeight: 160)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                
                // Text input + send
                HStack(spacing: 10) {
                    // Chips toggle button (when conversation active)
                    if !viewModel.messages.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showChips.toggle()
                            }
                        } label: {
                            Image(systemName: showChips ? "chevron.down" : "tag.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Text field
                    ZStack(alignment: .leading) {
                        if viewModel.inputText.isEmpty {
                            Text("Add your own words (optional)...")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.35))
                                .padding(.horizontal, 16)
                        }
                        TextField("", text: $viewModel.inputText, axis: .vertical)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .tint(Constants.DAMidBlue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .lineLimit(3)
                            .focused($inputFocused)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .strokeBorder(
                                        inputFocused
                                        ? Constants.DAMidBlue.opacity(0.6)
                                        : Color.white.opacity(0.15),
                                        lineWidth: 1.2
                                    )
                            )
                    )
                    .animation(.easeInOut(duration: 0.2), value: inputFocused)
                    
                    // Send button
                    Button {
                        inputFocused = false
                        showChips = false
                        Task { await viewModel.submit() }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(
                                    viewModel.canSubmit
                                    ? LinearGradient(
                                        colors: [Constants.DAMidBlue, Constants.DADarkBlue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 42, height: 42)
                            
                            if viewModel.viewState == .loading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.75)
                            } else {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(viewModel.canSubmit ? .white : .white.opacity(0.3))
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!viewModel.canSubmit || viewModel.viewState == .loading)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.canSubmit)
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 24)
            .background(Color(red: 0.05, green: 0.07, blue: 0.15))
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: AIChatMessage
    @ObservedObject var viewModel: AskViewModel
    
    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 60)
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [Constants.DAMidBlue.opacity(0.7), Constants.DADarkBlue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Constants.DAMidBlue.opacity(0.4), lineWidth: 1)
                    )
            }
            
        case .assistant:
            if let verse = message.verseResponse {
                HStack(alignment: .top) {
                    VerseCardView(
                        response: verse,
                        onSave: { viewModel.saveVerse(verse) },
                        isSaved: viewModel.isSaved(verse)
                    )
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - Error Banner

struct ErrorBannerView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)
            
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(2)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Paywall Teaser

struct AskPaywallTeaser: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @State private var showSubscription = false
    @State private var pulsing = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon with glow
            ZStack {
                Circle()
                    .fill(Constants.DAMidBlue.opacity(pulsing ? 0.25 : 0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulsing ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulsing)
                
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Constants.DAMidBlue, Constants.gold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .onAppear { pulsing = true }
            
            VStack(spacing: 12) {
                Text("Scripture. On Demand.")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Ask for a Bible verse on any topic —\njoy, anxiety, identity, relationships, and more.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
            }
            .padding(.horizontal, 32)
            
            // Feature list
            VStack(alignment: .leading, spacing: 14) {
                FeatureRow(icon: "sparkles", text: "AI-curated Bible verses for your moment")
                FeatureRow(icon: "heart.text.square.fill", text: "29 topics from faith to mental health")
                FeatureRow(icon: "heart.fill", text: "Save verses to your personal collection")
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // CTA
            Button {
                showSubscription = true
            } label: {
                Text("Unlock SpeakLife Premium")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Constants.DAMidBlue, Constants.DADarkBlue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Constants.DADarkBlue.opacity(0.5), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showSubscription) {
            OptimizedSubscriptionView {
                showSubscription = false
            }
            .presentationDetents([.large])
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Constants.DAMidBlue)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.75))
        }
    }
}
