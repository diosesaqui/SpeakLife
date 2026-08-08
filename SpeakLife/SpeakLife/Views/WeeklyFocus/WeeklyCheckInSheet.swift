//
//  WeeklyCheckInSheet.swift
//  SpeakLife
//
//  The Sunday ask. Reuses PersonalDeclarationOnboardingView's flow verbatim —
//  mic → SpeechTranscriptionService → keyword match → result — presented as a
//  sheet with weekly copy. Voice-first, typing as fallback, skip always
//  available.
//
//  The payoff must be immediate. On submit, premium users go straight to the
//  seven days laid out with their own words at the top; if answering feels like
//  a form and the result feels generic, nobody answers twice.
//
//  Free users get the same ask, the same echo, and one matched verse — then the
//  paywall on "here's your week". Everything up to that point costs zero LLM
//  calls, so a free user who answers every Sunday and never converts costs
//  nothing but a local notification.
//

import SwiftUI

struct WeeklyCheckInSheet: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var declarationStore: DeclarationViewModel
    /// @StateObject rather than @ObservedObject even though it is injected —
    /// the wrapper's autoclosure is evaluated once, so a re-evaluation of the
    /// presenting cover's builder can't hand the sheet a fresh view model
    /// mid-answer. Same pattern as PersonalDeclarationOnboardingView.
    @StateObject var viewModel: WeeklyFocusViewModel

    /// push | card | interstitial — stamped onto every check-in event.
    let surface: String

    @Environment(\.dismiss) private var dismiss

    @State private var appeared = false
    @State private var micBreath = false
    @State private var skipDelayElapsed = false
    @State private var matchingRotation: Double = 0

    private var skipVisible: Bool {
        skipDelayElapsed || viewModel.errorMessage != nil
    }

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

            switch viewModel.step {
            case .input, .clarify: inputView
            case .matching: matchingView
            case .result:   resultView
            case .paywall:  paywallView
            case .week:     weekView
            }
        }
        .onAppear {
            viewModel.prepareForPresentation(surface: surface)
            // The week is built locally and idempotently — this is a read in
            // every case but the very first open of a new week.
            Task { await viewModel.load(isPremium: subscriptionStore.isPremium) }
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                micBreath = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(.easeIn(duration: 0.4)) { skipDelayElapsed = true }
            }
        }
    }

    // MARK: - Input

    private var inputView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 48)

            VStack(spacing: 12) {
                Text(viewModel.isEscalating ? "🕯️" : "🙏")
                    .font(.system(size: 40))

                Text(viewModel.question)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("Say it plain. This shapes your declarations,\nyour audio, and your week.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)

            Spacer()

            if viewModel.showTextInput {
                textInputBlock
            } else {
                micBlock
            }

            Spacer()

            Button("Not this week") {
                viewModel.skip()
                dismiss()
            }
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundColor(.white.opacity(0.5))
            .opacity(skipVisible ? 1 : 0)
            .allowsHitTesting(skipVisible)
            .animation(.easeIn(duration: 0.4), value: skipVisible)

            Spacer().frame(height: 32)
        }
    }

    private var micBlock: some View {
        VStack(spacing: 22) {
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
                        .fill(
                            viewModel.isRecording
                                ? LinearGradient(colors: [Color.red, Color(red: 0.9, green: 0.1, blue: 0.2)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color(red: 0.25, green: 0.55, blue: 1.0),
                                                          Color(red: 0.4, green: 0.3, blue: 1.0)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 88, height: 88)
                        .shadow(
                            color: (viewModel.isRecording ? Color.red : Color(red: 0.3, green: 0.5, blue: 1.0)).opacity(0.6),
                            radius: 24, x: 0, y: 8
                        )
                        .scaleEffect(micBreath ? 1.04 : 0.97)

                    Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(PlainButtonStyle())

            if viewModel.isRecording && !viewModel.inputText.isEmpty {
                Text(viewModel.inputText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 8) {
                Text(viewModel.isRecording ? "Listening... tap to stop" : "Tap to speak")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(viewModel.isRecording ? 0.9 : 0.6))

                if let error = viewModel.errorMessage, !viewModel.isRecording {
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                                viewModel.errorMessage = nil
                            }
                        }
                }

                if !viewModel.isRecording {
                    Button("Type instead") {
                        viewModel.showTextInput = true
                        viewModel.errorMessage = nil
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.35))
                }
            }
        }
    }

    private var textInputBlock: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                if viewModel.inputText.isEmpty {
                    Text("What's heaviest going into this week?")
                        .foregroundColor(.white.opacity(0.35))
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

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                viewModel.errorMessage = nil
                Task { await viewModel.submitTextInput() }
            } label: {
                Text("Set My Week")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.5, blue: 1.0),
                                         Color(red: 0.4, green: 0.3, blue: 1.0)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    )
                    .padding(.horizontal, 24)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Matching

    private var matchingView: some View {
        VStack(spacing: 26) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [Color(red: 0.3, green: 0.6, blue: 1.0),
                                     Color(red: 0.6, green: 0.3, blue: 1.0)],
                            startPoint: .leading, endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(matchingRotation))
                    .onAppear {
                        withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                            matchingRotation = 360
                        }
                    }

                Image(systemName: "hands.sparkles.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.85))
            }

            VStack(spacing: 8) {
                Text("Building your week...")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text("Matching God's word to what you carry")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Result (both tiers reach this)

    private var resultView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    Spacer().frame(height: 36)

                    Text("Here's what God says about that.")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Their own words, echoed back. The single cheapest thing
                    // that makes the answer feel heard.
                    Text("\u{201C}\(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D}")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)

                    if let match = viewModel.match {
                        VStack(spacing: 10) {
                            Text(match.verse)
                                .font(.system(size: 16, weight: .medium, design: .serif))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("— \(match.verseReference)")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .dsGlass(cornerRadius: DS.Radius.lg)
                        .padding(.horizontal, 24)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("SPEAK THIS TODAY")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.yellow.opacity(0.85))
                                .kerning(1.2)

                            Text(match.declarationText)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.yellow.opacity(0.12),
                                                 Color(red: 0.1, green: 0.1, blue: 0.3).opacity(0.6)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.yellow.opacity(0.35), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 24)
                    }
                }
            }

            Button {
                Task { await viewModel.continueToWeek(isPremium: subscriptionStore.isPremium) }
            } label: {
                Text(subscriptionStore.isPremium ? "Show Me My Week" : "See My Full Week")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [Color(red: 0.2, green: 0.5, blue: 1.0),
                                         Color(red: 0.4, green: 0.3, blue: 1.0)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                    )
                    .padding(.horizontal, 24)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(viewModel.isSubmitting)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
    }

    // MARK: - Paywall (free tier only)
    //
    // Presented at the highest-investment point of their week — they have just
    // said the thing out loud and seen one verse come back. The week itself is
    // what's behind the door.

    private var paywallView: some View {
        HighConversionPaywallView(
            callback: {
                if subscriptionStore.isPremium {
                    Task { await viewModel.paywallConverted() }
                } else {
                    dismiss()
                }
            },
            source: "feature_gate"
        )
        .environmentObject(appState)
        .environmentObject(declarationStore)
        .environmentObject(subscriptionStore)
    }

    // MARK: - Week (premium)

    @ViewBuilder
    private var weekView: some View {
        if let focus = viewModel.focus {
            WeekOverviewView(
                focus: focus,
                declarations: declarationStore.allAvailableDeclarations,
                isPartialWeek: viewModel.didRebuildPartialWeek,
                devotional: viewModel.devotional,
                onCompleteDay: { day in
                    Task { await viewModel.completeDay(day) }
                },
                onMarkResolved: {
                    Task { await viewModel.markResolved() }
                },
                onDone: { dismiss() }
            )
        } else {
            ProgressView().tint(.white)
        }
    }
}
