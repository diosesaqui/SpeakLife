//
//  NewOnboardingScreens.swift
//  SpeakLife
//
//  Created with Apple Design Standards
//

import SwiftUI
import FirebaseAnalytics

// MARK: - NEW SCREEN 1: Emotional Hook
struct EmotionalHookScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void

    @State private var headlineVisible = false
    @State private var subVisible = false
    @State private var buttonVisible = false

    // Pain confessions — 2 most powerful, most universal
    private let painPoints = [
        "You know God is real — but fear still creeps in",
        "You've read the Word — but it hasn't become first response yet"
    ]

    var body: some View {
        ZStack {
            backgroundView
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 28) {
                    // Headline — honors their faith, names the gap
                    VStack(spacing: 10) {
                        Text("You know God is real.")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .opacity(headlineVisible ? 1 : 0)
                            .offset(y: headlineVisible ? 0 : 20)

                        Text("Now let His promises make you unshakable.")
                            .font(.system(size: 22, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(3)
                            .padding(.horizontal, 28)
                            .opacity(headlineVisible ? 1 : 0)
                            .offset(y: headlineVisible ? 0 : 16)
                            .animation(.easeOut(duration: 0.6).delay(0.15), value: headlineVisible)
                    }

                    // Pain confessions
                    VStack(spacing: 13) {
                        ForEach(Array(painPoints.enumerated()), id: \.offset) { index, point in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "minus")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.top, 3)
                                Text(point)
                                    .font(.system(size: 15, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineSpacing(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .opacity(subVisible ? 1 : 0)
                            .offset(x: subVisible ? 0 : -18)
                            .animation(.easeOut(duration: 0.45).delay(0.25 + Double(index) * 0.07), value: subVisible)
                        }
                    }
                    .padding(.horizontal, 36)

                    // Bridge line — weapon frame
                    VStack(spacing: 6) {
                        Text("Spoken truth is your greatest weapon.")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        Text("It's exactly how Jesus defeated every attack.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .opacity(subVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.7), value: subVisible)
                }
                .padding(.horizontal, 16)
                Spacer()
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onContinue()
                }) {
                    Text("Show me how")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Capsule().fill(Color.white))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .opacity(buttonVisible ? 1 : 0)
                .offset(y: buttonVisible ? 0 : 20)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { headlineVisible = true }
            withAnimation(.easeOut(duration: 0.7).delay(0.3)) { subVisible = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.9)) { buttonVisible = true }
            Analytics.logEvent("onboarding_hook_shown", parameters: nil)
        }
    }

    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.78), Color.black.opacity(0.45), Color.black.opacity(0.6)]),
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - NEW SCREEN 4: Transformation Social Proof
struct TransformationSocialProofScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void

    @State private var statVisible = false
    @State private var card1Visible = false
    @State private var card2Visible = false
    @State private var buttonVisible = false

    private let testimonials: [(before: String, after: String, name: String)] = [
        (
            before: "I used to wake up in a panic every morning. Anxiety ruled my days.",
            after: "Now I wake up declaring. The fear is still there sometimes — but it doesn't get the first word anymore.",
            name: "Sarah M."
        ),
        (
            before: "I didn't know who I was in Christ. I just felt lost. Unworthy.",
            after: "After 30 days of identity declarations, something shifted. I actually believe I'm chosen now.",
            name: "Marcus T."
        )
    ]

    var body: some View {
        ZStack {
            backgroundView
            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 28) {
                    VStack(spacing: 6) {
                        Text("100,000+")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("believers have made this shift")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                        HStack(spacing: 3) {
                            ForEach(0..<5) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.yellow)
                            }
                            Text("Rated 4.9 on App Store")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.65))
                                .padding(.leading, 4)
                        }
                    }
                    .opacity(statVisible ? 1 : 0)
                    .scaleEffect(statVisible ? 1 : 0.9)

                    VStack(spacing: 14) {
                        ForEach(Array(testimonials.enumerated()), id: \.offset) { index, t in
                            TestimonyTransformCard(
                                before: t.before,
                                after: t.after,
                                name: t.name,
                                isVisible: index == 0 ? card1Visible : card2Visible
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                Spacer()
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onContinue()
                }) {
                    Text("Start my transformation")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Capsule().fill(Color.white))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .opacity(buttonVisible ? 1 : 0)
                .offset(y: buttonVisible ? 0 : 20)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { statVisible = true }
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) { card1Visible = true }
            withAnimation(.easeOut(duration: 0.6).delay(0.65)) { card2Visible = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.9)) { buttonVisible = true }
        }
    }

    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.75), Color.black.opacity(0.45), Color.black.opacity(0.6)]),
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
}

