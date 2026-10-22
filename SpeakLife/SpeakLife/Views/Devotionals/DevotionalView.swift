//
//  DevotionalView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 5/10/23.
//

import SwiftUI

struct DevotionalView: View {
    
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIPad: Bool { horizontalSizeClass == .regular }
    @StateObject var viewModel: DevotionalViewModel
    @EnvironmentObject var declarationViewModel: DeclarationViewModel
    @EnvironmentObject var appState: AppState
    @StateObject private var metricsService = ListenerMetricsService.shared
    @State private var scrollToTop = false
    @State private var share = false
    @State var presentDevotionalSubscriptionView = false
    @State private var readerCount: String? = nil
    @State private var showAllCategories = false
    
    let spacing: CGFloat = 50
    
    var body: some View {
        contentView
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                self.presentationMode.wrappedValue.dismiss()
            }
            .onAppear {
                // Track verses/devotionals read for badge system
                let current = UserDefaults.standard.integer(forKey: "totalVersesRead")
                UserDefaults.standard.set(current + 1, forKey: "totalVersesRead")
                StreakIntegrationManager.notifyDevotionalCompleted()
            }
            .task {
                await viewModel.loadCategoryDevotional(isPremium: isPremiumReader)
            }
            .sheet(isPresented: $viewModel.categoryNeedsPaywall, onDismiss: {
                Task { await viewModel.paywallClosed(isPremium: isPremiumReader) }
            }) {
                OptimizedSubscriptionView() {
                    viewModel.categoryNeedsPaywall = false
                }
            }
            .sheet(isPresented: $showAllCategories) {
                allCategoriesSheet
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
//            .onAppear {
//                // Track devotional view for metrics
//                ListenerMetricsService.shared.trackListen(
//                    contentId: viewModel.devotionalId,
//                    contentType: .devotional
//                )
                
                // Fetch reader count for this devotional
//                Task {
//                    let metrics = await metricsService.fetchMetrics(for: [viewModel.devotionalId], contentType: .devotional)
//                    if let count = metrics[viewModel.devotionalId] {
//                        readerCount = ListenerMetricsService.formatListenerCount(count)
//                    }
//                }
         //   }
        
    }
    
    @ViewBuilder
    var contentView: some  View {
        if subscriptionStore.isPremium || !viewModel.devotionalLimitReached || subscriptionStore.isInDevotionalPremium {
            devotionalView
                .onAppear {
                    // Carried no properties, so there was no way to tell which
                    // devotionals people actually open.
                    AnalyticsService.shared.track(Event.devotionalTapped, parameters: [
                        "devotional_id": viewModel.devotionalId,
                        "devotional_title": viewModel.title,
                        "devotional_date": viewModel.devotionalDate
                    ])
                }
                .alert(isPresented: $viewModel.hasError) {
                    Alert(title: Text(viewModel.errorString))
                }
        } else {
            GeometryReader { proxy in
                OptimizedSubscriptionView() {
                }
                .frame(height: proxy.size.height * 0.99)
            }
        }
    }
    
