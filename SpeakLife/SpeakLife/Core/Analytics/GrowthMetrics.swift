//
//  GrowthMetrics.swift
//  SpeakLife
//
//  The weekly-decision metrics layer.
//
//  Events answer "what happened". This answers "who is this person, and where
//  are they in their life with the app" — the durable per-person facts that
//  LTV, activation and retention are computed from.
//
//  Why person properties and not just events: PostHog can cohort on a person
//  property directly ("everyone whose lifetime revenue > 0", "everyone who
//  activated in under an hour"). Deriving the same thing from the event stream
//  costs a join per question and silently breaks the moment an event is
//  renamed — which this codebase has done repeatedly.
//
//  Every helper here is idempotent. They are called from hot paths (app
//  foreground, task completion, purchase callbacks that StoreKit can replay),
//  so each one either dedupes against UserDefaults or is safe to repeat.
//

import Foundation

final class GrowthMetrics {

    static let shared = GrowthMetrics()

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Storage keys

    private enum Key {
        static let activatedAt = "growth_activated_at"
        static let lastDayStarted = "growth_last_day_started"
        static let lastOpenAt = "growth_last_open_at"
        static let featuresUsed = "growth_features_used"
        static let trialStartedAt = "growth_trial_started_at"
        static let maxStreak = "growth_max_streak"
        static let aliasedRevenueID = "growth_aliased_revenue_id"
    }

    /// Person-property names. Referenced rather than typed at call sites so a
    /// rename is a compile error instead of a cohort that silently splits.
    enum Person {
        // Revenue properties deliberately absent: RevenueCat owns revenue and
        // posts it to PostHog itself, with real USD amounts and with the
        // renewals this process never sees. See `recordPurchaseDimensions`.
        static let plan = "plan"
        static let billingTerm = "billing_term"
        static let trialStartedAt = "trial_started_at"
        static let activatedAt = "activated_at"
        static let hoursToActivate = "hours_to_activate"
        static let maxStreak = "max_streak"
        static let featuresUsedCount = "features_used_count"
        static let installDate = "install_date"
        static let churnedAt = "churned_at"
        static let lastCancelReason = "last_cancel_reason"
    }

    // MARK: - Install cohort
    //
    // Mirrored once per launch so every person record carries its cohort anchor,
    // including the existing base whose install date was backfilled.

    func recordInstallCohort() {
        AnalyticsService.shared.setUserProperty(
            Person.installDate,
            value: AnalyticsContext.shared.userInstallDate.analyticsISO8601String
        )
    }

    // MARK: - Revenue identity
    //
    // The prerequisite for every LTV question. RevenueCat posts revenue to
    // PostHog under its own `$RCAnonymousID:…`; the app reports behaviour under
    // PostHog's device id. Measured over 90 days: 78 person records with
    // revenue, 3,914 with behaviour, overlap zero. Until these are aliased,
    // "LTV by onboarding variant" has no join to make.
    //
    // Aliased once per RevenueCat id. The id is stable per install but changes
    // on `logIn`, so the last-aliased value is stored rather than a bare flag.

    func linkRevenueIdentity(appUserID: String) {
        guard !appUserID.isEmpty else { return }

        // Outbound half, and the one that makes server-side revenue land on the
        // right person. RevenueCat's PostHog integration runs while the app is
        // shut, so it cannot consult anything the app knows at that moment — it
        // reads the `$posthogUserId` attribute the app pushed in earlier.
        // Aliasing alone only joins what the client itself sends. Re-sent every
        // launch because the distinct id changes on identify/reset, and RC only
        // writes an attribute that actually changed.
        if let distinctId = AnalyticsService.shared.postHogDistinctId {
            RevenueCatManager.shared.setPostHogUserID(distinctId)
        }

        lock.lock()
        let alreadyLinked = defaults.string(forKey: Key.aliasedRevenueID) == appUserID
        if !alreadyLinked { defaults.set(appUserID, forKey: Key.aliasedRevenueID) }
        lock.unlock()

        guard !alreadyLinked else { return }
        AnalyticsService.shared.aliasUser(appUserID)
    }

    // MARK: - Metric: daily active, retention, resurrection
    //
    // `Application Opened` is SDK autocapture: it fires on every foreground, so
    // it measures app switching, not days. This fires exactly once per calendar
    // day and carries the gap since the previous one, which is what D1/D7/D30
    // retention and resurrection actually need.

    func trackDayStarted(currentStreak: Int) {
        let today = Self.dayStamp(Date())

        lock.lock()
        let previousDay = defaults.string(forKey: Key.lastDayStarted)
        guard previousDay != today else {
            lock.unlock()
            return
        }
        let lastOpen = defaults.object(forKey: Key.lastOpenAt) as? Date
        defaults.set(today, forKey: Key.lastDayStarted)
        defaults.set(Date(), forKey: Key.lastOpenAt)
        lock.unlock()

        let daysSinceLastOpen = lastOpen.map {
            max(0, Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0)
        }

        var params: [String: Any] = [
            "days_since_install": AnalyticsContext.shared.daysSinceInstall,
            "current_streak": currentStreak,
            "is_first_ever_day": previousDay == nil
        ]

        if let gap = daysSinceLastOpen {
            params["days_since_last_open"] = gap
            // A return after a week away is a different event from a daily
            // habit, and mixing them hides both.
            params["is_resurrected"] = gap >= 7
        }

        AnalyticsService.shared.track("app_day_started", parameters: params)
    }

    // MARK: - Metric: activation
    //
    // The single most important number in the funnel: did this install ever
    // become a user? Fired once, ever, on the first real act of use — not on
    // opening a screen.

