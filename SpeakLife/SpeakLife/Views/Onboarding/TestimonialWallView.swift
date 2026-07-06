//
//  TestimonialWallView.swift
//  SpeakLife
//
//  Full-page scrollable testimonial wall shown in every active onboarding
//  arm right before the paywall. Stacks real App Store reviews (5-star,
//  verbatim, no developer responses, no dates) under a 4.9-rating header so
//  the user hits the pricing decision right after seeing the proof.
//
//  Distinct from the dormant TestimonialsOnboardingView carousel: this is a
//  scroll wall (all reviews visible by scrolling) with a sticky continue CTA.
//

import SwiftUI

struct TestimonialWallView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    let size: CGSize
    /// Onboarding arm name for analytics ("product", "warfare", "quiz", ...).
    let flow: String
    let onContinue: () -> Void

    @State private var v = false
    // 4.9 = current US App Store rating (primary market). Update when it moves.
    private static let rating = 4.9
    @State private var displayedRating: Double = 0

    private static let starGold = Color(red: 1.0, green: 0.8, blue: 0)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Spacer().frame(height: size.height * 0.08)

                    header
                        .appearStagger(v)

                    VStack(spacing: 14) {
                        ForEach(Array(Self.reviews.enumerated()), id: \.offset) { index, review in
                            reviewCard(review)
                                .appearStagger(v, delay: min(0.12 + Double(index) * 0.05, 0.5))
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 24)
                }
            }
            // Content dissolves just above the CTA instead of hard-stopping.
            .mask(
                VStack(spacing: 0) {
                    Rectangle().fill(Color.black)
                    LinearGradient(
                        gradient: Gradient(colors: [.black, .clear]),
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 48)
                }
            )

            ProductContinueButton(label: "Continue →") { onContinue() }
                .padding(.top, 2)
                .padding(.bottom, 36)
        }
        // The wall always sits on the dark onboarding photo; pin the scheme so
        // the card material never flips to its light appearance.
        .environment(\.colorScheme, .dark)
        .onAppear {
            AnalyticsService.shared.track("testimonial_wall_shown", parameters: ["flow": flow])
            withAnimation { v = true }
        }
        .task { await countUpRating() }
    }

    // Steps the big numeral 0.0 → 4.9 over ~0.6s (spring-free, ends exact).
    private func countUpRating() async {
        for value in stride(from: 0.7, through: Self.rating, by: 0.35) {
            try? await Task.sleep(nanoseconds: 45_000_000)
            withAnimation(.easeOut(duration: 0.08)) {
                displayedRating = min(value, Self.rating)
            }
        }
        withAnimation(.easeOut(duration: 0.1)) { displayedRating = Self.rating }
    }

    private var header: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text(String(format: "%.1f", displayedRating))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: displayedRating))
                HStack(spacing: 5) {
                    ForEach(0..<5) { index in
                        Image(systemName: "star.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Self.starGold)
                            .scaleEffect(v ? 1 : 0.3)
                            .opacity(v ? 1 : 0)
                            .animation(
                                .spring(response: 0.35, dampingFraction: 0.6)
                                    .delay(0.15 + Double(index) * 0.09),
                                value: v
                            )
                    }
                }
                Text("APP STORE RATING")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(2.0)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Rated 4.9 out of 5 stars on the App Store")

            Text("Believers everywhere are\nspeaking life. Hear them.")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 10)
    }

    // Mirrors the App Store review card layout: bold title, then stars on the
    // left with the reviewer name right-aligned, then the quote. No dates.
    private func reviewCard(_ review: WallReview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !review.title.isEmpty {
                Text(review.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .center) {
                HStack(spacing: 2.5) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Self.starGold)
                    }
                }
                // Every wall review is 5 stars; VoiceOver reads it once here
                // instead of five star glyphs per card.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("5 out of 5 stars")
                Spacer()
                Text(review.author)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
            }

            Text(review.quote)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.88))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Review data

struct WallReview {
    let title: String
    let quote: String
    let author: String
}

