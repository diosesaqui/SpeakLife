//
//  PrayerWallPost.swift
//  SpeakLife
//
//  Model for community Prayer Wall posts.
//

import Foundation
import FirebaseFirestore

struct PrayerWallPost: Identifiable, Codable {
    @DocumentID var id: String?
    let text: String
    let displayName: String   // e.g. "A sister in Christ"
    let deviceId: String
    let timestamp: Timestamp
    var prayerCount: Int
    var reports: Int
    var isHidden: Bool
    var isAnswered: Bool

    init(text: String, displayName: String, deviceId: String) {
        self.text = text
        self.displayName = displayName
        self.deviceId = deviceId
        self.timestamp = Timestamp()
        self.prayerCount = 0
        self.reports = 0
        self.isHidden = false
        self.isAnswered = false
    }
}
