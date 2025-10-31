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
    private let powerWords = ["I", "am", "God", "Jesus", "blessed", "victorious", "loved", "chosen", "strong", "peace", "faith", "hope", "grace", "truth", "light", "kingdom", "eternal", "redeemed", "forgiven", "healed", "restored", "healing", "joy"]
    
    var body: some View {
        VStack(spacing: 16) {
            // Main text display - legendary smooth animation
            Text(animatedText)
                .font(themeViewModel.selectedFont)
                .foregroundColor(themeViewModel.selectedTheme.fontColor)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .scaleEffect(animationComplete ? 1.0 : (isAnimating ? 1.0 : 0.98))
                .blur(radius: (isAnimating || animationComplete) ? 0 : 0.5)
                .shadow(
                    color: .black.opacity(themeViewModel.selectedTheme.blurEffect ? 0.3 : 0),
                    radius: themeViewModel.selectedTheme.blurEffect ? 4 : 0
                )
                .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.3), value: isAnimating)
        
        }
        .onAppear {
            setupAnimation()
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
    
    private func setupAnimation() {
        guard !words.isEmpty else { return }
        
        if autoStartAnimation {
            startAnimation()
        } else {
            showCompleteText()
        }
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
        
        // Start legendary typewriter effect with buttery smooth timing
        // Optimized speed for perfect reading rhythm
        let charactersPerSecond = animationSpeed * 6 // Optimized for smooth flow
        let interval = 1.0 / charactersPerSecond
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            // Ensure UI updates happen on main thread for 60fps smoothness
            DispatchQueue.main.async {
                self.revealNextCharacter()
            }
        }
    }
    
    private func revealNextCharacter() {
        guard currentCharacterIndex < characters.count else {
            completeAnimation()
            return
        }
        
        let character = characters[currentCharacterIndex]
        
        // Build the revealed text with smooth transitions - always show full text
        let fullString = text
        
        // Apply legendary smooth styling with anticipation
        withAnimation(.easeOut(duration: 0.15).delay(0.02)) {
            animatedText = createStyledAttributedString(from: fullString)
        }
        
        // Check if we just completed a power word for glow effect
        if character == " " || currentCharacterIndex == characters.count - 1 {
            checkForCompletedPowerWord(at: currentCharacterIndex)
        }
        
        currentCharacterIndex += 1
    }
    
    private func createStyledAttributedString(from text: String) -> AttributedString {
        var result = AttributedString("")
        
        // Process each character with legendary smooth opacity animation
        for (index, char) in text.enumerated() {
            var charString = AttributedString(String(char))
            
            // Determine if this character is part of a power word
            let wordStart = findWordStart(in: text, at: index)
            let wordEnd = findWordEnd(in: text, at: index)
            let word = String(text[text.index(text.startIndex, offsetBy: wordStart)..<text.index(text.startIndex, offsetBy: wordEnd)])
            
            // Legendary smooth opacity transitions with easing curves
            let opacity: Double
            let distance = index - currentCharacterIndex
            
            if distance <= 0 {
                // Fully revealed characters - sharp and clear
                opacity = 1.0
            } else if distance == 1 {
                // Next character - subtle anticipation with breathing effect
                let breathingEffect = sin(Date().timeIntervalSince1970 * 3) * 0.05 + 0.15
                opacity = max(0.1, breathingEffect)
            } else if distance == 2 {
                // Second next character - barely visible hint
                opacity = 0.08
            } else if distance == 3 {
                // Third character - ghost hint
                opacity = 0.03
            } else {
                // Future characters - invisible
                opacity = 0.0
            }
            
            // Apply smooth color transitions with easing
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
    
    private func checkForCompletedPowerWord(at index: Int) {
        // Find the word that was just completed
        let revealedText = String(characters[0...index])
        let words = revealedText.components(separatedBy: .whitespacesAndNewlines)
        
        if let lastWord = words.last?.trimmingCharacters(in: .whitespacesAndNewlines),
           !lastWord.isEmpty,
           highlightPowerWords && isPowerWord(lastWord) {
            
            // Add subtle glow effect for power words
            addGlowEffect(to: lastWord)
        }
    }
    
    private func addGlowEffect(to word: String) {
        // Temporary glow effect for power words
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Find the word in the attributed string and add temporary styling
            if let range = animatedText.range(of: word) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    animatedText[range].backgroundColor = Constants.gold.opacity(0.2)
                }
                
                // Remove glow after a moment
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.4)) {
                        if let range = animatedText.range(of: word) {
                            animatedText[range].backgroundColor = nil
                        }
                    }
                }
            }
        }
    }
    
    private func completeAnimation() {
        timer?.invalidate()
        timer = nil
        
        // Show final bright, clear text
        showCompleteText()
    }
    
    private func showCompleteText() {
        var fullText = AttributedString("")
        
        for (index, word) in words.enumerated() {
            if index > 0 {
                fullText.append(AttributedString(" "))
            }
            
            var attributedWord = AttributedString(word)
            
            if highlightPowerWords && isPowerWord(word) {
                attributedWord.foregroundColor = Constants.gold
                attributedWord.font = themeViewModel.selectedFont.weight(.bold)
            } else {
                // Ensure full brightness after completion
                attributedWord.foregroundColor = themeViewModel.selectedTheme.fontColor
                attributedWord.font = themeViewModel.selectedFont
            }
            
            fullText.append(attributedWord)
        }
        
        withAnimation(.easeOut(duration: 0.2)) {
            animatedText = fullText
            isAnimating = false
            animationComplete = true
        }
        
        currentCharacterIndex = characters.count
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
