//
//  OptimizedSubscriptionViewV2.swift
//  SpeakLife
//
//  Polished subscription view with better layout and copy
//

import SwiftUI
import StoreKit
import FirebaseAnalytics

struct OptimizedSubscriptionViewV2: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    
    @State private var isShowingError = false
    @State private var errorMessage = ""
    @State private var selectedOption: String = "annual"
    @State private var showPrivacyPolicy = false
    @State private var showCloseButton = false
    
    var callback: (() -> Void)?
    
    private var yearlyPrice: String {
        subscriptionStore.currentOfferedPremium?.displayPrice ?? "$49.99"
    }
    
    private var monthlyPrice: String {
        subscriptionStore.currentOfferedPremiumMonthly?.displayPrice ?? "$9.99"
    }
    
    private var selectedProduct: Product? {
        selectedOption == "annual" ?
            subscriptionStore.currentOfferedPremium :
            subscriptionStore.currentOfferedPremiumMonthly
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full screen background
                backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Main content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            // App Icon & Title
                            
                            headerSection
                              //  .padding(.top, )
                            
                            // Hero Message
                            heroSection
                                .padding(.top, 30)
                            
                            // Value Props
                            valuePropsSection
                                .padding(.top, 40)
                            
                            // Testimonial/Social Proof
                            socialProofSection
                                .padding(.top, 30)
                            
                            // Spacer for sticky bottom
                            Spacer(minLength: 50)
                        }
                        .padding(.horizontal, 24)
                    }
                    
                    // Sticky Bottom Section
                    stickyBottomSection
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0),
                                    Color.black.opacity(0.8),
                                    Color.black.opacity(0.9)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                
                // Loading overlay
                if declarationStore.isPurchasing {
                    RotatingLoadingImageView()
                }
                
                // Close button (appears after 5 seconds)
                if showCloseButton {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: {
                                if let callback = callback {
                                    callback()
                                } else {
                                    dismiss()
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white.opacity(0.7))
                                    .background(Circle().fill(Color.black.opacity(0.3)))
                            }
                            .padding(.top, 60)
                            .padding(.trailing, 20)
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            setupView()
            startCloseButtonTimer()
        }
        .alert("", isPresented: $isShowingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
    }
    
    // MARK: - View Components
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.1, green: 0.15, blue: 0.3), // Dark blue
                Color(red: 0.15, green: 0.1, blue: 0.25), // Dark purple
                Color(red: 0.05, green: 0.05, blue: 0.15) // Almost black
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // App Icon\
            Spacer().frame(height: 44)
            Image("appIconDisplay")
                .resizable()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // App Name
            Text("SpeakLife")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
    
    private var heroSection: some View {
        VStack(spacing: 12) {
            Text("Renew Your Mind. Respond Like Jesus")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("Give God’s Word daily attention and grow stronger in Christ.")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            // Rating
            HStack(spacing: 4) {
                ForEach(0..<5) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                }
                Text("4.9")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
//                Text("(2,847 ratings)")
//                    .font(.system(size: 12))
//                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private var valuePropsSection: some View {
        VStack(spacing: 20) {
            ValuePropRow(
                icon: "quote.bubble.fill",
                title: "Replace Every Lie With God's Truth",
                description: "Daily declarations rewire your mind until God's Word becomes your first response."
            )

            ValuePropRow(
                icon: "shield.fill",
                title: "Build a Mind Nothing Can Shake",
                description: "Spoken truth is your greatest weapon. It's exactly how Jesus defeated every attack."
            )

            ValuePropRow(
                icon: "eye.fill",
                title: "No More Fear of the Future — God Has a Promise for It",
                description: "Faith comes by hearing. Audio devotionals put Scripture in your ears morning and night."
            )

            ValuePropRow(
                icon: "person.circle.fill",
                title: "Become Who God Said You Are",
                description: "Know your identity in Christ so deeply that fear, doubt, and shame lose their grip."
            )


        }
    }
    
    private var socialProofSection: some View {
        VStack(spacing: 12) {
            Text("Join 100,000+ believers transforming their minds in Christ")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            
            // Mini testimonial
            VStack(spacing: 8) {
                Text("\"This app changed my life. My anxiety is gone!\"")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .italic()
                
                HStack(spacing: 2) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow.opacity(0.8))
                    }
                    Text("- Sarah M.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
    
    private var stickyBottomSection: some View {
        VStack(spacing: 16) {
            // Pricing Option (Single for simplicity)
            Button(action: { selectedOption = "annual" }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Annual Plan")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            // Badge
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.green)
                                )
                        }
                        
                        Text("3 days free, then \(yearlyPrice)/year")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text("Just $0.14/day")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                    }
                    
                    Spacer()
                    
                    // Checkmark
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green, lineWidth: 2)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Free trial text above CTA
            Text("First 3 days FREE, then \(yearlyPrice)/year")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            
            // CTA Button
            Button(action: makePurchase) {
                Text("Begin My 7-Day Faith Reset")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(
                                LinearGradient(
                                    colors: [Constants.DAMidBlue, Constants.DAMidBlue.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Terms & Privacy
            HStack(spacing: 20) {
                Button("Restore") {
                    restore()
                }
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
                
                Button("Terms") {
                    if let url = URL(string: "https://helloaotheapp.wordpress.com/2025/01/10/speaklife-terms-and-conditions/") {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
                
                Button("Privacy Policy") {
                    showPrivacyPolicy = true
                }
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .padding(.bottom, 8) // Extra bottom padding for home indicator
    }
    
    // MARK: - Helper Functions
    
    private func setupView() {
        Analytics.logEvent("subscription_view_appeared", parameters: nil)
    }
    
    private func startCloseButtonTimer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeIn(duration: 0.5)) {
                self.showCloseButton = true
            }
        }
    }
    
    private func makePurchase() {
        guard let product = selectedProduct else { return }
        
        Analytics.logEvent("subscription_initiated", parameters: [
            "product_type": selectedOption,
            "price": selectedOption == "annual" ? yearlyPrice : monthlyPrice
        ])
        
        Task {
            do {
                let purchased = try await subscriptionStore.purchase(product, paywallName: "OptimizedSubscriptionV2_Onboarding")
                // Only advance if purchase was successful
                if purchased {
                    Analytics.logEvent("subscription_success", parameters: [
                        "product_type": selectedOption,
                        "paywall_name": "OptimizedSubscriptionV2_Onboarding"
                    ])
                    callback?()
                    dismiss()
                } else {
                    // Purchase was attempted but no transaction returned
                    errorMessage = "Purchase was cancelled or failed. Please try again."
                    isShowingError = true
                }
            } catch {
                errorMessage = "Purchase failed. Please try again."
                isShowingError = true
                Analytics.logEvent("subscription_failed", parameters: [
                    "error": error.localizedDescription
                ])
            }
        }
    }
    
    private func restore() {
        Task {
            await MainActor.run {
                declarationStore.isPurchasing = true
            }
            
            await subscriptionStore.restore()
            
            await MainActor.run {
                declarationStore.isPurchasing = false
                errorMessage = "Purchases restored successfully"
                isShowingError = true
            }
        }
    }
    
//    private func restore() {
//        Task {

//            if subscriptionStore.isPremium {
//                callback?()
//                dismiss()
//            } else {
//                errorMessage = "No previous purchases found."
//                isShowingError = true
//            }
//        }
//    }
}

// MARK: - Supporting Views

struct ValuePropRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Constants.DAMidBlue)
                .frame(width: 30, height: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// Add this if it doesn't exist
//struct RotatingLoadingImageView: View {
//    @State private var isRotating = false
//    
//    var body: some View {
//        ZStack {
//            Color.black.opacity(0.4)
//                .ignoresSafeArea()
//            
//            Image("appIconDisplay")
//                .resizable()
//                .frame(width: 60, height: 60)
//                .rotationEffect(.degrees(isRotating ? 360 : 0))
//                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRotating)
//                .onAppear {
//                    isRotating = true
//                }
//        }
//    }
//}

// Add if doesn't exist
//struct PrivacyPolicyView: View {
//    @Environment(\.dismiss) var dismiss
//    
//    var body: some View {
//        NavigationView {
//            WebView(url: URL(string: "https://helloaotheapp.wordpress.com/privacy-policy/")!)
//                .navigationTitle("Privacy Policy")
//                .navigationBarTitleDisplayMode(.inline)
//                .toolbar {
//                    ToolbarItem(placement: .navigationBarTrailing) {
//                        Button("Done") {
//                            dismiss()
//                        }
//                    }
//                }
//        }
//    }
//}
//
//// Simple WebView wrapper
//struct WebView: UIViewRepresentable {
//    let url: URL
//    
//    func makeUIView(context: Context) -> WKWebView {
//        let webView = WKWebView()
//        webView.load(URLRequest(url: url))
//        return webView
//    }
//    
//    func updateUIView(_ uiView: WKWebView, context: Context) {}
//}
//
//import WebKit