    var devotionalView: some View {
        GeometryReader { geo in
            devotionalContent(geo: geo)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func devotionalContent(geo: GeometryProxy) -> some View {
        ZStack {

            Image(subscriptionStore.backgroundImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                // Use container size instead of UIScreen so it fills the sheet correctly on iPad
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .overlay(
                    Rectangle()
                        .fill(Color.black.opacity(0.2))
                )
            ScrollViewReader { scrollView in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Spacer()
                            .frame(height: 40)
                        if !subscriptionStore.isPremium && !subscriptionStore.isInDevotionalPremium {
                            Text("\(viewModel.devotionalsLeft) more free devotionals left")
                        }
                    
                        dateLabel
                        HStack {
                            Spacer()
                            AppLogo(height: 90)
                            Spacer()
                        }
                        .dsAppear(0)

                        categoryPicker

                        if viewModel.isGeneratingCategory || viewModel.isAwaitingCategory {
                            generatingState
                        } else if viewModel.categoryFailed {
                            failedState
                        } else {
                            titleLabel

                            bookLabel

                            devotionText
                        }
                        
                        HStack {
                            Spacer()
                            navigateDevotionalStack
                            Spacer()
                        }
                        
                    }
                    .id("titleID")
                    .padding(.horizontal, 24)
                    .foregroundColor(.white)
                    
                    .sheet(isPresented: $share) {
                        ShareSheet(activityItems: [viewModel.devotionalText as String,  URL(string: "\(APP.Product.urlID)")! as URL])
                    }
                }
               // .padding([.top], 40)
                .padding([.bottom], 80)
                .onChange(of: scrollToTop) { value in
                    if value {
                        scrollView.scrollTo("titleID", anchor: .top)
                        scrollToTop = false
                    }
                }
            }

            if viewModel.isAwaitingCategory {
                DevotionalWritingOverlay(
                    topic: viewModel.selectedCategory?.name ?? "your topic",
                    onReadDaily: { viewModel.showCalendarDevotional() }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.isAwaitingCategory)
        // Explicit close button on iPad, where this screen is presented as a
        // fullScreenCover with no swipe-to-dismiss gesture.
        .overlay(alignment: .topTrailing) {
            if isIPad {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 20)
                        .padding(.trailing, 20)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Close")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            self.share = false
        }
    }

    @ViewBuilder
    var dateLabel: some View {
        HStack {
            Spacer()
            Text(viewModel.devotionalDate)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        Spacer()
            .frame(height: spacing)
    }
    
    @ViewBuilder
    var titleLabel: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(viewModel.title)
                .font(DS.Typography.title)
                .foregroundStyle(.white)
                .dsAppear(0.06)
            
            if let listenerCount = readerCount {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(listenerCount) readers")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        
        Spacer()
            .frame(height: 24)
    }
    
    @ViewBuilder
    var bookLabel: some View {
        Text(viewModel.devotionalBooks)
            .font(.system(size: 18, weight: .semibold))
            .italic()
            .foregroundStyle(.white.opacity(0.9))
        
        Spacer()
            .frame(height: 24)
    }
    
    @ViewBuilder
    var devotionText: some View {
        Text(viewModel.devotionalText)
            .font(DS.Typography.body)
            .foregroundStyle(.white.opacity(0.8))
            .lineSpacing(4)
            .dsAppear(0.12)
        Spacer()
            .frame(height: spacing)
    }
    
    @ViewBuilder
    private var backDevotionalButton: some View {
        if viewModel.devotionValue > -10 {
            Button {
                Task {
                    viewModel.devotionValue -= 1
                    await viewModel.fetchDevotionalFor(value: viewModel.devotionValue)
                    withAnimation {
                        scrollToTop = true
                    }
                }
            } label: {
                Image(systemName: "arrow.backward.circle")
                    .resizable()
                    .frame(width: 30, height: 30)
            }
        }
    }
    
    @ViewBuilder
    private var forwardDevotionalButton: some View {
        if viewModel.devotionValue < 0 {
            Button {
                Task {
                    viewModel.devotionValue += 1
                    await viewModel.fetchDevotionalFor(value: viewModel.devotionValue)
                    withAnimation {
                        scrollToTop = true
                    }
                }
            } label: {
                Image(systemName: "arrow.forward.circle")
                    .resizable()
                    .frame(width: 30, height: 30)
            }
        }
    }
    
    private var shareButton: some View {
        Button {
            share.toggle()
            appState.requestReviewIfEligible(trigger: .devotionalShared)
            AnalyticsService.shared.track(Event.devotionalShared, parameters: ["devotionalID": viewModel.devotionalId])
        } label: {
            Image(systemName: "square.and.arrow.up")
                .resizable()
                .frame(width: 25)
        }
    }
    
    var navigateDevotionalStack: some View {
        HStack {
            if viewModel.selectedCategory == nil {
                backDevotionalButton

                Spacer()
                    .frame(width: 25)

                forwardDevotionalButton

                Spacer()
                    .frame(width: 25)
            }
            
            shareButton
            
        }
        .foregroundColor(.white)
    }
    
    
    // MARK: - Category devotionals

    private var isPremiumReader: Bool {
        subscriptionStore.isPremium || subscriptionStore.isInDevotionalPremium
    }

    /// Daily, the reader's recent picks and the top nine, with All topics
    /// pinned on the right so the rest are always one tap away. The row runs
    /// to the screen edge and fades out, which says "scroll me" without a
    /// hard clip. The pick is remembered, so each day opens on it.
    private var categoryPicker: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(title: "Daily", category: nil)
                        ForEach(viewModel.chipCategories) { category in
                            categoryChip(title: category.name, category: category)
                        }
                    }
                    .padding(.leading, 24)
                    .padding(.trailing, 20)
                }
                .mask(
                    HStack(spacing: 0) {
                        Rectangle()
                        LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 28)
                    }
                )
                .onAppear {
                    if let selected = viewModel.selectedCategory {
                        proxy.scrollTo(selected.rawValue, anchor: .center)
                    }
                }
                .onChange(of: viewModel.selectedCategoryRaw) { raw in
                    withAnimation { proxy.scrollTo(raw.isEmpty ? "daily" : raw, anchor: .center) }
                }
            }
            allTopicsButton
                .padding(.trailing, 24)
        }
        // Undo the page's 24pt side padding so the row can reach the edges.
        .padding(.horizontal, -24)
    }

    private func pick(_ category: DeclarationCategory?) {
        // Ignored rather than disabled while writing, so the selected chip
        // keeps its full white and the reader can see what is loading.
        guard category == nil || !viewModel.isGeneratingCategory else { return }
        Task {
            await viewModel.selectCategory(category, isPremium: isPremiumReader)
            withAnimation { scrollToTop = true }
        }
    }

    private func categoryChip(title: String, category: DeclarationCategory?) -> some View {
        let isSelected = viewModel.selectedCategory == category
        let isLocked = category.map { viewModel.isLocked($0, isPremium: isPremiumReader) } ?? false
        return Button {
            guard !isSelected else { return }
            pick(category)
        } label: {
            HStack(spacing: 6) {
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .lineLimit(1)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(isSelected ? Color.black : Color.white.opacity(isLocked ? 0.65 : 0.95))
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(
                Capsule().fill(isSelected ? Color.white : Color.white.opacity(0.12))
            )
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(isSelected ? 0 : 0.2), lineWidth: 1)
            )
            .padding(.vertical, 4) // 44pt tap target around a 36pt pill
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .id(category?.rawValue ?? "daily")
        .accessibilityLabel(isLocked ? "\(title), premium" : title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var allTopicsButton: some View {
        Button {
            guard !viewModel.isGeneratingCategory else { return }
            showAllCategories = true
        } label: {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.12)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                .padding(4)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("All topics")
    }

    /// Every category in a grid. Whatever the reader picks here joins their
    /// recents on the chip row.
    private var allCategoriesSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(DevotionalViewModel.devotionalCategories) { category in
                        let isSelected = viewModel.selectedCategory == category
                        let isLocked = viewModel.isLocked(category, isPremium: isPremiumReader)
                        Button {
                            showAllCategories = false
                            guard !isSelected else { return }
                            pick(category)
                        } label: {
                            HStack(spacing: 6) {
                                Text(category.name)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if isLocked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                } else if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                }
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(14)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Choose a topic")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    /// The overlay carries the loading moment; this only holds the page's
    /// height so nothing jumps when the devotional lands.
    private var generatingState: some View {
        Color.clear.frame(height: 420)
    }

    private var failedState: some View {
        VStack(spacing: 14) {
            Text("We couldn't load today's devotional. Check your connection and try again.")
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
            Button("Try again") {
                Task { await viewModel.loadCategoryDevotional(isPremium: isPremiumReader, userInitiated: true) }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white))
            Button("Read today's Daily devotional") {
                viewModel.showCalendarDevotional()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func shareSpeakLife()  {
        DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive })
                as? UIWindowScene {
                let url = URL(string: "\(APP.Product.urlID)")!
                
                let activityVC = UIActivityViewController(activityItems: ["Check out Speak Life - Bible Verses app that'll transform your life!", url], applicationActivities: nil)
                let window = scene.windows.first
                window?.rootViewController?.present(activityVC, animated: true)
            }
        }
    }
    
}

/// Full-screen moment for the ~10 seconds a category devotional takes to
/// write. A glowing ring turns around an open book while light ripples out,
/// and the status line walks through the steps, so the wait reads as
/// something being made for the reader rather than a spinner hanging.
private struct DevotionalWritingOverlay: View {
    let topic: String
    let onReadDaily: () -> Void

    @State private var step = 0
    @State private var spin = false
    @State private var breathe = false
    @State private var ripple = false
    @State private var progress: CGFloat = 0.04
    @State private var appeared = false

    private let steps = [
        "Finding today's verse",
        "Listening for what it says to you",
        "Writing it out",
        "Writing your prayer",
        "Almost ready"
    ]

    private let violet = Color(red: 0.55, green: 0.42, blue: 1.0)
    private let gold = Color(red: 1.0, green: 0.80, blue: 0.38)

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.45))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                emblem
                    .padding(.bottom, 40)

                Text("WRITING YOUR DEVOTIONAL")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(2.2)
                    .foregroundStyle(gold.opacity(0.9))
                    .padding(.bottom, 10)

                Text(topic)
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 18)

                ZStack {
                    Text(steps[step])
                        .id(step)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 10)),
                            removal: .opacity.combined(with: .offset(y: -10))
                        ))
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .frame(height: 24)
                .accessibilityLabel("Writing today's devotional on \(topic). \(steps[step])")

                progressBar
                    .padding(.top, 28)

                Spacer()

                Button(action: onReadDaily) {
                    Text("Read today's Daily instead")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 40)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.96)
        }
        .onAppear(perform: start)
        .task { await walkSteps() }
    }

    private var emblem: some View {
        ZStack {
            // Light rippling out from the center, staggered.
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(violet.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 120, height: 120)
                    .scaleEffect(ripple ? 2.1 : 0.9)
                    .opacity(ripple ? 0 : 0.7)
                    .animation(
                        .easeOut(duration: 2.7)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.9),
                        value: ripple
                    )
            }

            // Soft glow that breathes.
            Circle()
                .fill(RadialGradient(colors: [violet.opacity(0.55), .clear],
                                     center: .center, startRadius: 4, endRadius: 90))
                .frame(width: 190, height: 190)
                .scaleEffect(breathe ? 1.08 : 0.9)
                .blur(radius: 6)

            // Turning ring of light.
            Circle()
                .trim(from: 0.0, to: 0.72)
                .stroke(
                    AngularGradient(colors: [violet.opacity(0), violet, gold, .white],
                                    center: .center),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .frame(width: 112, height: 112)
                .rotationEffect(.degrees(spin ? 360 : 0))
                .shadow(color: gold.opacity(0.6), radius: 8)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 88, height: 88)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))

            Image(systemName: "book.fill")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(LinearGradient(colors: [.white, gold],
                                                startPoint: .top, endPoint: .bottom))
                .symbolEffect(.pulse, options: .repeating)
        }
        .frame(width: 200, height: 200)
        .accessibilityHidden(true)
    }

    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.12))
            Capsule()
                .fill(LinearGradient(colors: [violet, gold], startPoint: .leading, endPoint: .trailing))
                .frame(width: 180 * progress)
                .shadow(color: gold.opacity(0.5), radius: 4)
        }
        .frame(width: 180, height: 4)
        .accessibilityHidden(true)
    }

    private func start() {
        withAnimation(.easeOut(duration: 0.45)) { appeared = true }
        withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) { spin = true }
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { breathe = true }
        ripple = true
        // Eases toward 92% over ~12s and waits there; the overlay leaves the
        // moment the devotional lands, so it never has to fake 100%.
        withAnimation(.easeOut(duration: 12)) { progress = 0.92 }
    }

    private func walkSteps() async {
        while step < steps.count - 1 {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if Task.isCancelled { return }
            withAnimation(.easeInOut(duration: 0.45)) { step += 1 }
        }
    }
}
