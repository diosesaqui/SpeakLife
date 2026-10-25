//
//  BurstFaithActionView.swift
//  SpeakLife
//
//  The eighth slat of the Daily Burst.
//
//  Seven declarations are spoken, then this: one corresponding action, mapped to
//  whatever the burst was actually about. Someone who just declared healing is
//  invited to walk. Someone who declared provision is invited to give. The act is
//  what makes the words a decision instead of a sentiment.
//
//  Two rules govern the design:
//
//    · It cannot gate anything. The streak, the checklist task, and the completion
//      record are all written the moment the seventh declaration is spoken, before
//      this screen appears. "Not today" costs the user nothing.
//    · It never names the low thing. No copy here mentions what someone is up
//      against, and there is no shame path — declining is a plain button, not a
//      confession.
//
//  The primary act here is sending the burst to someone who needs it. Passing
//  the promises on is itself the act of faith, so a completed send is what
//  records the commitment; a cancelled share sheet leaves the user here.
//

import SwiftUI

struct BurstFaithActionView: View {

    let theme: DeclarationCategory
    let action: FaithAction
    /// True while the cards are being drawn. Shows the progress state and
    /// disables the button, so a second tap cannot start a second share.
    var isPreparingShare: Bool = false
    /// Sends the burst. The presenter records the commitment once the share
    /// sheet reports a completed share.
    let onSend: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false
    @State private var cardScale: CGFloat = 0.92

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Scrolls rather than clips: the premise and the detail line both
                // wrap, and on a small screen at large type the card would
                // otherwise push the buttons off the bottom.
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Spacing.lg) {
                        eyebrow
                        premise
                        actionCard(width: geometry.size.width)
                        anchor
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, 80)
                    .padding(.bottom, DS.Spacing.lg)
                }

                buttons(width: geometry.size.width)
                    .padding(.top, DS.Spacing.sm)
                    .padding(.bottom, 50)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            withAnimation(DS.Motion.smooth) {
                appeared = true
                cardScale = 1.0
            }
            Juice.play(.tapLight)
        }
    }

    // MARK: - Pieces

    private var eyebrow: some View {
        Text("NOW WALK IT OUT")
            .font(.system(size: 13, weight: .bold))
            .kerning(1.6)
            .foregroundColor(.white)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                Capsule().fill(DS.Gradient.ember)
            )
            .opacity(appeared ? 1 : 0)
    }

    private var premise: some View {
        Text(FaithActionCatalog.actionSet(for: theme).premise)
            .font(.system(size: 26, weight: .bold, design: .serif))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, DS.Spacing.sm)
            .opacity(appeared ? 1 : 0)
    }

    private func actionCard(width: CGFloat) -> some View {
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DS.Gradient.ember)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color(red: 1.0, green: 0.34, blue: 0.13).opacity(0.45),
                            radius: 10, x: 0, y: 5)

                Image(systemName: action.icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(action.headline)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(action.detail)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DS.Spacing.lg)
        .padding(.horizontal, DS.Spacing.md)
        .frame(width: min(width * 0.86, 420))
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(Color.white.opacity(0.10))
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            }
        )
        .scaleEffect(cardScale)
        .opacity(appeared ? 1 : 0)
    }

    private var anchor: some View {
        VStack(spacing: 4) {
            Text(FaithActionCatalog.anchorVerse)
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text(FaithActionCatalog.anchorBook)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, DS.Spacing.md)
        .opacity(appeared ? 1 : 0)
    }

    private func buttons(width: CGFloat) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Button(action: onSend) {
                HStack(spacing: DS.Spacing.xs) {
                    if isPreparingShare {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .controlSize(.small)
                        Text("Preparing your cards…")
                            .font(.system(size: 17, weight: .semibold))
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 17, weight: .bold))
                        Text("Send this burst to a friend in need")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundColor(.white)
                .padding(.horizontal, DS.Spacing.md)
                .frame(width: width * 0.85, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 27)
                        .fill(DS.Gradient.ember)
                )
                .shadow(color: Color(red: 1.0, green: 0.34, blue: 0.13).opacity(0.35),
                        radius: 10, x: 0, y: 5)
                .animation(DS.Motion.quick, value: isPreparingShare)
            }
            .buttonStyle(.dsPressable(feel: .tapSolid))
            .disabled(isPreparingShare)
            .accessibilityLabel(isPreparingShare ? "Preparing your cards" : "Send this burst to a friend in need")

            Button(action: onSkip) {
                Text("Not today")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                    .frame(width: width * 0.85, height: 44)
            }
            .buttonStyle(.dsPressable(feel: .tapLight))
            .disabled(isPreparingShare)
        }
        .opacity(appeared ? 1 : 0)
    }
}

#Preview("Send this burst") {
    ZStack {
        LinearGradient(colors: [Color(red: 0.08, green: 0.05, blue: 0.20), .black],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        BurstFaithActionView(
            theme: .faith,
            action: FaithActionCatalog.action(for: .faith),
            onSend: {},
            onSkip: {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Preparing cards") {
    ZStack {
        Color.black.ignoresSafeArea()
        BurstFaithActionView(
            theme: .health,
            action: FaithActionCatalog.action(for: .health),
            isPreparingShare: true,
            onSend: {},
            onSkip: {}
        )
    }
    .preferredColorScheme(.dark)
}
