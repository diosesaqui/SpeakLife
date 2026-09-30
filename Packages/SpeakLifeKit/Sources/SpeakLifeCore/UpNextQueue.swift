//
//  UpNextQueue.swift
//  SpeakLifeCore
//
//  The listener's "Up Next" list for the Meditation tab. A plain value type so
//  every queue rule lives in one place and runs under `swift test`.
//  `AudioPlayerViewModel` owns one and does the downloading and AVPlayer work
//  around it.
//
//  The queue never holds the episode that is playing right now. Popping an
//  item hands it to the player and removes it, so "Up Next" always means
//  "after this one".
//

import Foundation

public struct UpNextQueue: Equatable {
    /// Well past any real listening session. The cap only exists so a stuck
    /// gesture can't grow the list without bound.
    public static let defaultCapacity = 50

    public enum Placement: String {
        /// Plays right after the current episode.
        case next
        /// Plays after everything already queued.
        case last
    }

    public enum AddResult: Equatable {
        /// Inserted at this 0-based position.
        case added(position: Int)
        /// Was already queued further back; "Play Next" pulled it to the front.
        case moved(position: Int)
        /// Already queued where it was asked to go (or "Add to Queue" on an
        /// item that is already waiting). Left untouched.
        case alreadyQueued(position: Int)
        /// It is the episode playing right now.
        case isNowPlaying
        /// Not a real audio file (schema-priming rows, see `isPlayableAudio`).
        case notPlayable
        case full
    }

    public private(set) var items: [AudioDeclaration] = []
    public let capacity: Int

    public init(capacity: Int = UpNextQueue.defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    public var isEmpty: Bool { items.isEmpty }
    public var count: Int { items.count }
    public var next: AudioDeclaration? { items.first }

    public func contains(_ id: String) -> Bool {
        items.contains { $0.id == id }
    }

    public func position(of id: String) -> Int? {
        items.firstIndex { $0.id == id }
    }

    @discardableResult
    public mutating func add(_ item: AudioDeclaration,
                             placement: Placement,
                             nowPlayingId: String?) -> AddResult {
        guard item.isPlayableAudio else { return .notPlayable }
        guard item.id != nowPlayingId else { return .isNowPlaying }

        // One entry per episode. Playing the same episode twice in a row is
        // what the repeat button is for.
        if let existing = position(of: item.id) {
            switch placement {
            case .next:
                guard existing != 0 else { return .alreadyQueued(position: 0) }
                let moved = items.remove(at: existing)
                items.insert(moved, at: 0)
                return .moved(position: 0)
            case .last:
                return .alreadyQueued(position: existing)
            }
        }

        guard items.count < capacity else { return .full }

        switch placement {
        case .next:
            items.insert(item, at: 0)
            return .added(position: 0)
        case .last:
            items.append(item)
            return .added(position: items.count - 1)
        }
    }

    @discardableResult
    public mutating func remove(id: String) -> Bool {
        guard let index = position(of: id) else { return false }
        items.remove(at: index)
        return true
    }

    public mutating func remove(atOffsets offsets: IndexSet) {
        for index in offsets.sorted(by: >) where items.indices.contains(index) {
            items.remove(at: index)
        }
    }

    /// Same contract as SwiftUI's `move(fromOffsets:toOffset:)`, which
    /// `List.onMove` hands us: `destination` is an index in the list as it
    /// was before the move. Reimplemented because that helper lives in
    /// SwiftUI and this package is Foundation-only.
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let valid = source.filter { items.indices.contains($0) }.sorted()
        guard !valid.isEmpty else { return }
        let moving = valid.map { items[$0] }
        let removedBeforeDestination = valid.filter { $0 < destination }.count
        for index in valid.reversed() {
            items.remove(at: index)
        }
        let insertAt = min(max(destination - removedBeforeDestination, 0), items.count)
        items.insert(contentsOf: moving, at: insertAt)
    }

    public mutating func removeAll() {
        items.removeAll()
    }

    /// Removes and returns the first queued episode `isAllowed` accepts.
    /// Everything ahead of it that `isAllowed` rejects (a premium episode
    /// queued before the subscription lapsed) is dropped and returned in
    /// `skipped`, so it neither plays nor blocks the rest of the queue.
    public mutating func popNext(
        where isAllowed: (AudioDeclaration) -> Bool = { _ in true }
    ) -> (next: AudioDeclaration?, skipped: [AudioDeclaration]) {
        var skipped: [AudioDeclaration] = []
        while !items.isEmpty {
            let candidate = items.removeFirst()
            if isAllowed(candidate) {
                return (candidate, skipped)
            }
            skipped.append(candidate)
        }
        return (nil, skipped)
    }
}
