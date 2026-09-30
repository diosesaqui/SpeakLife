//
//  UpNextQueueTests.swift
//  SpeakLifeCoreTests
//
//  The queue decides what plays next with the phone in a pocket, where a
//  wrong answer is an episode the listener never chose or a queue that
//  silently stalls. Every rule gets its own case.
//

import XCTest
@testable import SpeakLifeCore

final class UpNextQueueTests: XCTestCase {

    private func episode(_ name: String, premium: Bool = false) -> AudioDeclaration {
        AudioDeclaration(id: "\(name).mp3", title: name, subtitle: "", duration: "5:00",
                         imageUrl: "", isPremium: premium)
    }

    private func ids(_ queue: UpNextQueue) -> [String] {
        queue.items.map(\.title)
    }

    // MARK: - Adding

    func testPlayNextInsertsAtFront() {
        var queue = UpNextQueue()
        queue.add(episode("a"), placement: .last, nowPlayingId: nil)
        let result = queue.add(episode("b"), placement: .next, nowPlayingId: nil)
        XCTAssertEqual(result, .added(position: 0))
        XCTAssertEqual(ids(queue), ["b", "a"])
    }

    func testAddToQueueAppends() {
        var queue = UpNextQueue()
        queue.add(episode("a"), placement: .last, nowPlayingId: nil)
        let result = queue.add(episode("b"), placement: .last, nowPlayingId: nil)
        XCTAssertEqual(result, .added(position: 1))
        XCTAssertEqual(ids(queue), ["a", "b"])
    }

    func testRepeatedPlayNextStacksNewestFirst() {
        var queue = UpNextQueue()
        queue.add(episode("a"), placement: .next, nowPlayingId: nil)
        queue.add(episode("b"), placement: .next, nowPlayingId: nil)
        XCTAssertEqual(ids(queue), ["b", "a"])
    }

    func testCannotQueueTheEpisodeAlreadyPlaying() {
        var queue = UpNextQueue()
        let a = episode("a")
        XCTAssertEqual(queue.add(a, placement: .next, nowPlayingId: a.id), .isNowPlaying)
        XCTAssertTrue(queue.isEmpty)
    }

    func testRejectsNonAudioRecords() {
        var queue = UpNextQueue()
        let junk = AudioDeclaration(id: "test-row", title: "Test Audio", subtitle: "",
                                    duration: "", imageUrl: "", isPremium: false)
        XCTAssertEqual(queue.add(junk, placement: .last, nowPlayingId: nil), .notPlayable)
        XCTAssertTrue(queue.isEmpty)
    }

    func testPlayNextOnQueuedItemMovesItToFrontWithoutDuplicating() {
        var queue = UpNextQueue()
        queue.add(episode("a"), placement: .last, nowPlayingId: nil)
        queue.add(episode("b"), placement: .last, nowPlayingId: nil)
        XCTAssertEqual(queue.add(episode("b"), placement: .next, nowPlayingId: nil), .moved(position: 0))
        XCTAssertEqual(ids(queue), ["b", "a"])
    }

    func testPlayNextOnItemAlreadyFirstIsNoOp() {
        var queue = UpNextQueue()
        queue.add(episode("a"), placement: .last, nowPlayingId: nil)
        XCTAssertEqual(queue.add(episode("a"), placement: .next, nowPlayingId: nil), .alreadyQueued(position: 0))
        XCTAssertEqual(ids(queue), ["a"])
    }

    func testAddToQueueOnQueuedItemLeavesItInPlace() {
        var queue = UpNextQueue()
        queue.add(episode("a"), placement: .last, nowPlayingId: nil)
        queue.add(episode("b"), placement: .last, nowPlayingId: nil)
        XCTAssertEqual(queue.add(episode("a"), placement: .last, nowPlayingId: nil), .alreadyQueued(position: 0))
        XCTAssertEqual(ids(queue), ["a", "b"])
    }

    func testDuplicateDetectionIgnoresFavoriteMetadata() {
        // The same episode arrives from the favorites tab carrying favorite
        // fields the catalog copy lacks. Identity is the file id.
        var queue = UpNextQueue()
        queue.add(episode("a"), placement: .last, nowPlayingId: nil)
        var favorited = episode("a")
        favorited.isFavorite = true
        XCTAssertEqual(queue.add(favorited, placement: .last, nowPlayingId: nil), .alreadyQueued(position: 0))
        XCTAssertEqual(queue.count, 1)
    }

    func testCapacityIsEnforced() {
        var queue = UpNextQueue(capacity: 2)
        queue.add(episode("a"), placement: .last, nowPlayingId: nil)
        queue.add(episode("b"), placement: .last, nowPlayingId: nil)
        XCTAssertEqual(queue.add(episode("c"), placement: .next, nowPlayingId: nil), .full)
        XCTAssertEqual(ids(queue), ["a", "b"])
        // A move is not growth, so it still works at capacity.
        XCTAssertEqual(queue.add(episode("b"), placement: .next, nowPlayingId: nil), .moved(position: 0))
    }