    func trackActivation(action: String) {
        lock.lock()
        guard defaults.object(forKey: Key.activatedAt) == nil else {
            lock.unlock()
            return
        }
        let now = Date()
        defaults.set(now, forKey: Key.activatedAt)
        lock.unlock()

        let hours = AnalyticsContext.shared.hoursSinceInstall

        AnalyticsService.shared.track("user_activated", parameters: [
            "activation_action": action,
            "hours_since_install": hours,
            "days_since_install": AnalyticsContext.shared.daysSinceInstall
        ])

        AnalyticsService.shared.setUserProperty(Person.activatedAt, value: now.analyticsISO8601String)
        AnalyticsService.shared.setUserProperty(Person.hoursToActivate, value: hours)
    }

    // MARK: - Metric: feature breadth
    //
    // Fires once per feature per person. Breadth in the first week is the
    // strongest retention predictor most apps have, and it cannot be recovered
    // later from a raw event stream without scanning a person's whole history.

    func trackFeatureFirstUse(_ feature: String) {
        lock.lock()
        var used = Set(defaults.stringArray(forKey: Key.featuresUsed) ?? [])
        guard !used.contains(feature) else {
            lock.unlock()
            return
        }
        used.insert(feature)
        defaults.set(Array(used).sorted(), forKey: Key.featuresUsed)
        let count = used.count
        lock.unlock()

        AnalyticsService.shared.track("feature_first_used", parameters: [
            "feature": feature,
            "days_since_install": AnalyticsContext.shared.daysSinceInstall,
            "feature_number": count
        ])

        AnalyticsService.shared.setUserProperty(Person.featuresUsedCount, value: count)
    }

    // MARK: - Metric: habit depth

    func recordStreak(_ streak: Int) {
        lock.lock()
        let previousMax = defaults.integer(forKey: Key.maxStreak)
        guard streak > previousMax else {
            lock.unlock()
            return
        }
        defaults.set(streak, forKey: Key.maxStreak)
        lock.unlock()

        AnalyticsService.shared.setUserProperty(Person.maxStreak, value: streak)
    }

    // MARK: - Subscription dimensions
    //
    // Revenue itself is NOT computed here. It used to be: `recordPurchase`
    // accumulated `product.price` — StoreKit's price in the buyer's LOCAL
    // currency — into a person property named `lifetime_revenue_usd`, so a
    // subscriber paying ¥5,800 added 5,800 to it. It also only ever ran from
    // the in-app purchase flow, so renewals and trial conversions, which happen
    // on Apple's servers while the app is shut, were never counted at all —
    // leaving "lifetime" revenue permanently equal to the first purchase.
    //
    // RevenueCat owns revenue now. Its PostHog integration posts trials,
    // conversions, renewals and refunds with real USD amounts, keyed to this
    // app's PostHog person through the `$posthogUserId` attribute pushed in
    // `linkRevenueIdentity`. What stays here is the part RevenueCat's payload
    // does not carry: the app's own view of which plan the person is on.

    func recordTrialStarted(productId: String, plan: String, trialDays: Int) {
        let now = Date()
        defaults.set(now, forKey: Key.trialStartedAt)

        AnalyticsService.shared.setUserProperty(Person.trialStartedAt, value: now.analyticsISO8601String)
        AnalyticsService.shared.setUserProperty(Person.plan, value: plan)
        AnalyticsService.shared.setUserProperty(Person.billingTerm, value: Self.billingTerm(for: productId))
        // `trial_converted` is deliberately not written. It used to be set
        // false here and had no reachable path to true — the conversion happens
        // server-side — so it read as zero conversions for every person who
        // ever started a trial. RevenueCat reports the conversion.
    }

    /// Records which plan a person just bought. Non-revenue only: the amount,
    /// the renewal and the trial conversion all come from RevenueCat.
    func recordPurchaseDimensions(productId: String, plan: String) {
        AnalyticsService.shared.setUserProperty(Person.plan, value: plan)
        AnalyticsService.shared.setUserProperty(Person.billingTerm, value: Self.billingTerm(for: productId))
    }

    func recordChurn(reason: String) {
        AnalyticsService.shared.setUserProperty(Person.churnedAt, value: Date().analyticsISO8601String)
        AnalyticsService.shared.setUserProperty(Person.lastCancelReason, value: reason)
    }

    // MARK: - Metric: push effectiveness
    //
    // Nothing recorded a notification tap before this, so the entire push
    // programme — lifecycle, streak-break, daily burst, personal declaration —
    // had no measurable open rate and no way to tell which type earns its send.

    func trackNotificationOpened(type: String, identifier: String, category: String?) {
        var params: [String: Any] = [
            "notification_type": type,
            "notification_identifier": identifier,
            "days_since_install": AnalyticsContext.shared.daysSinceInstall
        ]
        if let category = category, !category.isEmpty {
            params["notification_category"] = category
        }

        AnalyticsService.shared.track("notification_opened", parameters: params)
    }

    // MARK: - Helpers

    /// Derived from the product id rather than passed in, so a new SKU cannot
    /// quietly land in the wrong LTV bucket.
    private static func billingTerm(for productId: String) -> String {
        let id = productId.lowercased()
        if id.contains("1yr") || id.contains("year") || id.contains("annual") { return "annual" }
        if id.contains("1mo") || id.contains("month") { return "monthly" }
        if id.contains("week") { return "weekly" }
        if id.contains("life") { return "lifetime" }
        return "unknown"
    }

    private static func dayStamp(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}
