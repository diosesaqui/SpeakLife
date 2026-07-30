//
//  PersonalDeclarationOnboardingView.swift
//  SpeakLife
//

import SwiftUI
import FirebaseAnalytics

// MARK: - Ambient Orb (background atmosphere)

private struct AmbientOrb: View {
    let color: Color
    let size: CGFloat
    let offset: CGSize
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color.opacity(0.18))
            .frame(width: size, height: size)
            .blur(radius: size * 0.45)
            .offset(offset)
            .scaleEffect(pulse ? 1.12 : 0.92)
            .animation(
                .easeInOut(duration: Double.random(in: 3.5...5.5))
                    .repeatForever(autoreverses: true),
                value: pulse
            )
            .onAppear { pulse = true }
    }
}

// MARK: - Pulse Ring

private struct PulseRing: View {
    let delay: Double
    @State private var expand = false

    var body: some View {
        Circle()
            .stroke(Color.white.opacity(expand ? 0 : 0.25), lineWidth: 1.5)
            .frame(width: expand ? 200 : 88, height: expand ? 200 : 88)
            .scaleEffect(expand ? 2.2 : 1.0)
            .opacity(expand ? 0 : 1)
            .animation(
                .easeOut(duration: 1.8).repeatForever(autoreverses: false).delay(delay),
                value: expand
            )
            .onAppear { expand = true }
    }
}

// MARK: - Main View

