//
//  CreateYourOwnButton.swift
//  SpeakLife
//
//  Button to open Create Your Own view from the Declaration screen
//

import SwiftUI
import FirebaseAnalytics

struct CreateYourOwnButton: View {
    @State private var showCreateYourOwn = false
    @State private var buttonScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
            // Track button tap
            Analytics.logEvent("create_your_own_tapped", parameters: [
                "source": "declaration_view",
                "location": "top_bar"
            ])
            
            showCreateYourOwn = true
        }) {
            ZStack {
                // Background circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(Constants.DAMidBlue).opacity(0.9),
                                Color(Constants.DAMidBlue)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                
                // Icon
                Image(systemName: "plus.bubble.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .scaleEffect(buttonScale)
        .onAppear {
            // Subtle pulse animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                buttonScale = 1.05
            }
        }
        .fullScreenCover(isPresented: $showCreateYourOwn) {
            NavigationView {
                CreateYourOwnView()
                    .navigationBarItems(
                        trailing: Button("Done") {
                            showCreateYourOwn = false
                        }
                    )
            }
        }
    }
}

// Compact version for smaller spaces
struct CompactCreateYourOwnButton: View {
    @State private var showCreateYourOwn = false
    
    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            
            Analytics.logEvent("create_your_own_tapped", parameters: [
                "source": "declaration_view",
                "variant": "compact"
            ])
            
            showCreateYourOwn = true
        }) {
            Image(systemName: "plus.bubble.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color(Constants.DAMidBlue))
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.9))
                )
        }
        .fullScreenCover(isPresented: $showCreateYourOwn) {
            NavigationView {
                CreateYourOwnView()
                    .navigationBarItems(
                        trailing: Button("Done") {
                            showCreateYourOwn = false
                        }
                    )
            }
        }
    }
}

#if DEBUG
struct CreateYourOwnButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            CreateYourOwnButton()
            CompactCreateYourOwnButton()
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }
}
#endif