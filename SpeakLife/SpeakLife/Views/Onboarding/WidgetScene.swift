//
//  WidgetScene.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 6/18/22.
//

import SwiftUI

struct WidgetScene: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let callBack: (() -> Void)
    
    var body: some View {
        widgetScene(size: size)
    }
    
    private func widgetScene(size: CGSize)  -> some View {
        
        VStack {
            Spacer().frame(height: 30)
            
            Text("Stay Inspired—Add a Widget", comment: "Widget scene add widget text")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .shadow(color: Color.white.opacity(0.6), radius: 4, x: 0, y: 2)
                .foregroundColor(.white)
            
            Image("widget")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 235, height: size.height * 0.3)
            
            Spacer().frame(height:  size.height * 0.1)
            VStack {
               
                
                VStack {
                    Text("Long press your home screen until apps wiggle.", comment: "widget scene add instructions")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .body))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .lineLimit(nil)
                    
                    Spacer().frame(height: 24)
                    
                    Text("Tap the '+' in the top corner.", comment: "widget scene additional instructions")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .body))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(.white)
                        .lineLimit(nil)
                    
                    Spacer().frame(height: 24)
                    
                    Text("Search for SpeakLife and add the widget.", comment: "widget scene additional instructions")
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .body))
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .foregroundColor(.white)
                        .lineLimit(nil)
                }
                .frame(width: size.width * 0.8)
            }
            Spacer()
            
            ShimmerButton(colors: [Constants.DAMidBlue, .yellow], buttonTitle: "Got it!", action: callBack)
            .frame(width: size.width * 0.87 ,height: 50)
            .shadow(color: Constants.DAMidBlue, radius: 8, x: 0, y: 10)
            
            .background(Constants.DADarkBlue.opacity(0.6))
            
            .foregroundColor(.white)
            .cornerRadius(30)

            
            Spacer()
                .frame(width: 5, height: size.height * 0.07)
        }
        .frame(width: size.width, height: size.height)
        .background(
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .edgesIgnoringSafeArea(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
        )
    }
}


struct UseCaseScene: View {
    @EnvironmentObject var appState: AppState
    let size: CGSize
    let callBack: (() -> Void)
    
    var body: some View {
        useCaseScene(size: size)
    }
    
    private func useCaseScene(size: CGSize)  -> some View {
        VStack {
            TipsView(appState: _appState, tips: tips)
            Button(action: callBack) {
                HStack {
                    Text("Got it!", comment: "Use case scene confirmation")
                        .font(.body)
                        .fontWeight(.medium)
                        .frame(width: size.width * 0.91 ,height: 50)
                }.padding()
            }
            .frame(width: size.width * 0.87 ,height: 50)
            .background(Constants.DAMidBlue)
            
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(color: Constants.DAMidBlue, radius: 8, x: 0, y: 10)
        }
    }
}
