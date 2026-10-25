//
//  ReferralLink.swift
//  SpeakLife
//
//  The link every user-initiated share carries, so an install that comes from
//  a share is counted as one.
//
//  Before this, the declaration card shared an image with no link at all and
//  the devotional shared a bare App Store URL. Neither could be traced, which
//  is why PostHog showed zero `referral` installs while ~200 people a month
//  were sharing.
//
//  It is a Branch LONG link: the parameters ride in the query string of the
//  app.link root, so it is built synchronously with no network call and no SDK
//  round trip. Branch turns `channel` / `feature` / `campaign` into `~channel`
//  / `~feature` / `~campaign` on the click, and `BranchAttribution.attribution(from:)`
//  maps a channel containing "share" to `AcquisitionChannel.referral`.
//
//  It uses the ROOT path on purpose. Builds 4.59+ claim every path on
//  `speaklife.app.link` (see `StandLink.shareHost`); the root just opens the
//  app for anyone who has it, and Branch sends everyone else to the App Store.
//

import Foundation

enum ReferralLink {

    /// What was shared. Becomes Branch's `feature`, so installs break down by
    /// surface in Branch and in `acquisition_source`.
    enum Feature: String {
        case declarationCard = "declaration_card"
        case dailyBurst = "daily_burst"
        case devotional = "devotional"
        case profileInvite = "profile_invite"
        case favorite = "favorite"
        case tracker = "tracker"
        case audioFavorite = "audio_favorite"
        case bibleVerse = "bible_verse"
        case dailyVerse = "daily_verse"
        case bibleChat = "bible_chat"
        case standCompletion = "stand_completion"
        case speakOver = "speak_over"
        case yearInReview = "year_in_review"
    }

    static let host = "speaklife.app.link"

    /// Query key carrying the sharer's anonymous analytics id. Branch hands it
    /// back as link data on the recipient's first session.
    static let referrerKey = "sl_ref"

    /// - Parameters:
    ///   - feature: the surface the share came from.
    ///   - campaign: optional finer label, such as the declaration category.
    ///   - extra: link data for the recipient's app, such as what to open.
    ///     Branch passes unknown keys through on the first session.
    static func url(_ feature: Feature, campaign: String? = nil,
                    extra: [URLQueryItem] = []) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/"

        var items = [
            URLQueryItem(name: "channel", value: "share"),
            URLQueryItem(name: "feature", value: feature.rawValue)
        ]
        if let campaign, !campaign.isEmpty {
            items.append(URLQueryItem(name: "campaign", value: campaign))
        }
        // The sharer's anonymous analytics id. Branch passes unknown keys
        // through as link data, so a later "who brought whom" report (and a
        // reward for the sharer) can be built without changing the link.
        if let referrer = AnalyticsService.shared.postHogDistinctId, !referrer.isEmpty {
            items.append(URLQueryItem(name: referrerKey, value: referrer))
        }
        items.append(contentsOf: extra)
        components.queryItems = items

        // Every part above is a fixed, valid component, so this cannot be nil.
        return components.url ?? URL(string: "https://\(host)/")!
    }
}
