//
//  HelpUsGrowView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 7/23/24.
//

import SwiftUI
import StoreKit

struct HelpUsGrowModel {
    let title: String
    let message: String
    let buttonText: String
}

class HelpUsGrowViewModel: ObservableObject {
    @Published var model: HelpUsGrowModel
    @Published var isShowingRatingPrompt: Bool = false

    init(model: HelpUsGrowModel) {
        self.model = model
    }

    func requestReview() {
        // Here you would invoke the review request.
        // This might be more complex depending on how you want to handle this.
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    func showRatingPrompt() {
        // This triggers the UI to show the rating prompt
        self.isShowingRatingPrompt = true
    }
}

struct HelpUsGrowView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: HelpUsGrowViewModel
    let callBack: (() -> Void)

    init(viewModel: HelpUsGrowViewModel, callback: @escaping (() -> Void)) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.callBack = callback
    }

    var body: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Text(viewModel.model.title)
                    .font(.largeTitle)
                    .bold()
                
                Text(viewModel.model.message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Button(action: {
                    viewModel.showRatingPrompt()
                }) {
                    Text(viewModel.model.buttonText)
                        .font(.headline)
                        .padding()
                        .background(Color.blue)
                        //.foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .foregroundColor(.white)
            .padding()
            .alert(isPresented: $viewModel.isShowingRatingPrompt) {
                Alert(
                    title: Text("Rate Us"),
                    message: Text("Thanks for your support ✝️"),
                    primaryButton: .default(Text("Rate")) {
                        viewModel.requestReview()
                        appState.lastReviewRequestSetDate = Date()
                    },
                    secondaryButton: .cancel() {
                        callBack()
                    }
                )
            }
           
        }
        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
    }
}
