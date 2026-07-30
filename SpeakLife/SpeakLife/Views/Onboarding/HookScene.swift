//
//  HookScene.swift
//  SpeakLife
//
//  Hook screen before category selection to emotionally prime users
//

import SwiftUI
import FirebaseAnalytics

struct HookScene: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    
    let size: CGSize
    let callBack: (() -> Void)
    
    @State private var titleOpacity = 0.0
    @State private var subtitleOpacity = 0.0
    @State private var buttonOpacity = 0.0
    
    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // Progress dots at top
                HStack {
                    Spacer()
                    ProgressDots(current: 0, total: 5)
                        .padding(.top, proxy.safeAreaInsets.top + 10)
                        .padding(.trailing, 20)
                }
                .frame(width: proxy.size.width)
                
                Spacer()
                
                VStack(spacing: proxy.size.height < 700 ? 20 : 30) {
                    // Jesus image or soft glow background placeholder
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ]),
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 120
                                )
                            )
                            .frame(width: 150, height: 150)
                        
                        Image(systemName: "hands.sparkles")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .white.opacity(0.5), radius: 20, x: 0, y: 0)
                    }
                    .opacity(titleOpacity)
                    
                    // Hook message
                    VStack(spacing: proxy.size.height < 700 ? 12 : 16) {
                        Text("Your Words Carry Power.")
                            .font(.system(size: proxy.size.height < 700 ? 28 : 32, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                            .opacity(titleOpacity)
                        
                        Text("We speak because we agree with what Jesus already finished.")
                            .font(.system(size: proxy.size.height < 700 ? 18 : 22, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(radius: 2)
                            .opacity(subtitleOpacity)
                    }
                    .padding(.horizontal, 30)
                    
                    // Emotional priming text
                    Text("SpeakLife isn’t about getting victory. It’s about living from it.")
                        .font(.system(size: proxy.size.height < 700 ? 15 : 17, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 40)
                        .opacity(subtitleOpacity)
                }
                
                Spacer()
                
                // Continue button
                VStack(spacing: proxy.size.height < 700 ? 10 : 15) {
                    ShimmerButton(
                        colors: [.blue, .purple],
                        buttonTitle: "Walk in My New Identity →",
                        action: {
                            AnalyticsService.shared.track("HookScreenContinue")
                            callBack()
                        }
                    )
                    .frame(width: size.width * 0.85, height: proxy.size.height < 700 ? 48 : 54)
                    .opacity(buttonOpacity)
                }
                .padding(.bottom, proxy.safeAreaInsets.bottom + (proxy.size.height < 700 ? 20 : 30))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(
                ZStack {
                    Image(subscriptionStore.onboardingBGImage)
                        .resizable()
                        .scaledToFill()
                        .edgesIgnoringSafeArea(.all)
                    Color.black.opacity(0.5)
                        .edgesIgnoringSafeArea(.all)
                }
            )
        }
        .onAppear {
            animateContent()
            AnalyticsService.shared.track("HookScreenShown")
        }
    }
    
    private func animateContent() {
        withAnimation(.easeIn(duration: 0.8)) {
            titleOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeIn(duration: 0.8)) {
                subtitleOpacity = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.6)) {
                buttonOpacity = 1.0
            }
        }
    }
}
