//
//  ReferralPageView.swift
//  SpeakLife
//
//  "Invite friends, get a year free." Spec §5 J1 to J3, §9.3.
//
//  ⚠️ NO DECISIONS IN HERE. The body switches on `viewModel.state` and that is
//  all. Every transition is `ReferralPageReducer`'s (Core, tested), every side
//  effect is `ReferralViewModel`'s (tested with fakes). If you need an `if`
//  that is not about layout, it belongs in one of those.
//
//  Every number on this screen comes from the server snapshot, or from config
//  before there is one. None is written into the copy.
//

import SwiftUI
import SpeakLifeCore

@MainActor
struct ReferralPageView: View {

    @StateObject private var viewModel: ReferralViewModel
    @ObservedObject private var subscriptionStore: SubscriptionStore
    @ObservedObject private var presentation = ReferralPresentation.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// `onClose` is for the presenter's own bookkeeping. Dismissal itself goes
    /// through `dismiss`, so a page opened over the hard paywall closes back
    /// onto the paywall and never finishes onboarding (FE-ENT-17).
    init(entry: ReferralEntry,
         subscriptionStore: SubscriptionStore,
         onClose: @escaping () -> Void = {}) {
        _subscriptionStore = ObservedObject(wrappedValue: subscriptionStore)
        _viewModel = StateObject(wrappedValue: ReferralViewModel(
            entry: entry,
            dependencies: .live(subscriptionStore: subscriptionStore),
            onDismiss: onClose))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Gradients().speakLifeCYOCell.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        content
                        if let notice = viewModel.notice {
                            noticeView(notice)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.xl)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        close()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundColor(DS.Palette.textSecondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .onAppear {
            presentation.pageAppeared()
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
            presentation.pageDisappeared()
        }
        .onChange(of: subscriptionStore.isPremium) { _, isPremium in
            viewModel.premiumChanged(isPremium)
        }
        .sheet(item: $viewModel.sharePayload) { payload in
            ReferralActivitySheet(items: payload.activityItems) { activityType, completed in
                viewModel.shareFinished(activityType: activityType, completed: completed)
            }
        }
    }

    private func close() {
        viewModel.notNowTapped()
        dismiss()
    }

    // MARK: - States

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .tint(.white)
                .padding(.top, DS.Spacing.xxl)
                .accessibilityLabel("Loading")

        case .notEnrolled:
            pitch(count: 0, target: viewModel.displayTarget, code: nil, isWorking: false)

        case .enrolling:
            pitch(count: 0, target: viewModel.displayTarget, code: nil, isWorking: true)

        case .active(let count, let target, let code):
            pitch(count: count, target: target, code: code, isWorking: false)

        case .unlocked(_, let reward, let alreadyPremium):
            unlocked(reward: reward, alreadyPremium: alreadyPremium)

        case .unlockedPendingCode:
            message(icon: "gift.fill",
                    title: "You did it.",
                    body: "Your free year is being prepared. We'll let you know the moment it's ready.")

        case .redeemed:
            message(icon: "checkmark.seal.fill",
                    title: "Premium active.",
                    body: "Your free year is yours. Enjoy every morning of it.")
            doneButton

        case .error(let retryable):
            failure(retryable: retryable)
        }
    }

    // MARK: - Pitch and progress (not enrolled, enrolling, active)

    private func pitch(count: Int, target: Int, code: String?, isWorking: Bool) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "gift.fill")
                .font(.system(size: 44))
                .foregroundColor(DS.Palette.gold)
                .accessibilityHidden(true)

            VStack(spacing: DS.Spacing.sm) {
                Text("Invite \(target) friends. Get a year free.")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundColor(DS.Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text("Share SpeakLife with people you love. When \(target) of them join, a full year of Premium is yours.")
                    .font(.body)
                    .foregroundColor(DS.Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            steps(target: target)

            progress(count: count, target: target)

            Button {
                viewModel.inviteTapped()
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    if isWorking {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text("Invite friends")
                }
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Capsule().fill(DS.Palette.gold))
            }
            .disabled(isWorking)
            .accessibilityHint("Opens the share sheet with your invite link")

            if let code {
                codeRow(code)
            }

            Button("Not now") { close() }
                .font(.callout.weight(.medium))
                .foregroundColor(DS.Palette.textSecondary)
                .frame(minHeight: 44)
        }
    }

    private func steps(target: Int) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            step(1, "Send your link to friends who need God's Word in their mornings.")
            step(2, "They download SpeakLife and finish setting up.")
            step(3, "When \(target) have joined, your free year unlocks.")
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
            .fill(DS.Palette.surface))
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Text("\(number)")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundColor(.black)
                .frame(minWidth: 26, minHeight: 26)
                .background(Circle().fill(DS.Palette.gold))
            Text(text)
                .font(.callout)
                .foregroundColor(DS.Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    /// "2 of 5 friends joined", read as one element (FE-QA-14).
    private func progress(count: Int, target: Int) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            ProgressView(value: Double(count), total: Double(max(target, 1)))
                .tint(DS.Palette.gold)
                .scaleEffect(x: 1, y: 2, anchor: .center)
            Text("\(count) of \(target) friends joined")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DS.Palette.textPrimary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) of \(target) friends joined")
    }

    /// The code written out for reading aloud, for a friend Branch does not
    /// match (spec J5). Tap to copy.
    private func codeRow(_ code: String) -> some View {
        let formatted = viewModel.formatted(code)
        return VStack(spacing: DS.Spacing.xs) {
            Text("YOUR INVITE CODE")
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundColor(DS.Palette.textSecondary)
            Button {
                UIPasteboard.general.string = formatted
                PremiumHaptics.success()
            } label: {
                Text(formatted)
                    .font(.system(.title, design: .monospaced).weight(.bold))
                    .tracking(2)
                    .foregroundColor(DS.Palette.textPrimary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(DS.Palette.surface))
            }
            .accessibilityLabel("Your invite code, \(formatted.map { String($0) }.joined(separator: " ")). Tap to copy.")
            Text("Friends who install without the link can type this in.")
                .font(.caption)
                .foregroundColor(DS.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Unlocked

    private func unlocked(reward: ReferralReward, alreadyPremium: Bool) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "gift.fill")
                .font(.system(size: 48))
                .foregroundColor(DS.Palette.gold)
                .accessibilityHidden(true)

            Text("You did it. Your free year is ready.")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundColor(DS.Palette.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(alreadyPremium
                 ? "You already have Premium, so your free year starts at your next renewal."
                 : "Redeem it with Apple and a full year of Premium is yours.")
                .font(.body)
                .foregroundColor(DS.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(reward.code)
                .font(.system(.title2, design: .monospaced).weight(.bold))
                .foregroundColor(DS.Palette.textPrimary)
                .textSelection(.enabled)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Palette.surface))
                .accessibilityLabel("Your free year code, \(reward.code.map { String($0) }.joined(separator: " "))")

            Button {
                viewModel.redeemTapped()
            } label: {
                Text("Redeem my free year")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Capsule().fill(DS.Palette.gold))
            }

            Button {
                viewModel.reissueTapped()
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    if viewModel.isReissuing { ProgressView().tint(.white) }
                    Text("My code didn't work")
                }
                .font(.callout.weight(.medium))
                .foregroundColor(DS.Palette.textSecondary)
                .frame(minHeight: 44)
            }
            .disabled(viewModel.isReissuing)
        }
    }

    // MARK: - Messages

    private func message(icon: String, title: String, body: String) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(DS.Palette.gold)
                .accessibilityHidden(true)
            Text(title)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundColor(DS.Palette.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .font(.body)
                .foregroundColor(DS.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, DS.Spacing.xl)
    }

    private var doneButton: some View {
        Button {
            close()
        } label: {
            Text("Done")
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Capsule().fill(DS.Palette.gold))
        }
    }

    private func failure(retryable: Bool) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: retryable ? "wifi.exclamationmark" : "pause.circle")
                .font(.system(size: 40))
                .foregroundColor(DS.Palette.gold.opacity(0.85))
                .accessibilityHidden(true)
            Text(retryable
                 ? "We couldn't reach SpeakLife. Check your connection and try again."
                 : "Not available right now.")
                .font(.body)
                .foregroundColor(DS.Palette.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if retryable {
                Button {
                    viewModel.retryTapped()
                } label: {
                    Text("Try again")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Capsule().fill(DS.Palette.gold))
                }
            }
            Button("Not now") { close() }
                .font(.callout.weight(.medium))
                .foregroundColor(DS.Palette.textSecondary)
                .frame(minHeight: 44)
        }
        .padding(.top, DS.Spacing.xl)
    }

    @ViewBuilder
    private func noticeView(_ notice: ReferralNotice) -> some View {
        switch notice {
        case .codeCopied:
            noticeText("Your code is copied. Paste it into the box that just opened.")
        case .reissued:
            noticeText("Here's a fresh code. Try redeeming again.")
        case .reissueFailed:
            noticeText("We couldn't get a new code just now. Try again in a moment.")
        case .contactSupport(let lastFour):
            VStack(spacing: DS.Spacing.xs) {
                noticeText("We've already sent you a replacement code. Contact support and we'll make it right.")
                Button("Contact support") {
                    if let url = Self.supportURL(lastFour: lastFour) { openURL(url) }
                }
                .font(.callout.weight(.semibold))
                .foregroundColor(DS.Palette.gold)
                .frame(minHeight: 44)
            }
        }
    }

    private func noticeText(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundColor(DS.Palette.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Prefilled with the last four of the code only (FE-PAG-16). The whole
    /// code is a working free year and does not belong in an email thread.
    static func supportURL(lastFour: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "speaklife@diosesaqui.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "My free year code didn't work"),
            URLQueryItem(name: "body", value: "My free year code ending in \(lastFour) didn't work."),
        ]
        return components.url
    }
}

// MARK: - Share sheet

/// `UIActivityViewController` with a completion handler, which the shared
/// `ShareSheet` cannot take (its callback is a `let` with a default).
/// `referral_share_completed` needs to know the share actually went.
struct ReferralActivitySheet: UIViewControllerRepresentable {

    let items: [Any]
    let onComplete: (_ activityType: String?, _ completed: Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            onComplete(activityType?.rawValue, completed)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