struct TestimonyTransformCard: View {
    let before: String
    let after: String
    let name: String
    let isVisible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text("BEFORE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 2)
                Text(before)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
            HStack(alignment: .top, spacing: 8) {
                Text("NOW")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.green.opacity(0.8))
                    .padding(.top, 2)
                Text(after)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("— \(name)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
        .animation(.easeOut(duration: 0.5), value: isVisible)
    }
}

// MARK: - NEW SCREEN 2: Category Select
struct CategorySelectScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @StateObject private var selectionVM = ImprovementViewModel()
    let size: CGSize
    let onContinue: () -> Void

    @State private var titleVisible = false
    @State private var gridVisible = false

    private let topCategories: [DeclarationCategory] = [
        .anxiety, .identity, .fear, .faith,
        .confidence, .rest, .health, .joy,
        .hope, .marriage, .wealth, .wisdom
    ]

    // Transformation-framed display names for this screen
    private func journeyLabel(for category: DeclarationCategory) -> String {
        switch category {
        case .anxiety:    return "Worry \u{2192} Peace"
        case .identity:   return "Lost \u{2192} Identity"
        case .fear:       return "Fear \u{2192} Freedom"
        case .faith:      return "Doubt \u{2192} Bold Faith"
        case .confidence: return "Shame \u{2192} Confidence"
        case .rest:       return "Burnout \u{2192} Rest"
        case .health:     return "Sickness \u{2192} Healing"
        case .joy:        return "Sadness \u{2192} Joy"
        case .hope:       return "Hopeless \u{2192} Hopeful"
        case .marriage:   return "Conflict \u{2192} Breakthrough"
        case .wealth:     return "Lack \u{2192} Provision"
        case .wisdom:     return "Confusion \u{2192} Wisdom"
        default:          return category.displayName
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                backgroundView

                VStack(spacing: 0) {
                    // Safe area spacer — clears Dynamic Island / notch
                    Spacer().frame(height: proxy.safeAreaInsets.top + 16)

                    // Header
                    VStack(spacing: 6) {
                        Text("What are you believing\nGod for?")
                            .font(.system(size: size.height < 700 ? 26 : 30, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .opacity(titleVisible ? 1 : 0)
                            .offset(y: titleVisible ? 0 : 16)

                        Text("Your declarations will be personalized for your journey")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .opacity(titleVisible ? 1 : 0)
                            .offset(y: titleVisible ? 0 : 10)
                            .animation(.easeOut(duration: 0.5).delay(0.15), value: titleVisible)

                        Text("Select all that apply")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                            .opacity(titleVisible ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.25), value: titleVisible)
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: size.height < 700 ? 14 : 20)

                    // Category grid — fills available space, no Spacer() gap
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: size.height < 700 ? 7 : 9) {
                        ForEach(topCategories, id: \.self) { category in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectionVM.selectExperience(category)
                            }) {
                                HStack(spacing: 7) {
                                    Image(systemName: category.iconName)
                                        .font(.system(size: size.height < 700 ? 15 : 17))
                                        .frame(width: 20)
                                    Text(journeyLabel(for: category))
                                        .font(.system(size: size.height < 700 ? 13 : 14, weight: .medium, design: .rounded))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, size.height < 700 ? 11 : 13)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(selectionVM.selectedExperiences.contains(category)
                                              ? Color.blue : Color.white.opacity(0.13))
                                        .overlay(RoundedRectangle(cornerRadius: 24)
                                            .strokeBorder(
                                                selectionVM.selectedExperiences.contains(category)
                                                ? Color.blue : Color.white.opacity(0.25),
                                                lineWidth: 1))
                                )
                                .foregroundColor(.white)
                                .scaleEffect(selectionVM.selectedExperiences.contains(category) ? 1.02 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6),
                                           value: selectionVM.selectedExperiences.contains(category))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .opacity(gridVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: gridVisible)

                    Spacer().frame(height: size.height < 700 ? 14 : 20)

                    // CTA — sits directly below grid, no floating gap
                    VStack(spacing: 10) {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if selectionVM.selectedExperiences.isEmpty {
                                selectionVM.selectedExperiences = [.faith]
                            }
                            let cats = Set(selectionVM.selectedExperiences)
                            appState.selectedNotificationCategories = cats.map { $0.rawValue }.joined(separator: ",")
                            Analytics.logEvent("onboarding_category_selected", parameters: [
                                "count": NSNumber(value: selectionVM.selectedExperiences.count),
                                "categories": selectionVM.selectedExperiences.map { $0.rawValue }.joined(separator: ",") as NSString
                            ])
                            onContinue()
                        }) {
                            Text(selectionVM.selectedExperiences.isEmpty ? "Continue" : "Personalize My Experience")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Capsule().fill(Color.white))
                        }

