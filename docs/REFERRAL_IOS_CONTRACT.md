# Referral (Year Free): iOS Core API Contract

The public API of the referral logic layer in `SpeakLifeCore`
(`Packages/SpeakLifeKit/Sources/SpeakLifeCore/Referral/`). The app layer
(view model, Firebase service, views, link capture wiring) builds against this.

Spec: `docs/REFERRAL_YEAR_FREE_SPEC.md`. Test plan: `docs/REFERRAL_FE_TDD.md`.
Tests: `Packages/SpeakLifeKit/Tests/SpeakLifeCoreTests/Referral*Tests.swift`,
`PendingReferralStoreTests.swift`, `PostOnboardingPresenterTests.swift`.

Foundation only. No UIKit, SwiftUI, Firebase or Branch in any of it.

## Files

| File | Types |
|---|---|
| `ReferralLink.swift` | `ReferralSource`, `ReferralLink` |
| `PendingReferral.swift` | `ReferralKeyValueStore`, `InMemoryReferralKeyValueStore`, `PendingReferral`, `ReferralCaptureResult`, `PendingReferralStore` |
| `ReferralClaimPolicy.swift` | `ReferralClaimOutcome`, `ReferralClaimDecision`, `ReferralClaimPolicy` |
| `ReferralSnapshot.swift` | `ReferralStatus`, `ReferralReward`, `ReferralSnapshot` |
| `ReferralEligibility.swift` | `ReferralEligibilityInput`, `ReferralEligibility` |
| `ReferralPage.swift` | `ReferralPageState`, `ReferralPageEvent`, `ReferralPageEffect`, `ReferralPageMemory`, `ReferralPageReducer` |
| `ReferralShareText.swift` | `ReferralShareText` |
| `PostOnboardingPresenter.swift` | `PostOnboardingStep`, `PostOnboardingPresenter` |

## Final public API

