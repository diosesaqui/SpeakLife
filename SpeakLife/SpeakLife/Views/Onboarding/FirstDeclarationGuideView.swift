//
//  FirstDeclarationGuideView.swift
//  SpeakLife
//
//  Created on 12/31/25.
//

import SwiftUI
import FirebaseAnalytics

struct FirstDeclarationGuideView: View {
    let size: CGSize
    let action: () -> Void
    var isDismissible: Bool = false  // New parameter for post-onboarding use
    
    @State private var declarationText = ""
    @State private var showExample = false
    @State private var animateContent = false
    @State private var showingSaveAnimation = false
    @EnvironmentObject var viewModel: DeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    // Top bar - Progress dots or close button
                    HStack {
                        if isDismissible {
                            Button(action: {
                                AnalyticsService.shared.track("DeclarationPromptDismissed")
                                dismiss()
                                action()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.leading, 20)
                        }
                        
                        Spacer()
                        
                        if !isDismissible {
                            ProgressDots(current: 2, total: 5)
                                .padding(.trailing, 20)
                        }
                    }
                    .padding(.top, proxy.safeAreaInsets.top + 10)
                    .frame(width: proxy.size.width)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            headerSection
                                .padding(.top, 20)
                                .dsAppear(0)

                            scriptureSection
                                .padding(.horizontal)
                                .opacity(animateContent ? 1 : 0)
                                .offset(y: animateContent ? 0 : 20)
                            
                            declarationInputSection
                                .padding(.horizontal)
                                .opacity(animateContent ? 1 : 0)
                                .offset(y: animateContent ? 0 : 20)
                            
                            exampleSection
                                .opacity(animateContent ? 1 : 0)
                                .offset(y: animateContent ? 0 : 20)
                            
                            Spacer(minLength: 100)
                        }
                    }
                    
                    continueButton
                        .padding(.horizontal)
                        .padding(.bottom, proxy.safeAreaInsets.bottom + 30)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .background(
                    ZStack {
                        Image(subscriptionStore.onboardingBGImage)
                            .resizable()
                            .scaledToFill()
                            .edgesIgnoringSafeArea(.all)
                        Color.black.opacity(0.4)
                            .edgesIgnoringSafeArea(.all)
                    }
                )
            }
            
            // Save animation overlay
            if showingSaveAnimation {
                SaveConfirmationView(contentType: .affirmation) {
                    action()
                }
                .transition(.scale.combined(with: .opacity))
                .zIndex(1)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                animateContent = true
            }
            AnalyticsService.shared.track("FirstDeclarationGuideViewed")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundColor(.white)
                .rotationEffect(.degrees(animateContent ? 0 : -15))
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateContent)
            
            Text("Create Your First Declaration")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("Write it in present tense, as if it's already done")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }
    
    private var scriptureSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "book.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("Biblical Foundation")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("\"Have faith in God. Truly I tell you, if anyone says to this mountain, 'Go, throw yourself into the sea,' and does not doubt in their heart but believes that what they say will happen, it will be done for them.\"")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.95))
                    .italic()
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("- Mark 11:22-23")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(20)
            .dsGlass(cornerRadius: DS.Radius.md)
        }
    }

    private var declarationInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Declaration")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            Text("What do you want to declare over your life?")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
            
            ZStack(alignment: .topLeading) {
                if declarationText.isEmpty {
                    Text("Example: I declare that 2026 is my year of breakthrough. Every door that was closed is now opening. I walk in divine favor, supernatural provision, and perfect peace. What the enemy meant for evil, God is turning for my good...")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .lineSpacing(2)
                }
                
                TextEditor(text: $declarationText)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(8)
            }
            .frame(height: 120)
            .dsGlass(cornerRadius: DS.Radius.sm)
        }
    }
    
    private var exampleSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                withAnimation(.spring()) {
                    showExample.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16))
                    
                    Text(showExample ? "Hide Examples" : "Show Examples")
                        .font(.system(size: 15, weight: .medium))
                    
                    Spacer()
                    
                    Image(systemName: showExample ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .dsGlass(cornerRadius: DS.Radius.sm)
            }
            
            if showExample {
                VStack(alignment: .leading, spacing: 16) {
                    exampleItem(
                        title: "Breaking Generational Patterns",
                        declaration: "I declare that every generational curse is broken off my bloodline. I am establishing a new legacy of faith, prosperity, and righteousness. My children and children's children will serve the Lord. The cycle of lack, sickness, and dysfunction stops with me."
                    )
                    
                    exampleItem(
                        title: "Divine Purpose & Destiny",
                        declaration: "I declare that I am walking in my God-given purpose. Every gift and talent within me is activated. Doors of opportunity are opening that no man can shut. I am positioned for promotion, influence, and Kingdom impact. My latter days shall be greater than my former."
                    )
                    
                    exampleItem(
                        title: "Supernatural Breakthrough",
                        declaration: "I declare this is my season of suddenly. What took others years will happen for me in days. I'm moving from barely making it to more than enough. Every mountain of debt, disease, and delay is being removed. I will see the goodness of the Lord in the land of the living."
                    )
                    
                    exampleItem(
                        title: "Marriage & Relationships",
                        declaration: "I declare restoration and healing over every relationship in my life. My marriage is blessed, my family is united in love, and godly connections are being divinely orchestrated. I attract covenant relationships that push me closer to my destiny."
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal)
    }
    
    private func exampleItem(title: String, declaration: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            
            Text(declaration)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlass(cornerRadius: DS.Radius.sm)
    }
    
    private var continueButton: some View {
        VStack(spacing: 15) {
            ShimmerButton(
                colors: declarationText.isEmpty ? [.gray, .gray.opacity(0.7)] : [.blue, .purple],
                buttonTitle: declarationText.isEmpty ? "Write Your Declaration First" : (isDismissible ? "Save Declaration" : "Continue"),
                action: {
                    // Only proceed if declaration text is not empty
                    guard !declarationText.isEmpty else { 
                        // Gentle haptic to indicate they need to write something
                        Juice.play(.tapLight)
                        return
                    }
                    
                    Juice.play(.tapSolid)
                    
                    // Save the declaration
                    saveDeclaration()
                    
                    // Log analytics
                    AnalyticsService.shared.track("FirstDeclarationCreated", parameters: [
                        "text_length": declarationText.count
                    ])
                    
                    // Show save animation which will call action() when complete
                    withAnimation(.spring()) {
                        showingSaveAnimation = true
                    }
                }
            )
            .frame(width: size.width * 0.85, height: 54)
            
            // Show "Maybe Later" option only in dismissible mode
            if isDismissible {
                Button("Maybe Later") {
                    AnalyticsService.shared.track("DeclarationPromptPostponed")
                    dismiss()
                    action()
                }
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
            }
        }
    }
    
    private func saveDeclaration() {
        viewModel.createDeclaration(declarationText, contentType: .affirmation)
        
//        if let newDeclaration = viewModel.allDeclarations.first(where: { $0.text == declarationText }) {
//            viewModel.favorite(declaration: newDeclaration)
//        }
    }
}

//struct FirstDeclarationGuideView_Previews: PreviewProvider {
//    static var previews: some View {
//        FirstDeclarationGuideView(size: UIScreen.main.bounds.size) {
//            print("Continue tapped")
//        }
//        .environmentObject(DeclarationViewModel())
//    }
//}
