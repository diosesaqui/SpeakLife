//
//  Devotional.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 5/10/23.
//

import Foundation

struct WelcomeDevotional: Codable {
    let version: Int
    let devotionals: [Devotional]
}

struct Devotional: Codable, Identifiable {
    let date: Date
    let title: String
    let devotionalText: String
    let books: String
    
    var id: String {
        "\(date) + \(title)"
    }
}