```swift
public enum ReferralSource: String, Codable, Sendable { case deferred, universalLink = "universal_link", manual }

public enum ReferralLink {
  public static let alphabet: String          // "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
  public static let codeLength: Int           // 8
  public static func normalize(_ raw: String) -> String?
  public static func code(from url: URL) -> String?
  public static func code(fromBranchParams params: [String: Any]) -> String?
  public static func shareURL(code: String, host: String) -> URL?
  public static func formatted(_ code: String) -> String
}

public protocol ReferralKeyValueStore: AnyObject {
  func data(forKey key: String) -> Data?
  func set(_ data: Data?, forKey key: String)      // nil removes
  func bool(forKey key: String) -> Bool
  func set(_ value: Bool, forKey key: String)
}
public final class InMemoryReferralKeyValueStore: ReferralKeyValueStore { public init() }

public struct PendingReferral: Codable, Equatable, Sendable {
  public let code: String; public let capturedAt: Date; public let source: ReferralSource
  public var attempts: Int; public var lastAttemptAt: Date?
  public init(code:capturedAt:source:attempts: = 0, lastAttemptAt: = nil)   // ADDED
  public func isExpired(now: Date, windowDays: Int) -> Bool                 // ADDED
}
public enum ReferralCaptureResult: Equatable { case captured, alreadyPending, alreadyClaimed, invalid }
public final class PendingReferralStore {
  public static let pendingKey: String   // "pendingReferral" (spec §9.5)       ADDED
  public static let finalKey: String     // "referralClaimFinal"                 ADDED
  public let windowDays: Int                                                       // ADDED
  public init(store: ReferralKeyValueStore, windowDays: Int = 14, now: @escaping () -> Date = { Date() })
  public var pending: PendingReferral? { get }
  public var isFinal: Bool { get }
  @discardableResult public func capture(code: String, source: ReferralSource) -> ReferralCaptureResult
  public func recordAttempt()
  public func markFinal()
  public func clear()
}

public enum ReferralClaimOutcome: Equatable {
  case credited, rejected(reason: String), retryLater, unknown(String), transportError
  public static func parse(outcome: String?, reason: String?) -> ReferralClaimOutcome   // ADDED
  public var analyticsValue: String { get }   // credited/rejected/retry_later/unknown/error   ADDED
}
public enum ReferralClaimDecision: Equatable { case claim, wait, discard }
public enum ReferralClaimPolicy {
  public static let minRetryInterval: TimeInterval   // 3600
  public static let nonFinalRejectionReasons: Set<String>   // ["disabled", "retry_later"]   ADDED
  public static func decide(pending: PendingReferral?, isOnboarded: Bool, skippedOnboarding: Bool,
                            isDebugReplay: Bool, now: Date, windowDays: Int = 14) -> ReferralClaimDecision
  public static func shouldMarkFinal(after outcome: ReferralClaimOutcome) -> Bool
  public static func apply(_ outcome: ReferralClaimOutcome, to store: PendingReferralStore)   // ADDED
}

public enum ReferralStatus: String, Codable, Sendable {
  case active, unlocked, unlockedPendingCode = "unlocked_pending_code"
  public init(lenient raw: String?)   // ADDED; unknown → .active. Decodable is lenient too.
}
public struct ReferralReward: Codable, Equatable, Sendable {
  public let code: String; public let expiresAt: Date?; public let reissueCount: Int
  public init(code:expiresAt:reissueCount:)    // ADDED (needed by the VM's fakes)
  public init?(dictionary: [String: Any])      // ADDED
}
public struct ReferralSnapshot: Codable, Equatable, Sendable {
  public static let defaultTarget: Int   // 5                         ADDED
  public static let cacheKey: String     // "referralSnapshotCache"   ADDED
  public let code: String; public let count: Int; public let target: Int
  public let status: ReferralStatus; public let reward: ReferralReward?
  public init(code:count:target:status:reward:)
  public init?(dictionary: [String: Any])
  public var effectiveTarget: Int { get }
  public var displayCount: Int { get }
  public func cacheData() -> Data?                                 // ADDED
  public static func fromCache(_ data: Data?) -> ReferralSnapshot? // ADDED
}

public struct ReferralEligibilityInput: Equatable {
  public var flagEnabled, isDebugReplay, converted, hasFullAccess, autoShownBefore, hasPendingStandCode: Bool
  public var snapshot: ReferralSnapshot?
  public init(flagEnabled:isDebugReplay:converted:hasFullAccess:autoShownBefore:hasPendingStandCode:snapshot: = nil)
}
public enum ReferralEligibility {
  public static let inviteCodeEntryWindowDays: Int   // 14   ADDED
  public static func shouldAutoShow(_ input: ReferralEligibilityInput) -> Bool
  public static func showsProfileRow(flagEnabled: Bool, snapshot: ReferralSnapshot?, isPremium: Bool) -> Bool
  public static func showsInviteCodeEntry(isOnboarded: Bool, firstLaunchAt: Date?, now: Date, hasPending: Bool, isFinal: Bool) -> Bool
  public static func showsHardPaywallLink(flagEnabled: Bool, hardPaywallFlag: Bool, isHardPaywall: Bool) -> Bool
}

public enum ReferralPageState: Equatable {
  case loading, notEnrolled, enrolling
  case active(count: Int, target: Int, code: String)
  case unlocked(code: String, reward: ReferralReward, alreadyPremium: Bool)
  case unlockedPendingCode
  case redeemed
  case error(retryable: Bool)
}
public enum ReferralPageEvent: Equatable {
  case snapshotLoaded(ReferralSnapshot?, fromCache: Bool)
  case inviteTapped, retryTapped
  case enrollSucceeded(ReferralSnapshot), enrollFailed(retryable: Bool)
  case redeemTapped(at: Date)
  case premiumChanged(isPremium: Bool, at: Date)
  case reissueSucceeded(ReferralReward), reissueFailed(exhausted: Bool)
}
public enum ReferralPageEffect: Equatable {
  case enroll, presentShareSheet(code: String), openRedeem(code: String)
  case track(event: String, properties: [String: String])
  case markRewardUnlockedSeen
}
public struct ReferralPageMemory: Equatable {
  public var lastSeenCount: Int; public var rewardUnlockedSeen: Bool; public var lastRedeemTapAt: Date?
  public init(lastSeenCount: Int = 0, rewardUnlockedSeen: Bool = false, lastRedeemTapAt: Date? = nil)
}
public enum ReferralPageReducer {
  public static let redeemAttributionWindow: TimeInterval   // 1800   ADDED
  public enum AnalyticsEvent { progressSeen, rewardUnlocked, redeemTapped, rewardRedeemed, reissueRequested }  // String constants, ADDED
  public static func reduce(state: ReferralPageState, event: ReferralPageEvent,
                            memory: inout ReferralPageMemory, isPremium: Bool) -> (ReferralPageState, [ReferralPageEffect])
}

public enum ReferralShareText {
  public static let placeholder: String       // "{link}"            ADDED
  public static let defaultTemplate: String   // spec §12 default    ADDED
  public static func render(template: String, link: URL) -> String
}

public enum PostOnboardingStep: Equatable { case standJoin, referral, none }
public enum PostOnboardingPresenter {
  public static func next(hasPendingStandCode: Bool, referralEligible: Bool) -> PostOnboardingStep
  public static func canPresentWelcomeOffer(referralPageOpen: Bool) -> Bool
  public static func canPresentPersonalDeclarationPrompt(referralPageOpen: Bool) -> Bool   // ADDED
}
```

