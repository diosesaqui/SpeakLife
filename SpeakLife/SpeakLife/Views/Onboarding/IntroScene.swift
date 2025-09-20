//
//  IntroScene.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 3/29/22.
//

import SwiftUI

struct FeatureBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.blue)
            Text(text)
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 16, relativeTo: .body))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}


struct IntroTipScene: View {
    
    @EnvironmentObject var viewModel: DeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @State private var currentTestimonialIndex: Int = 0
    let impactMed = UIImpactFeedbackGenerator(style: .soft)
    
    @State private var showTitle = false
    @State private var showBodyText = false
    @State private var showSubtext = false
    @State private var buttonTapped = false
    
    let title: String
    let bodyText: String
    let subtext: String
    var bullets: [String] = []
    let ctaText: String
    let showTestimonials: Bool
    let isScholarship: Bool
   // var imageName: String
    
    let size: CGSize
    let callBack: (() -> Void)?
    var buyCallBack: ((InAppId.Subscription) -> Void)?
    @State var errorTitle = ""
    @State var isShowingError: Bool = false
    @State private var animateButton: Bool = false
    @State private var showText: Bool = false
    
    @State private var selectedOption = InAppId.Subscription.speakLife1YR29
    
    var body: some  View {
        introTipScene(size: size)
            .alert(isPresented: $isShowingError, content: {
                Alert(title: Text(errorTitle), message: nil, dismissButton: .default(Text("OK")))
            })
            .onAppear {
                showText = true
                animateButton = true
            }
    }
    
   
    
    private func introTipScene(size: CGSize) -> some View  {
        VStack {
            Spacer().frame(height: 30)
        
            VStack(alignment: /*@START_MENU_TOKEN@*/.center/*@END_MENU_TOKEN@*/) {
                Text(title)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .white.opacity(0.6), radius: 4, x: 0, y: 2)
                    .opacity(showText ? 1 : 0)
                    .offset(y: showText ? 0 : 20)
                    .animation(.easeOut(duration: 1).delay(0.1), value: showText)
                    .padding([.horizontal])

                Spacer().frame(height: appState.onBoardingTest ? size.height * 0.04 : 24)
                
                VStack(spacing: 24) {
                    
                    Text(bodyText)
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 18, relativeTo: .body))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(8)
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : 20)
                        .animation(.easeOut(duration: 1).delay(0.3), value: showText)
                        .padding(.horizontal)// was 12
                    //.lineLimit(nil)
                    
                    Text(subtext)
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 14, relativeTo: .body))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(8)
                        .opacity(showText ? 1 : 0)
                        .offset(y: showText ? 0 : 20)
                        .animation(.easeOut(duration: 1).delay(0.5), value: showText)
                    // was 8
                        .lineLimit(nil)
                    Spacer()
                        .frame(width: 5, height: size.height * 0.02)
                    ForEach(bullets, id: \.self) { bullet in
                        HStack {
                            VStack {
                                FeatureBullet(text: bullet)
                                Spacer()
                                    .frame(width: 5, height: size.height * 0.02)
                            }
                            Spacer()
                        }.padding([.leading])
                    }
                    .opacity(showText ? 1 : 0)
                    .offset(y: showText ? 0 : 20)
                    .animation(.easeOut(duration: 1).delay(0.7), value: showText)
                   
                }
                
            }
          
            
            Spacer()
            ShimmerButton(colors: [.blue], buttonTitle: ctaText, action: buttonTouched)
            .frame(width: size.width * 0.87 ,height: 50)