extension TestimonialWallView {
    // Real App Store reviews, verbatim (developer responses removed).
    // Ordered so the strongest conversion-relevant proof leads.
    static let reviews: [WallReview] = [
        WallReview(
            title: "The best app ever made!",
            quote: "Second to the Bible, this app is my favorite. It brings me such joy and encouragement and every time I've read something I just feel lighter, more encouraged and excited what God has in store for my day. To the creator of this app, may God continue to pour into you as you pour out this blessing to the world! I am grateful for your gift!",
            author: "chevonne818"
        ),
        WallReview(
            title: "So Thankful!",
            quote: "This app is amazing! Better than I ever hoped from an app. It is exactly what I needed.",
            author: "Lenore7283"
        ),
        WallReview(
            title: "Amazing",
            quote: "So far, I've only used the free week trial. This has been life-changing. It gives you affirmations to speak out loud. Also meditations on different things like Psalm 91, your identity in Christ, etc. I fully recommend this to anyone who is looking to grow their relationship with Jesus. And to deepen their belonging.",
            author: "Heather L Compton"
        ),
        WallReview(
            title: "Transformed my mind",
            quote: "I am blessed to have an app like this that helps me remember God's promises in his word. I love the daily reminders they've been helping me renew my mind and how I think. Empower me with God's word throughout my day.",
            author: "Omi_mindset"
        ),
        WallReview(
            title: "Best app on the market",
            quote: "I'm spending more time on this than on Facebook. This is filling me with truth instead of garbage and the audios are amazing. Love the music. We need more of this for sure. Best app out there for devotional and declarations. Highly recommend.",
            author: "Kyla Clark"
        ),
        WallReview(
            title: "Beautiful!",
            quote: "I can already feel God's mighty working power from seeing the first few pages. This app was definitely an inspiration from God and is heaven sent!",
            author: "12Veevee12"
        ),
        WallReview(
            title: "",
            quote: "I felt God was using the person who created this app! Incredible.",
            author: "Diego Alberto Souza"
        ),
        WallReview(
            title: "Wow!",
            quote: "I just read the letter from my Heavenly Father on this app, and I love that every sentence and thought is a scripture put together that really drives home the message of God's love for me.",
            author: "JaniceBanjo"
        ),
        WallReview(
            title: "Transforming",
            quote: "I am so happy that I get to use SpeakLife. I love the different episodes about how our words matter. Our words can change the course of our life good or bad. I just wanted to say thank you for all your encouragement each day. I also am very excited about the victorious affirmations.",
            author: "KathyAnn1434"
        ),
        WallReview(
            title: "Helping me to know & love Jesus",
            quote: "Thank SpeakLife for helping me to know who Jesus is. I love everything about SpeakLife. It has brought me closer to him. My heart is full & grateful.",
            author: "Traveler RJ"
        ),
        WallReview(
            title: "Excellent App!",
            quote: "Excellent app! I love saying the declarations each morning.",
            author: "msmusicmaker"
        ),
        WallReview(
            title: "Beautiful",
            quote: "As soon as I opened this app it began to speak life and confirmation over me.",
            author: "Tea lite"
        ),
        WallReview(
            title: "Amazing!!",
            quote: "Thank you, thank you, thank you. The scripture says we should renew our mind through the word. This app is the epitome of tech designed to accomplish that purpose. Words can't express how grateful I am to the creators of this app.",
            author: "Tripp7777777"
        ),
        WallReview(
            title: "Amazing App!",
            quote: "To God be the glory I've been reading all this and it's so renewing and just so wooooo Hallelujah",
            author: "CoolKidCharles12"
        ),
        WallReview(
            title: "Thank you for this app!",
            quote: "I appreciate all the work put into creating this app and the continued improvements. I really enjoyed the testimony of the person who came up with this app. It was inspiring to listen to.",
            author: "Happy Nature Gal"
        )
    ]
}

// Local copy of the stagger modifier (the one in ProductOnboardingView is
// file-private).
private struct WallAppearStagger: ViewModifier {
    let shown: Bool
    let delay: Double
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .animation(.easeOut(duration: 0.55).delay(delay), value: shown)
    }
}

private extension View {
    func appearStagger(_ shown: Bool, delay: Double = 0) -> some View {
        modifier(WallAppearStagger(shown: shown, delay: delay))
    }
}

// MARK: - Preview

struct TestimonialWallView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TestimonialWallView(
                size: UIScreen.main.bounds.size,
                flow: "preview",
                onContinue: {}
            )
        }
    }
}