                        Button("Skip for now") {
                            selectionVM.selectedExperiences = [.general]
                            onContinue()
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, proxy.safeAreaInsets.bottom + 20)
                }
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { titleVisible = true }
            withAnimation(.easeOut(duration: 0.6).delay(0.35)) { gridVisible = true }
            Analytics.logEvent("onboarding_category_shown", parameters: nil)
        }
    }

    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.72), Color.black.opacity(0.45), Color.black.opacity(0.58)]),
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Legacy screens (no longer in main flow, kept for reference)

// MARK: - Screen 1: Scripture Anchor
struct ScriptureAnchorScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    @State private var isContentVisible = false
    @State private var isButtonVisible = false
    
    var body: some View {
        ZStack {
            // Background
            backgroundView
            
            // Content
            VStack(spacing: 0) {
                Spacer()
                
                // Main Quote
                VStack(spacing: 20) {
                    Text("\"My people are destroyed for lack of knowledge.\"")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .lineSpacing(6)
                        .padding(.horizontal, 24)
                        .minimumScaleFactor(0.8)
                        .opacity(isContentVisible ? 1 : 0)
                        .offset(y: isContentVisible ? 0 : 20)
                    
                    // Scripture Reference
                    Text("Hosea 4:6")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(isContentVisible ? 1 : 0)
                        .offset(y: isContentVisible ? 0 : 20)
                        .animation(.easeOut(duration: 0.8).delay(0.2), value: isContentVisible)
                }
                
                Spacer()
                    .frame(minHeight: 40, maxHeight: 60)
                
                // Sub-points
                VStack(spacing: 12) {
                    Text("Not lack of faith.")
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Text("Not lack of prayer.")
                        .font(.system(size: 19, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Text("Lack of knowing how to respond.")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .opacity(isContentVisible ? 1 : 0)
                .offset(y: isContentVisible ? 0 : 30)
                .animation(.easeOut(duration: 0.8).delay(0.4), value: isContentVisible)
                
                Spacer()
                
                // Continue Button
                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 50)
                    .opacity(isButtonVisible ? 1 : 0)
                    .offset(y: isButtonVisible ? 0 : 20)
            }
            .frame(width: size.width, height: size.height)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isContentVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                isButtonVisible = true
            }
        }
    }
    
    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            
            // Gradient overlay for better text readability
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
    
    var continueButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onContinue()
        }) {
            HStack(spacing: 8) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule()
                    .fill(Color.white)
            )
        }
    }
}

// MARK: - Screen 2: Reframe the Problem
struct ReframeProblemScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    @State private var isContentVisible = false
    @State private var isButtonVisible = false
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 48) {
                    // Main Message
                    VStack(spacing: 16) {
                        Text("You don't lose because")
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                        
                        Text("life is strong.")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .scaleEffect(isContentVisible ? 1 : 0.8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: isContentVisible)
                    }
                    .multilineTextAlignment(.center)
                    .opacity(isContentVisible ? 1 : 0)
                    .offset(y: isContentVisible ? 0 : 30)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 60, height: 1)
                        .opacity(isContentVisible ? 1 : 0)
                        .scaleEffect(x: isContentVisible ? 1 : 0)
                        .animation(.easeOut(duration: 0.8).delay(0.4), value: isContentVisible)
                    
                    VStack(spacing: 16) {
                        Text("You lose because")
                            .font(.system(size: 28, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                        
                        Text("truth isn't spoken.")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .scaleEffect(isContentVisible ? 1 : 0.8)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6), value: isContentVisible)
                    }
                    .multilineTextAlignment(.center)
                    .opacity(isContentVisible ? 1 : 0)
                    .offset(y: isContentVisible ? 0 : 30)
                    .animation(.easeOut(duration: 0.8).delay(0.4), value: isContentVisible)
                }
                .padding(.horizontal, 32)
                
                Spacer()
                    .frame(height: 80)
                
                // Scripture Context
                VStack(spacing: 12) {
                    Text("Jesus didn't tell us to endure mountains.")
                        .font(.system(size: 19, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                    
                    Text("He told us to talk to them.")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .opacity(isContentVisible ? 1 : 0)
                .offset(y: isContentVisible ? 0 : 30)
                .animation(.easeOut(duration: 0.8).delay(0.8), value: isContentVisible)
                
                Spacer()
                
                continueButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                    .opacity(isButtonVisible ? 1 : 0)
                    .offset(y: isButtonVisible ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isContentVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(1.0)) {
                isButtonVisible = true
            }
        }
    }
    
    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.65),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
    
    var continueButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onContinue()
        }) {
            Text("Show me")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
        }
    }
}

