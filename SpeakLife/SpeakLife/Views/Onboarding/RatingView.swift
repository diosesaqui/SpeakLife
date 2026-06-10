//
//  Untitled.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 2/28/25.
//

import SwiftUI
import StoreKit

struct RatingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    let size: CGSize
    let callBack: (() -> Void)
    @State private var showStars = [false, false, false, false, false]

    /// Actual top safe-area inset. The parent onboarding container applies
    /// `.ignoresSafeArea()`, so the GeometryReader proxy reports 0 here — read it
    /// from the key window instead so the title clears the notch / Dynamic Island
    /// on every device. Falls back to a sensible notch height if unavailable.
    private var topSafeInset: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.safeAreaInsets.top) ?? 47
    }

    var body: some View {
        GeometryReader { proxy in
            VStack {
                
                Text("SpeakLife")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.white.opacity(0.5), radius: 4, x: 0, y: 2)
                    // Parent onboarding container uses .ignoresSafeArea(), so this
                    // GeometryReader spans the full screen including the notch /
                    // Dynamic Island. Clear it using the real top safe-area inset
                    // plus a little breathing room.
                    .padding(.top, topSafeInset + 12)
                
                Spacer()
                
                ZStack {
                    // Background circle layers
                    Circle()
                        .strokeBorder(Constants.DAMidBlue.opacity(0.3), lineWidth: 4)
                        .frame(width: 260, height: 260)
                    
                    Circle()
                        .strokeBorder(Constants.DAMidBlue.opacity(0.2), lineWidth: 4)
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .fill(Constants.DAMidBlue.opacity(0.3))
                        .frame(width: 140, height: 140)
                    
                    // Five-star rating with staggered fade-in animations
                    HStack(spacing: 10) {
                        ForEach(0..<5) { index in
                            Image(systemName: "star.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30 + CGFloat(index % 3) * 10, height: 30 + CGFloat(index % 3) * 10)
                                .foregroundColor(Color.yellow)
                                .shadow(color: Color.yellow.opacity(0.5), radius: 5, x: 0, y: 0)
                                .opacity(showStars[index] ? 1 : 0)
                                .scaleEffect(showStars[index] ? 1 : 0.8)
                                .animation(Animation.spring(response: 0.5, dampingFraction: 0.6)
                                    .delay(0.1 * Double(index)), value: showStars[index])
                        }
                    }
                    .onAppear {
                        // Trigger the fade-in animation for each star
                        for i in 0..<5 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1 * Double(i)) {
                                showStars[i] = true
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
                
                Spacer()
                
                
                Text("Help us make the world more like Jesus!")
                    .font(Font.custom("AppleSDGothicNeo-Bold", size: 22, relativeTo: .body))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    .padding(10)
                
                // Subtext about app review
                Text("Your 5-star rating makes a difference in growing God's family.")
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 18, relativeTo: .body))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                ShimmerButton(colors: [.blue], buttonTitle: "Rate us", action: {
                    AnalyticsService.shared.track("onboarding_rating_tapped")
                    appState.requestReviewIfEligible(trigger: .onboardingRatingScreen)
                    callBack()
                })
                    .frame(width: size.width * 0.87 ,height: 50)

                    .scaleEffect(showStars[4] ? 1 : 0.95) // Button appears last
                    .animation(Animation.spring(response: 0.4, dampingFraction: 0.5)
                        .delay(0.5), value: showStars[4])
                    .padding(.horizontal, 20)

                Spacer()
                    .frame(width: 5, height: size.height * 0.07)
            }
            // Top-align: if the stacked content is taller than the screen it
            // overflows off the BOTTOM instead of centering (which would shove the
            // title up off the top edge).
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .background(
                ZStack {
                    Image(subscriptionStore.onboardingBGImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .edgesIgnoringSafeArea(.all)
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                }

            )
        }
    }
       
}
