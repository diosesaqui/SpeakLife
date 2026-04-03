//
//  AnimatedDeclarationText.swift
//  SpeakLife
//
//  Apple Design Award-worthy animated text implementation
//

import SwiftUI

struct AnimatedDeclarationText: View {
    let text: String
    let themeViewModel: ThemeViewModel
    let onAnimationComplete: (() -> Void)?
    
    init(text: String, themeViewModel: ThemeViewModel, onAnimationComplete: (() -> Void)? = nil) {
        self.text = text
        self.themeViewModel = themeViewModel
        self.onAnimationComplete = onAnimationComplete
    }
    
    @State private var animatedText: AttributedString = AttributedString("")
    @State private var revealProgress: Double = 0.0
    @State private var isAnimating = false
    @State private var animationComplete = false
    @State private var timer: Timer?
    @State private var animationDebouncer: Timer?
    @State private var fullStyledText: AttributedString = AttributedString("")
    @State private var viewId = UUID() // Force view recreation on text change
    @State private var hasCalledCompletion = false // Prevent duplicate completions
    @State private var lastText = "" // Track last text to detect changes
    @State private var wasAnimatingBeforeDisappear = false // Track animation state before view disappears
    @State private var savedProgress: Double = 0.0 // Save progress when interrupted
    @Environment(\.scenePhase) private var scenePhase // Track app lifecycle
    
    // User settings
    @AppStorage("animationSpeed") private var animationSpeed = 0.5
    @AppStorage("autoStartAnimation") private var autoStartAnimation = true
    @AppStorage("highlightPowerWords") private var highlightPowerWords = true
    @AppStorage("showAnimationProgress") private var showAnimationProgress = true
    
    // Power words for highlighting
    private let powerWords = ["I", "am", "God", "Jesus", "blessed", "victorious", "loved", "chosen", "strong", "peace", "faith", "hope", "grace", "truth", "light", "kingdom", "eternal", "redeemed", "forgiven", "healed", "restored", "healing", "joy", "Christ"]
    
    var body: some View {
        VStack(spacing: 16) {
            // Main text display - legendary smooth animation
            Text(animatedText)
                .font(themeViewModel.selectedFont)
                .minimumScaleFactor(0.4)
                .foregroundColor(themeViewModel.selectedTheme.fontColor)
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .kerning(0.5) // Subtle letter spacing for elegance
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .scaleEffect(animationComplete ? 1.0 : 0.98)
                .opacity(animationComplete || isAnimating ? 1.0 : 0.8)
                .shadow(
                    color: .black.opacity(themeViewModel.selectedTheme.blurEffect ? 0.15 : 0.05),
                    radius: themeViewModel.selectedTheme.blurEffect ? 4 : 1,
                    x: 0,
                    y: 1
                )
                .animation(.easeOut(duration: 0.25), value: animationComplete)
        
        }
        .onAppear {
            // When view appears, check if animation was interrupted
            if wasAnimatingBeforeDisappear {
                // Animation was interrupted by tab switch - complete it instantly
                showCompleteText()
                wasAnimatingBeforeDisappear = false
            } else if lastText != text {
                lastText = text
                resetAndStartAnimation()
            } else if !animationComplete && !isAnimating {
                // Text hasn't changed but no animation completed, start fresh
                resetAndStartAnimation()
            }
        }
        .onChange(of: text) { newText in
            if lastText != newText {
                lastText = newText
                viewId = UUID() // Force view recreation
                resetAndStartAnimation()
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background, .inactive:
                // App going to background or becoming inactive - pause animation
                if isAnimating && !animationComplete {
                    timer?.invalidate()
                    timer = nil
                }
            case .active:
                // App becoming active - resume or complete animation
                if isAnimating && !animationComplete && timer == nil {
                    // Animation was interrupted, complete it instantly
                    showCompleteText()
                }
            @unknown default:
                break
            }
        }
        .id(viewId) // Force SwiftUI to recreate view when viewId changes
        .onDisappear {
            // When view disappears (tab switch), save state and clean up timer
            if isAnimating && !animationComplete {
                // Animation in progress - save state and pause timer
                wasAnimatingBeforeDisappear = true
                savedProgress = revealProgress
                timer?.invalidate()
                timer = nil
            } else {
                // Animation complete or not started - full cleanup
                wasAnimatingBeforeDisappear = false
                cleanupResources()
            }
        }
        .onTapGesture {
            handleTap()
        }
        .accessibilityLabel(text)
        .accessibilityHint(isAnimating ? "Tap to complete animation" : "Tap to restart animation")
    }
    
    // MARK: - Computed Properties
    
    private var words: [String] {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
    
    // MARK: - Animation Logic
    
    
    private func cleanupResources() {
        timer?.invalidate()
        timer = nil
        animationDebouncer?.invalidate()
        animationDebouncer = nil
    }
    
    private func resetAndStartAnimation() {
        // Kill all timers immediately
        timer?.invalidate()
        timer = nil
        animationDebouncer?.invalidate()
        animationDebouncer = nil
        
        // Clear all state immediately
        animatedText = AttributedString("")
        revealProgress = 0.0
        animationComplete = false
        isAnimating = false
        hasCalledCompletion = false
        fullStyledText = AttributedString("")
        wasAnimatingBeforeDisappear = false // Reset tab switch state
        savedProgress = 0.0
        
        // Force UI update before starting new animation
        DispatchQueue.main.async {
            // Start fresh after ensuring UI has updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.startFreshAnimation()
            }
        }
    }
    