// MARK: - Screen 3: The Jesus Method
struct JesusMethodScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    @State private var isContentVisible = false
    @State private var stepsVisible = [false, false, false]
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                Spacer()
                
                Text("Jesus gave a")
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .opacity(isContentVisible ? 1 : 0)
                    .offset(y: isContentVisible ? 0 : 20)
                
                Text("clear instruction.")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(isContentVisible ? 1 : 0)
                    .offset(y: isContentVisible ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.2), value: isContentVisible)
                
                Spacer()
                    .frame(height: 80)
                
                // Three Steps
                VStack(spacing: 28) {
                    ForEach(0..<3) { index in
                        HStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 48, height: 48)
                                
                                Text("\(index + 1)")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            
                            Text(stepText(for: index))
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 40)
                        .opacity(stepsVisible[index] ? 1 : 0)
                        .offset(x: stepsVisible[index] ? 0 : -30)
                    }
                }
                
                Spacer()
                    .frame(height: 60)
                
                // Footer
                VStack(spacing: 8) {
                    Text("This isn't metaphor.")
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("This is spiritual law.")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                }
                .opacity(isContentVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.8).delay(1.5), value: isContentVisible)
                
                Spacer()
                
                continueButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                    .opacity(stepsVisible[2] ? 1 : 0)
                    .offset(y: stepsVisible[2] ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isContentVisible = true
            }
            
            for index in 0..<3 {
                withAnimation(.easeOut(duration: 0.6).delay(Double(index) * 0.3 + 0.5)) {
                    stepsVisible[index] = true
                }
            }
        }
    }
    
    func stepText(for index: Int) -> String {
        switch index {
        case 0: return "Speak to the mountain"
        case 1: return "Believe what you say"
        case 2: return "Expect it to move"
        default: return ""
        }
    }
    
    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
    
    var continueButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onContinue()
        }) {
            Text("I want this")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
        }
    }
}

// MARK: - Screen 4: Self-Diagnosis
struct SelfDiagnosisScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    @State private var selectedOption: String = ""
    @State private var isContentVisible = false
    @State private var optionsVisible = false
    
    let options = [
        ("worry", "Worry and hope it changes"),
        ("pray", "Pray silently but stay anxious"),
        ("endure", "Try to endure it"),
        ("speak", "Speak God's Word with confidence")
    ]
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 8) {
                    Text("When a \"mountain\"")
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Text("shows up in your life...")
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Text("what do you usually do?")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(isContentVisible ? 1 : 0)
                .offset(y: isContentVisible ? 0 : 20)
                
                Spacer()
                    .frame(height: 60)
                
                // Options
                VStack(spacing: 16) {
                    ForEach(options, id: \.0) { option in
                        DiagnosisOptionCard(
                            text: option.1,
                            isSelected: selectedOption == option.0,
                            onTap: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedOption = option.0
                                }
                                if option.0 == "speak" {
                                    Analytics.logEvent("self_diagnosis_correct", parameters: nil)
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    onContinue()
                                }
                            }
                        )
                        .opacity(optionsVisible ? 1 : 0)
                        .offset(y: optionsVisible ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(Double(options.firstIndex(where: { $0.0 == option.0 }) ?? 0) * 0.1), value: optionsVisible)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isContentVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                optionsVisible = true
            }
        }
    }
    
    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
}

struct DiagnosisOptionCard: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(text)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? .black : .white)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// Custom button style for better press feedback
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Continue with remaining screens...
// (Truth Gap, Application, Micro-Commitment, Position SpeakLife)

// Screen 5: Truth Gap
struct TruthGapScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    @State private var isContentVisible = false
    @State private var isButtonVisible = false
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 50) {
                    VStack(spacing: 12) {
                        Text("Most believers pray.")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .opacity(isContentVisible ? 1 : 0)
                            .offset(y: isContentVisible ? 0 : 20)
                        
                        Text("Few speak with authority.")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .opacity(isContentVisible ? 1 : 0)
                            .offset(y: isContentVisible ? 0 : 20)
                            .animation(.easeOut(duration: 0.8).delay(0.3), value: isContentVisible)
                    }
                    
                    VStack(spacing: 16) {
                        Text("Prayer asks.")
                            .font(.system(size: 24, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("Authority commands.")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .opacity(isContentVisible ? 1 : 0)
                    .offset(y: isContentVisible ? 0 : 30)
                    .animation(.easeOut(duration: 0.8).delay(0.6), value: isContentVisible)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                
                Spacer()
                
                continueButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                    .opacity(isButtonVisible ? 1 : 0)
                    .offset(y: isButtonVisible ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isContentVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                isButtonVisible = true
            }
        }
    }
    
    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.45),
                    Color.black.opacity(0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
    
    var continueButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onContinue()
        }) {
            Text("Teach me how")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
        }
    }
}

