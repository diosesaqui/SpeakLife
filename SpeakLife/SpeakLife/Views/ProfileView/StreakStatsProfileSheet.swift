//
//  StreakStatsProfileSheet.swift
//  SpeakLife
//
//  Streak stats + badges sheet accessible from Profile row.
//

import SwiftUI

struct StreakStatsProfileSheet: View {
    @ObservedObject var viewModel: EnhancedStreakViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // ── Streak Stats ──────────────────────────────────────
                    VStack(spacing: 16) {
                        Text("Your Streak")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            statCard(
                                icon: "flame.fill",
                                color: .orange,
                                value: "\(viewModel.streakStats.currentStreak)",
                                label: "Current"
                            )
                            statCard(
                                icon: "trophy.fill",
                                color: .yellow,
                                value: "\(viewModel.streakStats.longestStreak)",
                                label: "Best"
                            )
                            statCard(
                                icon: "calendar.badge.checkmark",
                                color: .green,
                                value: "\(viewModel.streakStats.totalDaysCompleted)",
                                label: "Total Days"
                            )
                        }

                        // Streak freeze status
                        if viewModel.streakStats.streakFreezeAvailable {
                            HStack(spacing: 8) {
                                Text("🛡️")
                                Text("Streak freeze available — one missed day won't break your streak")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal, 20)

                    Divider()
                        .padding(.horizontal, 20)

                    // ── Badges ────────────────────────────────────────────
                    VStack(spacing: 16) {
                        let allBadges    = viewModel.badgeManager.allBadges
                        let earnedCount  = allBadges.filter { $0.isUnlocked }.count

                        HStack {
                            Text("Badges")
                                .font(.title2.bold())
                            Spacer()
                            Text("\(earnedCount)/\(allBadges.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)

                        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(allBadges) { badge in
                                badgeCell(badge)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Color.clear.frame(height: 20)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Streak & Badges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Stat Card

    private func statCard(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title.bold())
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Badge Cell

    private func badgeCell(_ badge: Badge) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked
                          ? badge.type.primaryColor.opacity(0.15)
                          : Color(.tertiarySystemBackground))
                    .frame(width: 60, height: 60)

                Image(systemName: badge.type.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(badge.isUnlocked ? badge.type.primaryColor : .gray.opacity(0.3))
            }

            Text(badge.isUnlocked ? badge.title : "???")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(badge.isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if badge.isUnlocked {
                Text(rarityLabel(badge.rarity))
                    .font(.system(size: 8))
                    .foregroundColor(rarityColor(badge.rarity))
            }
        }
    }

    private func rarityColor(_ rarity: BadgeRarity) -> Color {
        switch rarity {
        case .common:    return .gray
        case .uncommon:  return .green
        case .rare:      return .blue
        case .epic:      return .purple
        case .legendary: return .orange
        }
    }

    private func rarityLabel(_ rarity: BadgeRarity) -> String {
        switch rarity {
        case .common:    return "Common"
        case .uncommon:  return "Uncommon"
        case .rare:      return "Rare"
        case .epic:      return "Epic"
        case .legendary: return "Legendary"
        }
    }
}
