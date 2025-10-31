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
    @State private var currentCharacterIndex = 0
    @State private var isAnimating = false
    @State private var animationComplete = false
    @State private var timer: Timer?
    
    // User settings
    @AppStorage("animationSpeed") private var animationSpeed = 2.0
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
                .scaleEffect(animationComplete ? 1.0 : (isAnimating ? 1.0 : 0.96))
                .blur(radius: animationComplete ? 0 : (isAnimating ? 0 : 1.2))
                .shadow(
                    color: .black.opacity(themeViewModel.selectedTheme.blurEffect ? 0.25 : 0.1),
                    radius: themeViewModel.selectedTheme.blurEffect ? 6 : 2,
                    x: 0,
                    y: 2
                )
                .animation(.spring(response: 0.8, dampingFraction: 0.85, blendDuration: 0.4), value: isAnimating)
                .animation(.easeInOut(duration: 0.3), value: animationComplete)
        
        }
        .onAppear {
            // ALWAYS animate on appear - every swipe should animate
            resetAnimation()
            DispatchQueue.main.async {
                setupAnimation()
            }
        }
        .onChange(of: text) { _ in
            // ALWAYS animate when text changes
            resetAnimation()
            DispatchQueue.main.async {
                setupAnimation()
            }
        }
        .onTapGesture {
            handleTap()
        }
        .accessibilityLabel(text)
        .accessibilityHint(isAnimating ? "Tap to complete animation" : "Tap to restart animation")
    }
    
    // MARK: - Computed Properties
    
    private var characters: [Character] {
        Array(text)
    }
    
    private var words: [String] {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
    
    // MARK: - Animation Logic
    
    private func resetAnimation() {
        timer?.invalidate()
        timer = nil
        currentCharacterIndex = 0
        animationComplete = false
        isAnimating = false
        animatedText = AttributedString("")
    }
    
    private func setupAnimation() {
        guard !words.isEmpty else { return }
        
        // Always start animation for consistent behavior
        startAnimation()
    }
    
    private func startAnimation() {
        guard !isAnimating else { return }
        
        withAnimation(.easeIn(duration: 0.1)) {
            isAnimating = true
        }
        currentCharacterIndex = 0
        animationComplete = false
        
        // Handle very short text immediately
        if characters.count <= 10 {
            showCompleteText()
            return
        }
        
        // Clear current text
        animatedText = AttributedString("")
        
        // Start smooth, elegant reveal without jumps
        // Perfect pacing for beautiful fade effect
        let baseSpeed = 10.0 // Optimized for smooth fade perception
        let speedMultiplier = 1.0 + (animationSpeed - 2.0) * 0.15 // Subtle speed adjustment
        let charactersPerSecond = baseSpeed * speedMultiplier
        let interval = 1.0 / charactersPerSecond
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.revealNextCharacter()
        }
    }
    
    private func revealNextCharacter() {
        guard currentCharacterIndex < characters.count else {
            completeAnimation()
            return
        }
        
        // Always use full text to prevent layout jumps, control visibility through opacity
        let fullString = text
        
        // Apply smooth opacity-based reveal without layout changes
        withAnimation(.linear(duration: 0.06)) {
            animatedText = createStyledAttributedString(from: fullString, forceFullOpacity: false)
        }
        
        // Power word glow removed for cleaner animation
        
        currentCharacterIndex += 1
    }
    
    private func createStyledAttributedString(from text: String, forceFullOpacity: Bool = false) -> AttributedString {
        var result = AttributedString("")
        
        // Process each character with legendary smooth opacity animation
        for (index, char) in text.enumerated() {
            var charString = AttributedString(String(char))
            
            // Determine if this character is part of a power word
            let wordStart = findWordStart(in: text, at: index)
            let wordEnd = findWordEnd(in: text, at: index)
            let word = String(text[text.index(text.startIndex, offsetBy: wordStart)..<text.index(text.startIndex, offsetBy: wordEnd)])
            
            // Beautiful smooth gradient fade without harsh transitions
            let opacity: Double
            
            if forceFullOpacity {
                // Show all characters at full opacity when animation is complete
                opacity = 1.0
            } else {
                let distance = Double(index - currentCharacterIndex)
                
                if distance < -2 {
                    // Fully settled characters
                    opacity = 1.0
                } else if distance < 0 {
                    // Recently revealed - smooth settling animation
                    let settlingProgress = 1.0 + (distance / 2.0) // Maps -2 to 0 -> 0 to 1
                    opacity = 0.85 + (settlingProgress * 0.15) // 0.85 to 1.0
                } else if distance <= 4 {
                    // Upcoming characters - beautiful exponential fade
                    // Using cosine for ultra-smooth falloff
                    let progress = distance / 4.0 // 0 to 1
                    opacity = (1.0 - progress) * 0.6 * cos(progress * .pi / 2)
                } else {
                    // Future characters - invisible but maintaining layout
                    opacity = 0.0
                }
            }
            
            // Apply smooth color transitions without animation artifacts
            if highlightPowerWords && isPowerWord(word.trimmingCharacters(in: .whitespacesAndNewlines)) {
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
    
    private func findWordStart(in text: String, at index: Int) -> Int {
        let chars = Array(text)
        var start = index
        while start > 0 && !chars[start - 1].isWhitespace {
            start -= 1
        }
        return start
    }
    
    private func findWordEnd(in text: String, at index: Int) -> Int {
        let chars = Array(text)
        var end = index
        while end < chars.count - 1 && !chars[end + 1].isWhitespace {
            end += 1
        }
        return end + 1
    }
    
    
    private func completeAnimation() {
        timer?.invalidate()
        timer = nil
        
        // Show final bright, clear text
        showCompleteText()
    }
    
    private func showCompleteText() {
        // Create attributed string that preserves original text structure
        animatedText = createStyledAttributedString(from: text, forceFullOpacity: true)
        
        currentCharacterIndex = characters.count
        
        // Notify that animation is complete (only once)
        if !animationComplete {
            onAnimationComplete?()
        }
        
        withAnimation(.easeOut(duration: 0.2)) {
            isAnimating = false
            animationComplete = true
        }
    }
    
    private func handleTap() {
        if isAnimating {
            // Complete animation immediately
            timer?.invalidate()
            showCompleteText()
        } else {
            // Restart animation
            startAnimation()
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