// Screen 6: Application
struct ApplicationScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    @State private var isContentVisible = false
    @State private var isQuoteVisible = false
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 40) {
                    Text("Jesus didn't say\n\"talk to God about the mountain.\"")
                        .font(.system(size: 28, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.95))
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .opacity(isContentVisible ? 1 : 0)
                        .offset(y: isContentVisible ? 0 : 20)
                    
                    VStack(spacing: 20) {
                        Text("He said:")
                            .font(.system(size: 22, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Text("\"Speak to the mountain.\"")
                            .font(.system(size: 34, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                            .scaleEffect(isQuoteVisible ? 1 : 0.8)
                            .opacity(isQuoteVisible ? 1 : 0)
                    }
                    
                    Text("What you speak first\ndetermines what stays.")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                        .opacity(isContentVisible ? 1 : 0)
                        .offset(y: isContentVisible ? 0 : 30)
                        .animation(.easeOut(duration: 0.8).delay(0.8), value: isContentVisible)
                }
                
                Spacer()
                
                continueButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                    .opacity(isQuoteVisible ? 1 : 0)
                    .offset(y: isQuoteVisible ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isContentVisible = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
                isQuoteVisible = true
            }
        }
    }
    
    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.65),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
    
    var continueButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onContinue()
        }) {
            Text("That changes everything")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
        }
    }
}

// Screen 7: Micro-Commitment
struct MicroCommitmentScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    @State private var selectedOption: String = ""
    @State private var isContentVisible = false
    @State private var optionsVisible = false
    
    let commitmentOptions = [
        ("ready", "Yes — I'm ready", "commitment_ready"),
        ("learn", "I want to learn", "commitment_learn"),
        ("never", "I've never been taught this", "commitment_never_taught")
    ]
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                Spacer()
                
                Text("Are you willing to start\nresponding the way\nJesus taught?")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .opacity(isContentVisible ? 1 : 0)
                    .offset(y: isContentVisible ? 0 : 20)
                
                Spacer()
                    .frame(height: 80)
                
                VStack(spacing: 16) {
                    ForEach(commitmentOptions, id: \.0) { option in
                        CommitmentOptionCard(
                            text: option.1,
                            isSelected: selectedOption == option.0,
                            onTap: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedOption = option.0
                                }
                                Analytics.logEvent(option.2, parameters: nil)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    onContinue()
                                }
                            }
                        )
                        .opacity(optionsVisible ? 1 : 0)
                        .offset(y: optionsVisible ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(Double(commitmentOptions.firstIndex(where: { $0.0 == option.0 }) ?? 0) * 0.1), value: optionsVisible)
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isContentVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                optionsVisible = true
            }
        }
    }
    
    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.5)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
}

struct CommitmentOptionCard: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.15))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// Screen 8: Position SpeakLife
struct PositionSpeakLifeScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    @State private var isLogoVisible = false
    @State private var isContentVisible = false
    @State private var isButtonVisible = false
    
    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                Spacer()
                
                // App Icon
                Image("appIconDisplay")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .cornerRadius(26)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .scaleEffect(isLogoVisible ? 1 : 0.5)
                    .opacity(isLogoVisible ? 1 : 0)
                
                Spacer()
                    .frame(height: 50)
                
                VStack(spacing: 32) {
                    Text("Here's how SpeakLife\nbuilds your faith.")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .foregroundColor(.white)
                        .opacity(isContentVisible ? 1 : 0)
                        .offset(y: isContentVisible ? 0 : 20)

                    VStack(spacing: 18) {
                        FeatureScriptureRow(
                            icon: "quote.bubble.fill",
                            feature: "Daily Declarations",
                            scripture: "\"Faith comes by hearing\" — Rom 10:17",
                            delay: 0.3,
                            isVisible: isContentVisible
                        )
                        FeatureScriptureRow(
                            icon: "headphones",
                            feature: "Guided Audio Devotionals",
                            scripture: "\"Meditate on it day and night\" — Josh 1:8",
                            delay: 0.5,
                            isVisible: isContentVisible
                        )
                        FeatureScriptureRow(
                            icon: "bell.fill",
                            feature: "Daily Scripture Reminders",
                            scripture: "\"Your word is a lamp\" — Ps 119:105",
                            delay: 0.7,
                            isVisible: isContentVisible
                        )
                        FeatureScriptureRow(
                            icon: "flame.fill",
                            feature: "Streak — Track Your Growth",
                            scripture: "\"Press on toward the goal\" — Phil 3:14",
                            delay: 0.9,
                            isVisible: isContentVisible
                        )
                    }
                    .padding(.horizontal, 32)
                }
                
                Spacer()
                
                continueButton
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                    .opacity(isButtonVisible ? 1 : 0)
                    .offset(y: isButtonVisible ? 0 : 20)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isLogoVisible = true
            }
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                isContentVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.8)) {
                isButtonVisible = true
            }
        }
    }
    
    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.6),
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.4)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
    
    var continueButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onContinue()
        }) {
            Text("Try your first declaration")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Capsule()
                        .fill(Color.white)
                )
        }
    }
}

