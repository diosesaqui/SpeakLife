//
//  MenuButtonView.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 7/23/24.
//

import SwiftUI

struct FirstView: View {
    var body: some View {
        Text("First View")
            .font(.largeTitle)
            .navigationTitle("First")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct SecondView: View {
    var body: some View {
        Text("Second View")
            .font(.largeTitle)
            .navigationTitle("Second")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct ThirdView: View {
    var body: some View {
        Text("Third View")
            .font(.largeTitle)
            .navigationTitle("Third")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct MenuButton: View {
    @EnvironmentObject var devotionalViewModel: DevotionalViewModel
    @EnvironmentObject var viewModel: DeclarationViewModel
    @EnvironmentObject var themeViewModel: ThemeViewModel
    @Binding var showMenu: Bool

    var body: some View {
        VStack {
            
            Button(action: {
                withAnimation {
                    showMenu.toggle()
                }
            }) {
                Image(systemName: showMenu ? "xmark.circle.fill" : "plus.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.blue)
            }
            
            if showMenu {
                NavigationLink(destination:  CategoryChooserView(viewModel: viewModel)) {
                    Text("Categories")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                NavigationLink(destination:  ThemeChooserView(themesViewModel: themeViewModel)) {
                    Text("Themes")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                NavigationLink(destination: DevotionalView(viewModel: devotionalViewModel)) {
                    Text("Devotionals")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                NavigationLink(destination: ThirdView()) {
                    Text("Prayers")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
    }
}
