//
//  LandingView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 11/27/23.
//

import SwiftUI

struct LandingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @State private var backgroundImage = "moonlight2" // Default fallback
    
    var body: some View {
        ZStack(alignment: .center) {
            Image(backgroundImage)
                   .resizable()
                   .aspectRatio(contentMode: .fill)
                   .frame(maxWidth: .infinity, maxHeight: .infinity)
                   .edgesIgnoringSafeArea(.all)

            VStack {
                // App Icon centered and shaped
                AnimatedAppIconView()
                
                Spacer()
                    .frame(height: UIScreen.main.bounds.height * 0.3)
                
            }

           }
           .frame(maxWidth: .infinity, maxHeight: .infinity)
           .background(Color.clear)
           .onAppear {
               // Safely update background image when subscription store is ready
               backgroundImage = subscriptionStore.onboardingBGImage.isEmpty ? "moonlight2" : subscriptionStore.onboardingBGImage
           }

    }
}

struct AnimatedAppIconView: View {
    @State private var animationScale: CGFloat = 1.0
    @State private var animationOpacity: Double = 1.0
    @State private var animationPhase: Int = 0

    var body: some View {
        VStack {
            Image(uiImage: UIImage(named: "appIconDisplay") ?? UIImage())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 250, height: 250)
                .clipShape(Circle())
            Text("SpeakLife")
                .font(.system(size: 36, weight: .bold))
                .shadow(color: Color.white.opacity(0.6), radius: 4, x: 0, y: 2)
                .foregroundColor(.white)
        }
        .scaleEffect(animationScale)
        .opacity(animationOpacity)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Phase 1: Scale down
        withAnimation(.easeInOut(duration: 0.5)) {
            animationScale = 0.5
            animationPhase = 1
        }
        
        // Phase 2: Scale up and zoom
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard animationPhase == 1 else { return } // Safety check
            withAnimation(.easeInOut(duration: 0.5)) {
                animationScale = 5.0
                animationPhase = 2
            }
            
            // Phase 3: Fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard animationPhase == 2 else { return } // Safety check
                withAnimation(.easeOut(duration: 0.5)) {
                    animationOpacity = 0
                    animationPhase = 3
                }
            }
        }
    }
}