//            .shadow(color: .white.opacity(animateButton ? 0.3 : 0.1), radius: animateButton ? 12 : 6)
//            .scaleEffect(animateButton ? 1.02 : 1.0)
//            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: animateButton)
//            //.shadow(color: Constants.DAMidBlue, radius: 8, x: 0, y: 10)
//            
//            //.foregroundColor(.white)
//            .cornerRadius(30)
//            //.shadow(color: Constants.DAMidBlue.opacity(0.5), radius: 8, x: 0, y: 10)
//            .scaleEffect(buttonTapped ? 0.95 : 1.0)

            
            Spacer()
                .frame(width: 5, height: size.height * 0.07)
        }
        .frame(width: size.width, height: size.height)
        .background(
            ZStack {
                Image(subscriptionStore.testGroup == 0 ? subscriptionStore.onboardingBGImage : onboardingBGImage2)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                    .brightness(0.05)
                Color.black.opacity(subscriptionStore.testGroup == 0 ? 0.4 : 0.2)
                    .edgesIgnoringSafeArea(.all)
            }
        )
    }
    
    func buttonTouched() {
        buttonTapped = true
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)) {
            buttonTapped = false
        }
        if isScholarship {
        buyCallBack?(selectedOption)
        } else {
            callBack?()
        }
    }
}

//let testimonials: [Testimonial] = [
//    Testimonial(id: 1, text: "This app has transformed my daily routine, bringing peace and inspiration to every day.", author: "Alex J.", details: "UK"),
//    Testimonial(id: 2, text: "A truly uplifting experience every time I use this app. Highly recommended for anyone seeking daily motivation.", author: "Caleb W.", details: "USA"),
//    Testimonial(id: 3, text: "I really love this app and have been sharing it with my friends and family! I bought the subscription and am pleased with it. Great job!", author: "Samantha F.", details: "USA"),
//    Testimonial(id: 4, text: "Powerful affirmations. Loving it!! Everyone should give it a try", author: "Rahul P.", details: "India"),
//    Testimonial(id: 7, text: "I love the awesome backgrounds, the categories you can pick to suit, God uses all things for the good of those that love Him and are Called.", author: "Emily C.", details: "United Kingdom"),
//    Testimonial(id: 8, text: "I absolutely love this app because instead of scrolling on tiktok, Instagram etc. I can scroll here and learn about God even more.", author: "Maria S.", details: "Philippines")
//]

struct IntroScene: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    let headerText: String
    let bodyText: String
    let footerText: String
    let buttonTitle: String
    
    let size: CGSize
    let callBack: (() -> Void)
    
    var body: some  View {
        introSceneAlt(size: size)
    }
    
    private func introSceneAlt(size: CGSize) -> some View  {
        VStack {
            
            if appState.onBoardingTest {
                Spacer()
            } else {
                Spacer().frame(height: 90)
                
                Image("declarationsIllustration")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 235, height: size.height * 0.25)
            }
           
            
            Spacer().frame(height: 40)
            VStack {
                Text(headerText)
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 40, relativeTo: .title))
                    .fontWeight(.semibold)
                    .foregroundColor(appState.onBoardingTest ? .white : Constants.DEABlack)
                
                Spacer().frame(height: 16)
                
                VStack {
                    Text(bodyText)
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .body))
                        .foregroundColor(appState.onBoardingTest ? .white : Constants.DALightBlue)
                        .multilineTextAlignment(.center)
                        .lineSpacing(10)
                        .lineLimit(nil)
                    
                    Spacer().frame(height: appState.onBoardingTest ? size.height * 0.25 : 24)
                    
                    Text(footerText)
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .title2))
                        .foregroundColor(appState.onBoardingTest ? .white :Constants.DALightBlue)
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
                    Text(buttonTitle)
                        .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .body))
                        .fontWeight(.medium)
                        .frame(width: size.width * 0.91 ,height: 50)
                }.padding()
            }
            .frame(width: size.width * 0.87 ,height: 50)
            .background(.blue)
            
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(color: Constants.DAMidBlue, radius: 8, x: 0, y: 10)
            
            Spacer()
                .frame(width: 5, height: size.height * 0.07)
        }
        .frame(width: size.width, height: size.height)
        .background(
            ZStack {
                Image(subscriptionStore.testGroup == 0 ? subscriptionStore.onboardingBGImage : onboardingBGImage2)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                Color.black.opacity(subscriptionStore.testGroup == 0 ? 0.1 : 0.2)
                    .edgesIgnoringSafeArea(.all)
            }
        )
        
    }
}



