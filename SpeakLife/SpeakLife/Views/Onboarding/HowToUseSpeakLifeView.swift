//
//  HowToUseSpeakLifeView.swift
//  SpeakLife
//
//  The "How to Use SpeakLife" guide, opened from Profile > Yours.
//
//  It used to replay five onboarding screens, which sold features rather than
//  explained them and predated the Today tab, the Daily Burst and Bible Chat.
//  It now walks through every feature in one scroll: what it is, how to use
//  it, and why, with the verse behind it. Cards start collapsed so the whole
//  list fits on a phone at a glance.
//

import SwiftUI

struct HowToUseSpeakLifeView: View {
    // Kept so the Profile call site, which injects all three, is unchanged.
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: DeclarationViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var expanded: Set<String> = []

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.15, blue: 0.3), Color(red: 0.02, green: 0.07, blue: 0.15)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    dailyRhythm
                    Text("EVERY FEATURE")
                        .font(.system(size: 14, weight: .heavy))
                        .tracking(1.6)
                        .foregroundColor(DS.Palette.gold)
                        .padding(.top, 8)
                    ForEach(GuideFeature.all) { feature in
                        GuideFeatureCard(
                            feature: feature,
                            isExpanded: expanded.contains(feature.id),
                            onTap: { toggle(feature) }
                        )
                    }
                    Text("Speak life over your day, every day. Your words carry power.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 64)
            }

            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.4), radius: 4)
            }
            .padding(.trailing, 20)
            .padding(.top, 12)
            .accessibilityLabel("Close")
        }
        .onAppear { AnalyticsService.shared.track("how_to_use_opened") }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How to Use SpeakLife")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("What each part of the app does, how to use it, and why it matters.")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The whole app in four steps, before any detail.
    private var dailyRhythm: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("YOUR DAILY RHYTHM")
                .font(.system(size: 14, weight: .heavy))
                .tracking(1.6)
                .foregroundColor(DS.Palette.gold)
            rhythmStep(1, "Speak", "Your Daily Burst in the morning. Seven declarations, out loud.")
            rhythmStep(2, "Hear", "An audio episode on the drive, on a walk, or at bedtime.")
            rhythmStep(3, "Read", "Today's devotional, five minutes in the Word.")
            rhythmStep(4, "Write", "Your gratitude or journal entry before bed.")
            Text("Not sure what's next? Open the Today tab and do Your Next Step.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: "#7C3AED"), Color(hex: "#4F46E5")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func rhythmStep(_ number: Int, _ verb: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#4C1D95"))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white))
            VStack(alignment: .leading, spacing: 2) {
                Text(verb)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                Text(detail)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func toggle(_ feature: GuideFeature) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expanded.contains(feature.id) {
                expanded.remove(feature.id)
            } else {
                expanded.insert(feature.id)
                AnalyticsService.shared.track("how_to_use_section_expanded", parameters: [
                    "section": feature.id
                ])
            }
        }
    }
}

// MARK: - Content

private struct GuideFeature: Identifiable {
    let id: String
    let icon: String
    let tint: String
    let title: String
    /// Where to find it, in the words the app itself uses.
    let location: String
    let what: String
    let how: [String]
    let why: String

