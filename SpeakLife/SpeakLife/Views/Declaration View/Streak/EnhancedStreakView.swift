//
//  EnhancedStreakView.swift
//  SpeakLife
//
//  Enhanced streak view that replaces the countdown timer with daily checklist
//

import SwiftUI
import Photos

struct EnhancedStreakView: View {
    @EnvironmentObject var viewModel: EnhancedStreakViewModel
    @State private var showStreakSheet = false
    @State private var showChecklistView = false
    @State private var showCompletedBanner = false
    
    var body: some View {
        VStack(spacing: 0) {
            if showCompletedBanner && viewModel.todayChecklist.isCompleted {
                // Show completion banner temporarily
                CompletedStreakBadge(streakNumber: viewModel.streakStats.currentStreak)
                    .onTapGesture {
                        showStreakSheet = true
                    }
                    .transition(.scale.combined(with: .opacity))
                    .onAppear {
                        // Auto-collapse after 5 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            withAnimation(.easeInOut(duration: 0.8)) {
                                showCompletedBanner = false
                            }
                        }
                    }
            } else {
                // Always show compact circle button (default state)
                CompactStreakButton(viewModel: viewModel) {
                    if viewModel.todayChecklist.isCompleted {
                        showStreakSheet = true
                    } else {
                        showChecklistView = true
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onChange(of: viewModel.todayChecklist.isCompleted) { isCompleted in
            if isCompleted {
                // Show banner when tasks completed
                withAnimation(.easeInOut(duration: 0.5)) {
                    showCompletedBanner = true
                }
            }
        }
        .fullScreenCover(isPresented: $showChecklistView) {
            DailyChecklistFullScreenView(viewModel: viewModel)
        }
        .fullScreenCover(isPresented: $showStreakSheet) {
            EnhancedStreakSheet(
                isShown: $showStreakSheet,
                viewModel: viewModel
            )
        }
        .fullScreenCover(isPresented: $viewModel.showFireAnimation) {
            FireStreakView(streakNumber: viewModel.streakStats.currentStreak)
                .onTapGesture {
                    viewModel.showFireAnimation = false
                    // Show banner after fire animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation {
                            showCompletedBanner = true
                        }
                    }
                }
        }
        .fullScreenCover(isPresented: $viewModel.showCompletionCelebration) {
            if let celebration = viewModel.celebrationData {
                CompletionCelebrationView(celebration: celebration)
            }
        }
        .fullScreenCover(isPresented: $viewModel.showBadgeUnlock) {
            if let badge = viewModel.badgeManager.recentlyUnlocked {
                BadgeUnlockView(badge: badge, isPresented: $viewModel.showBadgeUnlock)
                    .onDisappear {
                        viewModel.dismissBadgeUnlock()
                    }
            }
        }
    }
}