// MARK: - Feature + Scripture Row
struct FeatureScriptureRow: View {
    let icon: String
    let feature: String
    let scripture: String
    let delay: Double
    let isVisible: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.15)))

            VStack(alignment: .leading, spacing: 3) {
                Text(feature)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(scripture)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .italic()
            }
            Spacer()
        }
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 16)
        .animation(.easeOut(duration: 0.6).delay(delay), value: isVisible)
    }
}

// MARK: - Screen 10: Live Declaration Preview
struct LiveDeclarationPreviewScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void

    @State private var cardVisible = false
    @State private var scriptureVisible = false
    @State private var buttonVisible = false
    @State private var pulseScale: CGFloat = 1.0

    // Hardcoded preview declaration — feels personal without requiring data load
    private let declarations: [(text: String, scripture: String, reference: String)] = [
        (
            "I am not moved by fear. I am moved by faith. God has not given me a spirit of fear, but of power, love, and a sound mind. I declare that I walk in peace today.",
            "For God has not given us a spirit of fear, but of power and of love and of a sound mind.",
            "2 Timothy 1:7"
        ),
        (
            "I know who I am. I am chosen, redeemed, and called by name. My identity is not defined by my past — it is secured by Christ's finished work.",
            "But you are a chosen generation, a royal priesthood, a holy nation, His own special people.",
            "1 Peter 2:9"
        ),
        (
            "I speak to every anxious thought and command it to go. The peace of God that surpasses all understanding guards my heart and my mind in Christ Jesus.",
            "Be anxious for nothing, but in everything by prayer... the peace of God will guard your hearts.",
            "Philippians 4:6-7"
        )
    ]

    private var selected: (text: String, scripture: String, reference: String) {
        // Rotate based on day of year so it feels fresh
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return declarations[dayIndex % declarations.count]
    }

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 0) {
                Spacer()

                // Header
                VStack(spacing: 8) {
                    Text("Here's your first declaration.")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text("Read it aloud. Mean every word.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                .opacity(cardVisible ? 1 : 0)
                .offset(y: cardVisible ? 0 : 20)
                .padding(.horizontal, 32)

                Spacer().frame(height: 36)

                // Declaration Card
                VStack(spacing: 20) {
                    // Quotation mark
                    Text("\u{201C}")
                        .font(.system(size: 64, weight: .bold, design: .serif))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                        .padding(.bottom, -30)

                    Text(selected.text)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 8)

                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: 1)
                        .padding(.horizontal, 16)

                    // Scripture
                    VStack(spacing: 4) {
                        Text("\u{201C}\(selected.scripture)\u{201D}")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundColor(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .italic()
                        Text(selected.reference)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .padding(.horizontal, 8)
                    .opacity(scriptureVisible ? 1 : 0)
                    .offset(y: scriptureVisible ? 0 : 10)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .scaleEffect(cardVisible ? 1 : 0.92)
                .opacity(cardVisible ? 1 : 0)

                Spacer()

                // Why declarations work — scripture backing
                HStack(spacing: 8) {
                    Text("Knowing the truth isn't enough. You have to SPEAK it until you live it.")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .italic()
//                    Image(systemName: "text.book.closed.fill")
//                        .font(.system(size: 16))
//                        .foregroundColor(.white.opacity(0.55))
//                    Text("\u{201C}Death and life are in the power of the tongue.\u{201D} \u{2014} Prov 18:21")
//                        .font(.system(size: 13, weight: .medium, design: .rounded))
//                        .foregroundColor(.white.opacity(0.6))
//                        .italic()
//                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 12)
                .opacity(scriptureVisible ? 1 : 0)

                // CTA
                VStack(spacing: 12) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onContinue()
                    }) {
                        Text("I want more of this")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Capsule().fill(Color.white))
                    }

                   
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .opacity(buttonVisible ? 1 : 0)
                .offset(y: buttonVisible ? 0 : 20)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                cardVisible = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
                scriptureVisible = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.9)) {
                buttonVisible = true
            }
            Analytics.logEvent("onboarding_preview_shown", parameters: nil)
        }
    }

    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()

            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black.opacity(0.75),
                    Color.black.opacity(0.45),
                    Color.black.opacity(0.55)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Audio Feature Screen
