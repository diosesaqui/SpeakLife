//
//  OptimizedSubscriptionViewV1.swift
//  SpeakLife
//
//  Original Optimized for maximum trial conversion and sales (Version 1 for A/B Testing)
//

import SwiftUI
import StoreKit
import FirebaseAnalytics

// MARK: - View Models (V1)
struct PricingOptionV1 {
    let product: Product?
    let isSelected: Bool
    let isYearly: Bool
    let displayPrice: String
    let monthlyEquivalent: String?
    let savingsPercentage: String?
    let isMostPopular: Bool
}

// MARK: - Subcomponents (V1)
struct ValuePropositionV1: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.7, green: 0.3, blue: 1.0),  // Bright violet
                                    Color(red: 0.85, green: 0.6, blue: 1.0), // Lavender
                                    Color(red: 0.5, green: 0.2, blue: 0.9)   // Deep purple
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )

                        )
                        .shadow(color: Color.orange.opacity(0.3), radius: 4, x: 0, y: 2)
                )
            
            Text(text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PricingOptionViewV1: View {
    let option: PricingOptionV1
    let action: () -> Void
    let showingWeeklyMonthly: Bool
    
    var body: some View {
        Button(action: action) {
            ZStack {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(getSubscriptionTypeText(for: option, showingWeeklyMonthly: showingWeeklyMonthly))
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(textColor)
                        }
                    }
                    
                    Spacer()
                    
                    Text(option.displayPrice)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(textColor)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(backgroundGradient)
                .scaleEffect(option.isSelected ? 1.02 : 1.0)
                .shadow(
                    color: option.isSelected ? shadowColor : Color.clear,
                    radius: option.isSelected ? (option.isYearly ? 12 : 8) : 0,
                    y: option.isSelected ? (option.isYearly ? 6 : 4) : 0
                )
                
                // Most Popular badge
                if option.isMostPopular {
                    VStack {
                        HStack {
                            Spacer()
                            Text("7-Day Free Trial")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(
                                            Constants.gold
                                        )
                                )
                                .shadow(color: Color.yellow.opacity(0.4), radius: 6, y: 2)
                                .offset(x: -12, y: -12)
                        }
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getSubscriptionTypeText(for option: PricingOptionV1, showingWeeklyMonthly: Bool) -> String {
        guard let product = option.product else {
            return "Weekly"
        }
        
        if product.id.contains("Weekly") || product.id.contains("1WK") || product.id.lowercased().contains("week") {
            return "Weekly"
        } else if product.id.contains("1YR") || product.id.contains("Yearly") || product.id.lowercased().contains("year") {
            return "Yearly - \(option.monthlyEquivalent ?? "")"
        } else if product.id.contains("Monthly") || product.id.contains("MO") || product.id.lowercased().contains("month") {
            return "Monthly"
        } else {
            // Fallback based on the isYearly flag in the option
            if option.isYearly {
                return "Yearly"
            } else {
                return "Weekly"
            }
        }
    }
    
    private var textColor: Color {
        return .white
    }
    
    private var subtextColor: Color {
        if option.isSelected && option.isYearly {
            return .black.opacity(0.7)
        }
        return .white.opacity(0.7)
    }
    
    private var badgeBackgroundColor: Color {
        if option.isSelected && option.isYearly {
            return Color.black.opacity(0.7)
        }
        return Color.white.opacity(0.3)
    }
    
    private var shadowColor: Color {
        if option.isYearly {
            return Color.orange.opacity(0.2)
        }
        return Color.white.opacity(0.1)
    }
    
    private var backgroundGradient: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(weeklySelectedGradient)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        Color.white.opacity(0.9),
                        lineWidth: option.isSelected ? 3 : 1
                        )
            )
    }
    
    private var yearlySelectedGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 1.0, green: 0.88, blue: 0.2),
                Color(red: 1.0, green: 0.8, blue: 0.0),
                Color(red: 0.9, green: 0.7, blue: 0.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var weeklySelectedGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0.2),
                Color.white.opacity(0.15)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var unselectedGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.white.opacity(0.08),
                Color.white.opacity(0.04)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct FloatingCTAButtonV1: View {
    let isYearlyPlan: Bool
    let displayPrice: String
    let action: () -> Void
    @Binding var animateCTA: Bool
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(ctaTitle)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                
                Text(ctaSubtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.black.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color.white, location: 0.0),
                                .init(color: Color(red: 0.95, green: 0.95, blue: 0.95), location: 1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color.white.opacity(0.4), radius: 25, x: 0, y: 10)
                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
            )
            .scaleEffect(animateCTA ? 1.015 : 1.0)
            .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: animateCTA)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var ctaTitle: String {
        isYearlyPlan ? "Start My Transformation" : "Begin Speaking Life Today"
    }
    
    private var ctaSubtitle: String {
        return "Cancel anytime"
    }
 }

