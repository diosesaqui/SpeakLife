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
    @AppStorage("animationSpeed") private var animationSpeed = 2.6
    @AppStorage("autoStartAnimation") private var autoStartAnimation = true
    @AppStorage("highlightPowerWords") private var highlightPowerWords = true
    @AppStorage("showAnimationProgress") private var showAnimationProgress = true
    
    // Power words for highlighting
    private let powerWords = ["I", "am", "God", "Jesus", "blessed", "victorious", "loved", "chosen", "strong", "peace", "faith", "hope", "grace", "truth", "light", "kingdom", "eternal", "redeemed", "forgiven", "healed", "restored", "healing", "joy"]
    
    var body: some View {
        VStack(spacing: 16) {
            // Main text display - clean and centered like Apple
            Text(animatedText)
                .font(themeViewModel.selectedFont)
                .foregroundColor(themeViewModel.selectedTheme.fontColor)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .shadow(
                    color: .black.opacity(themeViewModel.selectedTheme.blurEffect ? 0.3 : 0),
                    radius: themeViewModel.selectedTheme.blurEffect ? 4 : 0
                )
        
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
        
        isAnimating = true
        currentCharacterIndex = 0
        animationComplete = false
        
        // Handle very short text immediately
        if characters.count <= 10 {
            showCompleteText()
            return
        }
        
        // Clear current text
        animatedText = AttributedString("")
        
        // Start typewriter effect - character by character
        // Speed is characters per second, so faster for letters than words
        let charactersPerSecond = animationSpeed * 5 // 5x faster for letter animation
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / charactersPerSecond, repeats: true) { _ in
            self.revealNextCharacter()
        }
    }
    
    private func revealNextCharacter() {
        guard currentCharacterIndex < characters.count else {
            completeAnimation()
            return
        }
        
        let character = characters[currentCharacterIndex]
        
        // Build the revealed text up to current position
        let revealedString = String(characters[0...currentCharacterIndex])
        
        // Apply styling to the entire revealed text
        animatedText = createStyledAttributedString(from: revealedString)
        
        // Check if we just completed a power word for glow effect
        if character == " " || currentCharacterIndex == characters.count - 1 {
            checkForCompletedPowerWord(at: currentCharacterIndex)
        }
        
        currentCharacterIndex += 1
    }
    
    private func createStyledAttributedString(from text: String) -> AttributedString {
        var result = AttributedString("")
        let revealedCharCount = currentCharacterIndex + 1
        
        // Process each character with elite opacity animation
        for (index, char) in text.enumerated() {
            var charString = AttributedString(String(char))
            
            // Determine if this character is part of a power word
            let wordStart = findWordStart(in: text, at: index)
            let wordEnd = findWordEnd(in: text, at: index)
            let word = String(text[text.index(text.startIndex, offsetBy: wordStart)..<text.index(text.startIndex, offsetBy: wordEnd)])
            
            // Simple typewriter effect - all revealed characters at full opacity
            if index <= currentCharacterIndex {
                let opacity = 1.0  // All revealed characters get full opacity
                
                if highlightPowerWords && isPowerWord(word.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    withAnimation {
                        charString.foregroundColor = Constants.gold.opacity(opacity)
                        charString.font = themeViewModel.selectedFont.weight(.bold)
                    }
                } else {
                    withAnimation {
                        charString.foregroundColor = themeViewModel.selectedTheme.fontColor.opacity(opacity)
                        charString.font = themeViewModel.selectedFont
                    }
                }
            } else {
                // Not yet revealed - completely transparent
                charString.foregroundColor = Color.clear
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
        isAnimating = false
        animationComplete = true
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
                attributedWord.foregroundColor = themeViewModel.selectedTheme.fontColor
                attributedWord.font = themeViewModel.selectedFont
            }
            
            fullText.append(attributedWord)
        }
        
        withAnimation(.easeIn(duration: 0.3)) {
            animatedText = fullText
        }
        
        currentCharacterIndex = characters.count
        animationComplete = true
        isAnimating = false
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
