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

    var body: some View {
        GeometryReader { proxy in
            VStack {
                
                Text("SpeakLife")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.white.opacity(0.5), radius: 4, x: 0, y: 2)
                    .padding(.top, 20)
                
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
                Text("Your app store review helps spread the word and grow the SpeakLife community!")
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 18, relativeTo: .body))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
                
                ShimmerButton(colors: [.blue], buttonTitle: "Rate us", action: callBack)
                    .frame(width: size.width * 0.87 ,height: 50)
                
                    .scaleEffect(showStars[4] ? 1 : 0.95) // Button appears last
                    .animation(Animation.spring(response: 0.4, dampingFraction: 0.5)
                        .delay(0.5), value: showStars[4])
                    .padding(.horizontal, 20)
                
                Spacer()
                    .frame(width: 5, height: size.height * 0.07)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(
                ZStack {
                    Image(subscriptionStore.testGroup == 0 ? subscriptionStore.onboardingBGImage : onboardingBGImage2)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .edgesIgnoringSafeArea(.all)
                    Color.black.opacity(subscriptionStore.testGroup == 0 ? 0.4 : 0.2)
                        .edgesIgnoringSafeArea(.all)
                }
                
            )
        }
        .onAppear {
            DispatchQueue.main.async {
                if let scene = UIApplication.shared.connectedScenes
                    .first(where: { $0.activationState == .foregroundActive })
                    as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: scene)
                }
            }
            appState.lastReviewRequestSetDate = Date()
        }
    }
       
}