struct PersonalDeclarationOnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject var viewModel: PersonalDeclarationViewModel

    let size: CGSize
    let onComplete: (PersonalDeclaration?) -> Void

    @State private var titleAppeared = false
    @State private var micAppeared = false
    @State private var micBreath = false
    @State private var glowPulse = false

    var body: some View {
        ZStack {
            // ── Deep background ──────────────────────────────────────────
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.04, blue: 0.14),
                    Color(red: 0.06, green: 0.10, blue: 0.24)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // ── Ambient orbs ─────────────────────────────────────────────
            AmbientOrb(
                color: Color(red: 0.2, green: 0.4, blue: 1.0),
                size: 320,
                offset: CGSize(width: -80, height: -180)
            )
            AmbientOrb(
                color: Color(red: 0.5, green: 0.2, blue: 0.9),
                size: 260,
                offset: CGSize(width: 100, height: 160)
            )
            AmbientOrb(
                color: Color(red: 0.1, green: 0.6, blue: 0.8),
                size: 200,
                offset: CGSize(width: -60, height: 280)
            )

            // ── Step content ─────────────────────────────────────────────
            switch viewModel.step {
            case .input:                        inputView
            case .focusChoice(let categories):  focusChoiceView(categories: categories)
            case .clarify:                      clarifyView
            case .matching:                     matchingView
            case .result:                       resultView
            }
        }
        .frame(width: size.width, height: size.height)
        .onAppear {
            AnalyticsService.shared.track("personal_declaration_screen_shown")
            withAnimation(.easeOut(duration: 0.7)) { titleAppeared = true }
            withAnimation(.easeOut(duration: 0.7).delay(0.35)) { micAppeared = true }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                micBreath = true
            }
        }
    }

    // MARK: - Input View

    private var inputView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.11)

            // Title block
            VStack(spacing: 14) {
                Text("What's one thing you're\ntrusting God for?")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .opacity(titleAppeared ? 1 : 0)
                    .offset(y: titleAppeared ? 0 : 18)
                    .animation(.easeOut(duration: 0.6), value: titleAppeared)

                Text("Speak it out. This becomes your daily declaration\nuntil it comes to pass.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(titleAppeared ? 1 : 0)
                    .offset(y: titleAppeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.6).delay(0.12), value: titleAppeared)
            }

            Spacer()

            if viewModel.showTextInput {
                textInputBlock
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
            } else {
                micBlock
                    .opacity(micAppeared ? 1 : 0)
                    .scaleEffect(micAppeared ? 1 : 0.85)
                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.35), value: micAppeared)
            }

            Spacer()

            Spacer().frame(height: size.height * 0.06)
        }
    }

    // MARK: - Mic Block

    private var micBlock: some View {
        VStack(spacing: 24) {
            ZStack {
                // Ambient glow behind button
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (viewModel.isRecording ? Color.red : Color(red: 0.2, green: 0.5, blue: 1.0)).opacity(0.35),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(glowPulse ? 1.15 : 0.9)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: glowPulse)
                    .onAppear { glowPulse = true }

                // Pulse rings (recording only)
                if viewModel.isRecording {
                    PulseRing(delay: 0.0)
                    PulseRing(delay: 0.6)
                    PulseRing(delay: 1.2)
                }

                // Mic button
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
                                    : LinearGradient(colors: [Color(red: 0.25, green: 0.55, blue: 1.0), Color(red: 0.4, green: 0.3, blue: 1.0)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 88, height: 88)
                            .shadow(
                                color: (viewModel.isRecording ? Color.red : Color(red: 0.3, green: 0.5, blue: 1.0)).opacity(0.6),
                                radius: 24, x: 0, y: 8
                            )
                            .scaleEffect(micBreath ? 1.04 : 0.97)
                            .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: micBreath)

                        Image(systemName: viewModel.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white)
                            .scaleEffect(viewModel.isRecording ? 0.85 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: viewModel.isRecording)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Live transcription preview
            if viewModel.isRecording && !viewModel.inputText.isEmpty {
                Text(viewModel.inputText)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    )
                    .padding(.horizontal, 24)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeOut(duration: 0.25), value: viewModel.inputText)
            }

            VStack(spacing: 8) {
                Text(viewModel.isRecording ? "Listening... tap to stop" : "Tap to speak")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(viewModel.isRecording ? 0.9 : 0.6))
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isRecording)

                // Validation error
                if let error = viewModel.errorMessage, !viewModel.isRecording {
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.45))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .onAppear {
                            // Auto-clear after 4s so they can try again
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
                    .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Text Input Block

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
                    Text("Type what you're believing for...")
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
                    .transition(.opacity)
            }

            ShimmerButton(
                colors: [Color(red: 0.2, green: 0.5, blue: 1.0), Color(red: 0.4, green: 0.3, blue: 1.0)],
                buttonTitle: "Find My Declaration"
            ) {
                viewModel.errorMessage = nil
                Task { await viewModel.submitTextInput() }
            }
            .frame(width: size.width * 0.87, height: 54)
        }
    }

    // MARK: - Focus Choice View

    private func focusChoiceView(categories: [DeclarationCategory]) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.10)

            VStack(spacing: 12) {
                Text("🙏")
                    .font(.system(size: 40))

                Text("Let's put our faith into\none thing right now.")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("Which one is God putting on your heart most?")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer().frame(height: 36)

            VStack(spacing: 14) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        Task { await viewModel.selectFocus(category: category) }
                    } label: {
                        HStack(spacing: 14) {
                            Text(category.focusEmoji)
                                .font(.system(size: 22))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.focusTitle)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(category.focusSubtitle)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 24)
                }
            }

            Spacer().frame(height: 24)

            Button("Start over") {
                viewModel.inputText = ""
                viewModel.step = .input
            }
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.3))

            Spacer()
        }
    }

    // MARK: - Clarify View

    private var clarifyView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: size.height * 0.12)

            VStack(spacing: 12) {
                Text("🤔")
                    .font(.system(size: 40))

                Text("Can you tell us\na little more?")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("The more specific you are, the more personal your declaration will be.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer().frame(height: 32)

            // Editable text field pre-filled with what they already said
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )

                if viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("e.g. I'm anxious about losing my job and can't sleep...")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.3))
                        .padding(16)
                }

                TextEditor(text: $viewModel.inputText)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(12)
                    .frame(minHeight: 120, maxHeight: 160)
            }
            .frame(minHeight: 120)
            .padding(.horizontal, 24)

            Spacer().frame(height: 24)

            Button {
                Task { await viewModel.submitClarification() }
            } label: {
                Text("Generate My Declaration")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white)
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
            }
            .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)

            Spacer().frame(height: 16)

            Button("Start over") {
                viewModel.inputText = ""
                viewModel.step = .input
            }
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.3))

            Spacer()
        }
    }

    // MARK: - Matching View

    private var matchingView: some View {
        VStack(spacing: 28) {
            ZStack {
                // Spinning outer ring
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [Color(red: 0.3, green: 0.6, blue: 1.0), Color(red: 0.6, green: 0.3, blue: 1.0)],
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
                Text("Finding your declaration...")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text("Matching God's word to your faith")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Result View

    private var resultView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer().frame(height: size.height * 0.08)

                VStack(spacing: 6) {
                    Text("🙏")
                        .font(.system(size: 44))

                    Text("Here's what God says about that.")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer().frame(height: 28)

                if let match = viewModel.match {
                    // Low-confidence nudge — no keywords matched, defaulted to faith
                    if !match.isConfident {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.yellow.opacity(0.7))
                                .font(.system(size: 14))
                            Text("We gave you a general declaration. Tap below to be more specific.")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 12)

                        Button("Try Again — Be More Specific") {
                            withAnimation { viewModel.step = .input }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.4, green: 0.7, blue: 1.0))
                        .padding(.bottom, 20)
                    }

                    // Verse block
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
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 16)

                    // Declaration block
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "hands.sparkles.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.yellow)
                            Text("YOUR DECLARATION")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.yellow.opacity(0.85))
                                .kerning(1.2)
                        }

                        Text(match.declarationText)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(
                                LinearGradient(
                                    colors: [Color.yellow.opacity(0.12), Color(red: 0.1, green: 0.1, blue: 0.3).opacity(0.6)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.yellow.opacity(0.35), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 32)

                    ShimmerButton(
                        colors: [Color(red: 0.2, green: 0.5, blue: 1.0), Color(red: 0.4, green: 0.3, blue: 1.0)],
                        buttonTitle: "Speak This Every Day →"
                    ) {
                        Task {
                            do {
                                let declaration = try await viewModel.saveAndContinue(
                                    startTimeIndex: appState.startTimeIndex
                                )
                                appState.hasPersonalDeclaration = true
                                UserPreferencesTracker.shared.personalDeclarationBelief = declaration.beliefText
                                AnalyticsService.shared.track("personal_declaration_saved", parameters: [
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

    @State private var matchingRotation: Double = 0
}