    // MARK: - Popping

    func testPopNextReturnsAndRemovesHead() {
        var queue = UpNextQueue()
        queue.add(episode("a"), placement: .last, nowPlayingId: nil)
        queue.add(episode("b"), placement: .last, nowPlayingId: nil)
        let popped = queue.popNext()
        XCTAssertEqual(popped.next?.title, "a")
        XCTAssertTrue(popped.skipped.isEmpty)
        XCTAssertEqual(ids(queue), ["b"])
    }

    func testPopNextOnEmptyQueue() {
        var queue = UpNextQueue()
        let popped = queue.popNext()
        XCTAssertNil(popped.next)
        XCTAssertTrue(popped.skipped.isEmpty)
    }

    func testPopNextDropsLockedEpisodesAfterSubscriptionLapses() {
        var queue = UpNextQueue()
        queue.add(episode("locked1", premium: true), placement: .last, nowPlayingId: nil)
        queue.add(episode("locked2", premium: true), placement: .last, nowPlayingId: nil)
        queue.add(episode("free"), placement: .last, nowPlayingId: nil)
        queue.add(episode("locked3", premium: true), placement: .last, nowPlayingId: nil)

        let popped = queue.popNext(where: { !$0.isPremium })
        XCTAssertEqual(popped.next?.title, "free")
        XCTAssertEqual(popped.skipped.map(\.title), ["locked1", "locked2"])
        // Only what was ahead of the playable one is dropped.
        XCTAssertEqual(ids(queue), ["locked3"])
    }

    func testPopNextWhenNothingIsAllowedEmptiesQueue() {
        var queue = UpNextQueue()
        queue.add(episode("locked", premium: true), placement: .last, nowPlayingId: nil)
        let popped = queue.popNext(where: { !$0.isPremium })
        XCTAssertNil(popped.next)
        XCTAssertEqual(popped.skipped.count, 1)
        XCTAssertTrue(queue.isEmpty)
    }

    // MARK: - Editing

    func testRemoveById() {
        var queue = UpNextQueue()
        queue.add(episode("a"), placement: .last, nowPlayingId: nil)
        queue.add(episode("b"), placement: .last, nowPlayingId: nil)
        XCTAssertTrue(queue.remove(id: "a.mp3"))
        XCTAssertFalse(queue.remove(id: "missing.mp3"))
        XCTAssertEqual(ids(queue), ["b"])
    }

    func testRemoveAtOffsetsIgnoresOutOfRange() {
        var queue = UpNextQueue()
        ["a", "b", "c"].forEach { queue.add(episode($0), placement: .last, nowPlayingId: nil) }
        queue.remove(atOffsets: IndexSet([0, 2, 9]))
        XCTAssertEqual(ids(queue), ["b"])
    }

    func testMoveDownMatchesSwiftUISemantics() {
        // List.onMove dragging "a" below "c" reports destination 3.
        var queue = UpNextQueue()
        ["a", "b", "c", "d"].forEach { queue.add(episode($0), placement: .last, nowPlayingId: nil) }
        queue.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(ids(queue), ["b", "c", "a", "d"])
    }

    func testMoveUp() {
        var queue = UpNextQueue()
        ["a", "b", "c", "d"].forEach { queue.add(episode($0), placement: .last, nowPlayingId: nil) }
        queue.move(fromOffsets: IndexSet(integer: 3), toOffset: 1)
        XCTAssertEqual(ids(queue), ["a", "d", "b", "c"])
    }

    func testMoveToEnd() {
        var queue = UpNextQueue()
        ["a", "b", "c"].forEach { queue.add(episode($0), placement: .last, nowPlayingId: nil) }
        queue.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(ids(queue), ["b", "c", "a"])
    }

    func testMoveMultiple() {
        var queue = UpNextQueue()
        ["a", "b", "c", "d", "e"].forEach { queue.add(episode($0), placement: .last, nowPlayingId: nil) }
        queue.move(fromOffsets: IndexSet([0, 2]), toOffset: 4)
        XCTAssertEqual(ids(queue), ["b", "d", "a", "c", "e"])
    }

    func testMoveOutOfRangeIsNoOp() {
        var queue = UpNextQueue()
        ["a", "b"].forEach { queue.add(episode($0), placement: .last, nowPlayingId: nil) }
        queue.move(fromOffsets: IndexSet(integer: 7), toOffset: 0)
        XCTAssertEqual(ids(queue), ["a", "b"])
    }

    func testRemoveAll() {
        var queue = UpNextQueue()
        queue.add(episode("a"), placement: .last, nowPlayingId: nil)
        queue.removeAll()
        XCTAssertTrue(queue.isEmpty)
        XCTAssertNil(queue.next)
    }
}
