//
//  AcquisitionAttribution.swift
//  SpeakLife
//
//  Per-person acquisition channel — the missing half of CAC vs LTV.
//
//  Revenue per person became answerable once GrowthMetrics aliased the
//  RevenueCat identity onto the app's person. It is still not *actionable*
//  without knowing where the person came from: "we make $X per user" cannot
//  tell you which channel to spend the next dollar on. This file stamps a
//  durable channel on every person so LTV, activation and retention all
//  break down by where the install came from.
//
//  Design rules, and why:
//
//  * FIRST TOUCH WINS, but only after the highest-confidence source available
//    has had a chance to speak. Apple Search Ads resolves over the network and
//    a deferred deep link can land a beat later, so a naive first-writer rule
//    would stamp everyone `organic` in the first 200ms. Sources therefore carry
//    a priority and may upgrade the record until it is sealed.
//
//  * SEALED AT 24 HOURS. After that the record is immutable: a person who taps
//    a marketing email on day 30 was still acquired by whatever brought them in
//    on day 0, and letting late touches overwrite that silently rewrites
//    history under every cohort chart already drawn.
//
//  * ORGANIC IS A DECISION, NOT A DEFAULT. It is only written after the async
//    resolvers have had `finalizeDelay` to report, so "organic" means "we
//    looked and found nothing", not "we hadn't looked yet".
//

import Foundation
#if canImport(AdServices)
import AdServices
#endif

// MARK: - Channel

/// Normalized channel. Raw source strings vary per network and per link; this
/// is the stable dimension charts are built on, so it must not grow a new
/// spelling every time a campaign is set up.
enum AcquisitionChannel: String {
    case appleSearchAds = "apple_search_ads"
    case meta = "meta"
    case tiktok = "tiktok"
    case google = "google"
    case ownedDeeplink = "owned_deeplink"
    case referral = "referral"
    case organic = "organic"
    case unknown = "unknown"

    /// Higher wins when two sources report before the record seals. Ordered by
    /// how much the claim can be trusted: Apple's token is cryptographic proof,
    /// a deep link is a real click, organic is the absence of evidence.
    var priority: Int {
        switch self {
        case .appleSearchAds: return 100
        case .meta, .tiktok, .google: return 80
        case .ownedDeeplink, .referral: return 60
        case .organic: return 10
        case .unknown: return 0
        }
    }

    /// True when the attribution came from a source that identifies the click
    /// itself rather than being inferred.
    var isDeterministic: Bool {
        switch self {
        case .appleSearchAds, .meta, .tiktok, .google, .ownedDeeplink, .referral:
            return true
        case .organic, .unknown:
            return false
        }
    }

    /// Maps the free-text `utm_source` / network names that show up on links.
    static func from(sourceString raw: String?) -> AcquisitionChannel {
        guard let value = raw?.lowercased(), !value.isEmpty else { return .unknown }
        if value.contains("apple") || value.contains("asa") { return .appleSearchAds }
        if value.contains("facebook") || value.contains("meta")
            || value.contains("instagram") || value.contains("ig") { return .meta }
        // `bytedanceglobal_int` is how an MMP names TikTok's ad network, and it
        // contains neither "tiktok" nor anything else matched here.
        if value.contains("tiktok") || value.contains("bytedance") { return .tiktok }
        if value.contains("google") || value.contains("youtube") || value.contains("adwords") { return .google }
        if value.contains("email") || value.contains("push")
            || value.contains("qr") || value.contains("bio") { return .ownedDeeplink }
        if value.contains("referral") || value.contains("share") || value.contains("friend") { return .referral }
        return .unknown
    }
}

// MARK: - Record

struct AcquisitionRecord {
    var channel: AcquisitionChannel
    var source: String
    var campaign: String?
    var adGroup: String?
    var creative: String?
    var keyword: String?
    var onboardingVariant: String?
    var attributedAt: Date

    var personProperties: [String: Any] {
        var props: [String: Any] = [
            AcquisitionAttribution.Person.channel: channel.rawValue,
            AcquisitionAttribution.Person.source: source,
            AcquisitionAttribution.Person.isDeterministic: channel.isDeterministic,
            AcquisitionAttribution.Person.attributedAt: attributedAt.analyticsISO8601String
        ]
        // Set only when known: an empty string here is indistinguishable from a
        // real campaign named "" in a breakdown, and reads as a live segment.
        if let campaign = campaign, !campaign.isEmpty { props[AcquisitionAttribution.Person.campaign] = campaign }
        if let adGroup = adGroup, !adGroup.isEmpty { props[AcquisitionAttribution.Person.adGroup] = adGroup }
        if let creative = creative, !creative.isEmpty { props[AcquisitionAttribution.Person.creative] = creative }
        if let keyword = keyword, !keyword.isEmpty { props[AcquisitionAttribution.Person.keyword] = keyword }
        if let variant = onboardingVariant, !variant.isEmpty {
            props[AcquisitionAttribution.Person.onboardingVariant] = variant
        }
        return props
    }
}

