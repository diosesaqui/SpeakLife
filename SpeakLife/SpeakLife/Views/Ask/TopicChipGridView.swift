//
//  TopicChipGridView.swift
//  SpeakLife
//
//  Animated multi-select topic chip grid for the Ask tab.
//  Up to 3 topics selectable, with spring animations and haptic feedback.
//

import SwiftUI

struct TopicChipGridView: View {
    @ObservedObject var viewModel: AskViewModel
    
    // Staggered appear animation tracking
    @State private var appeared: Set<Int> = []
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            FlowLayout(spacing: 10) {
                ForEach(Array(AskViewModel.availableTopics.enumerated()), id: \.element.id) { index, topic in
                    TopicChip(
                        topic: topic,
                        isSelected: viewModel.isSelected(topic),
                        isDisabled: !viewModel.isSelected(topic) && !viewModel.canSelectMore,
                        appeared: appeared.contains(index)
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                            viewModel.toggleTopic(topic)
                        }
                        PremiumHaptics.light()
                    }
                    .onAppear {
                        let delay = Double(index) * 0.035
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                appeared.insert(index)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Single Chip

struct TopicChip: View {
    let topic: DeclarationCategory
    let isSelected: Bool
    let isDisabled: Bool
    let appeared: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: topic.chipIcon)
                    .font(.system(size: 12, weight: .semibold))
                Text(topic.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(chipBackground)
            .clipShape(Capsule())
            .overlay(chipBorder)
            .opacity(isDisabled ? 0.4 : 1.0)
            .scaleEffect(isPressed ? 0.94 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled && !isSelected)
        .scaleEffect(appeared ? 1.0 : 0.6)
        .opacity(appeared ? 1.0 : 0.0)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isPressed)
    }
    
    @ViewBuilder
    var chipBackground: some View {
        if isSelected {
            LinearGradient(
                colors: [Constants.DAMidBlue, Constants.DADarkBlue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.white.opacity(0.12)
        }
    }
    
    @ViewBuilder
    var chipBorder: some View {
        if isSelected {
            Capsule()
                .strokeBorder(Constants.DAMidBlue.opacity(0.6), lineWidth: 1.5)
        } else {
            Capsule()
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.size.height }.max() ?? 0 }.reduce(0) { $0 + $1 + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(height, 0))
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.size.height }.max() ?? 0
            var x = bounds.minX
            for item in row {
                item.view.place(at: CGPoint(x: x, y: y + (rowHeight - item.size.height) / 2), proposal: .unspecified)
                x += item.size.width + spacing
            }
            y += rowHeight + spacing
        }
    }
    
    private struct RowItem {
        let view: LayoutSubview
        let size: CGSize
    }
    
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[RowItem]] {
        let maxWidth = proposal.width ?? 320
        var rows: [[RowItem]] = []
        var currentRow: [RowItem] = []
        var currentX: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = [RowItem(view: view, size: size)]
                currentX = size.width + spacing
            } else {
                currentRow.append(RowItem(view: view, size: size))
                currentX += size.width + spacing
            }
        }
        if !currentRow.isEmpty { rows.append(currentRow) }
        return rows
    }
}

// MARK: - Category Icon Extension

extension DeclarationCategory {
    var chipIcon: String {
        switch self {
        case .love: return "heart.fill"
        case .identity: return "person.fill"
        case .faith: return "sparkles"
        case .grace: return "hands.sparkles.fill"
        case .rest: return "moon.stars.fill"
        case .hope: return "sun.horizon.fill"
        case .joy: return "face.smiling.fill"
        case .wisdom: return "lightbulb.fill"
        case .praise: return "music.note"
        case .destiny: return "star.fill"
        case .warfare: return "shield.fill"
        case .miracles: return "wand.and.stars"
        case .health: return "heart.text.square.fill"
        case .innerHealing: return "bandage.fill"
        case .obedience: return "checkmark.seal.fill"
        case .purity: return "drop.fill"
        case .gratitude: return "gift.fill"
        case .marriage: return "figure.2.and.child.holdinghands"
        case .parenting: return "figure.and.child.holdinghands"
        case .friendship: return "person.2.fill"
        case .godsprotection: return "lock.shield.fill"
        case .favor: return "crown.fill"
        case .wealth: return "dollarsign.circle.fill"
        case .work: return "briefcase.fill"
        case .anxiety: return "brain.fill"
        case .fear: return "exclamationmark.triangle.fill"
        case .hardtimes: return "cloud.rain.fill"
        case .addiction: return "arrow.triangle.2.circlepath"
        case .heaven: return "cloud.sun.fill"
        default: return "circle.fill"
        }
    }
}
