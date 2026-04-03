//
//  DeclarationsCounterView.swift
//  SpeakLife
//
//  Reusable UI components that display the declarations counter.
//  Place DeclarationsCounterBadge in ProfileView (prominent)
//  and DeclarationsInlineStat in DayCelebrationView.
//

import SwiftUI

// MARK: - DeclarationsCounterBadge
/// Prominent card showing lifetime + today declarations.
/// Used in ProfileView alongside the streak stats row.
struct DeclarationsCounterBadge: View {
    @ObservedObject var service: DeclarationsCounterService = .shared
    var showToday: Bool = true

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "flame.fill")
                .font(.title)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.formattedLifetime)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("Lifetime Declarations")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if showToday, service.todayCount > 0 {
                    Text("Today: \(service.formattedToday) 🔥")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - DeclarationsInlineStat
/// Compact single-line stat for use inside DayCelebrationView.
/// Displays: "Today: 7.  Lifetime: 1,247 🔥"
struct DeclarationsInlineStat: View {
    @ObservedObject var service: DeclarationsCounterService = .shared

    var body: some View {
        Group {
            if service.lifetimeCount > 0 {
                Text("Today: \(service.formattedToday).  Lifetime: \(service.formattedLifetime) 🔥")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DeclarationsCounterView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            DeclarationsCounterBadge()
            DeclarationsInlineStat()
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
