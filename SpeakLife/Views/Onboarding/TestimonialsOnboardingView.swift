//
//  TestimonialsOnboardingView.swift
//  SpeakLife
//
//  Testimonials screen for onboarding flow
//

import SwiftUI

struct TestimonialsOnboardingView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    let onContinue: () -> Void
    
    @State private var currentTestimonialIndex = 0
    @State private var timer: Timer?
    
    let testimonials = [
        Testimonial(
            rating: 5,
            quote: "I’m spending more time on this than on Facebook. This is filling me with truth instead of garbage and the audios are amazing.",
            author: "Ky"
        ),
        Testimonial(
            rating: 5,
            quote: "Love the scriptures. Starting everyday and night this way has literally changed my life. God bless you all abundantly!",
            author: "Jessica"
        ),
        Testimonial(
            rating: 5,
            quote: "This app was created under the manifestation and direction of the Holy Spirit, bringing life through scripture and meditation to God’s people.",
            author: "Sarah"
        ),
        Testimonial(
            rating: 5,
            quote: "After a year of using this app daily, I can confidently say that my faith has grown stronger than ever before.",
            author: "Michael"
        ),
        Testimonial(
            rating: 5,
            quote: "The daily declarations have transformed my mindset. I wake up with purpose and end my day with gratitude.",
            author: "Rachel"
        ),
        Testimonial(
            rating: 5,
            quote: "To God be the glory I’ve been reading all this and it’s so renewing and just so wooooo Hallelujah",
            author: "Charlie"
        ),
        Testimonial(
            rating: 5,
            quote: "Thank SpeakLife for helping me to know who Jesus is. I love everything about SpeakLife. It has brought me closer to him. My heart is full & grateful.",
            author: "RJ"
        ),
        Testimonial(
            rating: 5,
            quote: "I love this app. To feed on the promises of God regularly throughout the day is so uplifting and encouraging. It feeds my soul.",
            author: "Tina"
        )
    ]
    
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
    
    var body: some View {
        ZStack {
            // Background gradient
            backgroundView
            
            VStack(spacing: 0) {
                // Close button area
                HStack {
                    Spacer()
                    Button(action: onContinue) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                // Main content
                VStack(spacing: 32) {
                    // Title
                    VStack(spacing: 8) {
                        Text("Join 100K+ Believers")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Experience Life Transformation")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.top, 20)
                    
                    // Stats section
                    HStack(spacing: 40) {
                        // Worshippers stat
                        VStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))
                                
                                Text("100K+")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Text("Believers")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        // Rating stat
                        VStack(spacing: 8) {
                            Text("4.9")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            HStack(spacing: 2) {
                                ForEach(0..<5) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))
                                }
                            }
                            
                            Text("RATING")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    // Testimonials carousel
                    TabView(selection: $currentTestimonialIndex) {
                        ForEach(Array(testimonials.enumerated()), id: \.offset) { index, testimonial in
                            TestimonialCard(testimonial: testimonial)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: 200)
                    
                    // Page indicator
                    HStack(spacing: 6) {
                        ForEach(0..<testimonials.count, id: \.self) { index in
                            Circle()
                                .fill(currentTestimonialIndex == index ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: currentTestimonialIndex)
                        }
                    }
                    .padding(.top, -16)
                    
                    Spacer()
                    
                    // Benefits section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))
                            Text("Daily Scripture Declarations")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))
                            Text("Personalized to Your Journey")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))
                            Text("Transform Your Mind & Heart")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // CTA Button
                    Button(action: onContinue) {
                        Text("Start Your Transformation")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Constants.SLBlue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.white)
                            .cornerRadius(28)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
           // guard let self = self else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                self.currentTestimonialIndex = (self.currentTestimonialIndex + 1) % self.testimonials.count
            }
        }
    }
}

struct TestimonialCard: View {
    let testimonial: Testimonial
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Stars
            HStack(spacing: 4) {
                ForEach(0..<testimonial.rating) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0))
                }
            }
            
            // Quote
            Text("\"\(testimonial.quote)\"")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            // Author
            HStack {
                Text("– \(testimonial.author)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}

struct Testimonial {
    let rating: Int
    let quote: String
    let author: String
}

// MARK: - Preview
struct TestimonialsOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        TestimonialsOnboardingView(
            size: UIScreen.main.bounds.size,
            onContinue: {}
        )
    }
}