struct AudioFeatureScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void

    @State private var headerVisible = false
    @State private var cardVisible = false
    @State private var buttonVisible = false

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    // Scripture headline
                    VStack(spacing: 12) {
                        Text("\u{201C}Faith comes by hearing,\nand hearing by the\nWord of God.\u{201D}")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .lineSpacing(4)
                            .opacity(headerVisible ? 1 : 0)
                            .offset(y: headerVisible ? 0 : 20)

                        Text("Romans 10:17")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .opacity(headerVisible ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(0.2), value: headerVisible)
                    }

                    // Feature card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "headphones")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Guided Audio Devotionals")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("Hear God's Word spoken over your life")
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.65))
                            }
                        }

                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 1)

                        Text("SpeakLife's audio library puts Scripture in your ears — during your commute, before sleep, first thing in the morning. Hearing truth consistently is how faith grows.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                    )
                    .padding(.horizontal, 24)
                    .opacity(cardVisible ? 1 : 0)
                    .scaleEffect(cardVisible ? 1 : 0.95)
                }

                Spacer()

                VStack(spacing: 12) {
                    Text("Read it once and it informs you. Hear it daily and it TRANSFORMS you.")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .italic()
                        .padding(.horizontal, 8)

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onContinue()
                    }) {
                        Text("What else does SpeakLife do?")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Capsule().fill(Color.white))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .opacity(buttonVisible ? 1 : 0)
                .offset(y: buttonVisible ? 0 : 20)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { headerVisible = true }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { cardVisible = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) { buttonVisible = true }
            Analytics.logEvent("onboarding_audio_feature_shown", parameters: nil)
        }
    }

    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.75), Color.black.opacity(0.45), Color.black.opacity(0.6)]),
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Daily Devotional Feature Screen
struct DailyDevotionalFeatureScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void

    @State private var headerVisible = false
    @State private var cardVisible = false
    @State private var buttonVisible = false

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    // Scripture headline
                    VStack(spacing: 12) {
                        Text("\u{201C}See what great love the\nFather has lavished on us,\nthat we should be called\nchildren of God.\u{201D}")
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .lineSpacing(4)
                            .opacity(headerVisible ? 1 : 0)
                            .offset(y: headerVisible ? 0 : 20)

                        Text("1 John 3:1")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .opacity(headerVisible ? 1 : 0)
                            .animation(.easeOut(duration: 0.6).delay(0.2), value: headerVisible)
                    }

                    // Feature card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "book.fill")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Daily Devotionals")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("Learn more about God's love for you")
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.65))
                            }
                        }

                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 1)

                        Text("Every day, a short devotional opens a new window into how deeply God loves you. Not religion but relationship. When you know how loved you are, fear loses its grip.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.1))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                    )
                    .padding(.horizontal, 24)
                    .opacity(cardVisible ? 1 : 0)
                    .scaleEffect(cardVisible ? 1 : 0.95)
                }

                Spacer()

                VStack(spacing: 12) {
                    Text("You know God is good. This is how you start believing He's good to YOU.")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .italic()
                        .padding(.horizontal, 8)

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onContinue()
                    }) {
                        Text("There\'s one more thing")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Capsule().fill(Color.white))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .opacity(buttonVisible ? 1 : 0)
                .offset(y: buttonVisible ? 0 : 20)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { headerVisible = true }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) { cardVisible = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.8)) { buttonVisible = true }
            Analytics.logEvent("onboarding_devotional_feature_shown", parameters: nil)
        }
    }

    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.75), Color.black.opacity(0.45), Color.black.opacity(0.6)]),
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Warrior Room Feature Screen
struct WarriorRoomFeatureScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void

    @State private var headerVisible = false
    @State private var cardVisible = false
    @State private var postsVisible = false
    @State private var buttonVisible = false

    // Sample prayer posts mirroring the real UI
    private let samplePosts: [(author: String, text: String, praying: Int, answered: Bool)] = [
        ("A sister in Christ", "I've been struggling with anxiety and fear. Please stand with me in prayer.", 12, false),
        ("A brother in Christ", "God is the greatest! Been through trials but His promises never failed!", 8, true)
    ]

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Scripture headline
                    VStack(spacing: 10) {
                        Text("\u{201C}Pray for each other so\nthat you may be healed.\u{201D}")
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .lineSpacing(4)
                            .opacity(headerVisible ? 1 : 0)
                            .offset(y: headerVisible ? 0 : 20)

                        Text("James 5:16")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .opacity(headerVisible ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.2), value: headerVisible)
                    }

                    // Feature label
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 42, height: 42)
                            Image(systemName: "shield.fill")
                                .font(.system(size: 19, weight: .medium))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("The Warrior Room")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Community prayer & testimonies")
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .opacity(cardVisible ? 1 : 0)

                    // Sample prayer posts
                    VStack(spacing: 10) {
                        ForEach(Array(samplePosts.enumerated()), id: \.offset) { index, post in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(post.author)
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.55))
                                    if post.answered {
                                        HStack(spacing: 3) {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(.green.opacity(0.8))
                                            Text("Answered")
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(.green.opacity(0.8))
                                        }
                                    }
                                    Spacer()
                                }

                                Text(post.text)
                                    .font(.system(size: 14, weight: .regular, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack(spacing: 6) {
                                    Image(systemName: "hands.and.sparkles.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.5))
                                    Text("Praying (\(post.praying))")
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.white.opacity(0.08)))
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.white.opacity(0.09))
                                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                            )
                            .opacity(postsVisible ? 1 : 0)
                            .offset(y: postsVisible ? 0 : 16)
                            .animation(.easeOut(duration: 0.5).delay(Double(index) * 0.12), value: postsVisible)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()

                VStack(spacing: 12) {
                    Text("No warrior wins alone.")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onContinue()
                    }) {
                        Text("Start my 7-Day Faith Reset")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Capsule().fill(Color.white))
                    }

                    Text("7 days free \u{2022}\u{2022} Cancel anytime")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .opacity(buttonVisible ? 1 : 0)
                .offset(y: buttonVisible ? 0 : 20)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { headerVisible = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.35)) { cardVisible = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.5)) { postsVisible = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.85)) { buttonVisible = true }
            Analytics.logEvent("onboarding_warrior_room_shown", parameters: nil)
        }
    }

    var backgroundView: some View {
        ZStack {
            Image(subscriptionStore.onboardingBGImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                .clipped()
                .ignoresSafeArea()
            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.75), Color.black.opacity(0.45), Color.black.opacity(0.6)]),
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Daily Commitment Screen

