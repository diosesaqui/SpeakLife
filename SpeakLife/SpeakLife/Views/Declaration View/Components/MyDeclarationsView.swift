//
//  MyDeclarationsView.swift
//  SpeakLife
//
//  Every thing the user is believing God for, in one place.
//
//  Free users anchor on a single declaration. Premium users can carry one for
//  each burden they're praying over — a healing, a marriage, a child, a job —
//  so the daily habit covers their whole life instead of one slice of it.
//

import SwiftUI

struct MyDeclarationsView: View {

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @Environment(\.dismiss) private var dismiss

    /// Opened straight onto this declaration's card (notification deep link).
    var initialDeclarationId: UUID? = nil

    @State private var active: [PersonalDeclaration] = []
    @State private var answered: [PersonalDeclaration] = []
    @State private var isLoading = true

    @State private var selectedDeclaration: PersonalDeclaration?
    @State private var breakthroughDeclaration: PersonalDeclaration?
    @State private var declarationPendingRemoval: PersonalDeclaration?
    @State private var showAddSheet = false
    @State private var showPremium = false
    /// The deep link opens its card exactly once. Without this, dismissing that
    /// card would trigger a reload that re-opened it.
    @State private var didHandleDeepLink = false
    @State private var warriorRoomTestimonyPrefill: WarriorRoomTestimonyPrefill?

    private let gold = Color(red: 1, green: 0.82, blue: 0.28)

    private var maxDeclarations: Int {
        PersonalDeclarationLimits.maxDeclarations(isPremium: subscriptionStore.isPremium)
    }

