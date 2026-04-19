//
//  BadgeTestView.swift
//  SpeakLife
//
//  Test view to verify badge system integration
//

import SwiftUI

struct BadgeTestView: View {
    @StateObject private var badgeManager = BadgeManager()
    @State private var showBadgeCollection = false
    @State private var showBadgeUnlock = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Badge System Test")
                .font(.title)
                .fontWeight(.bold)
            
            // Show some test badges
            HStack(spacing: 20) {
                ForEach(Array(badgeManager.allBadges.prefix(3)), id: \.id) { badge in
                    BadgeDisplayView(badge: badge, size: 80)
                }
            }
            
            // Stats
            VStack(spacing: 8) {
                Text("Badges Earned: \(badgeManager.unlockedBadgeCount)/\(badgeManager.totalBadgeCount)")
                    .font(.headline)
                
                Text("Completion: \(Int(badgeManager.completionPercentage * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Action buttons
            VStack(spacing: 12) {
                Button("View Badge Collection") {
                    showBadgeCollection = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Test Badge Unlock") {
                    testBadgeUnlock()
                }
                .buttonStyle(.bordered)
                
                Button("Simulate Progress") {
                    simulateProgress()
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showBadgeCollection) {
            BadgeCollectionView(badgeManager: badgeManager)
        }
        .fullScreenCover(isPresented: $showBadgeUnlock) {
            if let badge = badgeManager.recentlyUnlocked {
                BadgeUnlockView(badge: badge, isPresented: $showBadgeUnlock)
                    .onDisappear {
                        badgeManager.clearRecentlyUnlocked()
                    }
            }
        }
    }
    
    private func testBadgeUnlock() {
        // Find the first unlocked badge or create a test one
        if let firstBadge = badgeManager.allBadges.first(where: { $0.isUnlocked }) {
            badgeManager.recentlyUnlocked = firstBadge
            showBadgeUnlock = true
        } else {
            // Force unlock the first badge for testing
            let testStats = createTestStats(streak: 1)
            let userStats = createTestUserStats()
            badgeManager.checkForNewBadges(streakStats: testStats, userStats: userStats)
            
            if let newBadge = badgeManager.recentlyUnlocked {
                showBadgeUnlock = true
            }
        }
    }
    
    private func simulateProgress() {
        // Simulate different streak levels to unlock badges
        let progressLevels = [1, 7, 14, 30, 50, 100]
        
        for level in progressLevels {
            let testStats = createTestStats(streak: level)
            let userStats = createTestUserStats()
            badgeManager.checkForNewBadges(streakStats: testStats, userStats: userStats)
        }
    }
    
    private func createTestStats(streak: Int) -> StreakStats {
        var stats = StreakStats()
        stats.currentStreak = streak
        stats.longestStreak = streak
        stats.totalDaysCompleted = streak
        stats.lastCompletedDate = Date()
        return stats
    }
    
    private func createTestUserStats() -> UserStats {
        return UserStats(
            affirmationsSpoken: 50,
            versesRead: 25,
            socialShares: 5,
            favoritesAdded: 10,
            categoriesCompleted: Set(["Faith", "Health"])
        )
    }
}

// MARK: - Preview

#if DEBUG
struct BadgeTestView_Previews: PreviewProvider {
    static var previews: some View {
        BadgeTestView()
    }
}
#endif
