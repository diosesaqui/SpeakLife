//
//  TaskCompletionAnimation.swift
//  SpeakLife
//
//  Subtle, immediate feedback animation for individual task completion
//

import SwiftUI

struct TaskCompletionAnimation: View {
    @State private var checkScale: CGFloat = 0
    @State private var checkOpacity: Double = 0
    @State private var rippleScale: CGFloat = 0
    @State private var rippleOpacity: Double = 0.6
    
    let size: CGFloat
    let color: Color
    
    init(size: CGFloat = 28, color: Color = .white) {
        self.size = size
        self.color = color
    }
    
    var body: some View {
        ZStack {
            // Ripple effect
            RoundedRectangle(cornerRadius: 8)
                .stroke(color, lineWidth: 2)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)
                .frame(width: size, height: size)
            
            // Checkmark with satisfying scale animation
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.6, weight: .bold))
                .foregroundColor(Constants.DAMidBlue)
                .scaleEffect(checkScale)
                .opacity(checkOpacity)
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Immediate ripple effect
        withAnimation(.easeOut(duration: 0.4)) {
            rippleScale = 1.3
            rippleOpacity = 0
        }
        
        // Checkmark appears with satisfying bounce
        withAnimation(.interpolatingSpring(stiffness: 400, damping: 12)) {
            checkScale = 1.0
            checkOpacity = 1.0
        }
    }
}

struct CheckmarkAnimationModifier: ViewModifier {
    let isCompleted: Bool
    @State private var showAnimation = false
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if showAnimation {
                TaskCompletionAnimation()
            }
        }
        .onChange(of: isCompleted) { newValue in
            if newValue {
                showAnimation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showAnimation = false
                }
            } else {
                showAnimation = false
            }
        }
    }
}

extension View {
    func taskCompletionAnimation(isCompleted: Bool) -> some View {
        modifier(CheckmarkAnimationModifier(isCompleted: isCompleted))
    }
}

#Preview {
    TaskCompletionAnimation(size: 32, color: .blue)
        .frame(width: 100, height: 100)
        .background(Color.black.opacity(0.1))
}