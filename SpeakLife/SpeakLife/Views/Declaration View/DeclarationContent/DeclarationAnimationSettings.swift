//
//  DeclarationAnimationSettings.swift
//  SpeakLife
//
//  Animation settings for declaration text presentation
//

import SwiftUI

struct DeclarationAnimationSettings: View {
    @AppStorage("useAnimatedText") private var useAnimatedText = true
    @AppStorage("animationSpeed") private var animationSpeed = 8.0
    @AppStorage("autoStartAnimation") private var autoStartAnimation = true
    @AppStorage("highlightPowerWords") private var highlightPowerWords = true
    @AppStorage("showAnimationProgress") private var showAnimationProgress = true
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Animation Settings") {
                    Toggle("Enable Animated Text", isOn: $useAnimatedText)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                    
                    if useAnimatedText {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Typewriter Speed")
                                Spacer()
                                Text("\(animationSpeed, specifier: "%.1f")x")
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Image(systemName: "tortoise.fill")
                                    .foregroundColor(.gray)
                                
                                Slider(value: $animationSpeed, in: 2.0...15.0, step: 1.0)
                                
                                Image(systemName: "hare.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        Toggle("Auto-start Animation", isOn: $autoStartAnimation)
                        Toggle("Highlight Power Words", isOn: $highlightPowerWords)
                        Toggle("Show Progress Bar", isOn: $showAnimationProgress)
                    }
                }
                
                Section("How It Works") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("⌨️ **Typewriter effect** reveals text letter by letter")
                        Text("✨ **Power words** like 'blessed' and 'God' get golden highlights")
                        Text("👆 **Tap the text** to complete instantly or restart")
                        Text("⚡ **Adjust speed** from 2x (slow) to 15x (fast)")
                    }
                    .font(.caption)
                    .foregroundColor(.black)
                }
                
                if useAnimatedText {
                    Section("Preview") {
                        DeclarationAnimationPreview()
                            .frame(height: 120)
                            .background(Color.black.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
            }
            .navigationTitle("Text Animation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Preview component for testing animation settings
struct DeclarationAnimationPreview: View {
    @AppStorage("animationSpeed") private var animationSpeed = 6.0
    @AppStorage("highlightPowerWords") private var highlightPowerWords = true
    
    @State private var isAnimating = false
    
    private let sampleText = "I am blessed by God's grace."
    
    var body: some View {
        VStack {
            if isAnimating {
                AnimatedDeclarationText(
                    text: sampleText,
                    themeViewModel: ThemeViewModel()
                )
                .scaleEffect(0.8)
            } else {
                Text(sampleText)
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .opacity(0.6)
            }
            
            Button(isAnimating ? "Reset" : "Preview") {
                isAnimating.toggle()
                if !isAnimating {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isAnimating = true
                    }
                }
            }
            .font(.caption)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .padding()
    }
}

// Quick toggle for declaration view
struct AnimationToggleButton: View {
    @AppStorage("useAnimatedText") private var useAnimatedText = true
    @State private var showSettings = false
    
    var body: some View {
        Button(action: {
            showSettings = true
        }) {
            Image(systemName: useAnimatedText ? "textformat.size" : "textformat")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .padding(8)
                .background(Color.black.opacity(0.3))
                .clipShape(Circle())
        }
        .sheet(isPresented: $showSettings) {
            DeclarationAnimationSettings()
        }
    }
}

struct DeclarationAnimationSettings_Previews: PreviewProvider {
    static var previews: some View {
        DeclarationAnimationSettings()
    }
}
