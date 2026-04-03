//
//  SaveConfirmationView.swift
//  SpeakLife
//
//  Beautiful confirmation animation when saving journal entries and affirmations
//

import SwiftUI

struct SaveConfirmationView: View {
    let contentType: ContentType
    let onComplete: () -> Void
    
    @State private var showCheckmark = false
    @State private var showMessage = false
    @State private var showParticles = false
    @State private var pulseScale: CGFloat = 0.8
    @State private var glowIntensity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Success animation
                ZStack {
                    // Glow background
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.green.opacity(glowIntensity * 0.4),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                    
                    // Main circle background
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle()
                                .stroke(Color.green, lineWidth: 3)
                        )
                        .scaleEffect(pulseScale)
                    
                    // Checkmark
                    if showCheckmark {
                        Image(systemName: "checkmark")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.green)
                            .scaleEffect(showCheckmark ? 1.0 : 0.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showCheckmark)
                    }
                    
                    // Success particles
                    if showParticles {
                        ForEach(0..<12, id: \.self) { index in
                            SuccessParticle(
                                angle: Double(index) * 30,
                                delay: Double(index) * 0.05
                            )
                        }
                    }
                }
                
                // Success message
                if showMessage {
                    VStack(spacing: 12) {
                        Text(getSuccessTitle())
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text(getSuccessMessage())
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .scaleEffect(showMessage ? 1.0 : 0.8)
                    .opacity(showMessage ? 1.0 : 0.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showMessage)
                }
            }
        }
        .onAppear {
            startSuccessAnimation()
        }
    }
    
    private func getSuccessTitle() -> String {
        switch contentType {
        case .affirmation:
            return "Affirmation Saved! ✨"
        case .journal:
            return "Journal Entry Saved! 📝"
        }
    }
    
    private func getSuccessMessage() -> String {
        switch contentType {
        case .affirmation:
            return "Your declaration of faith has been saved. Speak it, believe it, receive it!"
        case .journal:
            return "Your spiritual reflection has been saved. God sees your faithful heart."
        }
    }
    
    private func startSuccessAnimation() {
        // Pulse animation for background circle
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
            glowIntensity = 1.0
        }
        
        // Show checkmark after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showCheckmark = true
            }
            
            // Add haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
        
        // Show particles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showParticles = true
        }
        
        // Show message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showMessage = true
            }
        }
        
        // Auto-complete after showing the full animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            onComplete()
        }
    }
}

struct SuccessParticle: View {
    let angle: Double
    let delay: Double
    
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1.0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Image(systemName: ["star.fill", "sparkles", "heart.fill"].randomElement()!)
            .font(.system(size: CGFloat.random(in: 12...20)))
            .foregroundColor([Color.yellow, Color.green, Color.blue, Color.purple].randomElement()!)
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(
                x: cos(angle * .pi / 180) * offset,
                y: sin(angle * .pi / 180) * offset
            )
            .onAppear {
                withAnimation(
                    .easeOut(duration: 2.0)
                    .delay(delay)
                ) {
                    offset = 80
                    opacity = 0
                    scale = 0.5
                }
            }
    }
}

struct PrayerHandsAnimation: View {
    @State private var animate = false
    
    var body: some View {
        Image(systemName: "hands.sparkles.fill")
            .font(.system(size: 60))
            .foregroundColor(.yellow)
            .scaleEffect(animate ? 1.2 : 1.0)
            .opacity(animate ? 0.8 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
    }
}

struct SavedIndicatorBadge: View {
    let contentType: ContentType
    @State private var bounce = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Text("\(contentType.displayName.capitalized) Saved")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.green.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(Color.green.opacity(0.5), lineWidth: 1)
                )
        )
        .scaleEffect(bounce ? 1.1 : 1.0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                bounce = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    bounce = false
                }
            }
        }
    }
}

// MARK: - Keyboard Height Modifier
struct KeyboardHeightModifier: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    let onChange: (CGFloat) -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
                    let height = keyboardFrame.cgRectValue.height
                    withAnimation(.easeInOut(duration: 0.3)) {
                        keyboardHeight = height
                        onChange(height)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    keyboardHeight = 0
                    onChange(0)
                }
            }
    }
}

extension View {
    func onKeyboardHeightChange(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        self.modifier(KeyboardHeightModifier(onChange: onChange))
    }
}

#if DEBUG
struct SaveConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        SaveConfirmationView(contentType: .affirmation) {
            print("Save confirmation completed")
        }
        .previewDisplayName("Save Confirmation")
        
        SavedIndicatorBadge(contentType: .journal)
            .previewDisplayName("Saved Badge")
            .padding()
            .background(Color.black)
    }
}
#endif