    static let all: [GuideFeature] = [
        GuideFeature(
            id: "today", icon: "sun.max.fill", tint: "#F59E0B",
            title: "Today", location: "Today tab",
            what: "Your plan for the day, built around what you told us you need.",
            how: [
                "Start with Your Next Step, the big card at the top.",
                "Tap the Today's Progress tile to jump straight to whatever is next.",
                "Later Today lists the rest. Finished tasks move to Completed."
            ],
            why: "You never have to open the app wondering what to do. One clear step at a time builds a daily habit."
        ),
        GuideFeature(
            id: "burst", icon: "bolt.fill", tint: "#7C3AED",
            title: "Daily Burst", location: "Today tab",
            what: "Seven declarations, spoken out loud. About two minutes.",
            how: [
                "Tap Start Burst.",
                "Hold the Speak It button and say each declaration out loud.",
                "Finish all seven to keep your streak."
            ],
            why: "Faith speaks. Jesus said whoever says to this mountain, be removed, and does not doubt, will have what they say (Mark 11:23). The Burst is the one task that keeps your streak alive."
        ),
        GuideFeature(
            id: "personal_declaration", icon: "hands.sparkles.fill", tint: "#B7791F",
            title: "Your Own Declaration", location: "Today tab",
            what: "A declaration in your own words for what you're trusting God for.",
            how: [
                "Tap Name what you're believing for, then say it or type it.",
                "SpeakLife turns it into a declaration built on Scripture.",
                "Speak it every day. When God comes through, tap It Came to Pass to save your testimony."
            ],
            why: "It puts God's Word on the exact thing in front of you, and keeps you speaking it until it comes to pass."
        ),
        GuideFeature(
            id: "take_it_captive", icon: "shield.lefthalf.filled", tint: "#475569",
            title: "Take a Thought Captive", location: "Today tab, after your first two days",
            what: "A one-minute drill for the thoughts that try to settle in.",
            how: [
                "Pick the thought.",
                "Reject it, then speak the truth over it out loud.",
                "The mic listens to make sure you said it."
            ],
            why: "We take every thought captive to make it obey Christ (2 Corinthians 10:5). Saying the truth out loud is how you hold that ground."
        ),
        GuideFeature(
            id: "speak_feed", icon: "quote.bubble.fill", tint: "#0EA5E9",
            title: "Speak Feed", location: "Speak tab",
            what: "Declarations for the areas of life you care about, one at a time.",
            how: [
                "Swipe to the next declaration, and read each one out loud.",
                "Tap the heart to save one to your favorites, or share it with a friend.",
                "Use the categories button to choose topics like peace, healing or provision."
            ],
            why: "Keep God's promises in front of you all day, not just in the morning."
        ),
        GuideFeature(
            id: "audio", icon: "headphones", tint: "#059669",
            title: "Audio", location: "Audio tab",
            what: "Declarations, Scripture and teaching to listen to.",
            how: [
                "Press play on today's pick, or browse by topic.",
                "Add episodes to Up Next so they keep playing.",
                "Great on the drive, on a walk, or while you fall asleep."
            ],
            why: "Faith comes by hearing, and hearing by the word of Christ (Romans 10:17)."
        ),
        GuideFeature(
            id: "devotional", icon: "book.fill", tint: "#0284C7",
            title: "Daily Devotional", location: "Today tab",
            what: "A short reading for each day.",
            how: [
                "Open it from your task list.",
                "Read it slowly, and take one line with you into the day."
            ],
            why: "Five minutes in the Word sets your mind before the day does."
        ),
        GuideFeature(
            id: "bible_chat", icon: "text.bubble.fill", tint: "#0D9488",
            title: "Bible Chat", location: "Bible Chat tab",
            what: "Ask about anything you're carrying and get Scripture on it.",
            how: [
                "Type your real question, in your own words.",
                "Read the verses it brings back, and ask a follow-up if you need one.",
                "The full Bible reader is there too."
            ],
            why: "God's Word speaks to the exact thing you're facing today."
        ),
        GuideFeature(
            id: "journal_gratitude", icon: "pencil.and.scribble", tint: "#D97706",
            title: "Journal and Gratitude", location: "Today tab",
            what: "A place to write down what God is doing.",
            how: [
                "Some days your writing task is Write 3 Things You're Grateful For. Other days it's Journal One Insight.",
                "Type it, or tap the mic and speak it.",
                "Your entries are saved so you can read them back."
            ],
            why: "We enter His gates with thanksgiving (Psalm 100:4). What you write down, you keep for the day you need it."
        ),
        GuideFeature(
            id: "victory_week", icon: "flag.fill", tint: "#DC2626",
            title: "Weekly Victory Focus", location: "Today tab, after your first week (Premium)",
            what: "Seven days built around one area where you need victory.",
            how: [
                "Name what you need victory in, or pick a theme.",
                "For seven days your Daily Burst and audio are built around it.",
                "Invite a friend to stand with you. Find them under My Stands in Profile."
            ],
            why: "Seven days standing on one promise builds faith that lasts. A cord of three strands is not quickly broken (Ecclesiastes 4:12)."
        ),
        GuideFeature(
            id: "community", icon: "person.3.fill", tint: "#EC4899",
            title: "Community", location: "Profile, and Today > Jump Back In",
            what: "The Warrior Room, where believers share prayer requests.",
            how: [
                "Post what you need prayer for.",
                "Pray for someone else's request while you're there."
            ],
            why: "Pray for each other. The prayer of a righteous person is powerful and effective (James 5:16)."
        ),
        GuideFeature(
            id: "streak_reminders", icon: "flame.fill", tint: "#EA580C",
            title: "Streak and Reminders", location: "Profile",
            what: "Your streak counts the days you speak your Daily Burst.",
            how: [
                "Turn on reminders in Profile > Reminders: a morning Daily Burst reminder and an Evening Check-in.",
                "A streak freeze covers one missed day.",
                "See your streak and badges under Streak & Badges."
            ],
            why: "Small, daily obedience builds a life of faith. The reminders make it easy to show up."
        )
    ]
}

// MARK: - Card

private struct GuideFeatureCard: View {
    let feature: GuideFeature
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color(hex: feature.tint)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(feature.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text(feature.what)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Hides the details" : "Shows how and why to use it")

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    Label(feature.location, systemImage: "mappin.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DS.Palette.gold)

                    sectionTitle("HOW")
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(feature.how.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1).")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white.opacity(0.9))
                                Text(step)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.9))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    sectionTitle("WHY")
                    Text(feature.why)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
                .transition(.opacity)
            }
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy))
            .tracking(1.4)
            .foregroundColor(.white.opacity(0.55))
    }
}
