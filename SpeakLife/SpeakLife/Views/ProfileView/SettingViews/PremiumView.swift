//
//  PremiumView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/16/22.
//

import SwiftUI

struct PremiumView: View {
    
    @Environment(\.openURL) var openURL
    
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State var presentDevotionalSubscriptionView = false
    @State private var countdown: TimeInterval = 0
        
    
    var body: some View {
        GeometryReader { geometry in
            if !subscriptionStore.isPremium {
                if appState.offerDiscount {
                    OfferPageView(countdown: $countdown) { }
                } else {
                    OptimizedSubscriptionView() { //}(size: geometry.size) {
                        // Handle callback - typically dismiss or navigation
                  }
                }
            } else {
                NavigationView {
                    ZStack {
                        // 💫 Gradient Background
                        Gradients().speakLifeCYOCell
                        .ignoresSafeArea()
                        
                        VStack(spacing: 24) {
                            Text("You are currently a premium member")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            
                            Text("Thank you for supporting the mission of speaking life daily!")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            
                            Button(action: {
                                openURL(URL(string: "itms-apps://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/DirectAction/manageSubscriptions")!)
                            }) {
                                Text("Manage Subscription")
                                    .font(.system(size: 17, weight: .medium, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .padding(.horizontal)
                            
                            Spacer()
                        }
                        .padding(.top, 80)
                    }
                    .navigationTitle("Manage Subscription")
                    .navigationBarTitleDisplayMode(.inline)
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
               // Stop the timer
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
