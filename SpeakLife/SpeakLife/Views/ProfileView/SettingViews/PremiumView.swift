//
//  PremiumView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/16/22.
//

import SwiftUI
import StoreKit

struct PremiumView: View {
    
    @Environment(\.openURL) var openURL
    
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var countdown: TimeInterval = 0
    @State private var showCancelConfirmation = false
        
    
    var body: some View {
        GeometryReader { geometry in
            if !subscriptionStore.isPremium {
                if appState.offerDiscount {
                    OfferPageView(countdown: $countdown) { }
                } else {
//                    if subscriptionStore.useEnhancedOnboarding {
//                        OptimizedSubscriptionViewV2() { }
//                    } else {
                        OptimizedSubscriptionView() { }
                  //  }
                }
            } else {
                NavigationView {
                    ZStack {
                        // 💫 Gradient Background
                        Gradients().speakLifeCYOCell
                            .ignoresSafeArea()
                        
                        VStack(spacing: 32) {
                            Spacer()
                            
                            // Header
                            VStack(spacing: 16) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(Color.yellow)
                                
                                Text("SpeakLife Premium")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("Thank you for supporting our mission!")
                                    .font(.system(size: 18, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            
                            Spacer()
                            
                            // Action Buttons
                            VStack(spacing: 16) {
                                Button(action: {
                                    AnalyticsService.shared.trackUserAction(
                                        "manage_subscription_tapped",
                                        category: "subscription",
                                        metadata: ["source": "premium_view"]
                                    )
                                    // Open iPhone Settings app
                                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                        openURL(settingsURL)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "gear")
                                        Text("Manage Subscription")
                                    }
                                    .font(.system(size: 18, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.blue.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                
                                Button(action: {
                                    AnalyticsService.shared.trackUserAction(
                                        "cancel_subscription_tapped",
                                        category: "subscription",
                                        metadata: ["source": "premium_view"]
                                    )
                                    showCancelConfirmation = true
                                }) {
                                    HStack {
                                        Image(systemName: "xmark.circle")
                                        Text("Cancel Subscription")
                                    }
                                    .font(.system(size: 18, weight: .medium, design: .rounded))
                                    .foregroundColor(.red)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 56)
                                    .background(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                            .padding(.horizontal, 32)
                            
                            Spacer()
                        }
                        .padding(.top, 80)
                    }
                    .navigationTitle("Manage Subscription")
                    .navigationBarTitleDisplayMode(.inline)
                    .sheet(isPresented: $showCancelConfirmation) {
                        CancellationConfirmationView(
                            isPresented: $showCancelConfirmation,
                            onCancel: {
                                openURL(URL(string: "itms-apps://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/DirectAction/manageSubscriptions")!)
                            }
                        )
                    }
                }
            }
        }
        .onAppear {
            if appState.discountEndTime == nil {
                appState.discountEndTime = Date().addingTimeInterval(1 * 60 * 5)
            }
            initializeTimer()
        }
        .onReceive(timer) { timer in
            updateTimer()
        }
    }
    
    private func updateTimer() {
        guard appState.timeRemainingForDiscount != 0 else { return }
        if let endTime = appState.discountEndTime, Date() < endTime {
            appState.timeRemainingForDiscount = Int(endTime.timeIntervalSinceNow)
            countdown = endTime.timeIntervalSinceNow
        } else {
            appState.offerDiscount = false
            appState.timeRemainingForDiscount = 0
            countdown = 0
            timer.upstream.connect().cancel()
        }
    }
    
    private func initializeTimer() {
        if let endTime = appState.discountEndTime, Date() < endTime, !subscriptionStore.isPremium {
            appState.offerDiscount = true
            appState.timeRemainingForDiscount = Int(endTime.timeIntervalSinceNow)
            countdown = endTime.timeIntervalSinceNow
        } else {
            appState.offerDiscount = false
        }
    }
    
}

struct CancellationConfirmationView: View {
    @Binding var isPresented: Bool
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Text("We're sorry to see you go!")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("As a reminder — if you cancel and re-subscribe later on you'll no longer be locked in to your current rate if prices go up.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                        
                        Text("Thanks for giving SpeakLife a try and remember to stay healthy and keep declaring God's word over your life every day!")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        // Cancel Button
                        Button(action: {
                            AnalyticsService.shared.trackUserAction(
                                "subscription_cancellation_confirmed",
                                category: "subscription",
                                metadata: ["source": "cancel_confirmation"]
                            )
                            isPresented = false
                            onCancel()
                        }) {
                            Text("Cancel Subscription")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .underline()
                        }
                        
                        Text("For additional instructions, please follow the link:")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                        
                        Link("https://support.apple.com/HT202039", destination: URL(string: "https://support.apple.com/HT202039")!)
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                            .underline()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Cancel Membership")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}
