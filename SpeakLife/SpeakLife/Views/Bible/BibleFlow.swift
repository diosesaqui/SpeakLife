//
//  BibleFlow.swift
//  SpeakLife
//
//  One navigation stack for the whole Bible feature.
//

import SwiftUI

/// A screen inside the Bible feature.
enum BibleSurface: Hashable {
    /// Live AI conversation.
    case chat
    /// "Ask the Bible" — the curated topic picker.
    case topics
    /// A topic's scripture-rooted answer.
    case answer(BibleChatTopic)
    /// The full Bible reader. The passage it opens on lives on the navigator
    /// rather than in the case, so returning to a reader that's already on
    /// screen retargets it instead of pushing a second copy.
    case reader
}

/// Owns navigation for the Bible feature.
///
/// The surfaces form a cycle: chat → reader → "Ask the Bible" → answer →
/// tapped verse → reader → … Every hop used to present its own sheet on top of
/// its own `NavigationView`, so one lap stacked a second navigation bar and
/// buried the user under a deck of duplicate screens to back out of.
///
/// Here every hop goes through `open(_:)`, which pushes a screen that isn't
/// showing yet and *unwinds* to one that is. A lap of the cycle walks back to
/// the screen it started from, and the stack never holds two copies of the
/// same surface.
@MainActor
final class BibleNavigator: ObservableObject {
    /// The screen the stack sits on, chosen by whichever entry point opened
    /// the flow.
    let root: BibleSurface

    @Published var path: [BibleSurface] = []

    /// The passage the reader should show. A reader being pushed reads it at
    /// init; one already on screen observes it and jumps.
    @Published var readerReference: String?

    init(root: BibleSurface, readerReference: String? = nil) {
        self.root = root
        self.readerReference = readerReference
    }

    /// Navigate to `surface`, returning to it if it's already on screen.
    func open(_ surface: BibleSurface) {
        // The root sits below everything, so returning to it means emptying
        // the stack.
        if isSameSurface(root, surface) {
            path.removeAll()
            return
        }
        if let index = path.lastIndex(where: { isSameSurface($0, surface) }) {
            // Already on screen: unwind back down to it, replacing it so a new
            // payload (a different topic) takes effect.
            path.replaceSubrange(index..., with: [surface])
            return
        }
        path.append(surface)
    }

    /// Open the reader on `reference`, or on the book list when it's nil.
    func openReader(reference: String? = nil) {
        readerReference = reference
        open(.reader)
    }

    /// Screen identity, ignoring payload: the answer for one topic and the
    /// answer for another are the same screen, so one replaces the other
    /// instead of stacking.
    private func isSameSurface(_ lhs: BibleSurface, _ rhs: BibleSurface) -> Bool {
        switch (lhs, rhs) {
        case (.chat, .chat), (.topics, .topics), (.reader, .reader), (.answer, .answer):
            return true
        default:
            return false
        }
    }
}

/// The Bible feature's entry point. Presenters show this and pick the surface
/// it opens on; from there the surfaces navigate among themselves inside this
/// one stack, so each keeps its own entry points without stacking modals.
struct BibleFlowView: View {
    @StateObject private var navigator: BibleNavigator

    init(root: BibleSurface, readerReference: String? = nil) {
        _navigator = StateObject(
            wrappedValue: BibleNavigator(root: root, readerReference: readerReference)
        )
    }

    var body: some View {
        NavigationStack(path: $navigator.path) {
            // Root vs pushed is fixed per surface, so it's read from the
            // environment rather than from the live path — deriving it from
            // `path.isEmpty` would drop a surface's close button halfway
            // through the push animation that covers it.
            surface(navigator.root)
                .environment(\.bibleSurfaceIsRoot, true)
                .navigationDestination(for: BibleSurface.self) { destination in
                    surface(destination)
                        .environment(\.bibleSurfaceIsRoot, false)
                }
        }
        .environmentObject(navigator)
        // The Bible feature is built for the app's forced-dark theme (verse
        // text uses .primary, backgrounds use systemBackground). Presented in a
        // sheet it no longer inherits the presenter's scheme, so pin it here or
        // text renders black on a white header.
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func surface(_ destination: BibleSurface) -> some View {
        switch destination {
        case .chat:
            BibleChatConversationView()
        case .topics:
            BibleChatView()
        case .answer(let topic):
            BibleChatAnswerView(topic: topic)
        case .reader:
            BibleView(initialReference: navigator.readerReference)
        }
    }
}

// MARK: - Root surface

private struct BibleSurfaceIsRootKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True for the surface the flow opened on. It's presented rather than
    /// pushed, so it carries a close button where every surface above it gets
    /// the stack's back button.
    var bibleSurfaceIsRoot: Bool {
        get { self[BibleSurfaceIsRootKey.self] }
        set { self[BibleSurfaceIsRootKey.self] = newValue }
    }
}
