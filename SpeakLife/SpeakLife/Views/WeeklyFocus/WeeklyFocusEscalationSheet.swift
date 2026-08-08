//
//  WeeklyFocusEscalationSheet.swift
//  SpeakLife
//
//  What the app says when it notices.
//
//  Shown once, and only once, per need that has carried three or more weeks
//  (`WeeklyFocusEscalation`). It offers exactly two doors and a way out, and
//  deliberately offers no new declarations: the user has spoken 60+ of them at
//  this need already. More of the same is the response that made them stop
//  believing the app was listening.
//
//    "Talk it through"     Bible Chat, opened with their own words already in
//                          the box, so the first reply is about them.
//    "It already happened" The Anchor's It Came to Pass flow. The likeliest
//                          reason a need has not moved in a month is that it
//                          moved and nobody marked it.
//    "Not now"             Closes it forever for this need. A dismissal is an
//                          answer, and asking again next Sunday is the nag.
//

import SwiftUI

struct WeeklyFocusEscalationSheet: View {

    // Held only to forward into the Bible Chat cover below. SwiftUI does not
    // reliably propagate environment objects across a presentation hop, which
    // BibleChatView already documents for its own paywall sheet — so they are
    // re-injected by hand rather than assumed.
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var declarationStore: DeclarationViewModel

    let focus: WeeklyFocus
    /// Only offered when there is an unreceived Anchor to mark. The parent owns
    /// that state (`AppState.hasPersonalDeclaration`), so it decides.
    let showsAnchorOption: Bool
    /// Present the Anchor card, whose "It Came to Pass" button runs the
    /// existing breakthrough flow. Reusing that path rather than rebuilding it
    /// keeps one definition of what a breakthrough is.
    let onOpenAnchor: () -> Void
    let onDismiss: () -> Void

    @State private var showChat = false
    @State private var appeared = false

    private var weeksCarried: Int { max(2, focus.carryOverCount + 1) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.04, blue: 0.14),
                    Color(red: 0.06, green: 0.10, blue: 0.24)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer().frame(height: 40)
                    header
                    VStack(spacing: 12) {
                        chatButton
                        if showsAnchorOption { anchorButton }
                    }
                    notNowButton
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            AnalyticsService.shared.track("weekly_focus_escalation_shown", parameters: [
                "need_bucket": focus.needBucket,
                "carry_over_count": focus.carryOverCount
            ])
        }
        .fullScreenCover(isPresented: $showChat) {
            // Bible Chat is a full surface with its own paywall handling, so it
            // is presented whole rather than embedded. The need rides in as the
            // draft, not as a sent message: they get to edit it, and nothing is
            // spent until they choose to send.
            BibleChatConversationView(prefillPrompt: WeeklyFocusEscalation.chatPrompt(for: focus))
                .environmentObject(appState)
                .environmentObject(subscriptionStore)
                .environmentObject(declarationStore)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            Text("\u{1F64F}")
                .font(.system(size: 52))

            Text("You've carried this \(weeksCarried) weeks.")
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let need = focus.needText, !need.isEmpty {
                Text("\u{201C}\(need)\u{201D}")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("More declarations is not the answer this week. Let's do something different.")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 6)
    }

    // MARK: - Doors

    private var chatButton: some View {
        Button {
            AnalyticsService.shared.track("weekly_focus_escalation_action", parameters: [
                "action": "bible_chat",
                "need_bucket": focus.needBucket
            ])
            showChat = true
        } label: {
            optionRow(
                icon: "bubble.left.and.bubble.right.fill",
                title: "Talk it through",
                subtitle: "Bring it to Bible Chat, already loaded.",
                filled: true
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var anchorButton: some View {
        Button {
            AnalyticsService.shared.track("weekly_focus_escalation_action", parameters: [
                "action": "came_to_pass",
                "need_bucket": focus.needBucket
            ])
            onOpenAnchor()
        } label: {
            optionRow(
                icon: "hands.sparkles.fill",
                title: "It already happened",
                subtitle: "Mark what God has already done.",
                filled: false
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var notNowButton: some View {
        Button {
            AnalyticsService.shared.track("weekly_focus_escalation_action", parameters: [
                "action": "dismiss",
                "need_bucket": focus.needBucket
            ])
            onDismiss()
        } label: {
            Text("Not now")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func optionRow(icon: String,
                           title: String,
                           subtitle: String,
                           filled: Bool) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(filled ? 1 : 0.8))
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(filled
                      ? AnyShapeStyle(LinearGradient(
                            colors: [Color(red: 0.2, green: 0.5, blue: 1.0),
                                     Color(red: 0.4, green: 0.3, blue: 1.0)],
                            startPoint: .leading, endPoint: .trailing))
                      : AnyShapeStyle(Color.white.opacity(0.08)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(filled ? 0.0 : 0.14), lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