struct CompactStreakButton: View {
    @ObservedObject var viewModel: EnhancedStreakViewModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background circle with gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.1, green: 0.15, blue: 0.3), Color(red: 0.02, green: 0.07, blue: 0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                // Progress ring
                Circle()
                    .stroke(Constants.DAMidBlue.opacity(0.3), lineWidth: 3)
                    .frame(width: 52, height: 52)
                
                Circle()
                    .trim(from: 0, to: viewModel.todayChecklist.completionProgress)
                    .stroke(Constants.DAMidBlue, lineWidth: 3)
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: viewModel.todayChecklist.completionProgress)
                
                // Center content
                if viewModel.todayChecklist.isCompleted {
                    // Fire icon with streak number
                    HStack(spacing: -2) {
                        Text("🔥")
                            .font(.system(size: 16))
                        Text("\(viewModel.streakStats.currentStreak)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else {
                    // Sexy task count with dots indicator
                    VStack(spacing: 4) {
                        // Main count number
                        Text("\(viewModel.todayChecklist.completedTasksCount)")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        // Dots indicator instead of fraction
                        HStack(spacing: 3) {
                            ForEach(0..<viewModel.todayChecklist.tasks.count, id: \.self) { index in
                                Circle()
                                    .fill(index < viewModel.todayChecklist.completedTasksCount ? Color.white : Color.white.opacity(0.3))
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CompletedStreakBadge: View {
    let streakNumber: Int
    @State private var animateFlame = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Fire animation
            ZStack {
                // Background circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                // Animated fire emoji
                Text("🔥")
                    .font(.system(size: 28))
                    .scaleEffect(animateFlame ? 1.1 : 0.9)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true),
                        value: animateFlame
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(streakNumber)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("day streak!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Text("🎉 Daily practice complete!")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.green)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.15, blue: 0.3), Color(red: 0.02, green: 0.07, blue: 0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            animateFlame = true
        }
    }
}

// MARK: - Enhanced Streak Sheet
struct EnhancedStreakSheet: View {
    @Binding var isShown: Bool
    @ObservedObject var viewModel: EnhancedStreakViewModel
    @State private var showBadgeCollection = false
    
    private var progress: Double {
        let currentStreak = viewModel.streakStats.currentStreak
        let nextMilestone = getNextMilestone(currentStreak)
        let previousMilestone = getPreviousMilestone(currentStreak)
        
        if currentStreak == 0 {
            return 0.0
        }
        
        let progressInMilestone = Double(currentStreak - previousMilestone)
        let milestoneRange = Double(nextMilestone - previousMilestone)
        
        return progressInMilestone / milestoneRange
    }
    
    private func getNextMilestone(_ current: Int) -> Int {
        let milestones = [7, 14, 30, 50, 100, 200, 365]
        return milestones.first { $0 > current } ?? (current + 100)
    }
    
    private func getPreviousMilestone(_ current: Int) -> Int {
        let milestones = [0, 7, 14, 30, 50, 100, 200, 365]
        return milestones.last { $0 <= current } ?? 0
    }
    
    private var showSparkles: Bool {
        progress >= 0.8
    }
    
    var body: some View {
        ZStack {
            Gradients().speakLifeCYOCell
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigation bar with badge and close buttons
                HStack {
                    Button("Badges") {
                        showBadgeCollection = true
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.2))
                    )
                    
                    Spacer()
                    
                    Button(action: {
                        isShown = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                VStack(spacing: 20) {
                
                // Today's checklist status
                DailyChecklistSummary(viewModel: viewModel)
                    .padding(.horizontal, 20)
                
                // Enhanced Progress ring with milestone info
                EnhancedProgressRing(
                    progress: progress,
                    currentStreak: viewModel.streakStats.currentStreak,
                    nextMilestone: getNextMilestone(viewModel.streakStats.currentStreak),
                    showSparkles: showSparkles
                )
                .padding(.top, 12)
                
                // Enhanced streak stats
                EnhancedStreakStatsView(viewModel: viewModel)
                    .padding(.horizontal, 24)
                
                // Action buttons
                VStack(spacing: 16) {
                    if !viewModel.todayChecklist.isCompleted {
                        VStack(spacing: 12) {
                            Button("Complete Daily Practice") {
                                isShown = false
                            }
                            .font(.headline)
                            .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(10)
                            
                            Button("Reset Today's Tasks") {
                                viewModel.resetDay()
                            }
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        }
                    } else {
                        // Show share button when daily tasks are completed
                        StreakShareButton(viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 24)
                
                    Spacer()
                }
                
                Spacer()
            }
        }
        .foregroundColor(.white)
        .sheet(isPresented: $showBadgeCollection) {
            BadgeCollectionView(badgeManager: viewModel.badgeManager)
        }
    }
}

struct DailyChecklistSummary: View {
    @ObservedObject var viewModel: EnhancedStreakViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Today's Practice")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                if viewModel.todayChecklist.isCompleted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Complete!")
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                } else {
                    Text("\(viewModel.todayChecklist.completedTasksCount)/\(viewModel.todayChecklist.tasks.count)")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Mini task list
            LazyVStack(spacing: 8) {
                ForEach(viewModel.todayChecklist.tasks) { task in
                    HStack {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(task.isCompleted ? .green : .white.opacity(0.5))
                            .font(.system(size: 16))
                        
                        Text(task.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .strikethrough(task.isCompleted)
                        
                        Spacer()
                        
                        if task.isCompleted {
                            Image(systemName: "star.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
}

struct EnhancedStreakStatsView: View {
    @ObservedObject var viewModel: EnhancedStreakViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Hero stat - Current streak
            PremiumStatCard(
                label: "Current Streak",
                value: "\(viewModel.streakStats.currentStreak)",
                subtitle: viewModel.streakStats.currentStreak == 1 ? "day" : "days",
                isHero: true
            )
            .onAppear {
                print("🔥 STATS DEBUG: Current streak displayed in stats: \(viewModel.streakStats.currentStreak)")
                print("🔥 STATS DEBUG: Longest streak: \(viewModel.streakStats.longestStreak)")
                print("🔥 STATS DEBUG: Total completed: \(viewModel.streakStats.totalDaysCompleted)")
            }
            
            // Secondary stats in elegant grid
            HStack(spacing: 16) {
                PremiumStatCard(
                    label: "Best Streak",
                    value: "\(viewModel.streakStats.longestStreak)",
                    subtitle: viewModel.streakStats.longestStreak == 1 ? "day" : "days",
                    isHero: false
                )
                
                PremiumStatCard(
                    label: "Total Completed",
                    value: "\(viewModel.streakStats.totalDaysCompleted)",
                    subtitle: viewModel.streakStats.totalDaysCompleted == 1 ? "day" : "days",
                    isHero: false
                )
            }
        }
        .padding(.horizontal, 8)
    }
}

struct PremiumStatCard: View {
    let label: String
    let value: String
    let subtitle: String
    let isHero: Bool
    
    var body: some View {
        VStack(spacing: isHero ? 8 : 6) {
            // Label
            Text(label.uppercased())
                .font(.system(size: isHero ? 14 : 12, weight: .medium, design: .default))
                .foregroundColor(.white.opacity(0.7))
                .tracking(1.2)
            
            // Value
            Text(value)
                .font(.system(
                    size: isHero ? 48 : 32,
                    weight: .black,
                    design: .default
                ))
                .foregroundColor(.white)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            
            // Subtitle
            Text(subtitle.uppercased())
                .font(.system(size: isHero ? 16 : 14, weight: .medium, design: .default))
                .foregroundColor(.white.opacity(0.8))
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isHero ? 24 : 20)
        .padding(.horizontal, isHero ? 32 : 20)
        .background(
            RoundedRectangle(cornerRadius: isHero ? 20 : 16)
                .fill(
                    LinearGradient(
                        colors: isHero ? 
                            [Color.white.opacity(0.15), Color.white.opacity(0.05)] :
                            [Color.white.opacity(0.08), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: isHero ? 20 : 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct StreakShareButton: View {
    @ObservedObject var viewModel: EnhancedStreakViewModel
    @State private var pulseScale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -1
    @State private var glowIntensity: Double = 0
    
    var body: some View {
        Button(action: shareStreak) {
            HStack(spacing: 12) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .semibold))
                
                Text("Share My \(viewModel.streakStats.currentStreak) Day Streak!")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .onAppear {
                        print("🔥 SHARE BUTTON DEBUG: Current streak displayed: \(viewModel.streakStats.currentStreak)")
                    }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    // Base gradient
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.3, blue: 0.6),
                                    Color(red: 0.8, green: 0.2, blue: 0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Shimmer effect
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .mask(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.clear, Color.white, Color.clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .rotationEffect(.degrees(45))
                                .offset(x: shimmerOffset * 300)
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
            )
            .shadow(color: Color(red: 1.0, green: 0.3, blue: 0.6).opacity(glowIntensity), radius: 10, x: 0, y: 0)
            .scaleEffect(pulseScale)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.02
                glowIntensity = 0.4
            }
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false).delay(0.5)) {
                shimmerOffset = 1
            }
        }
    }
    
    private func shareStreak() {
        // Generate and share streak achievement
        if let shareImage = viewModel.generateShareImage() {
            let celebration = CompletionCelebration(
                streakNumber: viewModel.streakStats.currentStreak,
                isNewRecord: viewModel.streakStats.currentStreak >= viewModel.streakStats.longestStreak,
                motivationalMessage: "🔥 \(viewModel.streakStats.currentStreak) days of speaking LIFE into my destiny! Every word has power! #SpeakLife",
                shareImage: shareImage
            )
            
            shareToInstagram(celebration: celebration)
        }
    }
    
    private func shareToInstagram(celebration: CompletionCelebration) {
        guard let shareImage = celebration.shareImage else { 
            print("❌ No share image available for sharing")
            return 
        }
        
        print("✅ Share image available: \(shareImage.size), scale: \(shareImage.scale)")
        
        // Create properly sized image for Instagram
        let targetSize = CGSize(width: 1080, height: 1920)
        let resizedImage = resizeImageForInstagram(shareImage, targetSize: targetSize)
        
        // Use Photos approach for reliable Instagram sharing
        print("📱 Using Photos approach for reliable Instagram sharing")
        trySaveToPhotosForManualShare(image: resizedImage)
    }
    
    // MARK: - Instagram Helper Methods
    
    private func resizeImageForInstagram(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    private func tryInstagramDirectShare(image: UIImage) -> Bool {
        // Check if Instagram is installed
        guard let instagramURL = URL(string: "instagram://app"),
              UIApplication.shared.canOpenURL(instagramURL) else {
            print("❌ Instagram app not installed")
            return false
        }
        
        // Try Instagram Stories with proper data format
        return shareToInstagramStories(image: image)
    }
    
    private func shareToInstagramStories(image: UIImage) -> Bool {
        print("🚀 Starting Instagram Stories sharing...")
        
        // Method 1: Try the pasteboard approach for Instagram Stories
        print("🔄 Trying pasteboard approach for Instagram Stories")
        if shareToInstagramViaPasteboard(image: image) {
            print("✅ Instagram Stories pasteboard method initiated")
            return true
        }
        
        // Method 2: Photos fallback (always works)
        print("🔄 Using Photos fallback for reliable sharing")
        return trySaveToPhotosForManualShare(image: image)
    }
    
    
    private func shareToInstagramViaPasteboard(image: UIImage) -> Bool {
        // Check if Instagram is available first
        guard let instagramStoriesURL = URL(string: "instagram-stories://share"),
              UIApplication.shared.canOpenURL(instagramStoriesURL) else {
            print("❌ Instagram Stories not available")
            return false
        }
        
        print("✅ Instagram Stories URL scheme is available")
        
        // Ensure image is exactly the right size for Instagram Stories
        let instagramSize = CGSize(width: 1080, height: 1920)
        let resizedImage = resizeImageExactly(image, to: instagramSize)
        
        // Convert to high-quality JPEG
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.9) else {
            print("❌ Failed to convert image to JPEG")
            return false
        }
        
        print("✅ Image prepared: \(resizedImage.size), \(imageData.count) bytes")
        
        // Clear pasteboard completely and set new data
        let pasteboard = UIPasteboard.general
        pasteboard.items = []
        
        // Try multiple pasteboard formats for maximum compatibility
        
        // Format 1: Instagram's official format
        pasteboard.setData(imageData, forPasteboardType: "com.instagram.sharedSticker.backgroundImage")
        
        // Format 2: Alternative Instagram format
        pasteboard.setData(imageData, forPasteboardType: "com.instagram.sharedSticker.stickerImage")
        
        // Format 3: Standard image format as fallback
        pasteboard.setData(imageData, forPasteboardType: "public.jpeg")
        pasteboard.image = resizedImage
        
        print("✅ Pasteboard configured with Instagram format")
        print("📱 Opening Instagram Stories...")
        
        // Open Instagram Stories
        UIApplication.shared.open(instagramStoriesURL, options: [:]) { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ Successfully launched Instagram Stories")
                } else {
                    print("❌ Failed to launch Instagram Stories")
                }
            }
        }
        
        return true
    }
    
    
    private func resizeImageExactly(_ image: UIImage, to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resizedImage
    }
    
    private func trySaveToPhotosForManualShare(image: UIImage) -> Bool {
        // Request photos permission first
        let photos = PHPhotoLibrary.shared()
        
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    self.saveImageToPhotos(image: image)
                case .denied, .restricted:
                    print("❌ Photos access denied")
                    self.showPhotosPermissionAlert()
                case .notDetermined:
                    print("❌ Photos permission not determined")
                @unknown default:
                    print("❌ Unknown photos permission status")
                }
            }
        }
        return true
    }
    
    private func saveImageToPhotos(image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Image saved to Photos")
                    self.showImageSavedAlert()
                } else {
                    print("❌ Failed to save image: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    private func showImageSavedAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "🎉 Image Saved!",
            message: "Your streak achievement has been saved to Photos. Open Instagram and create a new Story to share it!",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Instagram", style: .default) { _ in
            if let instagramURL = URL(string: "instagram://story-camera"),
               UIApplication.shared.canOpenURL(instagramURL) {
                UIApplication.shared.open(instagramURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        
        var topController = rootViewController
        while let presentedController = topController.presentedViewController {
            topController = presentedController
        }
        
        topController.present(alert, animated: true)
    }
    
    private func showPhotosPermissionAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: "Photos Access Needed",
            message: "To save your streak achievement, please allow access to Photos in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        var topController = rootViewController
        while let presentedController = topController.presentedViewController {
            topController = presentedController
        }
        
        topController.present(alert, animated: true)
    }
}

// MARK: - Preview
#if DEBUG
struct EnhancedStreakView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            EnhancedStreakView()
                .padding()
            
            Spacer()
        }
        .background(Color.black)
    }
}
#endif