    private var canAddAnother: Bool {
        active.count < maxDeclarations
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Color(red: 0.07, green: 0.08, blue: 0.14).ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if isLoading {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                } else if active.isEmpty && answered.isEmpty {
                    emptyState
                } else {
                    list
                }

                addButton
            }
        }
        .task { await reload() }
        .onAppear {
            AnalyticsService.shared.track("my_declarations_opened")
        }
        // The full speak-it card for one declaration. Speaking it advances that
        // record's counters, so re-read the list on the way out.
        .sheet(item: $selectedDeclaration, onDismiss: { Task { await reload() } }) { declaration in
            PersonalDeclarationCard(declaration: declaration) {
                selectedDeclaration = nil
                // Let the card finish dismissing before raising the celebration.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    breakthroughDeclaration = declaration
                }
            }
        }
        .fullScreenCover(item: $breakthroughDeclaration) { declaration in
            BreakthroughFlowView(
                declaration: declaration,
                onDismiss: {
                    breakthroughDeclaration = nil
                    Task { await reload() }
                },
                onSetNew: {
                    breakthroughDeclaration = nil
                    Task { @MainActor in
                        await reload()
                        startAdding()
                    }
                },
                onShareToWarriorRoom: { prefill in
                    warriorRoomTestimonyPrefill = WarriorRoomTestimonyPrefill(text: prefill)
                }
            )
            .environmentObject(appState)
        }
        .sheet(item: $warriorRoomTestimonyPrefill) { prefill in
            WarriorRoomTestimonyComposer(
                initialText: prefill.text,
                initialIsTestimony: true
            )
            .environmentObject(subscriptionStore)
        }
        .fullScreenCover(isPresented: $showAddSheet) {
            GeometryReader { geo in
                PersonalDeclarationOnboardingView(
                    viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                    size: geo.size,
                    flow: "my_declarations",
                    limit: maxDeclarations
                ) { newDeclaration in
                    if newDeclaration != nil {
                        appState.hasPersonalDeclaration = true
                    }
                    showAddSheet = false
                    Task { await reload() }
                }
                .environmentObject(appState)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPremium) {
            PremiumView()
                .environmentObject(subscriptionStore)
                .environmentObject(appState)
        }
        .alert("Stop believing for this?", isPresented: removalAlertBinding) {
            Button("Cancel", role: .cancel) { declarationPendingRemoval = nil }
            Button("Remove", role: .destructive) { confirmRemoval() }
        } message: {
            Text("This removes it from your daily declarations and cancels its reminder. If God already came through, use \"It Came to Pass\" instead so your testimony is saved.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            ZStack {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)

                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Close")
                }
            }
            .padding(.top, 12)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🙌 WHAT I'M BELIEVING FOR")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(gold)
                    Text(headline)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                if !active.isEmpty {
                    Text("\(active.count) of \(maxDeclarations)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 18)
        }
    }

    private var headline: String {
        switch active.count {
        case 0:  return "Nothing on the altar yet"
        case 1:  return "One thing, every day"
        default: return "\(active.count) things, every day"
        }
    }

    // MARK: - List

    private var list: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                ForEach(active) { declaration in
                    DeclarationRow(declaration: declaration, isAnswered: false) {
                        selectedDeclaration = declaration
                    }
                    .contextMenu {
                        Button {
                            breakthroughDeclaration = declaration
                        } label: {
                            Label("It Came to Pass", systemImage: "checkmark.circle.fill")
                        }
                        Button(role: .destructive) {
                            declarationPendingRemoval = declaration
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }

                if !answered.isEmpty {
                    HStack(spacing: 8) {
                        Text("ANSWERED")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundColor(Color(red: 0.3, green: 0.9, blue: 0.55).opacity(0.8))
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 1)
                    }
                    .padding(.top, 18)

                    ForEach(answered) { declaration in
                        // Answered declarations are a record, not a task —
                        // nothing to speak, nothing to tap.
                        DeclarationRow(declaration: declaration, isAnswered: true, onTap: nil)
                    }
                }

                Color.clear.frame(height: 12)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("🙏").font(.system(size: 52))
            Text("Name what you're trusting God for.")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("SpeakLife turns it into a declaration and\nbrings it back to you every day.")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Add Button

    @ViewBuilder
    private var addButton: some View {
        VStack(spacing: 8) {
            Button(action: startAdding) {
                HStack(spacing: 8) {
                    Image(systemName: canAddAnother ? "plus.circle.fill" : "crown.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(addButtonTitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.38, green: 0.35, blue: 0.95),
                                     Color(red: 0.55, green: 0.35, blue: 0.95)],
                            startPoint: .leading, endPoint: .trailing))
                )
                .shadow(color: Color(red: 0.38, green: 0.35, blue: 0.95).opacity(0.4),
                        radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 24)

            // Only says something when it's actually informative.
            if let hint = limitHint {
                Text(hint)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 28)
    }

    private var addButtonTitle: String {
        if active.isEmpty { return "Add My Declaration" }
        if canAddAnother { return "Add Another" }
        return subscriptionStore.isPremium ? "You're At Your Limit" : "Unlock More Declarations"
    }

    private var limitHint: String? {
        guard !canAddAnother else { return nil }
        if subscriptionStore.isPremium {
            return "You're carrying \(maxDeclarations). Mark one answered to add another."
        }
        return "Premium lets you believe for up to \(PersonalDeclarationLimits.premium) things at once."
    }

    // MARK: - Actions

    private func startAdding() {
        guard canAddAnother else {
            if subscriptionStore.isPremium {
                Juice.play(.warning)
            } else {
                AnalyticsService.shared.track("my_declarations_paywall_shown", parameters: [
                    "active_count": active.count
                ])
                showPremium = true
            }
            return
        }
        showAddSheet = true
    }

    private var removalAlertBinding: Binding<Bool> {
        Binding(
            get: { declarationPendingRemoval != nil },
            set: { if !$0 { declarationPendingRemoval = nil } }
        )
    }

    private func confirmRemoval() {
        guard let declaration = declarationPendingRemoval else { return }
        declarationPendingRemoval = nil
        Task {
            let remaining = try? await DIContainer.shared.makeDeleteDeclarationUseCase().execute(
                id: declaration.id,
                startTimeIndex: appState.personalDeclarationTimeIndex
            )
            await MainActor.run {
                appState.hasPersonalDeclaration = !(remaining ?? []).isEmpty
                AnalyticsService.shared.track("personal_declaration_removed", parameters: [
                    "days_believed": declaration.dayCount as NSNumber
                ])
            }
            await reload()
        }
    }

    private func reload() async {
        let all = await DIContainer.shared.personalDeclarationRepository.loadAll()
        await MainActor.run {
            active = all.filter { !$0.isReceived }
            // Most recent breakthrough first — the testimony worth re-reading.
            answered = all.filter(\.isReceived).sorted {
                ($0.receivedDate ?? .distantPast) > ($1.receivedDate ?? .distantPast)
            }
            appState.hasPersonalDeclaration = !active.isEmpty
            isLoading = false

            // Notification deep link — open the exact declaration that fired.
            if !didHandleDeepLink, let initialDeclarationId = initialDeclarationId {
                didHandleDeepLink = true
                if let match = all.first(where: { $0.id == initialDeclarationId }) {
                    selectedDeclaration = match
                }
            }
        }
    }
}

// MARK: - Row

private struct DeclarationRow: View {
    let declaration: PersonalDeclaration
    let isAnswered: Bool
    /// nil renders the row as a plain, non-interactive record.
    let onTap: (() -> Void)?

    private let gold = Color(red: 1, green: 0.82, blue: 0.28)
    private let green = Color(red: 0.3, green: 0.9, blue: 0.55)

    private var accent: Color { isAnswered ? green : gold }

    @ViewBuilder
    var body: some View {
        if let onTap = onTap {
            Button(action: {
                Juice.play(.tapLight)
                onTap()
            }) {
                card
            }
            .buttonStyle(.dsPressable(feel: .tapLight, haptics: false))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
        } else {
            card
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(declaration.category?.focusEmoji ?? "🙏")
                    .font(.system(size: 15))
                Text(declaration.category?.focusTitle ?? "Faith")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundColor(accent)
                Spacer()
                statusBadge
            }

            Text(declaration.declarationText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(isAnswered ? 0.65 : 1))
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            // The testimony is the reason an answered declaration stays on the
            // list at all — show it rather than a dead "speak it" affordance.
            if isAnswered, let testimony = declaration.testimony, !testimony.isEmpty {
                Text("\u{201C}\(testimony)\u{201D}")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 6) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 11))
                    .foregroundColor(accent.opacity(0.8))
                Text(declaration.verseReference)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                if !isAnswered {
                    HStack(spacing: 5) {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Speak it")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(gold)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(accent.opacity(isAnswered ? 0.2 : 0.25), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var statusBadge: some View {
        if isAnswered {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                Text("Answered")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundColor(green)
        } else {
            HStack(spacing: 5) {
                if declaration.spokenToday {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(green)
                }
                Text("Day \(declaration.dayCount)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }

    private var accessibilityLabel: String {
        if isAnswered {
            return "Answered. \(declaration.declarationText)"
        }
        let spoken = declaration.spokenToday ? "Spoken today." : "Not spoken yet today."
        return "Day \(declaration.dayCount). \(spoken) \(declaration.declarationText)"
    }
}
