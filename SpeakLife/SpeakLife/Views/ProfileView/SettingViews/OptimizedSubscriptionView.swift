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
    
    var body: some View {
        HStack(spacing: 16) {
            VStack {
                Image(systemName: benefit.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Constants.DAMidBlue) // SpeakLife blue
                    .frame(width: 24, height: 24)
                Spacer()
                
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(benefit.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(benefit.description)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

struct AbideStylePricingOption: View {
    let option: PricingOption
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                HStack(spacing: 12) {
                    // Selection indicator
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                            .frame(width: 20, height: 20)
                        
                        if option.isSelected {
                            Circle()
                                .fill(Constants.DAMidBlue) // SpeakLife blue
                                .frame(width: 12, height: 12)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text(option.subtitle)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Text(option.price)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
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
                
                // Best Offer badge
                if option.isBestOffer {
                    VStack {
                        HStack {
                            Spacer()
                            Text("Best Offer")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(red: 1.0, green: 0.8, blue: 0.0))
                                )
                                .offset(x: -8, y: -0)
                        }
                        Spacer()
                    }
                }
            }
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
    var flag = true
    
    var callback: (() -> Void)?
    
    // Benefits matching the Abide screenshot
    private let benefits = [
        AbideStyleBenefit(
            icon: "leaf.fill",
            title: "Find Peace",
            description: "Explore affirmation categories for answers to your life's circumanstances"
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
                                benefitsSection
                                
                                // Space for sticky bottom
                                // Spacer().frame(height: geometry.size.height * 0.2)
                            }
                        }
                        
                        stickyBottomSection
                            .frame(height: geometry.size.height * 0.35)
                    }
                    
                    // Close button
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Color.black.opacity(0.3)))
                            }
                            .padding(.top, geometry.safeAreaInsets.top + 20)
                            .padding(.trailing, 20)
                        }
                        Spacer()
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
            }
        }
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
        ZStack {
            // Background image
            Image("starrySunrise")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: geometry.size.height * 0.33)
                .clipped()
            
            // Gradient overlay
//            LinearGradient(
//                gradient: Gradient(colors: [
//                    Color.clear,
//                    Constants.SLBlue.opacity(0.3)
//                ]),
//                startPoint: .top,
//                endPoint: .bottom
//            )
            
            // Content
            VStack(spacing: geometry.size.height * 0.02) {
                Spacer().frame(height:geometry.size.height * 0.1)
                
                // Logo and title
                VStack(spacing: geometry.size.height * 0.015) {
                    Image("appIconDisplay")
                        .resizable()
                        .frame(width: geometry.size.width * 0.18, height: geometry.size.width * 0.18)
                        .clipShape(RoundedRectangle(cornerRadius: geometry.size.width * 0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: geometry.size.width * 0.04)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    
                    Text("SpeakLife")
                        .font(.system(size: 26, weight: .bold))
                        .shadow(color: Color.white.opacity(0.6), radius: 4, x: 0, y: 2)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                }
                
                Spacer()
                    .frame(height:geometry.size.height * 0.0005)
                
                // Join banner
                VStack(spacing: geometry.size.height * 0.01) {
                    Text("Join the 50,000+ Growing in Faith Daily")
                        .font(.system(size: geometry.size.width * 0.040, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(dynamicHeaderPricing)
                        .font(.system(size: geometry.size.width * 0.035, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, geometry.size.width * 0.05)
                .padding(.vertical, geometry.size.height * 0.02)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Constants.DAMidBlue.opacity(0.9))
                )
                .padding(.horizontal, geometry.size.width * 0.05)
                .padding(.bottom, geometry.size.height * 0.025)
            }
        }
        .frame(height: geometry.size.height * 0.33)
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(benefits, id: \.title) { benefit in
                BenefitRow(benefit: benefit)
            }
        }
       // .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 24)
       // .padding(.bottom, 24)
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
            
            AbideStylePricingOption(
                option: PricingOption(
                    product: subscriptionStore.currentOfferedPremiumMonthly,
                    title: "Monthly",
                    subtitle: "Full access, 7 days free \(monthlyEquivalentPrice)",
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
    
    private var stickyBottomSection: some View {
        VStack(spacing: 0) {
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
            
            VStack(spacing: 8) {
                // Pricing options
                pricingSection
                
                // CTA button
                ctaButton
                
                // Bottom links
                bottomLinks
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .padding(.bottom, 8)
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
            
            Link("Privacy", destination: URL(string: "https://speaklife.io/privacy")!)
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
