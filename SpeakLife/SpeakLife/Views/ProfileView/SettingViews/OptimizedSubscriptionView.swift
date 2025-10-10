//
//  OptimizedSubscriptionView.swift
//  SpeakLife
//
//  Rebuilt with Abide-inspired design for maximum conversion
//

import SwiftUI
import StoreKit
import FirebaseAnalytics

// MARK: - View Models
struct AbideStyleBenefit {
    let icon: String
    let title: String
    let description: String
}

struct PricingOption {
    let product: Product?
    let title: String
    let subtitle: String
    let price: String
    let isSelected: Bool
    let isBestOffer: Bool
}

// MARK: - Subcomponents
struct BenefitRow: View {
    let benefit: AbideStyleBenefit
    @Environment(\.horizontalSizeClass) var sizeClass
    
    private var isCompact: Bool {
        sizeClass == .compact
    }
    
    var body: some View {
        HStack(spacing: isCompact ? 16 : 20) {
            VStack {
                Image(systemName: benefit.icon)
                    .font(.system(size: isCompact ? 20 : 24, weight: .medium))
                    .foregroundColor(Constants.DAMidBlue) // SpeakLife blue
                    .frame(width: isCompact ? 24 : 30, height: isCompact ? 24 : 30)
                Spacer()
                
            }
            VStack(alignment: .leading, spacing: isCompact ? 2 : 4) {
                Text(benefit.title)
                    .font(.system(size: isCompact ? 14 : 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(benefit.description)
                    .font(.system(size: isCompact ? 12 : 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, isCompact ? 4 : 6)
    }
}

struct AbideStylePricingOption: View {
    let option: PricingOption
    let action: () -> Void
    @Environment(\.horizontalSizeClass) var sizeClass
    
    private var isCompact: Bool {
        sizeClass == .compact
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: isCompact ? 12 : 16) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        .frame(width: isCompact ? 20 : 24, height: isCompact ? 20 : 24)
                    
                    if option.isSelected {
                        Circle()
                            .fill(Constants.DAMidBlue) // SpeakLife blue
                            .frame(width: isCompact ? 12 : 14, height: isCompact ? 12 : 14)
                    }
                }
                
                VStack(alignment: .leading, spacing: isCompact ? 2 : 3) {
                    Text(option.title)
                        .font(.system(size: isCompact ? 16 : 18, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(option.subtitle)
                        .font(.system(size: isCompact ? 12 : 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Text(option.price)
                    .font(.system(size: isCompact ? 16 : 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, isCompact ? 12 : 16)
            .padding(.vertical, isCompact ? 12 : 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(option.isSelected ? 
                          Constants.DAMidBlue.opacity(0.3) : // SpeakLife blue
                          Color.black.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(option.isSelected ? 
                                   Constants.DAMidBlue : // SpeakLife blue
                                   Color.white.opacity(0.2), 
                                   lineWidth: option.isSelected ? 2 : 1)
                    )
            )
            .overlay(
                // Best Offer badge as overlay
                Group {
                    if option.isBestOffer {
                        Text("Best Offer")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color(red: 1.0, green: 0.8, blue: 0.0))
                            )
                            .offset(y: -8)
                    }
                }
                , alignment: .topTrailing
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AbideStyleCTAButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("Continue")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Constants.DAMidBlue) // SpeakLife blue
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Main View
struct OptimizedSubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    @State private var isShowingError = false
    @State private var errorMessage = ""
    @State private var selectedOption: String = "annual" // "annual" or "monthly"
    @State private var showPrivacyPolicy = false
    var flag = true
    var callback: (() -> Void)?
    
    // Benefits matching the Abide screenshot
    private let benefits = [
        AbideStyleBenefit(
            icon: "leaf.fill",
            title: "Find Peace",
            description: "Explore affirmation categories for answers to your life's circumstances"
        ),
//        AbideStyleBenefit(
//            icon: "moon.fill",
//            title: "Improve Sleep",
//            description: "500+ calming bedtime stories, relaxing music, and ambient sounds"
//        ),
        AbideStyleBenefit(
            icon: "heart.fill",
            title: "Be Encouraged",
            description: "Start your day with \"New Creation\" devotionals and uplifting audio"
        ),
        AbideStyleBenefit(
            icon: "sparkles",
            title: "Deepen Faith",
            description: "1500+ affirmations on topics like anxiety, healing, and spiritual growth with 25+ visual backgrounds"
        ),
        AbideStyleBenefit(
            icon: "speaker.wave.2.fill",
            title: "Seamless Listening",
            description: "Stream continuously to renw your mind"
        ),
        AbideStyleBenefit(
            icon: "heart.circle.fill",
            title: "Invest in Well-Being",
            description: "Get full access for just $39.99/year—less than $1/week"
        )
    ]
    
    var body: some View {
       
        GeometryReader { geometry in
            if subscriptionStore.showSubscriptionFirst {
                OptimizedSubscriptionViewV1(size: geometry.size)
            } else {
                ZStack {
                    // Background
                    Constants.SLBlue.ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // Scrollable content
                        ScrollView {
                            VStack(spacing: 0) {
                                // Header with background image
                                
                                headerSection(geometry: geometry)
                                
                                // Benefits
                                benefitsSection(geometry: geometry)
                                
                                // Space for sticky bottom
                                // Spacer().frame(height: geometry.size.height * 0.2)
                            }
                        }
                        
                        stickyBottomSection(geometry: geometry)
                            .frame(height: isIPad(geometry) ? 
                                   geometry.size.height * 0.25 : 
                                   geometry.size.height * 0.35)
                    }
                
                    
                    if declarationStore.isPurchasing {
                        RotatingLoadingImageView()
                    }
                }
                
                .onAppear(perform: setupView)
                .alert("", isPresented: $isShowingError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(errorMessage)
                }
                .sheet(isPresented: $showPrivacyPolicy) {
                    PrivacyPolicyView()
                }
            }
        }
    }
    
    // Helper function to detect iPad
    private func isIPad(_ geometry: GeometryProxy) -> Bool {
        return geometry.size.width > 600
    }
    
    // MARK: - Computed Properties
    private var yearlyPrice: String {
        subscriptionStore.currentOfferedPremium?.displayPrice ?? "$39.99"
    }
    
    private var monthlyPrice: String {
        subscriptionStore.currentOfferedPremiumMonthly?.displayPrice ?? "$9.99"
    }
    
    private var yearlyEquivalentPrice: String {
        guard let yearlyProduct = subscriptionStore.currentOfferedPremium else {
            return "then $39.99 per year"
        }
        return "then \(yearlyProduct.displayPrice) per year"
    }
    
    private var monthlyEquivalentPrice: String {
        guard let monthlyProduct = subscriptionStore.currentOfferedPremiumMonthly else {
            return "then $9.99/mo"
        }
        return "then \(monthlyProduct.displayPrice)/mo"
    }
    
    private var dynamicHeaderPricing: String {
        if selectedOption == "annual" {
            guard let yearlyProduct = subscriptionStore.currentOfferedPremium else {
                return "Get 7 days free, then $39.99 per year"
            }
            return "Get 7 days free, then \(yearlyProduct.displayPrice) per year"
        } else {
            guard let monthlyProduct = subscriptionStore.currentOfferedPremiumMonthly else {
                return "Get 7 days free, then $9.99/mo"
            }
            return "Get 7 days free, then \(monthlyProduct.displayPrice)/mo"
        }
    }
    
    private var selectedProduct: Product? {
        selectedOption == "annual" ? 
            subscriptionStore.currentOfferedPremium : 
            subscriptionStore.currentOfferedPremiumMonthly
    }
    
    // MARK: - View Components
    
    private func headerSection(geometry: GeometryProxy) -> some View {
        let iPad = isIPad(geometry)
        let iconSize = iPad ? min(120, geometry.size.width * 0.12) : geometry.size.width * 0.18
        let headerHeight = iPad ? geometry.size.height * 0.28 : geometry.size.height * 0.33
        let titleSize: CGFloat = iPad ? 32 : 26
        let joinTextSize = iPad ? min(20, geometry.size.width * 0.03) : geometry.size.width * 0.040
        let subtitleSize = iPad ? min(16, geometry.size.width * 0.025) : geometry.size.width * 0.035
        
        return ZStack {
            // Background image
            Image("starrySunrise")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: headerHeight)
                .clipped()
            
            // Content
            VStack(spacing: iPad ? 20 : geometry.size.height * 0.02) {
                Spacer().frame(height: iPad ? 60 : geometry.size.height * 0.1)
                
                // Logo and title
                VStack(spacing: iPad ? 12 : geometry.size.height * 0.015) {
                    Image("appIconDisplay")
                        .resizable()
                        .frame(width: iconSize, height: iconSize)
                        .clipShape(RoundedRectangle(cornerRadius: iPad ? 24 : geometry.size.width * 0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: iPad ? 24 : geometry.size.width * 0.04)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text("SpeakLife")
                        .font(.system(size: titleSize, weight: .bold))
                        .shadow(color: Color.white.opacity(0.6), radius: 4, x: 0, y: 2)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
                
                Spacer()
                    .frame(height: iPad ? 10 : geometry.size.height * 0.0005)
                
                // Join banner
                VStack(spacing: iPad ? 8 : geometry.size.height * 0.01) {
                    Text("Join the 50,000+ Growing in Faith Daily")
                        .font(.system(size: joinTextSize, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(iPad ? 1 : 2)
                    
                    Text(dynamicHeaderPricing)
                        .font(.system(size: subtitleSize, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, iPad ? 24 : geometry.size.width * 0.05)
                .padding(.vertical, iPad ? 16 : geometry.size.height * 0.02)
                .frame(maxWidth: iPad ? 500 : .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Constants.DAMidBlue.opacity(0.9))
                )
                .padding(.horizontal, iPad ? 40 : geometry.size.width * 0.05)
                .padding(.bottom, iPad ? 20 : geometry.size.height * 0.025)
            }
        }
        .frame(height: headerHeight)
    }
    
    private func benefitsSection(geometry: GeometryProxy) -> some View {
        let iPad = isIPad(geometry)
        let horizontalPadding = iPad ? 40.0 : 24.0
        let topPadding = iPad ? 32.0 : 24.0
        
        return VStack(alignment: .leading, spacing: iPad ? 16 : 12) {
            ForEach(benefits, id: \.title) { benefit in
                BenefitRow(benefit: benefit)
            }
        }
        .frame(maxWidth: iPad ? 700 : .infinity, alignment: .leading)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
    }
    
    private var pricingSection: some View {
        VStack(spacing: 0) {
            AbideStylePricingOption(
                option: PricingOption(
                    product: subscriptionStore.currentOfferedPremium,
                    title: "Annual",
                    subtitle: "Full access, 7 days free \(yearlyEquivalentPrice)",
                    price: yearlyPrice,
                    isSelected: selectedOption == "annual",
                    isBestOffer: true
                ),
                action: { selectedOption = "annual" }
            )
            .padding(.bottom, 8)
            
            AbideStylePricingOption(
                option: PricingOption(
                    product: subscriptionStore.currentOfferedPremiumMonthly,
                    title: "Monthly",
                    subtitle: "\(monthlyEquivalentPrice)",
                    price: monthlyPrice,
                    isSelected: selectedOption == "monthly",
                    isBestOffer: false
                ),
                action: { selectedOption = "monthly" }
            )
        }
        .frame(maxWidth: .infinity)
    }
    
    private var ctaButton: some View {
        AbideStyleCTAButton(action: makePurchase)
            .frame(maxWidth: .infinity)
    }
    
    private func stickyBottomSection(geometry: GeometryProxy) -> some View {
        let iPad = isIPad(geometry)
        let horizontalPadding = iPad ? 40.0 : 20.0
        let verticalPadding = iPad ? 20.0 : 12.0
        
        return VStack(spacing: 0) {
            // Gradient fade effect at top
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Constants.SLBlue.opacity(0.95)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 15)
            
            VStack(spacing: 12) {
                // Pricing options - centered on iPad
                if iPad {
                    HStack(spacing: 20) {
                        Spacer()
                        pricingSection
                            .frame(maxWidth: 600)
                        Spacer()
                    }
                } else {
                    pricingSection
                }
                
                // CTA button
                ctaButton
                    .frame(maxWidth: iPad ? 600 : .infinity)
                
                // Bottom links
                bottomLinks
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .padding(.bottom, iPad ? 20 : 8)
            .background(Constants.SLBlue.opacity(0.95))
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    private var bottomLinks: some View {
        HStack(spacing: 30) {
            Button("Restore", action: restore)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            Button("Privacy Policy") {
                showPrivacyPolicy = true
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
        }
    }
    
    // MARK: - Actions
    private func setupView() {
        // Default to annual option
        selectedOption = "annual"
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
                guard let selectedProduct = selectedProduct else {
                    errorMessage = "Please select a subscription option."
                    isShowingError = true
                    return
                }
                
                if let _ = try await subscriptionStore.purchaseWithID([selectedProduct.id]) {
                    Analytics.logEvent("subscription_started", parameters: [
                        "product_id": selectedProduct.id,
                        "price": selectedProduct.price,
                        "duration": selectedProduct.subscription?.subscriptionPeriod.debugDescription ?? "unknown"
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