// MARK: - Attribution

final class AcquisitionAttribution {

    static let shared = AcquisitionAttribution()

    /// How long the async resolvers get before `organic` is written.
    private let finalizeDelay: TimeInterval = 8

    /// How long the record stays open to a higher-priority source.
    private let sealAfter: TimeInterval = 24 * 60 * 60

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    enum Person {
        static let channel = "acquisition_channel"
        static let source = "acquisition_source"
        static let campaign = "acquisition_campaign"
        static let adGroup = "acquisition_ad_group"
        static let creative = "acquisition_creative"
        static let keyword = "acquisition_keyword"
        static let onboardingVariant = "acquisition_onboarding_variant"
        static let isDeterministic = "acquisition_is_deterministic"
        static let attributedAt = "acquisition_attributed_at"
    }

    private enum Key {
        static let channel = "acq_channel"
        static let source = "acq_source"
        static let campaign = "acq_campaign"
        static let adGroup = "acq_ad_group"
        static let creative = "acq_creative"
        static let keyword = "acq_keyword"
        static let variant = "acq_onboarding_variant"
        static let attributedAt = "acq_attributed_at"
        static let searchAdsChecked = "acq_apple_search_ads_checked"
    }

    // MARK: - Entry point

    /// Call once from `didFinishLaunchingWithOptions`.
    func start() {
        // Re-mirror on every launch. Person properties are not guaranteed to
        // have survived (a reinstall of the SDK, a reset, a failed request), and
        // re-sending a value that is already set is free.
        if let existing = storedRecord() {
            mirror(existing, isUpgrade: false, emitEvent: false)
        }

        resolveAppleSearchAds()

        // Organic is only written once the resolvers have had their window.
        DispatchQueue.main.asyncAfter(deadline: .now() + finalizeDelay) { [weak self] in
            self?.finalizeAsOrganicIfUnattributed()
        }
    }

    // MARK: - Recording

    /// A deep link, universal link, or deferred link opened the app.
    ///
    /// Reads the standard UTM set plus the app's own `ob=` onboarding code, so a
    /// link built for either purpose still yields a channel.
    func recordDeepLink(_ url: URL, source: String) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let items = components.queryItems ?? []

        func value(_ name: String) -> String? {
            items.first { $0.name.lowercased() == name }?.value
        }

        let utmSource = value("utm_source")
        // An owned link with no utm_source is still a real, non-organic touch,
        // so it falls back to the caller's source rather than to unknown.
        var channel = AcquisitionChannel.from(sourceString: utmSource)
        if channel == .unknown {
            channel = AcquisitionChannel.from(sourceString: value("utm_medium"))
        }
        if channel == .unknown {
            channel = .ownedDeeplink
        }

