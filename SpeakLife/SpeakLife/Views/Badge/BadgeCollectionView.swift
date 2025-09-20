//
//  BadgeCollectionView.swift
//  SpeakLife
//
//  Elegant badge collection and progress display
//

import SwiftUI
import Photos

struct BadgeCollectionView: View {
    @ObservedObject var badgeManager: BadgeManager
    @State private var selectedBadge: Badge? {
        didSet {
            print("🎯 Badge selection changed: \(selectedBadge?.title ?? "nil")")
        }
    }
    @State private var selectedFilter: BadgeFilter = .all
    @State private var animateOnAppear = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.15),
                        Color(red: 0.1, green: 0.1, blue: 0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 32) {
                        // Header with progress
                        BadgeCollectionHeader(badgeManager: badgeManager)
                            .padding(.horizontal, 20)
                        
                        // Filter tabs
                        BadgeFilterTabs(selectedFilter: $selectedFilter)
                            .padding(.horizontal, 20)
                        
                        // Badge grid
                        BadgeGrid(
                            badges: filteredBadges,
                            animateOnAppear: animateOnAppear,
                            onBadgeTap: { badge in
                                // Add small delay to ensure proper state change
                                DispatchQueue.main.async {
                                    selectedBadge = badge
                                }
                            }
                        )
                        .padding(.horizontal, 20)
                        
                        // Next milestone preview
                        if let nextBadge = badgeManager.getNextBadgeToUnlock() {
                            NextMilestoneCard(badge: nextBadge)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Badge Collection")
            .navigationBarTitleDisplayMode(.large)
            .preferredColorScheme(.dark)
        }
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailView(badge: badge, isPresented: Binding(
                get: { selectedBadge != nil },
                set: { if !$0 { selectedBadge = nil } }
            ))
            .onAppear {
                print("🏆 BadgeDetailView appeared with badge: \(badge.title)")
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                animateOnAppear = true
            }
        }
    }
    
    private var filteredBadges: [Badge] {
        switch selectedFilter {
        case .all:
            return badgeManager.allBadges
        case .unlocked:
            return badgeManager.allBadges.filter { $0.isUnlocked }
        case .locked:
            return badgeManager.allBadges.filter { !$0.isUnlocked }
        case .type(let badgeType):
            return badgeManager.getBadgesByType(badgeType)
        case .rarity(let rarity):
            return badgeManager.getBadgesByRarity(rarity)
        }
    }
}

// MARK: - Collection Header

struct BadgeCollectionHeader: View {
    @ObservedObject var badgeManager: BadgeManager
    
    @State private var progressAnimation: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 24) {
            // Stats overview
            HStack(spacing: 20) {
                StatCard(
                    title: "Badges Earned",
                    value: "\(badgeManager.unlockedBadgeCount)",
                    subtitle: "of \(badgeManager.totalBadgeCount)",
                    color: .green
                )
                
                StatCard(
                    title: "Completion",
                    value: "\(Int(badgeManager.completionPercentage * 100))%",
                    subtitle: "unlocked",
                    color: .blue
                )
            }
            
            // Progress bar
            VStack(spacing: 12) {
                HStack {
                    Text("Collection Progress")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(badgeManager.unlockedBadgeCount)/\(badgeManager.totalBadgeCount)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                ProgressBar(
                    progress: badgeManager.completionPercentage,
                    animationValue: progressAnimation
                )
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).delay(0.5)) {
                progressAnimation = badgeManager.completionPercentage
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .tracking(1)
            
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ProgressBar: View {
    let progress: Double
    let animationValue: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 8)
                
                // Progress
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width * animationValue,
                        height: 8
                    )
                
                // Glow effect
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.3))
                    .frame(
                        width: geometry.size.width * animationValue,
                        height: 8
                    )
                    .blur(radius: 4)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Filter Tabs

enum BadgeFilter: Hashable {
    case all
    case unlocked
    case locked
    case type(BadgeType)
    case rarity(BadgeRarity)
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .unlocked: return "Earned"
        case .locked: return "Locked"
        case .type(let type): return type.rawValue.capitalized
        case .rarity(let rarity): return rarity.displayName
        }
    }
}

struct BadgeFilterTabs: View {
    @Binding var selectedFilter: BadgeFilter
    
    private let filters: [BadgeFilter] = [
        .all,
        .unlocked,
        .locked
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filters, id: \.self) { filter in
                    FilterTab(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct FilterTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.white : Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Badge Grid

struct BadgeGrid: View {
    let badges: [Badge]
    let animateOnAppear: Bool
    let onBadgeTap: (Badge) -> Void
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 20), count: 3)
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(Array(badges.enumerated()), id: \.element.id) { index, badge in
                BadgeGridItem(
                    badge: badge,
                    animationDelay: Double(index) * 0.1,
                    shouldAnimate: animateOnAppear
                ) {
                    onBadgeTap(badge)
                }
            }
        }
    }
}