struct DailyCommitmentScreen: View {
    let size: CGSize
    let onContinue: () -> Void

    @State private var headerVisible = false
    @State private var timelinesVisible = false
    @State private var buttonVisible = false

    private let milestones: [(String, String, String)] = [
        ("1", "Week 1", "You start waking up with God's Word — not your worries."),
        ("2", "Month 1", "When fear hits, you speak before you spiral."),
        ("3", "Month 3", "A trial hits that would have broken you before. It doesn't.")
    ]

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.06, green: 0.08, blue: 0.18), Color(red: 0.1, green: 0.05, blue: 0.2)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Header
                VStack(spacing: 16) {
                    Text("Daily is the difference.")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("\"Be transformed by the renewing of your mind.\"")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .italic()
                        .multilineTextAlignment(.center)

                    Text("— Romans 12:2")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 32)
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : 16)

                Spacer().frame(height: 36)

                // Subhead — Matthew 7:24 rock metaphor
                Text("Everyone who builds their life on His Word — when the storms hit, they stand.\nSpeakLife is how you build that foundation. Every single day.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(headerVisible ? 1 : 0)

                Text("— Matthew 7:24")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .opacity(headerVisible ? 1 : 0)

                Spacer().frame(height: 40)

                // Timeline milestones
                VStack(spacing: 16) {
                    ForEach(Array(milestones.enumerated()), id: \.offset) { index, milestone in
                        HStack(alignment: .top, spacing: 16) {
                            // Step indicator
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Text(milestone.0)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(milestone.1)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(milestone.2)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.white.opacity(0.65))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 28)
                        .opacity(timelinesVisible ? 1 : 0)
                        .offset(y: timelinesVisible ? 0 : 12)
                        .animation(.easeOut(duration: 0.45).delay(Double(index) * 0.15), value: timelinesVisible)
                    }
                }

                Spacer().frame(height: 32)

                // Commitment note
                Text("The bigger the battle, the more you need to speak it. Every single day.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(timelinesVisible ? 1 : 0)

                Spacer()

                // First-time experience line
                Text("The first time you speak God's Word to a fear and watch it move — you'll never face a battle the same way again. No matter how big or small.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 16)
                    .opacity(buttonVisible ? 1 : 0)

                // CTA
                VStack(spacing: 10) {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onContinue()
                    }) {
                        Text("I'm ready to commit")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Capsule().fill(Color.white))
                    }

                    Text("Daily practice builds an unshakable mind")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .opacity(buttonVisible ? 1 : 0)
            }
        }
        .onAppear {
            Analytics.logEvent("onboarding_commitment_shown", parameters: nil)
            withAnimation(.easeOut(duration: 0.6)) { headerVisible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation { timelinesVisible = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeIn(duration: 0.5)) { buttonVisible = true }
            }
        }
    }
}