    private func startFreshAnimation() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            animatedText = AttributedString("")
            return
        }
        
        // Create fresh styled text
        fullStyledText = createFullStyledText()
        
        // Reset state
        revealProgress = 0.0
        animationComplete = false
        isAnimating = true
        
        // Calculate timing
        let duration = max(1.0, Double(text.count) * 0.04 / animationSpeed)
        let stepSize = 1.0 / (duration * 60.0)
        
        // Set initial frame
        animatedText = createSmoothRevealText()
        
        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.updateRevealProgress(stepSize: stepSize)
            }
        }
    }
    
    
    
    
    
    
    private func updateRevealProgress(stepSize: Double) {
        guard isAnimating && !animationComplete else { return }
        
        revealProgress = min(1.0, revealProgress + stepSize)
        animatedText = createSmoothRevealText()
        
        if revealProgress >= 1.0 {
            completeAnimation()
        }
    }
    
    private func createFullStyledText() -> AttributedString {
        var result = AttributedString("")
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        for word in words {
            var wordString = AttributedString(word + " ")
            
            if highlightPowerWords && isPowerWord(word) {
                wordString.foregroundColor = Constants.gold
                wordString.font = themeViewModel.selectedFont.weight(.bold)
            } else {
                wordString.foregroundColor = themeViewModel.selectedTheme.fontColor
                wordString.font = themeViewModel.selectedFont
            }
            
            result.append(wordString)
        }
        
        return result
    }
    
    private func createSmoothRevealText() -> AttributedString {
        var result = AttributedString("")
        let totalLength = Double(text.count)
        let revealPoint = totalLength * revealProgress
        
        for (index, char) in text.enumerated() {
            var charString = AttributedString(String(char))
            let charPosition = Double(index)
            
            // Smooth gradient calculation - buttery smooth fade
            let opacity: Double
            let fadeWidth: Double = 8.0 // Smooth fade width
            
            if charPosition < revealPoint - fadeWidth {
                opacity = 1.0
            } else if charPosition <= revealPoint {
                let fadeProgress = (revealPoint - charPosition) / fadeWidth
                opacity = max(0.0, min(1.0, fadeProgress))
            } else {
                opacity = 0.0
            }
            
            // Find word for power word highlighting
            let word = findWordContaining(index: index)
            
            if highlightPowerWords && isPowerWord(word) {
                charString.foregroundColor = Constants.gold.opacity(opacity)
                charString.font = themeViewModel.selectedFont.weight(.bold)
            } else {
                charString.foregroundColor = themeViewModel.selectedTheme.fontColor.opacity(opacity)
                charString.font = themeViewModel.selectedFont
            }
            
            result.append(charString)
        }
        
        return result
    }
    
    private func findWordContaining(index: Int) -> String {
        guard index >= 0 && index < text.count else { return "" }
        
        let chars = Array(text)
        var start = index
        var end = index
        
        // Find word boundaries efficiently
        while start > 0 && !chars[start - 1].isWhitespace {
            start -= 1
        }
        while end < chars.count - 1 && !chars[end + 1].isWhitespace {
            end += 1
        }
        
        return String(chars[start...end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    
    
    private func completeAnimation() {
        guard !animationComplete else { return }
        
        timer?.invalidate()
        timer = nil
        
        // Delay completion callback to ensure text is fully visible first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.showCompleteText()
        }
    }
    
    private func showCompleteText() {
        guard !animationComplete else { return }
        
        // Show final complete text
        revealProgress = 1.0
        animatedText = fullStyledText
        
        // Mark animation as complete and notify callback ONCE
        animationComplete = true
        
        if !hasCalledCompletion {
            hasCalledCompletion = true
            onAnimationComplete?()
        }
        
        withAnimation(.easeOut(duration: 0.2)) {
            isAnimating = false
        }
    }
    
    private func handleTap() {
        if isAnimating && !animationComplete {
            // Complete animation immediately
            completeAnimation()
        } else if animationComplete {
            // Restart animation from beginning
            resetAndStartAnimation()
        }
    }
    
    // MARK: - Helper Functions
    
    private func isPowerWord(_ word: String) -> Bool {
        let cleanWord = word.lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return powerWords.contains { powerWord in
            powerWord.lowercased() == cleanWord
        }
    }
}

// MARK: - Preview

struct AnimatedDeclarationText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            // Short text
            AnimatedDeclarationText(
                text: "I am blessed by God.",
                themeViewModel: ThemeViewModel()
            )
            
            // Medium text
            AnimatedDeclarationText(
                text: "I am blessed and highly favored by God. His grace covers me completely.",
                themeViewModel: ThemeViewModel()
            )
            
            // Long text
            AnimatedDeclarationText(
                text: "I am blessed and highly favored by God. His grace covers me completely, and I walk in His perfect peace and strength today. Every step I take is guided by His wisdom and love.",
                themeViewModel: ThemeViewModel()
            )
        }
        .background(Color.black)
        .previewLayout(.sizeThatFits)
    }
}
