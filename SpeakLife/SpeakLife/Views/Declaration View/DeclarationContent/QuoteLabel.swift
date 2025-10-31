//
//  QuoteLabel.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/17/22.
//

import SwiftUI

struct QuoteLabel: View {
    
    @ObservedObject var themeViewModel: ThemeViewModel
    @AppStorage("useAnimatedText") private var useAnimatedText = true
    
    var quote: String
    let onAnimationComplete: (() -> Void)?
    
    init(themeViewModel: ThemeViewModel, quote: String, onAnimationComplete: (() -> Void)? = nil) {
        self.themeViewModel = themeViewModel
        self.quote = quote
        self.onAnimationComplete = onAnimationComplete
    }
    
    var body: some View {
        Group {
            if useAnimatedText {
                AnimatedDeclarationText(
                    text: quote.firstUppercased,
                    themeViewModel: themeViewModel,
                    onAnimationComplete: onAnimationComplete
                )
                .id(quote) // Force recreation when text changes
            } else {
                // Fallback to original static text
                Text(quote.firstUppercased)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .font(themeViewModel.selectedFont)
                    .minimumScaleFactor(0.4)
                    .padding()
                    .onAppear {
                        // Immediately mark as complete when not using animation
                        onAnimationComplete?()
                    }
            }
        }
    }
}

struct QuoteLabel_Previews: PreviewProvider {
    
    static var previews: some View {
        QuoteLabel(themeViewModel: ThemeViewModel(), quote: "I am thankful for all my future blessings!")
    }
}
