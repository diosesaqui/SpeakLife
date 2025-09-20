//
//  LoadingView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 1/23/24.
//

import SwiftUI



struct PersonalizationLoadingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    let size: CGSize
    let callBack: (() -> Void)
    
    @State private var checkedFirst = false
    @State private var checkedSecond = false
    @State private var checkedThird = false
    let delay: Double = Double.random(in: 6...7)
    
    var body: some View {
        ZStack {
            
            if appState.onBoardingTest {
                Image(subscriptionStore.onboardingBGImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
            } else {
                Gradients().purple
                    .edgesIgnoringSafeArea(.all)
            }
            VStack(spacing: 10) {
                VStack(spacing: 10) {
                    Spacer()
                        .frame(height: 110)
                    
                    Text("Hang tight, while we build your Speak Life plan")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(Animation.easeInOut(duration: 0.5)) {
                            checkedFirst = true
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(Animation.easeInOut(duration: 0.5)) {
                            checkedSecond = true
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation(Animation.easeInOut(duration: 0.5)) {
                            checkedThird = true
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 10) {
                    BulletPointView(text: "Analyzing answers", isHighlighted: $checkedFirst, delay: 0.5)
                    BulletPointView(text: "Matching your goals", isHighlighted: $checkedSecond, delay: 1.0)
                    BulletPointView(text: "Creating affirmation notifications", isHighlighted: $checkedThird, delay: 1.5)
                }
                .frame(maxWidth: .infinity, alignment: appState.onBoardingTest ? .center : .leading)
                .padding()
            }
            
            .ignoresSafeArea()
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation {
                        callBack()
                    }
                }
            }
        }
    }
}

struct BulletPointView: View {
    let text: String
    @Binding var isHighlighted: Bool
    let delay: Double // delay for the animation
    
    var body: some View {
        HStack {
            Image(systemName: isHighlighted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isHighlighted ? Constants.gold : .white)
                .scaleEffect(isHighlighted ? 1.1 : 1.0)
            Text(text)
                .foregroundColor(.white)
        }
        .opacity(!isHighlighted ? 0 : 1)
        .animation(.easeInOut, value: !isHighlighted)
        .onChange(of: isHighlighted) { newValue in
            if newValue {
                withAnimation(Animation.easeInOut(duration: 1.0).delay(delay)) {
                    isHighlighted = newValue
                }
            }
        }
    }
}
