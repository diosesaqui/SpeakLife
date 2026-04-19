//
//  SettingsRow.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/16/22.
//

import SwiftUI

struct SettingsRow<Content: View>: View {
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var isPresentingContentView: Bool
    
    let imageTitle: String
    let title: String
    let viewToPresent: Content
    var url: String? = nil
    let action: () -> Void
    
    @ViewBuilder
    var body: some View {
        ZStack {
        HStack {
            Image(systemName: imageTitle)
                .foregroundColor(Constants.DAMidBlue)
                
            Text("\(title)", comment: "Manage subscription setting row title")
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(Constants.DAMidBlue)
        }
            Button(action: action) {
                
            }
            .fullScreenCover(isPresented: $isPresentingContentView) {
                self.isPresentingContentView = false
            } content: {
                viewToPresent
            }
            if url != nil {
            Link("", destination: URL(string: url!)!)
            }
        }.foregroundColor(colorScheme == .dark ? .white : .black)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                self.isPresentingContentView = false
            }
    }
}
