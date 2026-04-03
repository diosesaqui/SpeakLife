//
//  HideTabModifier.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 11/27/23.
//

import SwiftUI

struct HideTabBarModifier: ViewModifier {
    var hide: Bool

    func body(content: Content) -> some View {
        content
            .padding(.bottom, hide ? -120 : 0)
            .animation(.default, value: hide)// Adjust the value based on the actual size of your tab bar
    }
}

extension View {
    func hideTabBar(if condition: Bool) -> some View {
        self.modifier(HideTabBarModifier(hide: condition))
    }
}
