//
//  MessageBodyFormatterTests.swift
//  SpeakLifeCoreTests
//
//  The reader's job is to be legible, so this file covers the two ways that
//  fails: text that arrives with its breaks intact and gets mangled anyway, and
//  text that arrives as one run and gets left that way.
//

import XCTest
@testable import SpeakLifeCore

final class MessageBodyFormatterTests: XCTestCase {

    /// The message from the bug report: composed in paragraphs, delivered flat.
    private let flattenedBroadcast = """
    "This is the day that the Lord has made; let us rejoice and be glad in it." (Ps 118:24) Not tomorrow. Not the one you're still replaying. This one. Yesterday is finished business. Whether it was a win or a wound, it's out of your reach now. And tomorrow isn't yours yet. Today is the only ground you actually stand on, and God already made it. That's why His mercies are "new every morning." (Lam 3:23) Fresh mercy for fresh ground. You don't have to drag yesterday into a day God just built for you. So take this one. Move from hope. Move from peace. One day is all any of us gets at a time. This is yours. Make it count.
    """

    // MARK: - Author's breaks

    func testAuthoredParagraphsAreKept() {
        let raw = "First paragraph, short and done.\n\nSecond paragraph, also short."
        XCTAssertEqual(MessageBodyFormatter.paragraphs(from: raw), [
            "First paragraph, short and done.",
            "Second paragraph, also short.",
        ])
    }

    func testSingleNewlineIsAParagraphBreak() {
        // Senders write one break between paragraphs as often as two.
        let raw = "Line one.\nLine two."
        XCTAssertEqual(MessageBodyFormatter.paragraphs(from: raw), ["Line one.", "Line two."])
    }

    func testEscapedNewlinesBecomeRealBreaks() {
        // A body through one JSON layer too many arrives carrying backslash-n.
        let raw = #"God is with you.\n\nHe always has been."#
        let paragraphs = MessageBodyFormatter.paragraphs(from: raw)
        XCTAssertEqual(paragraphs, ["God is with you.", "He always has been."])
        XCTAssertFalse(paragraphs.contains { $0.contains("\\n") },
                       "A literal backslash-n must never survive into the reader.")
    }

    func testCarriageReturnsAndUnicodeSeparatorsNormalize() {
        let raw = "One.\r\nTwo.\u{2028}Three.\u{2029}Four."
        XCTAssertEqual(MessageBodyFormatter.paragraphs(from: raw),
                       ["One.", "Two.", "Three.", "Four."])
    }

    func testShortBodyIsLeftExactlyAsWritten() {
        // Under the threshold there is nothing to fix, so nothing is touched.
        let raw = "I see you, and I am proud of how far you've come. Keep going."
        XCTAssertEqual(MessageBodyFormatter.paragraphs(from: raw), [raw])
    }

    func testEmptyBodyProducesNoBlocks() {
        XCTAssertTrue(MessageBodyFormatter.paragraphs(from: "   \n\n  ").isEmpty)
        XCTAssertTrue(MessageBodyFormatter.blocks(from: "").isEmpty)
    }

    // MARK: - Re-paragraphing a flat body

    func testFlattenedBroadcastIsBrokenIntoParagraphs() {
        let paragraphs = MessageBodyFormatter.paragraphs(from: flattenedBroadcast)
        XCTAssertGreaterThan(paragraphs.count, 3,
                             "A 120-word run must not stay one block.")
        for paragraph in paragraphs {
            XCTAssertLessThanOrEqual(wordCount(paragraph), 60,
                                     "Paragraph still reads as a wall: \(paragraph)")
        }
    }

    func testReparagraphingLosesNoWords() {
        // The formatter may only insert breaks — never drop or reorder copy.
        let paragraphs = MessageBodyFormatter.paragraphs(from: flattenedBroadcast)
        XCTAssertEqual(paragraphs.joined(separator: " "), flattenedBroadcast)
    }

    func testOpeningVerseGetsItsOwnParagraph() {
        let paragraphs = MessageBodyFormatter.paragraphs(from: flattenedBroadcast)
        XCTAssertEqual(
            paragraphs.first,
            "\"This is the day that the Lord has made; let us rejoice and be glad in it.\" (Ps 118:24)",
            "The citation belongs to the verse it follows, and closes the paragraph."
        )
    }

    func testCitationDoesNotStrandTheNextSentence() {
        // The break goes AFTER "(Ps 118:24)", never between the quote and it.
        let paragraphs = MessageBodyFormatter.paragraphs(from: flattenedBroadcast)
        XCTAssertFalse(paragraphs.contains { $0.hasPrefix("(Ps 118:24)") })
        XCTAssertTrue(paragraphs.contains { $0.hasPrefix("Not tomorrow.") })
    }

    func testMidMessageVerseAlsoBreaks() {
        let paragraphs = MessageBodyFormatter.paragraphs(from: flattenedBroadcast)
        XCTAssertTrue(
            paragraphs.contains { $0.hasSuffix("(Lam 3:23)") },
            "A verse quoted mid-message ends its paragraph too: \(paragraphs)"
        )
    }

