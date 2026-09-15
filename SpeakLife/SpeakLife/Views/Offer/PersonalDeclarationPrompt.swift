//
//  PersonalDeclarationPrompt.swift
//  SpeakLife
//
//  Asks for the user's own declaration AFTER their first Daily Burst, instead
//  of during onboarding.
//
//  WHY IT MOVED
//
//  Onboarding asked people to compose their own declaration before they had
//  ever heard one. Over 30 days that screen was shown to 571 people: 249 saved
//  (43.6%), 223 skipped (39.1%), and 136 (23.8%) did neither — they abandoned
//  onboarding on it. In the `direct` arm, where it is the FIRST screen, 40 of
//  101 fell into the pain-fallback recovery path and 34 into the retry.
//
//  The problem was never the copy. There was no model to copy. After a Burst
//  they have spoken seven declarations out loud and have seven examples of the
//  form sitting in their mouth, which is the whole argument for the move.
//
//  The screen itself is unchanged. `PersonalDeclarationOnboardingView` already
//  supported an in-app surface (`flow: "app"`, reached from the breakthrough
//  flow); this only adds a new moment to present it from.
//
//  ⚠️ ONE PROMPT PER MOMENT. The welcome offer also fires after a Burst, so
//  these two would otherwise land on the same tap. They are separated by day
//  rather than by priority: this asks on the user's FIRST Burst day, and
//  `WelcomeOfferPresenter` arms from the SECOND onward. Coming back for a
//  second day is also a stronger buy signal than finishing a first, so the
//  offer is not merely deferred, it is better placed.
//

import SwiftUI

@MainActor
final class PersonalDeclarationPrompt: ObservableObject {

    static let shared = PersonalDeclarationPrompt()

    @Published var isPresented = false

    /// Asked at most once, ever. Someone who dismisses it can still set a
    /// declaration from My Declarations, and we do not chase them.
    private let askedKey = "personalDeclarationPromptAsked"

    private init() {}

    private var hasAsked: Bool { UserDefaults.standard.bool(forKey: askedKey) }

    /// True while this is on screen. Read by `WelcomeOfferPresenter` so the two
    /// can never both fire on one Burst.
    var isPendingOrShowing: Bool { isPresented }

    /// Whether the user already has a declaration.
    ///
    /// Reads the key behind `AppState.hasPersonalDeclaration`, which is an
    /// `@AppStorage("hasPersonalDeclaration")`, rather than taking AppState as
    /// a parameter: AppState is an environment object and the Burst view it
    /// would have to come from does not have it injected at either callsite.
    /// Same storage, same value, no callsite change.
    private var hasDeclaration: Bool {
        UserDefaults.standard.bool(forKey: "hasPersonalDeclaration")
    }

    /// Call on the way out of the first Daily Burst.
    func presentIfOwed(burstDayCount: Int) {
        guard burstDayCount == 1, !hasAsked, !hasDeclaration else { return }
        UserDefaults.standard.set(true, forKey: askedKey)
        isPresented = true
    }

    func dismiss() { isPresented = false }
}

// MARK: - Presentation

/// Hosted by the views that present the Burst, for the same reason the welcome
/// offer is: a cover raised from an ancestor while a descendant's cover is
/// still on screen is dropped silently.
struct PersonalDeclarationPromptModifier: ViewModifier {

    @ObservedObject private var prompt = PersonalDeclarationPrompt.shared
    @EnvironmentObject private var appState: AppState

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $prompt.isPresented) {
                GeometryReader { geo in
                    PersonalDeclarationOnboardingView(
                        viewModel: DIContainer.shared.makePersonalDeclarationViewModel(),
                        size: geo.size,
                        flow: "post_burst"
                    ) { saved in
                        if saved != nil { appState.hasPersonalDeclaration = true }
                        prompt.dismiss()
                    }
                    .environmentObject(appState)
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    /// Attach wherever `DailyDeclarationBurstView` is presented from.
    func personalDeclarationPrompt() -> some View {
        modifier(PersonalDeclarationPromptModifier())
    }
}
