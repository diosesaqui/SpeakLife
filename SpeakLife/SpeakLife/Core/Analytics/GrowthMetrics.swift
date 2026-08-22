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
        static let lifetimeRevenue = "growth_lifetime_revenue_usd"
        static let purchaseCount = "growth_purchase_count"
        static let firstPurchaseAt = "growth_first_purchase_at"
        static let trialStartedAt = "growth_trial_started_at"
        static let maxStreak = "growth_max_streak"
        static let aliasedRevenueID = "growth_aliased_revenue_id"
    }

    /// Person-property names. Referenced rather than typed at call sites so a
    /// rename is a compile error instead of a cohort that silently splits.
    enum Person {
        static let lifetimeRevenue = "lifetime_revenue_usd"
        static let purchaseCount = "purchase_count"
        static let firstPurchaseAt = "first_purchase_at"
        static let lastPurchaseAt = "last_purchase_at"
        static let plan = "plan"
        static let billingTerm = "billing_term"
        static let trialStartedAt = "trial_started_at"
        static let trialConverted = "trial_converted"
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

    // MARK: - Metric: LTV
    //
    // LTV needs cumulative revenue per person, and no destination computes that
    // for us — RevenueCat reports each transaction in isolation, so a person who
    // renewed four times looks identical to one who paid once until you sum the
    // stream yourself. Accumulated locally and mirrored onto the person so
    // "average LTV by onboarding variant" is a breakdown, not a data export.

    func recordTrialStarted(productId: String, plan: String, trialDays: Int) {
        let now = Date()
        defaults.set(now, forKey: Key.trialStartedAt)

        AnalyticsService.shared.setUserProperty(Person.trialStartedAt, value: now.analyticsISO8601String)
        AnalyticsService.shared.setUserProperty(Person.plan, value: plan)
        AnalyticsService.shared.setUserProperty(Person.billingTerm, value: Self.billingTerm(for: productId))
        AnalyticsService.shared.setUserProperty(Person.trialConverted, value: false)
    }

    /// Call for every paid transaction — first purchase, conversion and renewal
    /// alike. Renewals are the whole point: without them LTV collapses to first
    /// purchase price and every payback calculation is wrong.
    func recordPurchase(productId: String, plan: String, revenueUSD: Double, isRenewal: Bool) {
        let now = Date()

        lock.lock()
        let total = defaults.double(forKey: Key.lifetimeRevenue) + max(0, revenueUSD)
        let count = defaults.integer(forKey: Key.purchaseCount) + 1
        defaults.set(total, forKey: Key.lifetimeRevenue)
        defaults.set(count, forKey: Key.purchaseCount)

        let isFirst = defaults.object(forKey: Key.firstPurchaseAt) == nil
        if isFirst { defaults.set(now, forKey: Key.firstPurchaseAt) }
        let trialStartedAt = defaults.object(forKey: Key.trialStartedAt) as? Date
        lock.unlock()

        AnalyticsService.shared.track("revenue_recorded", parameters: [
            "product_id": productId,
            "plan": plan,
            "billing_term": Self.billingTerm(for: productId),
            "revenue_usd": revenueUSD,
            "is_renewal": isRenewal,
            "is_first_purchase": isFirst,
            "lifetime_revenue_usd": total,
            "purchase_number": count,
            "days_since_install": AnalyticsContext.shared.daysSinceInstall
        ])

        AnalyticsService.shared.setUserProperty(Person.lifetimeRevenue, value: total)
        AnalyticsService.shared.setUserProperty(Person.purchaseCount, value: count)
        AnalyticsService.shared.setUserProperty(Person.lastPurchaseAt, value: now.analyticsISO8601String)
        AnalyticsService.shared.setUserProperty(Person.plan, value: plan)

        if isFirst {
            AnalyticsService.shared.setUserProperty(Person.firstPurchaseAt, value: now.analyticsISO8601String)
        }
        if trialStartedAt != nil && !isRenewal {
            AnalyticsService.shared.setUserProperty(Person.trialConverted, value: true)
        }
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
