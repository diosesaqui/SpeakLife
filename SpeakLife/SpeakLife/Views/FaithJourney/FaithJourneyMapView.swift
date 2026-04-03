//
//  FaithJourneyMapView.swift
//  SpeakLife
//
//  Visual 21-node winding path map for the 21-Day Faith Journey.
//  Layout: 3 columns × 7 rows, direction alternates each row (snake path).
//

import SwiftUI

// MARK: - FaithJourneyMapView

struct FaithJourneyMapView: View {

    @ObservedObject var viewModel: FaithJourneyViewModel
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                pathSection
                    .padding(.horizontal, 20)

                if viewModel.activeJourney == nil {
                    startSection
                        .padding(.top, 36)
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 40)
            }
            .padding(.top, 24)
        }
        .navigationTitle("Faith Journey")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $viewModel.showCategoryPicker) {
            FaithJourneyCategoryPickerView(viewModel: viewModel)
        }
        .alert(item: $viewModel.currentMilestone) { milestone in
            Alert(
                title: Text(milestone.title),
                message: Text(milestone.message),
                dismissButton: .default(Text("Amazing! 🙌"))
            )
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            if let journey = viewModel.activeJourney {
                Text(journey.categoryName)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("Day \(journey.currentDay) of 21")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ProgressView(value: journey.progressPercent)
                    .progressViewStyle(.linear)
                    .tint(.orange)
                    .frame(maxWidth: 280)
                    .padding(.top, 4)

                Text("\(journey.completedDays.count) / 21 days completed")
                    .font(.caption)
                    .foregroundColor(.secondary)

            } else {
                Image(systemName: "map.fill")
                    .font(.system(size: 44))
                    .foregroundColor(.orange.opacity(0.7))
                    .padding(.bottom, 4)

                Text("21-Day Faith Journey")
                    .font(.title2.bold())

                Text("Choose a category and commit to 21 days of speaking life")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Path (3 × 7 snake grid)

    private var pathSection: some View {
        let journey = viewModel.activeJourney
        let completed = journey?.completedDaySet ?? []
        let current   = journey?.currentDay ?? 0

        return VStack(spacing: 24) {
            ForEach(0..<7, id: \.self) { row in
                let reversed = row % 2 == 1
                let days: [Int] = (0..<3).map { col in
                    row * 3 + (reversed ? (2 - col) : col) + 1
                }
                HStack(spacing: 20) {
                    ForEach(days, id: \.self) { day in
                        JourneyNodeView(
                            day: day,
                            isCompleted: completed.contains(day),
                            isCurrent:   day == current && journey != nil,
                            isLocked:    day > current || journey == nil
                        )
                    }
                }
            }
        }
    }

    // MARK: - Start CTA

    private var startSection: some View {
        VStack(spacing: 16) {
            Text("Ready to begin?")
                .font(.headline)
            Text("Pick a category to start your 21-day commitment.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                viewModel.showCategoryPicker = true
            } label: {
                Label("Choose My Journey", systemImage: "arrow.right.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.orange)
                    )
            }
        }
    }
}

// MARK: - JourneyNodeView

struct JourneyNodeView: View {

    let day: Int
    let isCompleted: Bool
    let isCurrent: Bool
    let isLocked: Bool

    private var isMilestone: Bool { day == 7 || day == 14 || day == 21 }
    private var size: CGFloat     { isMilestone ? 54 : 46 }

    var body: some View {
        ZStack {
            Circle()
                .fill(background)
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(border, lineWidth: isCurrent ? 3 : 1))
                .shadow(color: isCurrent ? Color.orange.opacity(0.45) : .clear, radius: 10, y: 4)

            nodeContent
        }
        .scaleEffect(isCurrent ? 1.12 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isCurrent)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var nodeContent: some View {
        if isCompleted {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
        } else if isMilestone {
            Image(systemName: milestoneIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isLocked ? .gray : .orange)
        } else {
            Text("\(day)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isLocked ? .gray : .primary)
        }
    }

    private var background: Color {
        if isCompleted { return .orange }
        if isCurrent   { return Color.orange.opacity(0.18) }
        if isLocked    { return Color(.systemGray5) }
        return Color(.systemGray6)
    }

    private var border: Color {
        if isCompleted || isCurrent { return .orange }
        return Color(.systemGray4)
    }

    private var milestoneIcon: String {
        switch day {
        case 7:  return "medal.fill"
        case 14: return "music.note"
        case 21: return "crown.fill"
        default: return "star.fill"
        }
    }

    private var accessibilityLabel: String {
        if isCompleted { return "Day \(day) — completed" }
        if isCurrent   { return "Day \(day) — today" }
        if isLocked    { return "Day \(day) — locked" }
        return "Day \(day)"
    }
}

// MARK: - Previews

#if DEBUG
struct FaithJourneyMapView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FaithJourneyMapView(viewModel: FaithJourneyViewModel())
        }
    }
}
#endif