struct LoadingScene: View {
    
    let size: CGSize
    let callBack: (() -> Void)
    
    @State private var pulsate = false
    @State private var rotate = false
    @State private var fadeInOut = false
    
    let animationDuration = 0.8
    let maxScale: CGFloat = 1.2
    let minOpacity = 0.5
    let maxOpacity = 1.0
    let delay = Double.random(in: 3...6)
    
    var body: some View {
        ZStack {
            Gradients().purple
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                
                Text("Preparing a personalized journey through the Word for you...")
                    .font(Font.custom("AppleSDGothicNeo-Regular", size: 20, relativeTo: .body))
                    .foregroundColor(.white)
                    .opacity(fadeInOut ? minOpacity : maxOpacity)
                    .animation(Animation.easeInOut(duration: animationDuration).repeatForever(autoreverses: true), value: fadeInOut)
                    .padding()
                
                Spacer().frame(height: 90)
                
                Circle()
                    .fill(Constants.DAMidBlue.opacity(0.7))
                    .frame(width: 200, height: 200)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .scaleEffect(pulsate ? maxScale : 1)
                            .opacity(fadeInOut ? minOpacity : maxOpacity)
                    )
                    .rotationEffect(.degrees(rotate ? 360 : 0))
                    .animation(Animation.easeInOut(duration: animationDuration).repeatForever(autoreverses: true), value: pulsate)
                    .animation(Animation.linear(duration: animationDuration * 2).repeatForever(autoreverses: false), value: rotate)
                    .animation(Animation.easeInOut(duration: animationDuration).repeatForever(autoreverses: true), value: fadeInOut)
                    .onAppear {
                        self.pulsate = true
                        self.rotate = true
                        self.fadeInOut = true
                    }
                
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation {
                    callBack()
                }
            }
        }
    }
}


struct TestimonialScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    let size: CGSize
    let callBack: (() -> Void)
    @State private var currentIndex = 0
    
    let testimonials = [
        Testimony(author: "Sophia M.", text: "The app is so centered on what we need in line with God’s promise over our life. I appreciate the idea behind this invention and great work,God inspiration and ideas never cease from the organization."),
        Testimony(author: "Sophia M.", text: "SpeakLife has brought so much peace into my life. The reminders of God’s promises help me stay calm even on my toughest days."),
        Testimony(author: "Emma R.", text: "I just found this App & everything I’ve read has been rooted in Scripture! I highly recommend getting this App to ensure (like myself) you are firmly rooted in the Truth & the Light of Christ in a World of Darkness, Selfishness, & Deceit! May we all find Peace, Grace, & Love by becoming everything our Heavenly Father designed us to be in this Life!"),
        Testimony(author: "Purestarcep17", text: "I love Bible apps that give you access to more Bible knowledge and affirmations so as I was discovering all of wonderful things that were included in SpeakLife I decided that this was something I needed in my life and I am so glad that I did. Because it was so well put together and informative. I have shared it with many people. I thank God for you all."),
        Testimony(author: "John K.", text: "I was fearful of losing my job and stumbled upon this app with God’s promises. I found one on how he would never leave me nor forsake me! I started saying it multiple times a day everyday! I ended up losing the job due to layoffs but got a new job paying 2x as much right before I was out of savings! Never missed a bill or anything! God is great! Thank you Speaklife!"),
        Testimony(author: "Sophia M.", text: "I love how the app represents the WORD OF GOD and I appreciate the affirmations and peaceful quotes."),
       
    ]

    var body: some View {
        VStack {
            Spacer().frame(height: 30)
            VStack(spacing: 30) {
                
                Text("Here's what others are saying")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                StarRatingView(rating: 4.9)
                Spacer()
                
                ScrollView(.horizontal, showsIndicators: false) {
                 
                        HStack(spacing: 20) {
                            TestimonialCard(testimonial: testimonials[0])
                            TestimonialCard(testimonial: testimonials[1])
                            TestimonialCard(testimonial: testimonials[2])
                            TestimonialCard(testimonial: testimonials[3])
                            TestimonialCard(testimonial: testimonials[4])
                            TestimonialCard(testimonial: testimonials[5])
                        }
                        .padding(.horizontal, 20)
                }
                .frame(height: 300)
                
                
                Spacer()
                
                ShimmerButton(colors: [.blue], buttonTitle: "Continue", action: callBack)
                    .frame(width: size.width * 0.87, height: 50)
                    //.shadow(color: Constants.DAMidBlue, radius: 8, x: 0, y: 10)
                    .cornerRadius(30)
                
            }
            Spacer()
                .frame(width: 5, height: size.height * 0.07)
        }
            .frame(width: size.width, height: size.height)
            .background(
                ZStack {
                    Image(subscriptionStore.testGroup == 0 ? subscriptionStore.onboardingBGImage : onboardingBGImage2)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .edgesIgnoringSafeArea(.all)
                    Color.black.opacity(subscriptionStore.testGroup == 0 ? 0.1 : 0.2)
                        .edgesIgnoringSafeArea(.all)
                }
            )
        }
}