// MARK: - Main View (V1)
struct OptimizedSubscriptionViewV1: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    @State private var isShowingError = false
    @State private var errorMessage = ""
    @State private var currentSelection: Product?
    @State private var hasInitialized = false
    @State private var animateCTA = false
    @State private var isInitialLoad = true
    @State private var testimonialIndex = 0
    @State private var timeRemaining: TimeInterval = 600
    
    let size: CGSize
    var callback: (() -> Void)?
    
    private let transformationStories = [
        "Thanks SpeakLife for helping me to know who Jesus is. I love everything about SpeakLife. It has brought me closer to Him...",
        "This app was created under the manifestation and direction of the Holy Spirit...",
        "I'm spending more time on this than facebook. This is filling me with truth instead of garbage and the audios are amazing...",
        "I love to be able to feed on promises of God thruout the day, it's so upliting and encouraging. It feeds my soul...",
        "I love this app so much its amazing all glory be to God...",
        "I just read the letter from my Heavenly Father on this app and it really drives home the message of God's love for me...",
        "I love the daily reminders they've been helping me renew my mind and how I think..."
    ]
    
    private let valueProps = [
        ValuePropositionV1(icon: "sparkles", text: "Speak healing, see it manifest"),
        ValuePropositionV1(icon: "bolt.fill", text: "Turn setbacks into breakthroughs"),
        ValuePropositionV1(icon: "leaf.fill", text: "Plant yourself in promises that prosper"),
        ValuePropositionV1(icon: "crown.fill", text: "Walk in supernatural provision"),
        ValuePropositionV1(icon: "heart.circle.fill", text: "Peace that silences every fear"),
    ]
    
    private let valuePropsSupport = [
        ValuePropositionV1(icon: "sunrise.fill", text: "Build your life on Jesus"),
        ValuePropositionV1(icon: "lock.open.fill", text: "Unlock 2000+ declarations, devotionals & audio"),
        ValuePropositionV1(icon: "hands.sparkles.fill", text: "Help millions discover God's promises"),
        ValuePropositionV1(icon: "sunrise.fill", text: "Life-changing revelations that unlock God's power"),
    ]
    
    var body: some View {
        ZStack {
            backgroundGradient
           // Constants.SLBlue
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    mainOfferSection
                    Spacer().frame(height: 16)
                    pricingSection
                    transformationSection
                    Spacer().frame(height: 8)
                   
                    trustSection
                    Spacer().frame(height: 150)
                }
            }
            
            VStack {
                Spacer()
                floatingCTASection
            }
            
            if declarationStore.isPurchasing {
                RotatingLoadingImageView()
            }
        }
        .onAppear(perform: setupView)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            updateCountdown()
        }
        .alert("", isPresented: $isShowingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Computed Properties (V1)
    private var isYearlyPlan: Bool {
        // Default to yearly on initial load to prevent CTA flicker
        guard let currentSelection = currentSelection else { return true }
        return currentSelection.id == subscriptionStore.currentOfferedPremium?.id ||
               currentSelection.id.contains("1YR") || currentSelection.id.contains("Yearly")
    }
    
    private var currentDisplayPrice: String {
        currentSelection?.displayPrice ?? 
        subscriptionStore.currentOfferedWeekly?.displayPrice ?? 
        "$3.99"
    }
    
    
    private var weeklyPrice: String {
        subscriptionStore.currentOfferedWeekly?.displayPrice ?? "$3.99"
    }
    
    private var monthlyPrice: String {
        subscriptionStore.currentOfferedPremiumMonthly?.displayPrice ?? "$9.99"
    }
    
    private var yearlyPrice: String {
        subscriptionStore.currentOfferedPremium?.displayPrice ?? "$59.99"
    }
    
    private var yearlyEquivalentPrice: String {
        guard let yearlyProduct = subscriptionStore.currentOfferedPremium else {
            return "$3.33/mo"
        }
        let monthlyEquiv = yearlyProduct.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = yearlyProduct.priceFormatStyle.locale
        return "\(formatter.string(from: NSNumber(value: Double(truncating: monthlyEquiv as NSNumber))) ?? "$3.33")/mo"
    }
    
    
    private var yearlySavingsFromWeekly: String? {
        guard let weeklyProduct = subscriptionStore.currentOfferedWeekly,
              let yearlyProduct = subscriptionStore.currentOfferedPremium else {
            return nil
        }
        
        // Calculate what 52 weeks would cost at weekly rate
        let weeklyYearlyEquivalent = weeklyProduct.price * 52
        let yearlyCost = yearlyProduct.price
        
        // Only show savings if yearly is actually cheaper
        if yearlyCost < weeklyYearlyEquivalent {
            let savings = ((weeklyYearlyEquivalent - yearlyCost) / weeklyYearlyEquivalent) * 100 / 52
            let roundedSavings = Int(Double(truncating: savings as NSNumber).rounded())
            return "SAVE \(roundedSavings)%"
        }
        return nil
    }
    
    // MARK: - View Components (V1)
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.1, green: 0.2, blue: 0.4),
                Color(red: 0.3, green: 0.1, blue: 0.4),
                Color(red: 0.2, green: 0.1, blue: 0.3)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var headerSection: some View {
        Spacer().frame(height: 30)
    }
    
    private var socialProofBanner: some View {
        HStack {
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(.green)
            Text("Join 50,000+ believers transforming fear into faith in just 5 minutes.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(.green)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(
            Capsule()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.purple.opacity(0.6), .blue.opacity(0.6)]),
                    startPoint: .leading,
                    endPoint: .trailing
                ))
        )
        .padding(.horizontal)
        .padding(.bottom, 24)
    }
  
    
    private var mainOfferSection: some View {
        VStack(spacing: 12) {
            appIconSection
            headlineSection
//            if subscriptionStore.showSubscriptionFirst {
//                valuePropsSupportSection
//            } else {
                valuePropsSection
         //   }
        }
    }
    
    private var appIconSection: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.15),
                            Color.clear
                        ]),
                        center: .center,
                        startRadius: 10,
                        endRadius: 80
                    )
                )
                .frame(width: 100, height: 100)
            
            Image("appIconDisplay")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.8),
                                    Color.white.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .white.opacity(0.2), radius: 30, x: 0, y: 10)
        }
    }
    
    private var headlineSection: some View {
        VStack(spacing: 4) {
            Text("Ready to Speak God's Promises Daily?")
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            
            Text("Join thousands who are watching their words become their reality.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
    }
    
    private var valuePropsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(valueProps, id: \.text) { prop in
                prop
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var valuePropsSupportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(valuePropsSupport, id: \.text) { prop in
                prop
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var transformationSection: some View {
        VStack(spacing: 16) {
            Text("\"\(transformationStories[testimonialIndex])\"")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(testimonialIndex)
                .animation(.easeInOut(duration: 0.5), value: testimonialIndex)
                .padding(.horizontal, 30)
        }
        .padding(.vertical, 12)
    }
    @ViewBuilder
    private var pricingSection: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 8)
            
            PricingOptionViewV1(
            option: PricingOptionV1(
                product: subscriptionStore.currentOfferedPremium,
                isSelected: currentSelection == subscriptionStore.currentOfferedPremium,
                isYearly: true,
                displayPrice: yearlyPrice,
                monthlyEquivalent: "\(yearlyEquivalentPrice)",
                savingsPercentage: yearlySavingsFromWeekly,
                isMostPopular: true
            ),
            action: selectYearly,
            showingWeeklyMonthly: false
        )
        .padding(.horizontal, 20)

                // Monthly option
                PricingOptionViewV1(
                    option: PricingOptionV1(
                        product: subscriptionStore.currentOfferedPremiumMonthly,
                        isSelected: currentSelection == subscriptionStore.currentOfferedPremiumMonthly,
                        isYearly: false,
                        displayPrice: monthlyPrice,
                        monthlyEquivalent: "Cancel anytime",
                        savingsPercentage: nil,
                        isMostPopular: false
                    ),
                    action: selectMonthly,
                    showingWeeklyMonthly: true
                )
                .padding(.horizontal, 20)
        }
    }
    
    private var floatingCTASection: some View {
        VStack(spacing: 0) {
            Constants.SLBlue.opacity(0.95)
//            LinearGradient(
//                gradient: Gradient(colors: [
//                    Color.clear,
//                    Color(red: 0.2, green: 0.1, blue: 0.3).opacity(0.95)
//                ]),
//                startPoint: .top,
//                endPoint: .bottom
//            )
            .frame(height: 20)
            
            VStack(spacing: 16) {
                FloatingCTAButtonV1(
                    isYearlyPlan: isYearlyPlan,
                    displayPrice: currentDisplayPrice,
                    action: makePurchase,
                    animateCTA: $animateCTA
                )
                
                trustIndicators
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                Constants.SLBlue.opacity(0.95)
//                Color(red: 0.2, green: 0.1, blue: 0.3).opacity(0.95)
//                    .overlay(
//                        Rectangle()
//                            .fill(Color.white.opacity(0.05))
//                            .blur(radius: 1)
//                    )
           )
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    private var trustIndicators: some View {
        HStack(spacing: 24) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.2))
                Text("Instant access")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.2, green: 0.6, blue: 1.0))
                Text("Cancel anytime")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
    
    private var trustSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.yellow)
                    }
                }
                Text("3k+ 5 star reviews")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            HStack(spacing: 20) {
                Button("Restore", action: restore)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Link("Privacy", destination: URL(string: "https://speaklife.io/privacy")!)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Actions (V1)
    private func selectWeekly() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentSelection = subscriptionStore.currentOfferedWeekly
        }
    }
    
    private func selectMonthly() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentSelection = subscriptionStore.currentOfferedPremiumMonthly
        }
    }
    
    private func selectYearly() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentSelection = subscriptionStore.currentOfferedPremium
        }
    }
    
    private func setupView() {
        if currentSelection == nil {
            // Default to yearly as most popular - no animation on initial load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                currentSelection = subscriptionStore.currentOfferedPremium
            }
        }
        
        startTestimonialRotation()
    }
    
    private func updateCountdown() {
        if timeRemaining > 0 {
            timeRemaining -= 1
        }
    }
    
    private func startTestimonialRotation() {
        Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                testimonialIndex = (testimonialIndex + 1) % transformationStories.count
            }
        }
    }
    
    private func makePurchase() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        Task {
            declarationStore.isPurchasing = true
            defer {
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    declarationStore.isPurchasing = false
                }
            }
            
            do {
                guard let currentSelection = currentSelection else {
                    errorMessage = "Please select a subscription option."
                    isShowingError = true
                    return
                }
                
                if let _ = try await subscriptionStore.purchaseWithID([currentSelection.id]) {
                    Analytics.logEvent("subscription_started_v1", parameters: [
                        "product_id": currentSelection.id,
                        "price": currentSelection.price,
                        "duration": currentSelection.subscription?.subscriptionPeriod.debugDescription ?? "unknown",
                        "ab_test_version": "v1"
                    ])
                    callback?()
                }
            } catch {
                errorMessage = "Unable to start your subscription. Please try again."
                isShowingError = true
            }
        }
    }
    
    private func restore() {
        Task {
            declarationStore.isPurchasing = true
            try? await AppStore.sync()
            declarationStore.isPurchasing = false
            errorMessage = "Purchases restored successfully"
            isShowingError = true
        }
    }
}