        record(
            AcquisitionRecord(
                channel: channel,
                source: utmSource ?? source,
                campaign: value("utm_campaign"),
                adGroup: value("utm_content") ?? value("utm_term"),
                creative: value("utm_creative"),
                keyword: value("utm_term"),
                onboardingVariant: value("ob"),
                attributedAt: Date()
            )
        )
    }

    /// Records a channel discovered by an SDK rather than a link.
    func record(
        channel: AcquisitionChannel,
        source: String,
        campaign: String? = nil,
        adGroup: String? = nil,
        creative: String? = nil,
        keyword: String? = nil
    ) {
        record(
            AcquisitionRecord(
                channel: channel,
                source: source,
                campaign: campaign,
                adGroup: adGroup,
                creative: creative,
                keyword: keyword,
                onboardingVariant: nil,
                attributedAt: Date()
            )
        )
    }

    // MARK: - Core write

    private func record(_ candidate: AcquisitionRecord) {
        lock.lock()

        let existing = storedRecordLocked()

        if let existing = existing {
            let age = Date().timeIntervalSince(existing.attributedAt)
            // Sealed: the acquisition story for this person is already told.
            guard age < sealAfter else {
                lock.unlock()
                return
            }
            // Still open, but only a better-evidenced source may overwrite.
            guard candidate.channel.priority > existing.channel.priority else {
                lock.unlock()
                return
            }
        }

        persistLocked(candidate)
        lock.unlock()

        mirror(candidate, isUpgrade: existing != nil, emitEvent: true)
    }

    private func finalizeAsOrganicIfUnattributed() {
        lock.lock()
        guard storedRecordLocked() == nil else {
            lock.unlock()
            return
        }
        let organic = AcquisitionRecord(
            channel: .organic,
            source: "organic",
            campaign: nil,
            adGroup: nil,
            creative: nil,
            keyword: nil,
            onboardingVariant: nil,
            attributedAt: Date()
        )
        persistLocked(organic)
        lock.unlock()

        mirror(organic, isUpgrade: false, emitEvent: true)
    }

    // MARK: - Fan-out

    private func mirror(_ record: AcquisitionRecord, isUpgrade: Bool, emitEvent: Bool) {
        for (name, value) in record.personProperties {
            AnalyticsService.shared.setUserProperty(name, value: value)
        }

        // RevenueCat carries these as reserved subscriber attributes, and its
        // own PostHog integration stamps them onto every revenue event it
        // sends. Without this, channel lives only on the app's person record and
        // any revenue that arrives server-side (renewals while the app is shut)
        // has no channel on it.
        RevenueCatManager.shared.setAttribution(
            mediaSource: record.channel.rawValue,
            campaign: record.campaign,
            adGroup: record.adGroup,
            creative: record.creative,
            keyword: record.keyword
        )

        guard emitEvent else { return }

        var params = record.personProperties
        params["is_upgrade"] = isUpgrade
        params["seconds_since_install"] = max(0, Int(
            record.attributedAt.timeIntervalSince(AnalyticsContext.shared.userInstallDate)
        ))
        AnalyticsService.shared.track("acquisition_attributed", parameters: params)
    }

    // MARK: - Apple Search Ads
    //
    // The only deterministic install attribution available on iOS, and the one
    // that matters most for an App Store search buy. Apple's token is exchanged
    // for the campaign/ad-group/keyword that produced the install.
    //
    // The endpoint returns 404 for a short window after install while Apple's
    // record propagates, so a single attempt loses real attributions.

    private func resolveAppleSearchAds() {
        #if canImport(AdServices)
        // No availability guard: AdServices is iOS 14.3+ and the deployment
        // target is 17.0, so a check here is always true and only warns.
        lock.lock()
        let alreadyChecked = defaults.bool(forKey: Key.searchAdsChecked)
        lock.unlock()
        guard !alreadyChecked else { return }

        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            guard let token = try? AAAttribution.attributionToken() else { return }

            for attempt in 0..<3 {
                if attempt > 0 {
                    // Apple documents the record as not immediately available.
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                }
                guard let payload = await Self.fetchAppleAttribution(token: token) else { continue }

                self.lock.lock()
                self.defaults.set(true, forKey: Key.searchAdsChecked)
                self.lock.unlock()

                // `attribution == false` is a real answer: Apple is telling us
                // this install did NOT come from a Search Ads click. Recording a
                // channel here would invent one.
                guard (payload["attribution"] as? Bool) == true else { return }

                self.record(
                    channel: .appleSearchAds,
                    source: "apple_search_ads",
                    campaign: Self.stringValue(payload["campaignId"]),
                    adGroup: Self.stringValue(payload["adGroupId"]),
                    creative: Self.stringValue(payload["creativeSetId"]),
                    keyword: Self.stringValue(payload["keywordId"])
                )
                return
            }
        }
        #endif
    }

    private static func fetchAppleAttribution(token: String) async -> [String: Any]? {
        guard let url = URL(string: "https://api-adservices.apple.com/api/v1/") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(token.utf8)
        request.timeoutInterval = 15

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else { return nil }

        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// Apple returns the ids as numbers; every downstream consumer wants strings.
    private static func stringValue(_ value: Any?) -> String? {
        switch value {
        case let string as String: return string
        case let number as NSNumber: return number.stringValue
        default: return nil
        }
    }

    // MARK: - Storage

    func storedRecord() -> AcquisitionRecord? {
        lock.lock()
        defer { lock.unlock() }
        return storedRecordLocked()
    }

    /// Caller must hold `lock`.
    private func storedRecordLocked() -> AcquisitionRecord? {
        guard let raw = defaults.string(forKey: Key.channel),
              let channel = AcquisitionChannel(rawValue: raw),
              let attributedAt = defaults.object(forKey: Key.attributedAt) as? Date else { return nil }

        return AcquisitionRecord(
            channel: channel,
            source: defaults.string(forKey: Key.source) ?? channel.rawValue,
            campaign: defaults.string(forKey: Key.campaign),
            adGroup: defaults.string(forKey: Key.adGroup),
            creative: defaults.string(forKey: Key.creative),
            keyword: defaults.string(forKey: Key.keyword),
            onboardingVariant: defaults.string(forKey: Key.variant),
            attributedAt: attributedAt
        )
    }

    /// Caller must hold `lock`.
    private func persistLocked(_ record: AcquisitionRecord) {
        defaults.set(record.channel.rawValue, forKey: Key.channel)
        defaults.set(record.source, forKey: Key.source)
        defaults.set(record.attributedAt, forKey: Key.attributedAt)
        setOrClear(record.campaign, Key.campaign)
        setOrClear(record.adGroup, Key.adGroup)
        setOrClear(record.creative, Key.creative)
        setOrClear(record.keyword, Key.keyword)
        setOrClear(record.onboardingVariant, Key.variant)
    }

    /// An upgrade from a sparse source to a rich one must not leave the previous
    /// source's campaign hanging off the new channel.
    private func setOrClear(_ value: String?, _ key: String) {
        if let value = value, !value.isEmpty {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
