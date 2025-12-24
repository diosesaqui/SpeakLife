//
//  GestureDelights.swift
//  SpeakLife
//
//  Premium gesture-based interactions and delightful feedback
//

import SwiftUI
import UIKit
import Foundation
import CoreGraphics

// MARK: - Shake Gesture Detector

class ShakeGestureManager: ObservableObject {
    @Published var didShake = false
    
    private var shakeCount = 0
    private var lastShakeTime = Date()
    
    func handleShake() {
        let now = Date()
        let timeSinceLastShake = now.timeIntervalSince(lastShakeTime)
        
        // Reset count if more than 2 seconds have passed
        if timeSinceLastShake > 2.0 {
            shakeCount = 0
        }
        
        shakeCount += 1
        lastShakeTime = now
        
        // Trigger on first shake
        if shakeCount == 1 {
            PremiumHaptics.shakeGesture()
            didShake = true
            
            // Reset after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.didShake = false
            }
        }
    }
}

// MARK: - Long Press with Preview

struct LongPressPreview<Content: View, Preview: View>: View {
    let content: Content
    let preview: Preview
    let onLongPress: () -> Void
    
    @State private var isPressed = false
    @State private var showPreview = false
    @State private var scale: CGFloat = 1.0
    @State private var previewOffset: CGFloat = 0
    @State private var glowIntensity: Double = 0
    
    init(
        onLongPress: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
        @ViewBuilder preview: () -> Preview
    ) {
        self.onLongPress = onLongPress
        self.content = content()
        self.preview = preview()
    }
    
    var body: some View {
        ZStack {
            content
                .scaleEffect(scale)
                .glow(color: .blue, intensity: glowIntensity)
                .onLongPressGesture(
                    minimumDuration: 0.5,
                    maximumDistance: 50
                ) {
                    // Long press completed
                    PremiumHaptics.safeSuccessSequence()
                    onLongPress()
                    dismissPreview()
                } onPressingChanged: { pressing in
                    if pressing {
                        startPreview()
                    } else if !showPreview {
                        // Short press - cancel
                        cancelPreview()
                    }
                }
            
            // Preview overlay
            if showPreview {
                VStack {
                    preview
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .shadow(radius: 20)
                        )
                        .scaleEffect(showPreview ? 1 : 0)
                        .offset(y: previewOffset)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showPreview)
                    
                    Spacer()
                }
                .padding(.top, 100)
            }
        }
    }
    
    private func startPreview() {
        PremiumHaptics.safeLight()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPressed = true
            scale = 0.95
            glowIntensity = 0.3
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if isPressed {
                showPreview = true
                previewOffset = -20
                
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    previewOffset = 0
                    glowIntensity = 0.6
                }
            }
        }
    }
    
    private func cancelPreview() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPressed = false
            scale = 1.0
            glowIntensity = 0
        }
        
        if showPreview {
            dismissPreview()
        }
    }
    
    private func dismissPreview() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showPreview = false
            previewOffset = -50
            scale = 1.0
            glowIntensity = 0
            isPressed = false
        }
    }
}

// MARK: - Swipe with Trail Effect

struct SwipeTrailGesture: ViewModifier {
    @State private var trailPoints: [CGPoint] = []
    @State private var swipeDirection: SwipeDirection?
    @State private var isActive = false
    
    let onSwipe: (SwipeDirection) -> Void
    let trailColor: Color
    
    enum SwipeDirection {
        case left, right, up, down
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                // Trail effect
                Canvas { context, size in
                    guard trailPoints.count > 1 else { return }
                    
                    for i in 0..<(trailPoints.count - 1) {
                        let start = trailPoints[i]
                        let end = trailPoints[i + 1]
                        let opacity = Double(i) / Double(trailPoints.count)
                        
                        var path = Path()
                        path.move(to: start)
                        path.addLine(to: end)
                        
                        context.stroke(
                            path,
                            with: .color(trailColor.opacity(opacity)),
                            lineWidth: 4
                        )
                    }
                }
            )
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        if !isActive {
                            isActive = true
                            PremiumHaptics.safeLight()
                        }
                        
                        trailPoints.append(value.location)
                        
                        // Limit trail points
                        if trailPoints.count > 20 {
                            trailPoints.removeFirst()
                        }
                    }
                    .onEnded { value in
                        let direction = determineSwipeDirection(
                            start: value.startLocation,
                            end: value.location
                        )
                        
                        if let direction = direction {
                            swipeDirection = direction
                            onSwipe(direction)
                            PremiumHaptics.swipeAction()
                        }
                        
                        // Clear trail
                        withAnimation(.easeOut(duration: 0.5)) {
                            trailPoints.removeAll()
                        }
                        
                        isActive = false
                    }
            )
    }
    
    private func determineSwipeDirection(start: CGPoint, end: CGPoint) -> SwipeDirection? {
        let deltaX = end.x - start.x
        let deltaY = end.y - start.y
        let distance = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        guard distance > 50 else { return nil }
        
        if abs(deltaX) > abs(deltaY) {
            return deltaX > 0 ? .right : .left
        } else {
            return deltaY > 0 ? .down : .up
        }
    }
}

// MARK: - Pull to Refresh with Custom Animation

struct PullToRefreshGesture<Content: View>: View {
    let content: Content
    let onRefresh: () -> Void
    
    @State private var pullOffset: CGFloat = 0
    @State private var isRefreshing = false
    @State private var rotationAngle: Double = 0
    @State private var scale: CGFloat = 0
    
    private let threshold: CGFloat = 80
    
