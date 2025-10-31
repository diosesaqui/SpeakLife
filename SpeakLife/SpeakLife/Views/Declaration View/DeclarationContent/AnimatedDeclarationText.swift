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
            Task { @MainActor in
                await forceResetAnimation()
            }
        }
        .onChange(of: text) { newText in
            // NUCLEAR immediate cleanup before async task
            cleanupResources()
            animatedText = AttributedString("")
            revealProgress = 0.0  // ⚡ FORCE progress reset immediately
            isAnimating = false
            animationComplete = false
            
            Task { @MainActor in
                await forceResetAnimation()
            }
        }
        .onDisappear {
            cleanupResources()
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
    
    @MainActor
    private func forceResetAnimation() async {
        // Step 1: Kill everything and wait
        timer?.invalidate()
        timer = nil
        animationDebouncer?.invalidate()
        animationDebouncer = nil
        
        // PARANOID: Clear all visual state multiple times
        animatedText = AttributedString("")
        revealProgress = 0.0
        animationComplete = false
        isAnimating = false
        fullStyledText = AttributedString("")
        
        // Wait for next runloop cycle
        await Task.yield()
        
        // Step 2: Double-check cleanup and FORCE ZERO PROGRESS
        timer?.invalidate()
        timer = nil
        animationDebouncer?.invalidate()
        animationDebouncer = nil
        
        // TRIPLE check progress is zero
        revealProgress = 0.0
        animatedText = AttributedString("")
        
        // Step 3: Validate and start fresh
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            animatedText = AttributedString("")
            return
        }
        
        // Create fresh text immediately
        fullStyledText = createFullStyledText()
        
        // Start with completely clean state - QUADRUPLE CHECK
        revealProgress = 0.0
        animationComplete = false
        isAnimating = true
        
        // ENSURE we start with blank text
        animatedText = AttributedString("")
        
        // Calculate timing
        let duration = max(1.0, Double(text.count) * 0.04 / animationSpeed)
        let stepSize = 1.0 / (duration * 60.0)
        
        // Set initial frame with GUARANTEED zero progress
        animatedText = createSmoothRevealText()
        
        // Start timer with fresh state
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateRevealProgress(stepSize: stepSize)
            }
        }
    }
    
    private func resetAndStartAnimation() {
        // NUCLEAR OPTION - kill everything multiple times
        timer?.invalidate()
        timer = nil
        animationDebouncer?.invalidate() 
        animationDebouncer = nil
        
        // Wait a frame to ensure timers are truly dead
        DispatchQueue.main.async {
            // Kill timers again (paranoid)
            self.timer?.invalidate()
            self.timer = nil
            self.animationDebouncer?.invalidate()
            self.animationDebouncer = nil
            
            // FORCE complete state wipe
            self.animatedText = AttributedString("")
            self.revealProgress = 0.0
            self.animationComplete = false
            self.isAnimating = false
            self.fullStyledText = AttributedString("")
            
            // Wait another frame before starting
            DispatchQueue.main.async {
                self.nuclearStartAnimation()
            }
        }
    }
    
    private func nuclearStartAnimation() {
        // PARANOID: Final timer check and kill
        timer?.invalidate()
        timer = nil
        animationDebouncer?.invalidate()
        animationDebouncer = nil
        
        // Validate text exists
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            animatedText = AttributedString("")
            return
        }
        
        // NUCLEAR state reset with delays between each step
        revealProgress = 0.0
        animationComplete = false
        isAnimating = false
        animatedText = AttributedString("")
        
        // Create fresh styled text
        fullStyledText = createFullStyledText()
        
        // Small delay to ensure clean slate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { // One frame delay
            self.actuallyStartAnimation()
        }
    }
    
    private func actuallyStartAnimation() {
        // Final paranoid check
        timer?.invalidate()
        timer = nil
        
        // Set state
        isAnimating = true
        revealProgress = 0.0
        animationComplete = false
        
        // Calculate timing
        let duration = max(1.0, Double(text.count) * 0.04 / animationSpeed)
        let stepSize = 1.0 / (duration * 60.0)
        
        // Set initial frame at 0% progress
        animatedText = createSmoothRevealText()
        
        // Start timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.updateRevealProgress(stepSize: stepSize)
            }
        }
    }
    
    private func forceStartAnimation() {
        // Redirect to nuclear approach
        nuclearStartAnimation()
    }
    
    private func setupAnimation() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            // Handle empty or whitespace-only text
            animatedText = AttributedString("")
            return 
        }
        guard !words.isEmpty else { return }
        
        // Always start animation for consistent behavior
        forceStartAnimation()
    }
    
    
    @MainActor
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
        
        showCompleteText()
    }
    
    private func showCompleteText() {
        guard !animationComplete else { return }
        
        // Show final complete text
        revealProgress = 1.0
        animatedText = fullStyledText
        
        // Mark animation as complete and notify callback
        animationComplete = true
        onAnimationComplete?()
        
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
