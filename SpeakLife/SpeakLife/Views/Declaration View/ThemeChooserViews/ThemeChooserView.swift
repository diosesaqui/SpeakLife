//
//  ThemeChooserView.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/7/22.
//

import SwiftUI

struct ThemeChooserView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var themesViewModel: ThemeViewModel
    @Environment(\.colorScheme) var colorScheme
    @State private var showingImagePicker = false
    @State private var isPresentingPremiumView = false
    @State private var selectedFont: UIFont?
    @State private var showFontPicker = false

    var twoColumnGrid = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .center, spacing: 20) {

                        Text("Pick from a selection of fonts and backgrounds to personalize your theme.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text("Select Font")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)

                        fontChooser(size: geometry.size)

                        selectCustomImageView
                            .padding(.horizontal)

                        Text("Choose Background Image 👇")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal)

                        LazyVGrid(columns: twoColumnGrid, spacing: 16) {
                            ForEach(themesViewModel.themes) { theme in
                                themeCell(imageString: theme.backgroundImageString, size: geometry.size, isPremium: theme.isPremium)
                                    .onTapGesture {
                                        if theme.isPremium && !subscriptionStore.isPremium {
                                            isPresentingPremiumView = true
                                        } else {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                themesViewModel.choose(theme)
                                                self.presentationMode.wrappedValue.dismiss()
                                            }
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom)
                }
                .sheet(isPresented: $showFontPicker) {
                    FontPickerView(themesViewModel: themesViewModel, selectedFont: $selectedFont, isPresented: $showFontPicker)
                }
                .sheet(isPresented: $showingImagePicker) {
                    ImagePicker(selectedImage: $themesViewModel.selectedImage)
                }
                .sheet(isPresented: $isPresentingPremiumView) {
                    PremiumView()
                }
                .background(
                    Image(subscriptionStore.onboardingBGImage)
                        .resizable()
                        .scaledToFill()
                        .overlay(Color.black.opacity(0.5))
                        .ignoresSafeArea()
                )
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    self.isPresentingPremiumView = false
                    self.showingImagePicker = false
                }
                .onAppear {
                    DispatchQueue.global(qos: .userInitiated).async {
                        themesViewModel.load()
                    }
                    UINavigationBar.appearance().largeTitleTextAttributes = [.foregroundColor: UIColor(Constants.DAMidBlue)]
                }
                .onDisappear {
                    DispatchQueue.global(qos: .userInitiated).async {
                        themesViewModel.save()
                    }
                }
            }
        }
    }

    private var selectCustomImageView: some View {
        Button {
            if !subscriptionStore.isPremium {
                presentPremiumView()
                Selection.shared.selectionFeedback()
            } else {
                showingImagePicker = true
            }
        } label: {
            Label("Select Custom Image", systemImage: "photo.fill")
                .fontWeight(.semibold)
                .foregroundColor(.blue)
        }
    }

    private func presentPremiumView() {
        self.isPresentingPremiumView = true
    }

    @ViewBuilder
    private func fontChooser(size: CGSize) -> some View {
        Text(themesViewModel.fontString)
            .font(.body)
            .foregroundColor(.blue)
            .onTapGesture {
                withAnimation {
                    self.showFontPicker = true
                }
            }
    }

    @ViewBuilder
    private func themeCell(imageString: String, size: CGSize, isPremium: Bool) -> some View {
        let dimension = size.width * 0.45

        ZStack(alignment: .topTrailing) {
            VStack {
                Image(imageString)
                    .resizable()
                    .scaledToFill()
                    .frame(width: dimension, height: dimension * 1.1)
                    .clipped()
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 6)
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.1), Color.clear, Color.white.opacity(0.1)]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .rotationEffect(Angle(degrees: -30))
                        .offset(x: -dimension)
                        .blendMode(.overlay)
                    )
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)

            if isPremium && !subscriptionStore.isPremium {
                Image(systemName: "lock.fill")
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
                    .foregroundColor(.white)
                    .shadow(radius: 4)
                    .offset(x: -10, y: 10)
            }
        }
    }
}