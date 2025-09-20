//
//  Personalization.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 1/9/24.
//

import SwiftUI

struct PersonalizationScene: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @StateObject private var faceBookTrackingViewModel = FacebookTrackingViewModel()
    
    let size: CGSize
    let callBack: (() -> Void)
              
    
    var body: some  View {
        personalizationView(size: size)
    }
    
    private func personalizationView(size: CGSize) -> some View  {
        VStack {
           
            if !appState.onBoardingTest {
                Spacer().frame(height: 90)
                Image("growth")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 235, height: size.height * 0.25)
            } else {
                Spacer()
            }
            
            Spacer().frame(height: 40)
            VStack {
                Text("Welcome to SpeakLife", comment: "Intro scene title label")
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 40, relativeTo: .title))
                    .fontWeight(.semibold)
                    .foregroundColor(appState.onBoardingTest ? .white : Constants.DEABlack)
                    .padding([.leading, .trailing])
                
                Spacer().frame(height: 16)
                
                VStack {
                    Text("We're glad you found us!" , comment: "Intro scene instructions")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .body))
                        .foregroundColor(appState.onBoardingTest ? .white : Constants.DALightBlue)
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .lineLimit(nil)
                    
                    Spacer().frame(height: appState.onBoardingTest ? size.height * 0.25 : 24)
                    
                    Text("Let's start with a couple questions to personalize your experience.", comment: "Intro scene extra tip")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .body))
                        .foregroundColor(appState.onBoardingTest ? .white : Constants.DALightBlue)
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(Color(red: 119, green: 142, blue: 180, opacity: 1))
                        .lineLimit(nil)
                }
                .frame(width: size.width * 0.8)
            }
            Spacer()
            
            Button(action: callBack) {
                HStack {
                    Text("Continue", comment: "Intro scene start label")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .body))
                        .fontWeight(.medium)
                        .frame(width: size.width * 0.91 ,height: 50)
                }.padding()
            }
            .frame(width: size.width * 0.87 ,height: 50)
            .background(Constants.DAMidBlue)
            
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(color: Constants.DAMidBlue, radius: 8, x: 0, y: 10)
            
            Spacer()
                .frame(width: 5, height: size.height * 0.07)
        }
        .frame(width: size.width, height: size.height)
        .background(
            Image(appState.onBoardingTest ? subscriptionStore.onboardingBGImage : "declarationBackground")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(.all)
        )
        .onAppear {
            faceBookTrackingViewModel.requestPermission()
        }
        
    }
    
    
}
