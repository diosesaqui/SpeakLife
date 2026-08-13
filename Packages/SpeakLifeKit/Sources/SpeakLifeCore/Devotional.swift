//
//  Devotional.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 5/10/23.
//

import Foundation

public struct WelcomeDevotional: Codable {
    public let version: Int
    public let devotionals: [Devotional]

    public init(version: Int, devotionals: [Devotional]) {
        self.version = version
        self.devotionals = devotionals
    }
}

public struct Devotional: Codable, Identifiable {
    public let date: Date
    public let title: String
    public let devotionalText: String
    public let books: String

    public var id: String {
        "\(date) + \(title)"
    }

    public init(date: Date, title: String, devotionalText: String, books: String) {
        self.date = date
        self.title = title
        self.devotionalText = devotionalText
        self.books = books
    }
}