struct BadgeGridItem: View {
    let badge: Badge
    let animationDelay: Double
    let shouldAnimate: Bool
    let onTap: () -> Void
    
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                BadgeView(
                    badge: badge,
                    size: 80,
                    showGlow: badge.isUnlocked,
                    showParticles: false
                )
                
                VStack(spacing: 4) {
                    Text(badge.displayTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(badge.isUnlocked ? .white : .gray)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    if badge.isUnlocked {
                        HStack(spacing: 2) {
                            ForEach(0..<rarityStars(badge.rarity), id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(badge.rarity.ringColor)
                            }
                        }
                    }
                }
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            if shouldAnimate {
                DispatchQueue.main.asyncAfter(deadline: .now() + animationDelay) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        scale = 1.0
                        opacity = 1.0
                    }
                }
            } else {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
    
    private func rarityStars(_ rarity: BadgeRarity) -> Int {
        switch rarity {
        case .common: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 4
        }
    }
}

// MARK: - Next Milestone Card

struct NextMilestoneCard: View {
    let badge: Badge
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next Milestone")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(badge.requirement.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                BadgeView(
                    badge: badge,
                    size: 60,
                    showGlow: false,
                    showParticles: false
                )
            }
            
            // Progress indicator could go here
            // based on current progress toward this badge
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    badge.type.primaryColor.opacity(0.5),
                                    badge.type.secondaryColor.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Badge Detail View

struct BadgeDetailView: View {
    let badge: Badge
    @Binding var isPresented: Bool
    
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.1, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigation bar
                HStack {
                    Spacer()
                    Button("Done") {
                        isPresented = false
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding()
                }
                .padding(.top, 10)
                
                ScrollView {
                    VStack(spacing: 40) {
                        // Badge showcase
                        BadgeView(
                            badge: badge,
                            size: 200,
                            showGlow: badge.isUnlocked,
                            showParticles: badge.isUnlocked
                        )
                        .scaleEffect(showContent ? 1 : 0.5)
                        .opacity(showContent ? 1 : 0)
                        .padding(.top, 20)
                        
                        // Badge info
                        VStack(spacing: 20) {
                            VStack(spacing: 12) {
                                Text(badge.displayTitle)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                HStack(spacing: 8) {
                                    ForEach(0..<rarityStars(badge.rarity), id: \.self) { _ in
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(badge.rarity.ringColor)
                                    }
                                    
                                    Text(badge.rarity.displayName.uppercased())
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(badge.rarity.ringColor)
                                        .tracking(1)
                                }
                            }
                            
                            Text(badge.displayDescription)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            
                            if let unlockedAt = badge.unlockedAt {
                                VStack(spacing: 4) {
                                    Text("Unlocked")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    Text(unlockedAt, style: .date)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                        
                        // Share button (if unlocked)
                        if badge.isUnlocked {
                            ShareBadgeButton(badge: badge)
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 20)
                                .padding(.bottom, 40)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                showContent = true
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func rarityStars(_ rarity: BadgeRarity) -> Int {
        switch rarity {
        case .common: return 1
        case .rare: return 2
        case .epic: return 3
        case .legendary: return 4
        }
    }
}

// MARK: - Share Badge Button

struct ShareBadgeButton: View {
    let badge: Badge
    
    var body: some View {
        Button(action: shareBadge) {
            HStack(spacing: 12) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                
                Text("Share Badge")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                badge.type.primaryColor,
                                badge.type.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func shareBadge() {
        // Generate shareable image and save to Photos
        if let shareImage = BadgeImageGenerator.generateShareableImage(badge: badge) {
            // Use Photos approach for consistent Instagram sharing
            saveToPhotosForSharing(image: shareImage)
        }
    }
    
    private func saveToPhotosForSharing(image: UIImage) {
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
    }
    
    private func saveImageToPhotos(image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Badge image saved to Photos")
                    self.showImageSavedAlert()
                } else {
                    print("❌ Failed to save badge image: \(error?.localizedDescription ?? "Unknown error")")
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
            title: "🎉 Badge Saved!",
            message: "Your '\(badge.title)' badge has been saved to Photos. Open Instagram and create a new Story to share it!",
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
            message: "To save your badge, please allow access to Photos in Settings.",
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
struct BadgeCollectionView_Previews: PreviewProvider {
    static var previews: some View {
        BadgeCollectionView(badgeManager: BadgeManager())
    }
}
#endif