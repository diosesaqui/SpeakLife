//
//  HowToUseSpeakLifeView.swift
//  SpeakLife
//
//  Reuses the real onboarding screens as a standalone
//  "How to Use SpeakLife" guide accessible from Settings.
//
//  Flow: LiveDeclarationPreview → AudioFeature → DailyDevotionalFeature → CreateYourOwn → WarriorRoom
//

import SwiftUI

struct HowToUseSpeakLifeView: View {
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: DeclarationViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var currentPage = 0

    private let totalPages = 5

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {

                // Page content
                Group {
                    switch currentPage {
                    case 0:
                        LiveDeclarationPreviewScreen(size: geometry.size) {
                            advance()
                        }
                        .environmentObject(subscriptionStore)

                    case 1:
                        AudioFeatureScreen(size: geometry.size) {
                            advance()
                        }
                        .environmentObject(subscriptionStore)

                    case 2:
                        DailyDevotionalFeatureScreen(size: geometry.size) {
                            advance()
                        }
                        .environmentObject(subscriptionStore)

                    case 3:
                        CreateYourOwnTutorial(size: geometry.size, action: {
                            advance()
                        })
                        .environmentObject(subscriptionStore)

                    case 4:
                        WarriorRoomFeatureScreen(size: geometry.size) {
                            dismiss()
                        }
                        .environmentObject(subscriptionStore)

                    default:
                        EmptyView()
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .animation(.easeInOut(duration: 0.35), value: currentPage)

                // Top bar — close button + page dots
                HStack {
                    Button(action: dismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.4), radius: 4)
                    }
                    .padding(.leading, 20)

                    Spacer()

                    // Page indicator dots
                    HStack(spacing: 7) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.white : Color.white.opacity(0.35))
                                .frame(width: index == currentPage ? 8 : 6,
                                       height: index == currentPage ? 8 : 6)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }

                    Spacer()

                    // Balance spacer
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .opacity(0)
                        .padding(.trailing, 20)
                }
                .padding(.top, geometry.safeAreaInsets.top + 8)
            }
            .ignoresSafeArea()
        }
    }

    private func advance() {
        if currentPage < totalPages - 1 {
            withAnimation { currentPage += 1 }
        } else {
            dismiss()
        }
    }

    private func dismiss() {
        presentationMode.wrappedValue.dismiss()
    }
}
