//
//  PersonalDeclarationOnboardingView.swift
//  SpeakLife
//

import SwiftUI
import FirebaseAnalytics

struct PersonalDeclarationOnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: PersonalDeclarationViewModel

    let size: CGSize
    let onComplete: (PersonalDeclaration?) -> Void  // nil = user skipped

    var body: some View {
        ZStack {
            // Background — matches existing onboarding screens
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.06, blue: 0.18),
                    Color(red: 0.08, green: 0.12, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch viewModel.step {
            case .input:    inputView
            case .matching: matchingView
            case .result:   resultView
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            Analytics.logEvent("personal_declaration_screen_shown", parameters: nil)
        }
    }

    // MARK: - Input View

    private var inputView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.12)

            VStack(spacing: 14) {
                Text("What's one thing you're\ntrusting God for?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("Speak it out. This becomes your daily declaration\nuntil it comes to pass.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            if viewModel.showTextInput {
                VStack(spacing: 16) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.1))

                        if viewModel.inputText.isEmpty {
                            Text("Type what you're believing for...")
                                .foregroundColor(.white.opacity(0.4))
                                .font(.system(size: 15))
                                .padding(14)
                        }

                        TextEditor(text: $viewModel.inputText)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .foregroundColor(.white)
                            .font(.system(size: 15))
                            .padding(10)
                    }
                    .frame(height: 110)
                    .padding(.horizontal, 24)

                    ShimmerButton(
                        colors: [Color(red: 0.2, green: 0.5, blue: 1.0), Color(red: 0.4, green: 0.3, blue: 1.0)],
                        buttonTitle: "Find My Declaration"
                    ) {
                        Task { await viewModel.submitTextInput() }
                    }
                    .frame(width: size.width * 0.87, height: 54)
                }
            } else {
                VStack(spacing: 20) {
                    // Pulsing mic button
                    Button {
                        Task {
                            if viewModel.isRecording {
                                await viewModel.stopRecording()
                            } else {
                                await viewModel.startRecording()
                            }
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(viewModel.isRecording
                                    ? Color.red.opacity(0.9)
                                    : Color(red: 0.2, green: 0.5, blue: 1.0))
                                .frame(width: 88, height: 88)

                            if viewModel.isRecording {
                                Circle()
                                    .stroke(Color.red.opacity(0.4), lineWidth: 12)
                                    .frame(width: 110, height: 110)
                                    .scaleEffect(1.1)
                                    .animation(
                                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                        value: viewModel.isRecording
                                    )
                            }

                            Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text(viewModel.isRecording ? "Tap to stop" : "Tap to speak")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))

                    Button("Type instead") {
                        viewModel.showTextInput = true
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
                    .padding(.top, 4)
                }
            }

            Spacer()

            Button("Skip for now") {
                Analytics.logEvent("personal_declaration_skipped", parameters: nil)
                onComplete(nil)
            }
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.white.opacity(0.3))
            .padding(.bottom, size.height * 0.06)
        }
    }

    // MARK: - Matching View (loading state)

    private var matchingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)

            Text("Finding your declaration...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Result View

    private var resultView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: size.height * 0.08)

                Text("Here's what God says about that.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer().frame(height: 24)

                if let match = viewModel.match {
                    // Verse block
                    VStack(spacing: 10) {
                        Text(match.verse)
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("— \(match.verseReference)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.08))
                    )
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 20)

                    // Declaration block
                    VStack(alignment: .leading, spacing: 10) {
                        Label("YOUR DECLARATION", systemImage: "hands.sparkles.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.yellow.opacity(0.85))

                        Text(match.declarationText)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 32)

                    // Primary CTA
                    ShimmerButton(
                        colors: [Color(red: 0.2, green: 0.5, blue: 1.0), Color(red: 0.4, green: 0.3, blue: 1.0)],
                        buttonTitle: "Speak This Every Day \u{2192}"
                    ) {
                        Task {
                            do {
                                let declaration = try await viewModel.saveAndContinue(
                                    startTimeIndex: appState.startTimeIndex
                                )
                                appState.hasPersonalDeclaration = true
                                UserPreferencesTracker.shared.personalDeclarationBelief = declaration.beliefText
                                Analytics.logEvent("personal_declaration_saved", parameters: [
                                    "category": declaration.categoryRaw as NSString
                                ])
                                onComplete(declaration)
                            } catch {
                                viewModel.errorMessage = "Something went wrong. Please try again."
                            }
                        }
                    }
                    .frame(width: size.width * 0.87, height: 54)

                    if let errorMsg = viewModel.errorMessage {
                        Text(errorMsg)
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.top, 8)
                    }

                    Spacer().frame(height: size.height * 0.08)
                }
            }
        }
    }
}
