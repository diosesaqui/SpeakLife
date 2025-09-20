//
//  QuoteLabel.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/17/22.
//

import SwiftUI

struct QuoteLabel: View {
    
    @ObservedObject var themeViewModel: ThemeViewModel
    
    var quote: String
    
    var body: some View {
        Text(quote.firstUppercased)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .font(themeViewModel.selectedFont)
            .minimumScaleFactor(0.4)
            .padding()
    }
}

struct QuoteLabel_Previews: PreviewProvider {
    
    static var previews: some View {
        QuoteLabel(themeViewModel: ThemeViewModel(), quote: "I am thankful for all my future blessings!")

    }
}
