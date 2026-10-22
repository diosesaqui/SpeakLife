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
            .sheet(isPresented: $viewModel.categoryNeedsPaywall) {
                OptimizedSubscriptionView() {
                    viewModel.categoryNeedsPaywall = false
                }
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
                        categoryPicker
                        HStack {
                            Spacer()
                            AppLogo(height: 90)
                            Spacer()
                        }
                        .dsAppear(0)

                        if viewModel.isGeneratingCategory {
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
            
        }
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

    /// "Daily" plus every life category. The pick is remembered, so each day
    /// opens on a fresh devotional written for that category.
    private var categoryPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryChip(title: "Daily", category: nil)
                    ForEach(DevotionalViewModel.devotionalCategories) { category in
                        categoryChip(title: category.name, category: category)
                    }
                }
                .padding(.vertical, 4)
            }
            .onAppear {
                if let selected = viewModel.selectedCategory {
                    proxy.scrollTo(selected.rawValue, anchor: .center)
                }
            }
        }
    }

    private func categoryChip(title: String, category: DeclarationCategory?) -> some View {
        let isSelected = viewModel.selectedCategory == category
        return Button {
            guard !isSelected else { return }
            Task {
                await viewModel.selectCategory(category, isPremium: isPremiumReader)
                withAnimation { scrollToTop = true }
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.black : Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Color.white : Color.white.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isGeneratingCategory)
        .id(category?.rawValue ?? "daily")
    }

    private var generatingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.white)
            Text("Writing today's devotional on \(viewModel.selectedCategory?.name ?? "your topic")...")
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var failedState: some View {
        VStack(spacing: 14) {
            Text("We couldn't load today's devotional. Check your connection and try again.")
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
            Button("Try again") {
                Task { await viewModel.loadCategoryDevotional(isPremium: isPremiumReader) }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white))
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