    func testNoEmptyOrUntrimmedParagraphs() {
        for paragraph in MessageBodyFormatter.paragraphs(from: flattenedBroadcast) {
            XCTAssertFalse(paragraph.isEmpty)
            XCTAssertEqual(paragraph, paragraph.trimmingCharacters(in: .whitespaces))
        }
    }

    func testLongAuthoredParagraphIsSplitButNeighborsAreNot() {
        let wall = String(repeating: "He is faithful to you today. ", count: 12)
        let raw = "Short opener.\n\n\(wall)\n\nShort closer."
        let paragraphs = MessageBodyFormatter.paragraphs(from: raw)
        XCTAssertEqual(paragraphs.first, "Short opener.")
        XCTAssertEqual(paragraphs.last, "Short closer.")
        XCTAssertGreaterThan(paragraphs.count, 3)
    }

    // MARK: - Sentence splitting edge cases

    func testAbbreviationsDoNotBreakSentences() {
        let sentences = MessageBodyFormatter.sentences(
            in: "Dr. Miller prayed for me. It changed everything."
        )
        XCTAssertEqual(sentences, ["Dr. Miller prayed for me.", "It changed everything."])
    }

    func testDecimalsAndReferencesDoNotBreakSentences() {
        let sentences = MessageBodyFormatter.sentences(
            in: "Read Psalm 118:24 today. Then read it again."
        )
        XCTAssertEqual(sentences, ["Read Psalm 118:24 today.", "Then read it again."])
    }

    func testEllipsesAndQuestionsAreSingleBoundaries() {
        let sentences = MessageBodyFormatter.sentences(in: "Wait for it... Do you see it? You will.")
        XCTAssertEqual(sentences, ["Wait for it...", "Do you see it?", "You will."])
    }

    func testQuotedSentenceKeepsItsClosingQuote() {
        let sentences = MessageBodyFormatter.sentences(in: "He said, \"Peace, be still.\" The wind stopped.")
        XCTAssertEqual(sentences, ["He said, \"Peace, be still.\"", "The wind stopped."])
    }

    func testLowercaseContinuationIsNotABoundary() {
        let sentences = MessageBodyFormatter.sentences(in: "Call on Him at 6 a.m. and He answers.")
        XCTAssertEqual(sentences.count, 1)
    }

    // MARK: - Citation detection

    func testCitationShapesAreRecognized() {
        for citation in ["(Ps 118:24)", "(1 Cor 2:16)", "(Lam 3:22-23)", "(John 10:10, NIV)"] {
            XCTAssertTrue(MessageBodyFormatter.endsWithCitation("His word is true. \(citation)"),
                          "Should recognize \(citation)")
        }
    }

    func testProseParenthesesAreNotCitations() {
        XCTAssertFalse(MessageBodyFormatter.endsWithCitation("He is good (and He always was)"))
        XCTAssertFalse(MessageBodyFormatter.endsWithCitation("Meet me at 6:30 (if you can)"))
    }

    // MARK: - Block kinds

    func testQuotedVerseIsTaggedAsScripture() {
        let blocks = MessageBodyFormatter.blocks(from: flattenedBroadcast)
        XCTAssertEqual(blocks.first?.kind, .scripture)
        XCTAssertTrue(blocks.contains { $0.kind == .prose })
    }

    func testUnquotedProseEndingInAReferenceIsNotScripture() {
        // Only a quoted verse is set apart; a prose aside that cites is prose.
        let blocks = MessageBodyFormatter.blocks(from: "Fresh mercy is yours today (Lam 3:23)")
        XCTAssertEqual(blocks.first?.kind, .prose)
    }

    func testBlockIdsAreUniqueAndOrdered() {
        let blocks = MessageBodyFormatter.blocks(from: flattenedBroadcast)
        XCTAssertEqual(blocks.map(\.id), Array(0..<blocks.count))
    }

    // MARK: - Lists

    func testListItemsSurviveIntact() {
        let raw = "Today:\n1. Speak it out loud.\n2. Believe it.\n- Rest in it."
        XCTAssertEqual(MessageBodyFormatter.paragraphs(from: raw), [
            "Today:",
            "1. Speak it out loud.",
            "2. Believe it.",
            "- Rest in it.",
        ])
    }

    // MARK: - Preview

    func testPreviewIsOneLine() {
        let preview = MessageBodyFormatter.preview("One.\n\nTwo.\n\nThree.")
        XCTAssertEqual(preview, "One. Two. Three.")
        XCTAssertFalse(preview.contains("\n"))
    }

    func testPreviewUnescapesToo() {
        XCTAssertEqual(MessageBodyFormatter.preview(#"One.\nTwo."#), "One. Two.")
    }

    // MARK: - Helpers

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: { $0.isWhitespace }).count
    }
}
