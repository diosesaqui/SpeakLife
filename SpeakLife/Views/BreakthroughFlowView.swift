//
//  BreakthroughFlowView.swift
//  SpeakLife
//

import SwiftUI
import FirebaseAnalytics
import MessageUI

struct BreakthroughFlowView: View {
    @EnvironmentObject var appState: AppState

    let declaration: PersonalDeclaration
    let onDismiss: () -> Void
    let onSetNew: () -> Void

    @State private var step: BreakthroughStep = .confirm
    @State private var testimony: String = ""
    @State private var isSaving = false
    @State private var sharedByEmail = false
    @State private var showMailView = false
    @State private var mailResult: Result<MFMailComposeResult, Error>? = nil

    private let markReceivedUseCase = DIContainer.shared.makeMarkReceivedUseCase()

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

            VStack(spacing: 12) {
                Text("You're saying God came through?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("Day \(declaration.dayCount) of believing.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
            }

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
                                .fill(Color.green.opacity(0.85))
                        )
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    onDismiss()
                } label: {
                    Text("Not yet — keep believing")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Testimony

    private var testimonyView: some View {
        VStack(spacing: 24) {
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
            .padding(.horizontal, 24)

            // Character count
            if !testimony.isEmpty {
                Text("\(testimony.count)/500")
                    .font(.system(size: 12))
                    .foregroundColor(testimony.count > 500 ? .red : .white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 28)
            }

            Spacer()

            VStack(spacing: 14) {
                // Primary CTA — email testimony to team
                Button {
                    guard !testimony.isEmpty else {
                        saveAndCelebrate(testimony: nil)
                        return
                    }
                    saveAndCelebrate(testimony: testimony)
                    if MFMailComposeViewController.canSendMail() {
                        showMailView = true
                    }
                } label: {
                    Group {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text(testimony.isEmpty ? "Continue" : "Send Us Your Testimony 🙏")
                                .font(.system(size: 17, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(testimony.isEmpty ? Color.white.opacity(0.15) : Color.green.opacity(0.85))
                    )
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isSaving || testimony.count > 500)

                if !testimony.isEmpty {
                    Button {
                        saveAndCelebrate(testimony: testimony)
                    } label: {
                        Text("Keep Private")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .disabled(isSaving)
                }

                Button {
                    saveAndCelebrate(testimony: nil)
                } label: {
                    Text("Skip")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.25))
                }
                .disabled(isSaving)
            }
            .padding(.bottom, 48)
            .sheet(isPresented: $showMailView) {
                MailView(
                    isShowing: $showMailView,
                    result: $mailResult,
                    origin: .testimony,
                    prefillBody: testimony,
                    isSubscribed: false
                )
                .onDisappear {
                    if case .success(_) = mailResult {
                        sharedByEmail = true
                    }
                }
            }
        }
    }

    // MARK: - Celebration

    private var celebrationView: some View {
        VStack(spacing: 28) {
            Spacer()

            Text(sharedByEmail ? "\u{1F64C}" : "\u{1F389}")
                .font(.system(size: 80))

            VStack(spacing: 12) {
                Text("Your faith moved mountains.")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("You believed for \(declaration.dayCount) day\(declaration.dayCount == 1 ? "" : "s")\nand God was faithful.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                if sharedByEmail {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Your testimony is on its way to us. Thank you.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 32)

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
                                .fill(Color(red: 0.2, green: 0.5, blue: 1.0))
                        )
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    onDismiss()
                } label: {
                    Text("Go to Home")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Save

    private func saveAndCelebrate(testimony: String?) {
        isSaving = true
        Task {
            try? await markReceivedUseCase.execute(id: declaration.id, testimony: testimony)
            await MainActor.run {
                appState.hasPersonalDeclaration = false
                Analytics.logEvent("personal_declaration_received", parameters: [
                    "days_believed": declaration.dayCount as NSNumber,
                    "has_testimony": (testimony != nil) as NSNumber
                ])
                isSaving = false
                withAnimation { step = .celebration }
            }
        }
    }
}
