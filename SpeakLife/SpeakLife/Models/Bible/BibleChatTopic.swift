//
//  BibleChatTopic.swift
//  SpeakLife
//
//  Curated topical answers for the "Ask the Bible" feature.
//

import SwiftUI

struct BibleChatTopic: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let question: String
    let icon: String
    let accentHex: String
    let summary: String
    let answer: String
    let verses: [BibleChatVerse]
    let reflection: String?

    var accentColor: Color { Color(hex: accentHex) }
}

struct BibleChatVerse: Codable, Hashable, Identifiable {
    let reference: String
    let text: String
    let translation: String?

    var id: String { reference + text.prefix(24) }
}

struct BibleChatTopicCollection: Codable {
    let version: Int
    let topics: [BibleChatTopic]
}
