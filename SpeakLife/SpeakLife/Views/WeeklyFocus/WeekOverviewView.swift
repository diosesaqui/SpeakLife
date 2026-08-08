//
//  WeekOverviewView.swift
//  SpeakLife
//
//  The payoff.
//
//  Seven days, their own words at the top, every declaration already chosen.
//  This has to land the instant they submit — if answering feels like filling
//  in a form and the result feels generic, nobody answers a second Sunday.
//
//  Everything here is resolved locally from IDs the week already stores, so the
//  screen has no loading state and cannot fail.
//

import SwiftUI

struct WeekOverviewView: View {

    let focus: WeeklyFocus
    /// True when the answer arrived after days had already been consumed.
    let isPartialWeek: Bool
    let onCompleteDay: ((Int) -> Void)?
    let onMarkResolved: (() -> Void)?
    let onDone: (() -> Void)?

    /// id → declaration, for this week's IDs only. Resolved once at
    /// construction: the week stores IDs, and re-scanning the whole 3,000-line
    /// content set on every render (SwiftUI rebuilds this struct freely) would
    /// be the most expensive thing on the screen.
    private let declarationsByID: [String: Declaration]

    @State private var expandedDay: Int? = nil

    /// - Parameter declarations: the full shipped set, from
    ///   `DeclarationViewModel.allAvailableDeclarations`.
    init(focus: WeeklyFocus,
         declarations: [Declaration],
         isPartialWeek: Bool = false,
         onCompleteDay: ((Int) -> Void)? = nil,
         onMarkResolved: (() -> Void)? = nil,
         onDone: (() -> Void)? = nil) {
        self.focus = focus
        self.isPartialWeek = isPartialWeek
        self.onCompleteDay = onCompleteDay
        self.onMarkResolved = onMarkResolved
        self.onDone = onDone

        let wanted = Set(focus.declarationIDs)
        var resolved: [String: Declaration] = [:]
        resolved.reserveCapacity(wanted.count)
        for declaration in declarations where wanted.contains(declaration.id) {
            if resolved[declaration.id] == nil {
                resolved[declaration.id] = declaration
            }
        }
        self.declarationsByID = resolved
    }

    private var todayIndex: Int { focus.clampedDayIndex }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.04, blue: 0.14),
                    Color(red: 0.06, green: 0.10, blue: 0.24)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Spacing.md) {
                        header
                        ForEach(0..<7, id: \.self) { day in
                            dayRow(day)
                        }
                        resolvedButton
                        Spacer().frame(height: 16)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, 28)
                }

                if let onDone {
                    Button(action: onDone) {
                        Text("Let's Go")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(
                                Capsule().fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.2, green: 0.5, blue: 1.0),
                                                 Color(red: 0.4, green: 0.3, blue: 1.0)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                            )
                            .padding(.horizontal, DS.Spacing.lg)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.bottom, 28)
                }
            }
        }
        .onAppear { expandedDay = todayIndex }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Text(isPartialWeek ? "UPDATED FOR THE REST OF YOUR WEEK" : "YOUR WEEK")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.yellow.opacity(0.85))
                .kerning(1.3)
                .multilineTextAlignment(.center)

            if let needText = focus.needText, !needText.isEmpty {
                Text("\u{201C}\(needText)\u{201D}")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(focus.category?.name ?? "This week")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
        }
        .padding(.bottom, 6)
    }

    /// Names the angle rather than the source. "Week 2 on this, from a
    /// different side" is a promise the content actually keeps; "we picked this
    /// from your onboarding answers" is trivia.
    private var subtitle: String {
        switch focus.angle {
        case .promise:   return "Seven days of what God says about this."
        case .identity:  return "Week two. Same need, from who you already are."
        case .authority: return "Week three. This week you speak to it."
        case .escalate:  return "You've carried this a while. Let's go deeper."
        }
    }

    // MARK: - Day row

    @ViewBuilder
    private func dayRow(_ day: Int) -> some View {
        let ids = focus.declarationIDs(forDay: day)
        let isToday = day == todayIndex
        let isComplete = focus.completedDays.contains(day)
        let isExpanded = expandedDay == day

        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(DS.Motion.smooth) {
                    expandedDay = isExpanded ? nil : day
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isComplete ? Color.green.opacity(0.25) : Color.white.opacity(0.08))
                            .frame(width: 30, height: 30)
                        if isComplete {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.green)
                        } else {
                            Text("\(day + 1)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.dayName(day))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text("\(ids.count) declaration\(ids.count == 1 ? "" : "s")")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                    }

                    Spacer()

                    if isToday {
                        Text("TODAY")
                            .font(.system(size: 10, weight: .bold))
                            .kerning(0.8)
                            .foregroundColor(.yellow.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.yellow.opacity(0.15)))
                    }

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(ids, id: \.self) { id in
                        if let declaration = declarationsByID[id] {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(declaration.text)
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.92))
                                    .fixedSize(horizontal: false, vertical: true)
                                if let book = declaration.book, !book.isEmpty {
                                    Text(book)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.42))
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if !isComplete, let onCompleteDay {
                        Button {
                            onCompleteDay(day)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("I spoke these")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsGlass(cornerRadius: DS.Radius.md, strokeOpacity: isToday ? 0.32 : 0.14)
    }

    // MARK: - Resolved

    @ViewBuilder
    private var resolvedButton: some View {
        if focus.needText != nil, focus.resolvedAt == nil, let onMarkResolved {
            Button(action: onMarkResolved) {
                Text("God answered this")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.vertical, 10)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Day names

    /// Sunday-first, matching `weekStart`. `Calendar.weekdaySymbols` is always
    /// indexed Sunday-first regardless of `firstWeekday`, and it is localized —
    /// so a French user reads "dimanche" against the same day 0.
    private static func dayName(_ day: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        guard symbols.count == 7, (0...6).contains(day) else { return "Day \(day + 1)" }
        return symbols[day]
    }
}