    init(onRefresh: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onRefresh = onRefresh
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Pull indicator
                    ZStack {
                        // Background circle
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 60, height: 60)
                            .scaleEffect(scale)
                        
                        // Icon
                        if isRefreshing {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.blue)
                                .rotationEffect(.degrees(rotationAngle))
                        } else {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.blue)
                                .rotationEffect(.degrees(pullOffset > threshold ? 180 : 0))
                        }
                    }
                    .frame(height: max(0, pullOffset))
                    .opacity(pullOffset > 20 ? 1 : 0)
                    
                    content
                        .offset(y: max(0, pullOffset))
                }
            }
            .coordinateSpace(name: "pullToRefresh")
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geo.frame(in: .named("pullToRefresh")).minY
                        )
                }
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                if value > 0 && !isRefreshing {
                    pullOffset = value
                    scale = min(value / threshold, 1.0)
                    
                    if value > threshold {
                        // Trigger haptic at threshold
                        PremiumHaptics.pullToRefresh()
                    }
                } else if value <= 0 && pullOffset > threshold && !isRefreshing {
                    // Release and refresh
                    triggerRefresh()
                } else if !isRefreshing {
                    pullOffset = 0
                    scale = 0
                }
            }
        }
    }
    
    private func triggerRefresh() {
        isRefreshing = true
        PremiumHaptics.safeSuccessSequence()
        
        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        onRefresh()
        
        // Simulate refresh completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isRefreshing = false
                pullOffset = 0
                scale = 0
                rotationAngle = 0
            }
        }
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Double Tap to Like

struct DoubleTapHeart: ViewModifier {
    @State private var hearts: [HeartData] = []
    let onDoubleTap: () -> Void
    
    struct HeartData: Identifiable {
        let id = UUID()
        var position: CGPoint
        var scale: CGFloat = 0
        var opacity: Double = 1
        var offset: CGPoint = .zero
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                // Floating hearts
                ForEach(hearts) { heart in
                    Image(systemName: "heart.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.red)
                        .scaleEffect(heart.scale)
                        .opacity(heart.opacity)
                        .position(
                            x: heart.position.x + heart.offset.x,
                            y: heart.position.y + heart.offset.y
                        )
                }
            )
            .onTapGesture(count: 2) {
                onDoubleTap()
                PremiumHaptics.favoriteAdded()
                addHeart()
            }
    }
    
    private func addHeart() {
        let heart = HeartData(
            position: CGPoint(
                x: CGFloat.random(in: 100...300),
                y: CGFloat.random(in: 200...400)
            )
        )
        hearts.append(heart)
        
        // Animate heart
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if let index = hearts.firstIndex(where: { $0.id == heart.id }) {
                hearts[index].scale = 1.2
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.easeOut(duration: 1.5)) {
                if let index = hearts.firstIndex(where: { $0.id == heart.id }) {
                    hearts[index].offset.y = -100
                    hearts[index].offset.x = CGFloat.random(in: -50...50)
                    hearts[index].opacity = 0
                    hearts[index].scale = 0.5
                }
            }
        }
        
        // Remove heart after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            hearts.removeAll { $0.id == heart.id }
        }
    }
}

// MARK: - Magnetic Button Effect

struct MagneticButton<Content: View>: View {
    let content: Content
    let action: () -> Void
    let magnetStrength: CGFloat
    
    @State private var offset: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    
    init(
        magnetStrength: CGFloat = 30,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.magnetStrength = magnetStrength
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        content
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                DragGesture(coordinateSpace: .local)
                    .onChanged { value in
                        let distance = sqrt(
                            value.translation.x * value.translation.x +
                            value.translation.y * value.translation.y
                        )
                        
                        if distance < magnetStrength {
                            // Magnetic attraction
                            let attraction = (magnetStrength - distance) / magnetStrength
                            
                            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                offset = CGSize(
                                    width: value.translation.x * 0.5,
                                    height: value.translation.y * 0.5
                                )
                                scale = 1.0 + attraction * 0.2
                            }
                            
                            if distance < magnetStrength * 0.3 {
                                PremiumHaptics.safeLight()
                            }
                        } else {
                            // Return to center
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                offset = .zero
                                scale = 1.0
                            }
                        }
                    }
                    .onEnded { value in
                        let distance = sqrt(
                            value.translation.x * value.translation.x +
                            value.translation.y * value.translation.y
                        )
                        
                        if distance < magnetStrength * 0.3 {
                            // Triggered
                            PremiumHaptics.safeMedium()
                            action()
                        }
                        
                        // Return to original state
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            offset = .zero
                            scale = 1.0
                        }
                    }
            )
    }
}

// MARK: - View Extensions

extension View {
    func swipeTrail(
        color: Color = .blue,
        onSwipe: @escaping (SwipeTrailGesture.SwipeDirection) -> Void
    ) -> some View {
        self.modifier(SwipeTrailGesture(onSwipe: onSwipe, trailColor: color))
    }
    
    func doubleTapHeart(onDoubleTap: @escaping () -> Void) -> some View {
        self.modifier(DoubleTapHeart(onDoubleTap: onDoubleTap))
    }
    
    func longPressPreview<Preview: View>(
        onLongPress: @escaping () -> Void,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        LongPressPreview(onLongPress: onLongPress) {
            self
        } preview: {
            preview()
        }
    }
    
    func magneticButton(
        magnetStrength: CGFloat = 30,
        action: @escaping () -> Void
    ) -> some View {
        MagneticButton(magnetStrength: magnetStrength, action: action) {
            self
        }
    }
    
    func pullToRefresh(onRefresh: @escaping () -> Void) -> some View {
        PullToRefreshGesture(onRefresh: onRefresh) {
            self
        }
    }
}

// MARK: - Shake Gesture UIKit Integration

extension UIWindow {
    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: NSNotification.Name("DeviceShaken"), object: nil)
        }
    }
}

struct ShakeGesture: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DeviceShaken"))) { _ in
                action()
            }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(ShakeGesture(action: action))
    }
}