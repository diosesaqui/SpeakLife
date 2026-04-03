//
//  CapsuleImageButton.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/2/22.
//

import SwiftUI


struct CapsuleImageButton: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var themeStore: ThemeViewModel
    
    let title: String

    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: title)
                .resizable()
                .scaledToFit()
                .frame(width: 25, height: 25)
        }
        .padding(Constants.padding)
        .frame(width: 50, height: 50)
        .background(themeStore.selectedTheme.mode == .dark ? Constants.backgroundColor : Constants.backgroundColorLight)
        .clipShape(Circle())
    }
}

struct CircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.7 : 1.0)
    }
}