struct Testimony: Identifiable {
    let id = UUID()
    let author: String
    let text: String
}

struct TestimonialCard: View {

    let testimonial: Testimony

    var body: some View {
        VStack(spacing: 20) {
            Text("“\(testimonial.text)”")
                .font(Font.custom("AppleSDGothicNeo-Regular", size: 16, relativeTo: .body))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
        }
        .frame(width: 260, height: 300)
            .padding()
            .background(BlurView(style: .dark))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}


import SwiftUI

struct FeatureShowcaseScreen: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    let size: CGSize
    let callBack: (() -> Void)
    
    var body: some View {
        VStack {
            Spacer().frame(height: 30)
            VStack(spacing: 30) {
                
                Text("Discover the Key Features")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Spacer()
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        FeatureCard(icon: "sparkles", title: "Personalized Affirmations", description: "Receive affirmations in alignment with your new identity in Jesus.")
                        FeatureCard(icon: "hands.sparkles", title: "Guided Prayer & Devotionals", description: "Start your day with devotionals that teach you God's grace and love.")
                        FeatureCard(icon: "bell.badge", title: "Daily Reminders", description: "Daily notifications to help you grow in peace, joy, and wisdom.")
                        FeatureCard(icon: "headphones", title: "Audio Declarations & Bible Stories", description: "Follow along with powerful declarations and Bible stories to activate your faith anytime.")
                    }
                    .padding(.horizontal, 20)
                }
                .frame(maxHeight: 350)
                Spacer()
                
                ShimmerButton(colors: [.blue], buttonTitle: "Continue", action: callBack)
                    .frame(width: size.width * 0.87 ,height: 50)
                    .foregroundColor(.white)
                    .cornerRadius(30)
                
                
            }
            Spacer()
                .frame(width: 5, height: size.height * 0.07)
        }
        .frame(width: size.width, height: size.height)
        .background(
            ZStack {
                Image(subscriptionStore.testGroup == 0 ? subscriptionStore.onboardingBGImage : onboardingBGImage2)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .edgesIgnoringSafeArea(.all)
                Color.black.opacity(subscriptionStore.testGroup == 0 ? 0.1 : 0.2)
                    .edgesIgnoringSafeArea(.all)
            }
                )
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 18) {
                    Image(systemName: icon)
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .padding()
                        .background(Circle().fill(Color.blue.opacity(0.8)))

                    Text(title)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(description)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            .frame(width: 260, height: 300)
                .padding()
                .background(BlurView(style: .dark))
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                
            }
}

