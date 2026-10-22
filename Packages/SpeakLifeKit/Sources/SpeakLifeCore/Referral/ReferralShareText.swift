//
//  ReferralShareText.swift
//  SpeakLifeCore
//
//  Fills the share copy (spec §9.4). The template is Remote Config
//  `referralShareText`, where `{link}` stands in for the link. Remote copy
//  can be wrong, so the result always carries the link exactly once: a
//  missing placeholder appends it, and extra placeholders are dropped.
//

import Foundation

public enum ReferralShareText {

    public static let placeholder = "{link}"

    /// Spec §12 default for `referralShareText`.
    public static let defaultTemplate =
        "I've been speaking God's promises out loud every morning with SpeakLife. Try it free: {link}"

    public static func render(template: String, link: URL) -> String {
        let linkText = link.absoluteString
        let parts = template.components(separatedBy: placeholder)
        if parts.count > 1 {
            let head = parts[0]
            let tail = parts.dropFirst().joined()
            return (head + linkText + tail).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let copy = template.trimmingCharacters(in: .whitespacesAndNewlines)
        if copy.isEmpty { return linkText }
        return copy + " " + linkText
    }
}
