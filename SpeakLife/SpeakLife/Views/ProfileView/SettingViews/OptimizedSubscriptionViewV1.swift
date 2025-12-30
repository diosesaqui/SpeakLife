//
//  OptimizedSubscriptionViewV1.swift
//  SpeakLife
//
//  Original Optimized for maximum trial conversion and sales (Version 1 for A/B Testing)
//

import SwiftUI
import StoreKit
import FirebaseAnalytics

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

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
    @State private var iconPulse = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
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
                        .shadow(color: Color(red: 0.7, green: 0.3, blue: 1.0).opacity(iconPulse ? 0.6 : 0.3), radius: iconPulse ? 8 : 4, x: 0, y: 2)
                )
                .scaleEffect(iconPulse ? 1.05 : 1.0)
                .onAppear {
                    withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        iconPulse = true
                    }
                }
            
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
    @State private var glowAnimation = false
    
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
                    color: option.isSelected ? (glowAnimation ? shadowColor.opacity(0.8) : shadowColor) : Color.clear,
                    radius: option.isSelected ? (glowAnimation ? (option.isYearly ? 18 : 12) : (option.isYearly ? 12 : 8)) : 0,
                    y: option.isSelected ? (option.isYearly ? 6 : 4) : 0
                )
                
                // Most Popular badge
                if option.isMostPopular {
                    VStack {
                        HStack {
                            Spacer()
                            Text("Most popular • Best for transformation")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
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
        .onAppear {
            if option.isSelected {
                withAnimation(Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    glowAnimation = true
                }
            }
        }
        .onChange(of: option.isSelected) { isSelected in
            if isSelected {
                withAnimation(Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    glowAnimation = true
                }
            } else {
                glowAnimation = false
            }
        }
    }
    
    private func getSubscriptionTypeText(for option: PricingOptionV1, showingWeeklyMonthly: Bool) -> String {
        guard let product = option.product else {
            return "Weekly"
        }
        
        if product.id.contains("Weekly") || product.id.contains("1WK") || product.id.lowercased().contains("week") {
            return "Weekly"
        } else if product.id.contains("1YR") || product.id.contains("Yearly") || product.id.lowercased().contains("year") {
            return "Yearly – \(option.monthlyEquivalent ?? "")"
        } else if product.id.contains("Lifetime") || product.id.lowercased().contains("lifetime") {
            return "Lifetime"
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
    let isLifetimePlan: Bool
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
        "Walk in Your New Identity"
    }
    
    private var ctaSubtitle: String {
        if isLifetimePlan {
            return "Forever access • One-time payment"
        }
        return isYearlyPlan ? "3 Days Free • Cancel Anytime" : "Your breakthrough starts today"
    }
    
    private var preferencesTracker: UserPreferencesTracker {
        UserPreferencesTracker.shared
    }
 }

// MARK: - Main View (V1)
struct OptimizedSubscriptionViewV1: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @ObservedObject private var preferencesTracker = UserPreferencesTracker.shared
    
    @State private var isShowingError = false
    @State private var errorMessage = ""
    @State private var currentSelection: Product?
    @State private var hasInitialized = false
    @State private var animateCTA = false
    @State private var isInitialLoad = true
    @State private var testimonialIndex = 0
    @State private var timeRemaining: TimeInterval = 600
    @State private var showPrivacyPolicy = false
    @State private var starAnimation = false
    @State private var showCloseButton = false
    @State private var starPositions: [CGPoint] = []
    @State private var starOffsets: [CGPoint] = []
    
    let size: CGSize
    var callback: (() -> Void)?
    var isPresentedModally: Bool = true  // Default to true to show close button by default
    
    private let transformationStories = [
        "Thanks SpeakLife for helping me to know who Jesus is. I love everything about SpeakLife. It has brought me closer to Him...",
        "This app was created under the manifestation and direction of the Holy Spirit...",
        "I'm spending more time on this than facebook. This is filling me with truth instead of garbage and the audios are amazing...",
        "I love to be able to feed on promises of God thruout the day, it's so upliting and encouraging. It feeds my soul...",
        "I love this app so much its amazing all glory be to God...",
        "I just read the letter from my Heavenly Father on this app and it really drives home the message of God's love for me...",
        "I love the daily reminders they've been helping me renew my mind and how I think..."
    ]
    
    private var valueProps: [ValuePropositionV1] {
        let paywallCopy = preferencesTracker.getDynamicPaywallCopy()
        let icons = ["flame.fill", "sun.max.fill", "crown.fill", "heart.circle.fill", "sparkles"]
        
        return paywallCopy.valueProps.prefix(5).enumerated().map { index, prop in
            ValuePropositionV1(
                icon: icons[safe: index] ?? "star.fill",
                text: prop
            )
        }
    }
    
    private let valuePropsSupport = [
        ValuePropositionV1(icon: "sunrise.fill", text: "Become the person Jesus sees when He looks at you"),
        ValuePropositionV1(icon: "lock.open.fill", text: "Access 2000+ divine promises that reshape reality"),
        ValuePropositionV1(icon: "hands.sparkles.fill", text: "Join the movement changing millions of destinies"),
        ValuePropositionV1(icon: "sunrise.fill", text: "Discover Heaven's secrets that unlock breakthrough"),
    ]
    
    var body: some View {
        ZStack {
            // Enhanced gradient background with depth
            enhancedBackgroundGradient
            
            // Main content
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                     //   headerSection
                        mainOfferSection
                        Spacer().frame(height: 16)
                        pricingSection
                        transformationSection
                        Spacer().frame(height: 8)
                       
                        trustSection
                        Spacer().frame(height: 150)
                    }
                }
            }
            
            VStack {
                Spacer()
                floatingCTASection
            }
            
            // Enhanced close button - only show when presented modally
//            if isPresentedModally {
//                VStack {
//                    HStack {
//                        Spacer()
//                        ElegantCloseButton(isVisible: showCloseButton) {
//                            dismiss()
//                        }
//                    }
//                    .padding(.top, 50)
//                    .padding(.trailing, 20)
//                    Spacer()
//                }
//            }
            
            if declarationStore.isPurchasing {
                RotatingLoadingImageView()
            }
        } // Allow content to extend to bottom
        .onAppear(perform: setupView)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            updateCountdown()
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
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
    
    private var isLifetimePlan: Bool {
        guard let currentSelection = currentSelection else { return false }
        return currentSelection.id == subscriptionStore.currentOfferedLifetime?.id ||
               currentSelection.id.contains("Lifetime")
    }
    
    private var currentDisplayPrice: String {
        currentSelection?.displayPrice ?? 
        subscriptionStore.currentOfferedWeekly?.displayPrice ?? 
        "$3.99"
    }
    
    
    private var weeklyPrice: String {
        subscriptionStore.currentOfferedWeekly?.displayPrice ?? "$3.99"
    }
    
    private var lifetimePrice: String {
        subscriptionStore.currentOfferedLifetime?.displayPrice ?? "$99.99"
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
    private var enhancedBackgroundGradient: some View {
        ZStack {
            // Base gradient layer with richer colors
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.35), // Deep royal blue
                    Color(red: 0.35, green: 0.1, blue: 0.5),  // Rich purple
                    Color(red: 0.15, green: 0.05, blue: 0.25) // Deep midnight
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Overlay gradient for depth
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.4, green: 0.2, blue: 0.8).opacity(0.3),
                    Color.clear
                ]),
                center: .topLeading,
                startRadius: 50,
                endRadius: 400
            )
            
            // Second radial gradient for glow effect
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.3, blue: 0.9).opacity(0.25),
                    Color.clear
                ]),
                center: .bottomTrailing,
                startRadius: 100,
                endRadius: 500
            )
            
            // Floating stars animation
            GeometryReader { geometry in
                ForEach(0..<20, id: \.self) { index in
                    Image(systemName: getStarSymbol(for: index))
                        .font(.system(size: getStarSize(for: index), weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(getStarOpacity(for: index, base: 0.4)),
                                    Color(red: 0.9, green: 0.9, blue: 1.0).opacity(getStarOpacity(for: index, base: 0.3)),
                                    Color(red: 0.8, green: 0.9, blue: 1.0).opacity(getStarOpacity(for: index, base: 0.2))
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .position(
                            x: (starPositions[safe: index]?.x ?? CGFloat.random(in: 20...max(40, geometry.size.width - 20))) + (starOffsets[safe: index]?.x ?? 0),
                            y: (starPositions[safe: index]?.y ?? CGFloat.random(in: 80...max(160, geometry.size.height - 150))) + (starOffsets[safe: index]?.y ?? 0)
                        )
                        .scaleEffect(starAnimation ? 1.0 : 0.7)
                        .rotationEffect(.degrees(starAnimation ? (index % 2 == 0 ? 360 : -360) : 0))
                        .animation(
                            Animation.easeInOut(duration: Double.random(in: 3.0...8.0))
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.1),
                            value: starAnimation
                        )
                        .onAppear {
                            // Initialize positions if needed with safe bounds
                            if starPositions.count <= index {
                                let safeWidth = max(40, geometry.size.width - 20)
                                let safeHeight = max(160, geometry.size.height - 150)
                                
                                let newPosition = CGPoint(
                                    x: CGFloat.random(in: 20...safeWidth),
                                    y: CGFloat.random(in: 80...safeHeight)
                                )
                                starPositions.append(newPosition)
                                
                                let newOffset = CGPoint(
                                    x: CGFloat.random(in: -30...30),
                                    y: CGFloat.random(in: -30...30)
                                )
                                starOffsets.append(newOffset)
                            }
                        }
                }
            }
        }
        .ignoresSafeArea()
    }
    
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
    }
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Progress dots at top
            HStack {
                Spacer()
                ProgressDots(current: 4, total: 4)
                    .padding(.top, 10)
                    .padding(.trailing, 20)
            }
            
            Spacer().frame(height: 30)
        }
    }
    
    private var socialProofBanner: some View {
        HStack {
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(.green)
            Text("95% experience breakthrough within 7 days")
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
          //  appIconSection
            Spacer().frame(height: 50)
            headlineSection
            Spacer().frame(height: 10)
            valuePropsSection
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
        VStack(spacing: 8) {
            Text("Live Daily From Victory")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.center)
//            
//            Text("Your breakthrough is waiting.")
//                .font(.system(size: 16, weight: .medium, design: .rounded))
//                .foregroundColor(.white.opacity(0.85))
//                .multilineTextAlignment(.center)
//                .padding(.top, 2)
        }
        .multilineTextAlignment(.center)
    }
    
    private var valuePropsSection: some View {
        VStack(spacing: 8) {
            Text("Activate What's Already Yours:")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
            
            VStack(alignment: .leading, spacing: 12) {
//                ValuePropositionV1(icon: "waveform.badge.mic", text: "Personalized declarations that align you with Heaven's reality")
//                ValuePropositionV1(icon: "brain.head.profile", text: "Anointed audio that rewires your thought life")
//                ValuePropositionV1(icon: "book.circle", text: "Living Word that transforms from the inside out")
//                ValuePropositionV1(icon: "shield.lefthalf.filled", text: "Supernatural peace that guards your heart and mind")
                
                ValuePropositionV1(icon: "waveform.badge.mic", text: "Speak from victory, not for it")
                ValuePropositionV1(icon: "brain.head.profile", text: "Align your mind with God’s truth daily")
                ValuePropositionV1(icon: "book.circle", text: "Live rooted in your identity and Jesus’ finished work")
                ValuePropositionV1(icon: "shield.lefthalf.filled", text: "Peaceful, premium audio experiences")
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
            if !subscriptionStore.onlyShowYearly {
                // Lifetime option
                PricingOptionViewV1(
                    option: PricingOptionV1(
                        product: subscriptionStore.currentOfferedLifetime,
                        isSelected: currentSelection == subscriptionStore.currentOfferedLifetime,
                        isYearly: false,
                        displayPrice: lifetimePrice,
                        monthlyEquivalent: "One-time purchase",
                        savingsPercentage: nil,
                        isMostPopular: false
                    ),
                    action: selectLifetime,
                    showingWeeklyMonthly: false
                )
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var floatingCTASection: some View {
        VStack(spacing: 0) {
            // Subtle separator
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.1),
                    Color.clear
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 1)
            
            VStack(spacing: 16) {
                FloatingCTAButtonV1(
                    isYearlyPlan: isYearlyPlan,
                    isLifetimePlan: isLifetimePlan,
                    displayPrice: currentDisplayPrice,
                    action: makePurchase,
                    animateCTA: $animateCTA
                )
                
                trustIndicators
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                // Semi-transparent blur effect background
                Color.black.opacity(0.3)
                    .background(
                        .ultraThinMaterial
                    )
            )
        }
        .ignoresSafeArea(.all)
        .preferredColorScheme(.dark)
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
                Text("4.9 stars")
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
                
                Button("Privacy Policy", action: privayPolicy)
                    .font(.caption)
                    .foregroundColor(.blue)
            
            }
        }
        .padding(.bottom, 40)
    }
    
    
    // MARK: - Helper Functions
    private func getStarSymbol(for index: Int) -> String {
        let starSymbols = [
            "star.fill", "star", "sparkle", 
            "star.fill", "sparkles", "star",
            "star.fill", "sparkle", "star"
        ]
        return starSymbols[index % starSymbols.count]
    }
    
    private func getStarSize(for index: Int) -> CGFloat {
        let sizes: [CGFloat] = [4, 6, 8, 5, 7, 3, 9, 4, 6, 5]
        return sizes[index % sizes.count]
    }
    
    private func getStarOpacity(for index: Int, base: Double) -> Double {
        let variations: [Double] = [0.8, 0.6, 0.9, 0.5, 0.7, 0.4, 0.8, 0.6, 0.5, 0.7]
        return base * variations[index % variations.count]
    }
    
    // MARK: - Actions (V1)
    private func selectWeekly() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentSelection = subscriptionStore.currentOfferedWeekly
        }
    }
    
    private func selectLifetime() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            currentSelection = subscriptionStore.currentOfferedLifetime
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
        
        // Initialize star arrays
        starPositions = []
        starOffsets = []
        
        // Start star floating animation
        withAnimation(.easeInOut(duration: 1.0)) {
            starAnimation = true
        }
        
        // Start continuous star movement
        startContinuousStarAnimation()
        
        // Start CTA button animation
        withAnimation {
            animateCTA = true
        }
        
        // Elegant fade-in for close button after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7, blendDuration: 0.6)) {
                showCloseButton = true
            }
        }
        
        // Track paywall impression
        AnalyticsService.shared.trackPaywallImpression(
            paywallId: "optimized_subscription_v1",
            metadata: [
                "variant": "v1",
                "initial_plan": "yearly"
            ]
        )
        
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
    
    private func startContinuousStarAnimation() {
        // Initialize star arrays with proper count (20 stars now)
        DispatchQueue.main.async {
            for i in 0..<20 {
                if self.starPositions.count <= i {
                    self.starPositions.append(CGPoint(x: 0, y: 0))
                }
                if self.starOffsets.count <= i {
                    self.starOffsets.append(CGPoint(x: 0, y: 0))
                }
            }
        }
        
        // Start a timer that continuously moves stars around
        Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 4.0)) {
                // Update star offsets randomly to create floating movement
                for i in 0..<min(20, self.starOffsets.count) {
                    self.starOffsets[i] = CGPoint(
                        x: CGFloat.random(in: -40...40),
                        y: CGFloat.random(in: -40...40)
                    )
                }
            }
        }
        
        // Additional timer for opacity changes to create twinkling effect
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.5)) {
                self.starAnimation.toggle()
            }
        }
    }
    
    private func makePurchase() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        Task {
            // Set loading state immediately
            await MainActor.run {
                declarationStore.isPurchasing = true
            }
            
            do {
                guard let currentSelection = currentSelection else {
                    await MainActor.run {
                        declarationStore.isPurchasing = false
                        errorMessage = "Please select a subscription option."
                        isShowingError = true
                    }
                    return
                }
                
                if let transaction = try await subscriptionStore.purchaseWithID([currentSelection.id]) {
                    // Track paywall conversion
                    let priceValue = NSDecimalNumber(decimal: currentSelection.price).doubleValue
                    let productType = currentSelection.id.contains("Lifetime") ? "lifetime" : "subscription"
                    AnalyticsService.shared.trackPaywallConversion(
                        productId: currentSelection.id,
                        paywallId: "optimized_subscription_v1",
                        price: priceValue,
                        metadata: [
                            "variant": "v1",
                            "type": productType,
                            "duration": currentSelection.subscription?.subscriptionPeriod.debugDescription ?? (productType == "lifetime" ? "lifetime" : "unknown")
                        ]
                    )
                    
                    // Check if this is a trial start
                    let hasTrial = currentSelection.subscription?.introductoryOffer?.period != nil
                    if hasTrial {
                        AnalyticsService.shared.trackTrialStarted(
                            productId: currentSelection.id,
                            price: priceValue,
                            metadata: [
                                "trial_days": currentSelection.subscription?.introductoryOffer?.period.value ?? 0,
                                "variant": "v1"
                            ]
                        )
                    }
                    
                    // Keep existing event for backward compatibility
                    Analytics.logEvent("subscription_started_v1", parameters: [
                        "product_id": currentSelection.id,
                        "price": currentSelection.price,
                        "duration": currentSelection.subscription?.subscriptionPeriod.debugDescription ?? "unknown",
                        "ab_test_version": "v1"
                    ])
                    
                    // Success - dismiss view
                    await MainActor.run {
                        declarationStore.isPurchasing = false
                        callback?()
                        dismiss()
                    }
                } else {
                    // User cancelled or purchase pending
                    await MainActor.run {
                        declarationStore.isPurchasing = false
                    }
                }
            } catch {
                await MainActor.run {
                    declarationStore.isPurchasing = false
                    errorMessage = "Unable to start your subscription. Please try again."
                    isShowingError = true
                }
            }
        }
    }
    
    private func restore() {
        Task {
            await MainActor.run {
                declarationStore.isPurchasing = true
            }
            
            try? await AppStore.sync()
            
            await MainActor.run {
                declarationStore.isPurchasing = false
                errorMessage = "Purchases restored successfully"
                isShowingError = true
            }
        }
    }
    
    private func privayPolicy() {
       showPrivacyPolicy = true
    }
}
