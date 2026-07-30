//
//  BreakthroughFlowView.swift
//  SpeakLife
//

import SwiftUI
import FirebaseAnalytics

struct BreakthroughFlowView: View {
    @EnvironmentObject var appState: AppState

    let declaration: PersonalDeclaration
    let onDismiss: () -> Void
    let onSetNew: () -> Void
    /// Called when the user opts to share the breakthrough as a testimony
    /// in the Warrior Room. The parent view dismisses this flow and
    /// presents the Warrior Room post composer prefilled with this text
    /// and `isTestimony=true`. Optional — if omitted, the share button
    /// falls back to the legacy in-flow `testimonies` collection write.
    var onShareToWarriorRoom: ((String) -> Void)? = nil

    @State private var step: BreakthroughStep = .confirm
    @State private var testimony: String = ""
    @State private var isSaving = false
    @State private var sharedToWall = false

    private let markReceivedUseCase = DIContainer.shared.makeMarkReceivedUseCase()
    @StateObject private var testimonyViewModel = TestimonyViewModel()

    /// The prefill text passed to the Warrior Room composer. Uses what the
    /// user typed in this flow if non-empty; otherwise generates a starter
    /// testimony from the declaration text.
    private var warriorRoomPrefill: String {
        let typed = testimony.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return typed }
        return "God came through. I had been declaring: \"\(declaration.declarationText)\" — praise Him!"
    }

    enum BreakthroughStep {
        case confirm
        case testimony
        case celebration
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.1, blue: 0.2), Color(red: 0.05, green: 0.18, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch step {
            case .confirm:   confirmView
            case .testimony: testimonyView
            case .celebration: celebrationView
            }
        }
    }

    // MARK: - Confirm

    private var confirmView: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("\u{1F64F}")
                .font(.system(size: 64))
                .dsAppear(0)

            VStack(spacing: DS.Spacing.sm) {
                Text("You're saying God came through?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)

                Text("Day \(declaration.dayCount) of believing.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
            }
            .dsAppear(0.06)

            Spacer()

            VStack(spacing: 14) {
                Button {
                    withAnimation { step = .testimony }
                } label: {
                    Text("Yes — He did it! \u{1F64C}")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(DS.Gradient.gold)
                        )
                        .foregroundColor(.white)
                        .padding(.horizontal, DS.Spacing.lg)
                }
                .buttonStyle(.dsPressable(feel: .tapSolid))

                Button {
                    onDismiss()
                } label: {
                    Text("Not yet — keep believing")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.dsPressable(feel: .tapSolid))
            }
            .padding(.bottom, DS.Spacing.xxl)
            .dsAppear(0.12)
        }
    }

    // MARK: - Testimony

    private var testimonyView: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()

            VStack(spacing: 10) {
                Text("\u{270D}\u{FE0F}")
                    .font(.system(size: 48))

                Text("What happened?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Encourage others on the Prayer Wall")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.55))
            }
            .dsAppear(0)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 140)

                if testimony.isEmpty {
                    Text("Tell God's story in your own words...")
                        .foregroundColor(.white.opacity(0.35))
                        .font(.system(size: 14))
                        .padding(14)
                }

                TextEditor(text: $testimony)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .foregroundColor(.white)
                    .font(.system(size: 14))
                    .padding(10)
                    .frame(height: 140)
            }
            .padding(.horizontal, DS.Spacing.lg)

            // Character count
            if !testimony.isEmpty {
                Text("\(testimony.count)/500")
                    .font(.system(size: 12))
                    .foregroundColor(testimony.count > 500 ? .red : .white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 28)
            }

            // Error from Firestore
            if let error = testimonyViewModel.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.lg)
            }

            Spacer()

            VStack(spacing: 14) {
                // Primary CTA — share testimony in the Warrior Room.
                // When `onShareToWarriorRoom` is wired (the modern path),
                // we mark received locally then hand off to the parent so
                // it can present the Warrior Room composer prefilled with
                // a starter testimony. Falls back to the legacy in-flow
                // `testimonies` collection write if the callback is nil.
                Button {
                    if let onShareToWarriorRoom {
                        shareToWarriorRoom(via: onShareToWarriorRoom)
                    } else if testimony.isEmpty {
                        saveAndCelebrate(testimony: nil, shareToWall: false)
                    } else {
                        saveAndCelebrate(testimony: testimony, shareToWall: true)
                    }
                } label: {
                    Group {
                        if isSaving || testimonyViewModel.isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Share Testimony 🏆")
                                .font(.system(size: 17, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(DS.Gradient.gold)
                    )
                    .foregroundColor(.white)
                    .padding(.horizontal, DS.Spacing.lg)
                }
                .buttonStyle(.dsPressable(feel: .tapSolid))
                .disabled(isSaving || testimonyViewModel.isSubmitting || testimony.count > 500)

                // Keep Private — saves locally, doesn't post
                if !testimony.isEmpty {
                    Button {
                        saveAndCelebrate(testimony: testimony, shareToWall: false)
                    } label: {
                        Text("Keep Private")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.dsPressable(feel: .tapSolid))
                    .disabled(isSaving || testimonyViewModel.isSubmitting)
                }

                Button {
                    saveAndCelebrate(testimony: nil, shareToWall: false)
                } label: {
                    Text("Skip")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.25))
                }
                .buttonStyle(.dsPressable(feel: .tapSolid))
                .disabled(isSaving || testimonyViewModel.isSubmitting)
            }
            .padding(.bottom, DS.Spacing.xxl)
        }
    }

    // MARK: - Celebration

    private var celebrationView: some View {
        VStack(spacing: 28) {
            Spacer()

            Text(sharedToWall ? "\u{1F64C}" : "\u{1F389}")
                .font(.system(size: 80))
                .dsAppear(0)

            VStack(spacing: DS.Spacing.sm) {
                Text("Your faith moved mountains.")
                    .font(DS.Typography.title)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("You believed for \(declaration.dayCount) day\(declaration.dayCount == 1 ? "" : "s")\nand God was faithful.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                if sharedToWall {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Your testimony is on the Prayer Wall.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .dsAppear(0.06)

            Spacer()

            VStack(spacing: 14) {
                Button {
                    onSetNew()
                } label: {
                    Text("Set a New Declaration \u{2192}")
                        .font(.system(size: 17, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(DS.Gradient.brand)
                        )
                        .foregroundColor(.white)
                        .padding(.horizontal, DS.Spacing.lg)
                }
                .buttonStyle(.dsPressable(feel: .tapSolid))

                Button {
                    appState.requestReviewIfEligible(trigger: .breakthroughCelebration)
                    onDismiss()
                } label: {
                    Text("Go to Home")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                }
                .buttonStyle(.dsPressable(feel: .tapSolid))
            }
            .padding(.bottom, DS.Spacing.xxl)
            .dsAppear(0.12)
        }
    }

    // MARK: - Save

    /// Marks the personal declaration as received locally, then hands off
    /// to the parent to present the Warrior Room composer. Skips the
    /// in-flow celebration screen — posting the testimony in the Warrior
    /// Room is the celebration.
    private func shareToWarriorRoom(via callback: @escaping (String) -> Void) {
        let prefill = warriorRoomPrefill
        isSaving = true
        Task {
            try? await markReceivedUseCase.execute(
                id: declaration.id,
                testimony: testimony.isEmpty ? nil : testimony
            )
            await MainActor.run {
                appState.hasPersonalDeclaration = false
                AnalyticsService.shared.track("personal_declaration_received", parameters: [
                    "days_believed": declaration.dayCount as NSNumber,
                    "shared_to_wall": true as NSNumber,
                ])
                isSaving = false
                callback(prefill)
                onDismiss()
            }
        }
    }

    private func saveAndCelebrate(testimony: String?, shareToWall: Bool) {
        isSaving = true
        Task {
            // Save locally
            try? await markReceivedUseCase.execute(id: declaration.id, testimony: testimony)

            // Post to Prayer Wall if user opted in
            if shareToWall, let text = testimony, !text.isEmpty {
                testimonyViewModel.addTestimony(user: "Anonymous", text: text)
            }

            await MainActor.run {
                appState.hasPersonalDeclaration = false
                AnalyticsService.shared.track("personal_declaration_received", parameters: [
                    "days_believed": declaration.dayCount as NSNumber,
                    "shared_to_wall": shareToWall as NSNumber
                ])
                sharedToWall = shareToWall && !(testimony?.isEmpty ?? true)
                isSaving = false
                withAnimation { step = .celebration }
            }
        }
    }
}