## Deviations from the agreed contract

Every one is additive. No agreed signature changed, so code written against
the agreed contract compiles unchanged.

1. **`ReferralClaimPolicy.decide` gained `windowDays: Int = 14`** as a trailing
   defaulted parameter, so FE-CLM-06 (expired pending → don't claim, clear it)
   is decided by the policy itself and returns `.discard`. Calls without it
   still compile.
2. **`PendingReferralStore.init`'s `now` default is `{ Date() }`**, not
   `Date.init`. Same type, same behaviour; avoids an overload-resolution
   wrinkle.
3. **Added helpers** (marked ADDED above): `PendingReferral.init` and
   `isExpired`, the store's key constants and `windowDays`,
   `ReferralClaimOutcome.parse(outcome:reason:)` and `analyticsValue`,
   `ReferralClaimPolicy.nonFinalRejectionReasons` and `apply(_:to:)`,
   `ReferralStatus.init(lenient:)`, `ReferralReward.init` and
   `init?(dictionary:)`, `ReferralSnapshot.defaultTarget`, `cacheKey`,
   `cacheData()` and `fromCache(_:)`, `ReferralEligibility.inviteCodeEntryWindowDays`,
   `ReferralPageReducer.redeemAttributionWindow` and `AnalyticsEvent`,
   `ReferralShareText.placeholder` and `defaultTemplate`,
   `PostOnboardingPresenter.canPresentPersonalDeclarationPrompt` (FE-ORD-05).
4. **`ReferralEligibilityInput.init`'s `snapshot` defaults to `nil`.**

## Behaviour the app layer needs to know

### Links
- `code(from:)` returns nil for **any** URL carrying a `stand` path segment or
  `stand` host, even with a `?ref=` on it. A Stand link is never a referral.
- `code(fromBranchParams:)`: a valid `ref` wins; an unusable `ref` falls
  through to `~referring_link`.
- `shareURL(code:host:)` returns nil for a code that does not normalise or an
  empty host. Pass Remote Config `referralLinkDomain` (default
  `speaklife.app.link`) as the host.
- `normalize` is a byte-for-byte copy of `StandLink.normalize`. It and the
  server's `normalizeCode` agree on every row of the shared fixture. Known
  theoretical divergence, not in the fixture: the client keeps non-ASCII
  letters and digits through the separator strip and then rejects them, while
  the server strips them. So a string like `K7MQ2XPAÄ` is nil on the client but
  `K7MQ2XPA` on the server. The client is the stricter side, so it never sends
  a code the server would reject.

### Pending referral
- Storage keys: `pendingReferral` (JSON-encoded `PendingReferral`, default
  `JSONEncoder` date strategy) and `referralClaimFinal` (Bool).
- `capture` order: final → `.alreadyClaimed`; bad code → `.invalid`; something
  pending → `.alreadyPending`; otherwise `.captured`. Map the result straight
  to `referral_link_opened.outcome` (`captured` / `already_pending` /
  `invalid`). `existing_user` is the app's call (already onboarded), made
  before `capture` is reached.
- Reading `pending` clears expired, corrupt, or post-final values as a side
  effect. `clear()` does not set the final flag; `markFinal()` does.
- The store takes no feature flag (FE-FLG-03).

### Claim
- `decide` order: no pending → `.wait`; debug replay → `.wait`; skipped
  onboarding (iCloud restore) → `.discard`; expired → `.discard`; not
  onboarded → `.wait`; last attempt under an hour ago → `.wait`; else `.claim`.
  On `.discard` the app calls `store.clear()`.
- Map a thrown error of any kind (network, timeout, `unavailable`,
  `unauthenticated`, `resource-exhausted`) to `.transportError`, and the
  callable's `{outcome, reason}` through `ReferralClaimOutcome.parse`.
- `apply(outcome, to: store)` marks final for `credited` and for `rejected`
  with any reason except `disabled` / `retry_later`; everything else calls
  `recordAttempt()`. Read `pending?.attempts` **before** `apply` if you want the
  attempt number of the call just made, or after it for the running total.
- Use `outcome.analyticsValue` for `referral_claim_result.outcome`; never put
  the code in the event.

### Snapshot
- `init?(dictionary:)` expects Firestore `Timestamp`s already converted to
  `Date`; it also accepts seconds since 1970 as a number. Numbers may be
  `Int`, `Int64`, `Double` or `NSNumber`. Nil only when `code` is missing or
  blank. Unknown status → `.active`; missing `count`/`target` → 0 (and
  `effectiveTarget` turns 0 into 5); a `reward` map without a `code` → nil.
- Cache with `cacheData()` / `fromCache(_:)` under `ReferralSnapshot.cacheKey`.
  Corrupt bytes give nil.

### Eligibility
- `shouldAutoShow` also returns false when the snapshot exists with a status
  other than `.active` (FE-ENT-08).
- It is pure. Set `referralAutoShown` only when the page is actually
  presented, so a Stand code taking the turn does not burn it (FE-ENT-05).
- `showsProfileRow`: hidden when `isPremium && snapshot.reward != nil`
  (FE-ENT-12, "redeemed"); otherwise shown when the status is `.unlocked` or
  `.unlockedPendingCode` even with the flag off (FE-FLG-02); otherwise follows
  the flag. **Spec ambiguity worth a product call:** a D7 user (subscribed
  before unlocking) who has a reward but has not redeemed it also matches
  "premium and a reward exists", so the row hides for them too. The page itself
  still handles them (FE-PAG-14) if reached another way, for example from the
  unlock push.
- `showsInviteCodeEntry`: nil `firstLaunchAt` hides the row (treated as an
  older install). The boundary is inclusive: exactly 14 days still shows.

### Page reducer
- Persist `ReferralPageMemory` after every `reduce`. It holds what makes
  `referral_progress_seen` and `referral_reward_unlocked` fire once.
- `snapshotLoaded(_, fromCache: true)` only acts while `.loading`. Server
  snapshots always replace the state (even with a lower count), except while
  `.enrolling`, where they are ignored so the enroll result lands and the share
  sheet opens exactly once. A server `nil` leaves `.error` alone, otherwise
  goes to `.notEnrolled`.
- `enrollSucceeded` returns `presentShareSheet(code:)` only if the record is
  `.active`. An existing unlocked record lands on its own state with no sheet.
- `inviteTapped` from `.active` re-opens the share sheet. The VM tracks
  `referral_share_tapped` itself, since it alone knows `entry`.
- `retryTapped` only acts on `.error(retryable: true)`.
- `unlocked` with `isPremium` and a stored `lastRedeemTapAt` derives
  `.redeemed` (a relaunch after redeeming). Without a tap it is
  `.unlocked(alreadyPremium: true)` (FE-PAG-14, D7 copy).
- `premiumChanged(isPremium: true, at:)` within 30 minutes after the redeem tap
  → `.redeemed` and `referral_reward_redeemed`.
- An `.unlocked` status with no reward is shown as `.unlockedPendingCode`.
- `referral_reward_unlocked` fires the first time either `unlocked` or
  `unlocked_pending_code` is seen, from cache or server, followed by
  `.markRewardUnlockedSeen`. It carries no properties: the VM adds
  `days_since_enrolled` if it has the enrol date.
- Copy-only outcomes are the VM's: "Not available right now"
  (`error(retryable: false)`), "Contact support" plus the prefilled email
  (after `reissueFailed(exhausted: true)`, where the state stays on the old
  code), and the D7 renewal copy (`alreadyPremium: true`).
- Analytics effects carry only counts, targets and a `result` string. Never a
  referral code, reward code or uid. `openRedeem(code:)` carries the reward code
  for the redeem URL and is not analytics.

### Share text
- Replaces the first `{link}`, drops any others, appends ` <link>` if the
  template has none, and returns just the link for a blank template. The link
  appears exactly once.

## Rows not covered in Core
- **FE-LNK-07** (`StandLink.code(from:)` refuses `/r/`): `StandLink` is in the
  app target, so the test belongs in `SpeakLifeTests`.
- **FE-ENT-17** (the hard paywall link opens the page and closing it returns to
  the paywall): presentation wiring in the app. FE-ENT-15/16 cover the
  decision.
- FE-VM, FE-CAP and FE-QA rows belong to the app layer.

## Not compiled
This layer was written in a Linux container with no Swift toolchain. Nothing
here has been compiled or run yet. The first `swift test` on macOS is the real
check.
