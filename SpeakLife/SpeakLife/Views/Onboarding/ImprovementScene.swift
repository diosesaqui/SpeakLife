//
//  ImprovementScene.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 1/9/24.
//

import SwiftUI
import FirebaseAnalytics

struct ImprovementScene: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    
    let size: CGSize
    @ObservedObject var viewModel: ImprovementViewModel
    let callBack: (() -> Void)
    
    var body: some  View {
        improvementView(size: size)
    }
    
    private func improvementView(size: CGSize) -> some View {
        GeometryReader { proxy in // ✅ Ensures full height
            VStack(spacing: 0) { // ✅ No extra spacing
                ScrollView(showsIndicators: true) {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 30)

                        Text("What's Your Biggest Battle Right Now?", comment: "Intro scene title label")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .shadow(color: Color.white.opacity(0.6), radius: 4, x: 0, y: 2)
                            .multilineTextAlignment(.center)
                            .foregroundColor(appState.onBoardingTest ? .white : Constants.DEABlack)
                            .padding()
                            .lineLimit(2)

                        Text("87% of believers struggle in silence. Let's create your personalized breakthrough plan.", comment: "Intro scene instructions")
                            .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .body))
                            .foregroundColor(appState.onBoardingTest ? .white : Constants.DALightBlue)
                            .multilineTextAlignment(.center)
                            .lineSpacing(10)
                            .frame(width: size.width * 0.8)

                        ImprovementSelectionListView(viewModel: viewModel)
                            .frame(width: size.width * 0.9, height: size.height * 0.5)

                        Spacer() // ✅ Pushes button down inside ScrollView
                    }
                    .frame(minHeight: proxy.size.height * 0.7) // ✅ Ensures enough height
                }

                Spacer() // ✅ Ensures the button stays at the bottom
                
                // CTA Button
                ShimmerButton(colors: [.blue], buttonTitle: "Get My Breakthrough Plan →", action: callBack)
                    .frame(width: size.width * 0.87, height: 50)
//                    .shadow(color: Constants.DAMidBlue, radius: 8, x: 0, y: 10)
                    .disabled(viewModel.selectedExperiences.isEmpty)
                    //.background(viewModel.selectedExperiences.isEmpty ? Constants.DAMidBlue.opacity(0.3) : Constants.DADarkBlue.opacity(0.6))
//                    .foregroundColor(.white)
//                    .cornerRadius(30)
                   // .shadow(color: Constants.DAMidBlue, radius: 8, x: 0, y: 10)

                Spacer()
                    .frame(height: proxy.size.height * 0.05) // ✅ Ensures bottom spacing
            }
            .frame(width: proxy.size.width, height: proxy.size.height) // ✅ Full screen constraint
            .background(
                ZStack {
                    Image(subscriptionStore.testGroup == 0 ? subscriptionStore.onboardingBGImage : onboardingBGImage2)
                        .resizable()
                        .scaledToFill()
                        .edgesIgnoringSafeArea(.all)
                    Color.black.opacity(subscriptionStore.testGroup == 0 ? 0.4 : 0.2)
                        .edgesIgnoringSafeArea(.all)
                }
            )
        }
    }
    
}

class ImprovementViewModel: ObservableObject {
    @Published var selectedExperiences: [DeclarationCategory] = []
    
    func selectExperience(_ experience: DeclarationCategory) {
        if selectedExperiences.contains(experience) {
            selectedExperiences.removeAll(where: { $0 == experience })
        } else {
            selectedExperiences.append(experience)
            Analytics.logEvent(experience.rawValue, parameters: nil)
        }
    }
}

struct ImprovementSelectionListView: View {
    @ObservedObject var viewModel: ImprovementViewModel
    let impactMed = UIImpactFeedbackGenerator(style: .soft)
    
    var body: some View {
        newBody
    }
    
    var newBody: some View {
        ScrollView {
            FlowLayout(items: DeclarationCategory.categoryOrder + DeclarationCategory.bibleCategories, spacing: 2) { interest in
                Text(interest.name)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Constants.DAMidBlue.opacity(viewModel.selectedExperiences.contains(interest) ? 0.8 : 0.3))
                    .cornerRadius(15)
                    .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Constants.DAMidBlue, lineWidth: viewModel.selectedExperiences.contains(interest) ? 2 : 0)
                                .shadow(color: Constants.DAMidBlue.opacity(0.7),
                                        radius: viewModel.selectedExperiences.contains(interest) ? 8 : 0)
                        )
                        // Slightly scale up when selected for a "pop"
                        .scaleEffect(viewModel.selectedExperiences.contains(interest) ? 1.05 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.selectedExperiences)
                    .onTapGesture {
                        withAnimation {
                            viewModel.selectExperience(interest)
                        }
                    }
            }
            .padding()
        }
    }
}

struct FlowLayout<Content: View>: View {
    let items: [DeclarationCategory]
    let spacing: CGFloat
    let content: (DeclarationCategory) -> Content
    
    @State private var totalHeight = CGFloat.zero
    
    init(items: [DeclarationCategory], spacing: CGFloat = 8, @ViewBuilder content: @escaping (DeclarationCategory) -> Content) {
        self.items = items
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight) // Set height based on content
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding(8)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width - spacing) > geometry.size.width) {
                            width = 0
                            height -= d.height + spacing
                        }
                        let result = width
                        if item == items.last {
                            width = 0 // Last item
                        } else {
                            width -= d.width + spacing
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if item == items.last {
                            height = 0 // Last item
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight)) // Tracks total height for layout
    }
    
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geo in
            Color.clear
                .preference(key: HeightPreferenceKey.self, value: geo.size.height)
        }
        .onPreferenceChange(HeightPreferenceKey.self) { binding.wrappedValue = $0 }
    }
}

struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
