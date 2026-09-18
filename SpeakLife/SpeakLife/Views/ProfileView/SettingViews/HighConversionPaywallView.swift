//
//  HighConversionPaywallView.swift
//  SpeakLife
//
//  Data-driven paywall - Remote Config flag: useHighConversionPaywall
//  Fixes: 70% abandon rate, missing price anchor, weak social proof
//
//  Copy is IDENTITY-LED (supersedes the pain-led version, which superseded the
//  "speak to every storm" positioning and, before that, the old personalized-
//  headline stack; retired variants high_conversion_v1 / _succinct_v1 /
//  _clean_v1 / _clean_dark_v1 / _storm_* / _pain_*).
//
//  The screen sells who the user becomes, never what the app has. Nobody
//  subscribes to a capability; they subscribe to who they will be once they
//  have it, and this app's claim is that speaking God's Word puts a person in
//  their right identity — unshakable, walking in authority, training for
//  reigning, living from Jesus rather than from what is happening to them.
//
//  Three beats, aimed at the problem the user named in onboarding (`UserPain`),
//  which still resolves every personalized string even though beat 1 no longer
//  says it out loud:
//
//    1. Name who they are     — the headline says who they are in Jesus
//    2. Turn it               — why what they've been doing hasn't moved it,
//                               and the mechanism that does (spoken, not read)
//    3. Name who they become  — five rows whose titles are the person this
//                               makes them (unshakable, walking in authority,
//                               living from their identity in Jesus), each with
//                               the concrete mechanic underneath it
//
//  The storm positioning is not gone; it is beat 2, where a mechanism belongs.
//  The problem is not gone either; it is the subhead's first half and it is what
//  `UserPain` still resolves the whole screen from.
//
//  Tracks paywallVariant on all events:
//    - "high_conversion_identity_v1"            (classic dark layout)
//    - "high_conversion_identity_clean_v1"      (light minimal layout via
//      Remote Config flag useCleanPaywallVariant: headline + illustration +
//      two plan cards + Continue)
//    - "high_conversion_identity_clean_dark_v1" (clean layout skinned with the
//      classic dark gradient/colors, via useCleanPaywallDarkTheme on top of
//      useCleanPaywallVariant)
//  The "identity" segment marks this reposition's release point so the rollout
//  reads as a clean before/after against the retired "pain" names.
//
//  If identity underperforms pain on shown→trial over a comparable window, the
//  HEADLINE is the thing to revert (the retired lines are in
//  docs/paywall-copy-research.md). The rows, the trial timeline and the pricing
//  fix shipped in the same release but are independent of beat 1.
//

import SwiftUI
import StoreKit

// MARK: - Pain Resolution
//
/// The problem the user is actually carrying, resolved from whatever the flow
/// managed to learn about them. This is the paywall's personalization spine —
/// the headline names it, the subhead turns it, and the solution rows say
/// concretely how SpeakLife answers *that* — and the onboarding mechanism
/// screen reads it too (see the extension in DirectOnboardingView).
///
/// **Sized to the matcher, not to the picker.** An earlier version had seven
/// cases, mirroring the seven options on the old category screen. But a user
/// describing their own situation can land in any of forty-odd declaration
/// categories, and seven buckets sent fear, loneliness, grief, addiction,
/// bitterness and every family situation to the same generic catch-all — which
/// is the one outcome a pain-led paywall cannot afford. These fifteen cover the
/// territory the matcher actually produces. `more` is still the catch-all, but
/// it should now be rare rather than routine.
enum UserPain: String, CaseIterable {
    case peace       // a mind that will not stop
    case fear        // afraid, under attack, dreading what is coming
    case health      // the body
    case abundance   // provision, work, debt, housing
    case identity    // who they are, what they are worth
    case shame       // condemnation, what they did or what was done
    case bondage     // the thing they cannot stop going back to
    case purpose     // calling, direction, a new chapter
    case joy         // flat, heavy, joyless
    case grief       // loss
    case loneliness  // no one close
    case marriage    // the marriage itself
    case family      // a child, a prodigal, a womb
    case nearness    // God feels far
    case more        // catch-all

    // MARK: Resolution

    /// From an onboarding segment.
    ///
    /// `direct` stamps `direct_<UserPain.rawValue>`, which round-trips exactly.
    /// The other six arms stamp `<arm>_<HeaviestBurden.shortLabel>`, whose seven
    /// values are all still case names here, so they round-trip too. The quiz
    /// arm stamps a `QuizSegment` name, which maps onto the nearest pain.
    /// Returns nil for anything unrecognized (including the quiz's
    /// `unsegmented`) so the caller falls back to unpersonalized copy rather
    /// than guessing at someone's problem.
    static func from(segment: String) -> UserPain? {
        guard !segment.isEmpty else { return nil }
        switch segment {
        case "battlefield_mind":    return .peace
        case "believer_authority":  return .more
        case "already_yours":       return .abundance
        case "his_heart":           return .nearness
        case "unsegmented":         return nil
        default: break
        }
        let label = segment.split(separator: "_").last.map(String.init) ?? segment
        return UserPain(rawValue: label)
    }

    /// From the category the declaration matcher assigned to what the user
    /// wrote. This is the path that has to be exhaustive: it is the only thing
    /// standing between a user's own words and generic paywall copy.
    ///
    /// Bible-book categories and anything else unlisted fall to `more`, which
    /// is the one bucket whose copy assumes nothing about the domain.
    static func from(categoryRaw: String) -> UserPain {
        switch DeclarationCategory(rawValue: categoryRaw) {
        case .anxiety, .rest, .hardtimes, .mentalHealth:            return .peace
        case .fear, .godsprotection, .warfare, .blood, .nameOfJesus: return .fear
        case .health, .wellness:                                     return .health
        case .wealth, .favor, .work, .business, .housing, .debt, .education:
            return .abundance
        case .identity, .confidence:                                 return .identity
        case .grace, .purity, .innerHealing, .obedience, .forgiveness:
            return .shame
        case .addiction, .anger:                                     return .bondage
        case .destiny, .wisdom, .newSeason, .miracles:               return .purpose
        case .joy, .praise, .gratitude:                              return .joy
        case .grief, .divorce:                                       return .grief
        case .love, .relationship, .friendship:                      return .loneliness
        case .marriage:                                              return .marriage
        case .parenting, .singleParent, .salvation, .fertility:      return .family
        case .godsheart, .faith, .hope, .heaven, .spiritualGrowth, .speaklife:
            return .nearness
        default:                                                     return .more
        }
    }

    /// From the category the user actually keeps opening inside the app.
    ///
    /// This is the returning user's equivalent of an onboarding segment, and
    /// it is better evidence than one: a segment is what somebody said once at
    /// the end of a flow, this is what they have done repeatedly since. The
    /// caller gates it on a real repeat count — see
    /// `HighConversionPaywallView.trackedCategoryPain` — so a single tap on
    /// one category never renames someone's problem.
    ///
    /// `general` returns nil: it is the tracker's "no signal" value, not a
    /// fifteenth kind of pain.
    static func from(category: UserPreferencesTracker.CategoryType) -> UserPain? {
        switch category {
        case .anxiety, .rest: return .peace
        case .fear:           return .fear
        case .health:         return .health
        case .confidence:     return .identity
        case .joy:            return .joy
        case .marriage:       return .marriage
        case .love, .faith:   return .nearness
        case .hope:           return .purpose
        case .general:        return nil
        }
    }

    /// The coarse burden this pain belongs to, for the shared onboarding
    /// screens (notification copy, goal word, feed seeding) that only speak the
    /// seven-value vocabulary.
    var burden: HeaviestBurden {
        switch self {
        case .peace, .fear:                       return .peace
        case .health:                             return .health
        case .abundance:                          return .abundance
        case .identity, .shame, .bondage:         return .identity
        case .purpose:                            return .purpose
        case .joy, .grief, .loneliness:           return .joy
        case .marriage, .family, .nearness, .more: return .allOfIt
        }
    }

    // MARK: Copy

    /// Headline. Says who they are in Jesus, present tense, second person.
    ///
    /// **This used to name the problem** ("Your mind won't stop.", "The numbers
    /// don't work right now."), and that version is what the 16.5%
    /// onboarding paywall→purchase baseline was measured on. The reframe is
    /// deliberate: a problem headline sells relief, and relief is a smaller
    /// thing than what this app actually claims. Speaking God's Word does not
    /// return you to neutral, it puts you in your right identity — unshakable,
    /// walking in authority, reigning in life rather than surviving it — and a
    /// screen that opens on what is wrong has already agreed to sell the
    /// smaller thing.
    ///
    /// Every line is short, second person, and standing on a specific verse:
    /// the mind of Christ (1 Cor 2:16), bold as a lion (Prov 28:1), healed
    /// (Isa 53:5), heir (Rom 8:17), no condemnation (Rom 8:1), free (John
    /// 8:36), the joy of the Lord as strength (Neh 8:10). Scripture is what
    /// keeps an identity claim from being flattery.
    ///
    /// The problem is not gone, it moved into the subhead, which still names
    /// the domain and still says what to do about it. Beat 1 asserts, beat 2
    /// turns, beat 3 says who they become.
    var problem: String {
        switch self {
        case .peace:      return "You have the mind of Christ."
        case .fear:       return "You are as bold as a lion."
        case .health:     return "You are healed and whole."
        case .abundance:  return "You are an heir, not a beggar."
        case .identity:   return "You are who God says you are."
        case .shame:      return "There is no condemnation on you."
        case .bondage:    return "Jesus already made you free."
        case .purpose:    return "You are called, and already equipped."
        case .joy:        return "The joy of the Lord is your strength."
        case .grief:      return "You are held, and you are not alone."
        case .loneliness: return "You are never alone again."
        case .marriage:   return "You carry peace into your home."
        case .family:     return "You are the one who stands for them."
        case .nearness:   return "You are His, and He is near."
        case .more:       return "You carry the authority Jesus gave you."
        }
    }

    /// Subhead. **Declare it, then act on it.**
    ///
    /// The headline one line above already named the problem, so this line says
    /// what to do about it — and it names the second half on purpose. Saying it
    /// and then living unchanged is the thing James calls dead faith, and a
    /// paywall that only promises a feeling ("expect instead of hope") is
    /// selling one internal state in place of another. Both halves, every time:
    /// the declaration, and the move that proves you believed it.
    ///
    /// Ten to thirteen words. No product name — the four rows underneath are
    /// where SpeakLife shows up.
    var solution: String {
        switch self {
        case .peace:      return "Declare God's peace over your mind, then walk through the day unshakable."
        case .fear:       return "Declare God's protection over tomorrow, then walk into it unafraid."
        case .health:     return "Declare the healing the cross paid for, then treat your body like it's yours."
        case .abundance:  return "Declare God's supply over your finances, then decide like the provision is there."
        case .identity:   return "Declare what God already said you are, then carry yourself like it's true."
        case .shame:      return "Declare what the cross already settled, then walk clean and stay there."
        case .bondage:    return "Declare the freedom Jesus bought you, then walk away the next time."
        case .purpose:    return "Declare the steps God already ordered, then take the next one."
        case .joy:        return "Declare God's joy over your day, then go live it out loud."
        case .grief:      return "Declare God's comfort over your heart, then let Him carry what you can't."
        case .loneliness: return "Declare God's nearness over your life, then live like He is in the room."
        case .marriage:   return "Declare God's peace over your home, then lead it like peace lives there."
        case .family:     return "Declare God's promises over the people you love, then stand instead of worrying."
        case .nearness:   return "Declare that God is near you, then go spend time with Him today."
        case .more:       return "Declare God's Word with the authority Jesus used, then live from it."
        }
    }

    /// The place this pain lives, used to aim the shared solution rows. Reads
    /// naturally after "over" and after "about".
    var domain: String {
        switch self {
        case .peace:      return "your mind"
        case .fear:       return "your future"
        case .health:     return "your body"
        case .abundance:  return "your provision"
        case .identity:   return "who you are"
        case .shame:      return "what you're carrying"
        case .bondage:    return "the thing that keeps winning"
        case .purpose:    return "your steps"
        case .joy:        return "your day"
        case .grief:      return "your heart"
        case .loneliness: return "your life"
        case .marriage:   return "your home"
        case .family:     return "the people you love"
        case .nearness:   return "your walk with God"
        case .more:       return "what you're facing"
        }
    }

    /// Headline for a paywall opened from inside the app instead of at the end
    /// of onboarding.
    ///
    /// A cold-open pain headline is the wrong screen for a returning user.
    /// "You've prayed about it. It hasn't moved." is a stranger's guess aimed
    /// at somebody whose behaviour we can actually see, and it was going to
    /// 135 of the 191 settings impressions in the last 30 days, which convert
    /// at a sixth of the onboarding rate.
    ///
    /// The first sentence is a statement about something the app watched the
    /// user do, which is why this is only ever reachable through
    /// `trackedCategoryPain` — they really have come back to this category,
    /// repeatedly, of their own accord. Resolved from a segment instead, it
    /// would be a claim we cannot support.
    ///
    /// The second sentence is the identity the first one earns. Recognition
    /// first, then the assertion: told "it is already yours" cold, a returning
    /// user hears marketing; told it right after the app has shown it was
    /// paying attention, they hear it.
    var returningProblem: String {
        switch self {
        case .peace:      return "You came back for peace. It is already yours."
        case .fear:       return "You came back for courage. It is already yours."
        case .health:     return "You came back for healing. It is already yours."
        case .abundance:  return "You came back for provision. It is already yours."
        case .identity:   return "You came back for who you are. That is settled."
        case .shame:      return "You came back for grace. It already covered you."
        case .bondage:    return "You came back for freedom. Jesus already bought it."
        case .purpose:    return "You came back for direction. Your steps are ordered."
        case .joy:        return "You came back for joy. It is already yours."
        case .grief:      return "You came back for comfort. He is already close."
        case .loneliness: return "You came back for His presence. He never left."
        case .marriage:   return "You came back for your home. Peace belongs there."
        case .family:     return "You came back for them. God has not let go."
        case .nearness:   return "You came back to be near Him. He is right here."
        case .more:       return "You came back to the Word. It is working in you."
        }
    }

    /// Returning-user subhead. One shape for all fifteen on purpose: this user
    /// already knows what SpeakLife is, so the line's only job is to name what
    /// is still behind the wall and aim it at the domain they keep returning
    /// to. Fifteen bespoke sentences here would be fifteen invented
    /// differences, which is the thing this file already decided not to do.
    var returningSolution: String {
        "Unlock all of it and become unshakable over \(domain)."
    }

    /// The bespoke first row — the new identity in Jesus, in this pain's own
    /// domain. This is the row that has to prove the product understood both
    /// the problem and who the person is on the other side of it.
    private var leadSolution: (icon: String, title: String, detail: String) {
        switch self {
        case .peace:      return ("megaphone.fill", "You win the battle in your mind", "Declarations written for a racing mind, short enough to say out loud and mean.")
        case .fear:       return ("megaphone.fill", "You walk into tomorrow unafraid", "Declarations on God's protection and His hold on what is coming.")
        case .health:     return ("megaphone.fill", "You live in the healing the cross paid for", "Healing declarations straight from Scripture, built to speak over your body daily.")
        case .abundance:  return ("megaphone.fill", "You live like your Father owns it all", "Declarations on provision, favor, and open doors, for the bills and the decisions.")
        case .identity:   return ("megaphone.fill", "You live from who Jesus says you are", "Identity declarations spoken in first person, until they are what you believe.")
        case .shame:      return ("megaphone.fill", "You walk clean and stay there", "Declarations on grace and a settled record, written for the days it comes back.")
        case .bondage:    return ("megaphone.fill", "You walk free and stay free", "Declarations that tell it where it stands instead of asking it to ease off.")
        case .purpose:    return ("megaphone.fill", "You move like someone with orders", "Declarations over your steps, your work, and the door God is opening.")
        case .joy:        return ("megaphone.fill", "You carry joy the day cannot set", "Declarations on God's joy and strength, made to speak first thing in the morning.")
        case .grief:      return ("megaphone.fill", "You grieve held, never alone", "Declarations on God's nearness to the brokenhearted, for the hard mornings.")
        case .loneliness: return ("megaphone.fill", "You live knowing He is right here", "Declarations on God's presence and His people, for the quiet hours.")
        case .marriage:   return ("megaphone.fill", "You lead your home in peace", "Declarations over your marriage and your household, not over your spouse's choices.")
        case .family:     return ("megaphone.fill", "You stand for them without flinching", "Declarations over your children and the people you are believing God for.")
        case .nearness:   return ("megaphone.fill", "You live close to Him again", "Declarations drawn straight from what God says about being near you.")
        case .more:       return ("megaphone.fill", "You live from your new identity in Jesus", "The exact Word for your exact situation, written to speak out loud.")
        }
    }

    /// Who they become, with the mechanic that makes it real underneath.
    ///
    /// **Titles say the person, details say the product.** These rows used to
    /// be a feature list with the problem's name dropped in ("Ask the Bible
    /// anything", "Thirty days, not one good day"). Nobody subscribes to a
    /// capability; they subscribe to who they will be once they have it, and
    /// the whole app is built on the claim that speaking God's Word makes you
    /// somebody — unshakable, walking in authority, living from your identity
    /// in Jesus rather than from what is currently happening to you.
    ///
    /// The detail lines still carry the concrete mechanic, and that is not a
    /// compromise. An identity promise with nothing under it is a slogan, and
    /// the storm arm already proved what happens when this screen sells a claim
    /// the user cannot see the machinery of.
    ///
    /// Row one is written for this pain; rows two through five run the same arc
    /// for everyone — walking in authority, staying unshakable through the day,
    /// training for reigning rather than collecting good days, knowing what God
    /// says — aimed at this pain's domain. That shared arc is what keeps fifteen
    /// sets of copy honest instead of fifteen sets of invented differences.
    ///
    /// "Training for reigning" is Romans 5:17 said the way a person would say
    /// it, and it is the one row that has to justify a thirty-day plan: a plan
    /// is a training claim, so the row makes the training claim out loud rather
    /// than counting days.
    ///
    /// Row two carries the sixty-second morning promise and sits second on
    /// purpose: it is the one row that answers "what does this actually cost me
    /// each day?", and the clean layout only renders the first three. Every
    /// user sees it, on every variant, whatever they came in for.
    var solutions: [(icon: String, title: String, detail: String)] {
        [
            leadSolution,
            ("sunrise.fill", "You walk in authority before the day starts", "One minute out loud every morning, and you take charge of \(domain) before anything else does."),
            ("headphones", "You stay unshakable all day", "Guided declarations over \(domain) for the morning, the commute, and before bed."),
            ("calendar", "You are training for reigning", "Thirty days of speaking over \(domain), because reigning in life gets trained into you, not wished onto you."),
            // Identity voice from the copy pass, but the claim stays what the
            // chat now actually does. "Chapter and verse in seconds" sells an
            // answer, and every faith app answers; the difference is that this
            // one hands back a line to speak and offers to save it.
            ("bubble.left.and.bubble.right.fill", "You leave with something to speak", "Bring \(domain) and get back a declaration in your mouth, not just an answer.")
        ]
    }

    var solutionHeader: String { "Who you become" }

    /// Rows for users we have no pain for at all (settings, feature gates, the
    /// quiz's `unsegmented` bucket).
    static let generalSolutions: [(icon: String, title: String, detail: String)] = UserPain.more.solutions

    /// The last line before the tap. One line for everybody — see
    /// `HighConversionPaywallView.closingAssuranceLine` for why it stopped
    /// varying by pain.
    static let closingAssurance = "Speak Life to activate God's promises."
}

// MARK: - Paywall Testimonials
//  Real App Store reviews, tagged by the `UserPain` each one actually speaks
//  to, so the paywall's proof is aimed at the same problem its headline named.
//
//  Why this exists: the paywall personalizes the headline, the subhead and
//  five solution rows off `UserPain`, and then used to hand every one of those
//  users the same fixed anxiety review. A user who came in on provision or on
//  a marriage read fifteen lines written for them followed by somebody else's
//  problem, at the exact moment the screen needs them to believe it works for
//  theirs.
//
//  **Every quote here is a real review. Nothing in this file may be written.**
//  If a pain has no real review, it falls back to the broadest true one rather
//  than getting an invented match — see `fallback` below. A fabricated
//  testimonial is not a copy decision, it is a false statement about a real
//  person shipped next to a price.
//
//  Buckets with NO real review yet (currently fall back):
//      health · abundance · shame · purpose · grief · loneliness ·
//      marriage · family
//  These are worth sourcing deliberately — a real provision or healing review
//  would immediately serve the three highest-volume unmatched segments.

enum PaywallTestimonial {

    struct Quote: Identifiable {
        let id = UUID()
        let text: String
        let author: String
        /// The pains this review genuinely speaks to. Tag only what the review
        /// actually says — a stretch here is the same failure as writing one.
        let domains: [UserPain]
    }

    /// The corpus. Order is the display order of the supporting wall.
    static let all: [Quote] = [
        Quote(
            text: "My anxiety attacks stopped after 2 weeks. I speak these declarations every morning and it changed everything.",
            author: "Marcus T., App Store review",
            // Deliberately narrow. This review names a specific outcome on a
            // specific timeline, which is powerful for the reader who came in
            // on a racing mind and an overclaim for everyone else.
            domains: [.peace, .fear]
        ),
        Quote(
            text: "I've tried journaling, therapy, everything. Nothing rewired my thinking like speaking God's Word daily. This app is different.",
            author: "DeShawn R., App Store review",
            // Behaviour-change proof, which outperforms outcome proof in this
            // category: he is not claiming a circumstance moved, he is saying
            // the practice took where other practices did not.
            domains: [.peace, .identity, .bondage]
        ),
        Quote(
            text: "I was skeptical but this is the real deal. My mind literally works differently now. Worth every penny.",
            author: "Priya K., App Store review",
            domains: [.identity, .more]
        ),
        Quote(
            text: "I love this app. To feed on the promises of God regularly throughout the day is so uplifting and encouraging. It feeds my soul.",
            author: "Tina, App Store review",
            // The fallback. It claims no outcome and no timeline, so it is true
            // for every pain on the screen — which is exactly what a fallback
            // has to be.
            domains: [.joy, .nearness, .more]
        ),
        Quote(
            text: "This app was created under the manifestation and direction of the Holy Spirit, bringing life through scripture and meditation to God's people.",
            author: "Crash L., App Store review",
            domains: [.nearness]
        )
    ]

    /// Shown when the named pain has no real review. The broadest true quote in
    /// the corpus, never the most impressive one.
    static let fallback: Quote = all[3]

    /// The review that speaks to this user's problem, or the fallback.
    ///
    /// `nil` pain (settings with no tracked category, the quiz's unsegmented
    /// bucket) gets the fallback too: with no problem named, there is no match
    /// to make, and the quote that claims least is the honest one.
    static func featured(for pain: UserPain?) -> Quote {
        guard let pain else { return fallback }
        return all.first { $0.domains.contains(pain) } ?? fallback
    }

    /// The rest of the wall, in corpus order, with the featured one removed so
    /// the same review never appears twice on one screen.
    static func supporting(excluding featured: Quote) -> [Quote] {
        all.filter { $0.id != featured.id }
    }
}

struct HighConversionPaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore
    @ObservedObject private var preferencesTracker = UserPreferencesTracker.shared

    @State private var selectedPlan: PlanType = .annual
    @State private var isShowingError = false
    @State private var errorMessage = ""
    @State private var showPrivacyPolicy = false
    @State private var showPayWhatYouCan = false
    @State private var showCloseButton = false
    @State private var timeOnPaywall: Date = Date()
    /// Per-product intro-offer eligibility (product id → eligible), checked
    /// against Apple per user. Keyed per product because eligibility is asked
    /// of whichever plan is selected (annual / monthly / weekly), and a single
    /// global bit checked only against the annual product mislabels the others.
    @State private var trialEligibility: [String: Bool] = [:]

    // MARK: - Welcome Offer
    //
    // MOVED OUT OF THIS SCREEN. The welcome offer used to appear here, as a
    // state swap when an onboarding user tapped the X without buying. It now
    // fires after the user's first Daily Burst — see WelcomeOfferPresenter.
    //
    // The reason is what the user has at each moment. On the decline path they
    // had opened the app minutes ago and just said no to paying; a cheaper
    // price is the one thing a person who has felt nothing yet has no way to
    // judge. After a burst they have spoken seven declarations out loud and
    // felt it, and the offer is an answer to something they now want.
    //
    // WelcomeOfferView itself is unchanged and still lives in this file. Only
    // where it is presented from moved.

    // MARK: - Post-Purchase Mission State
    // Brief mission/thank-you state shown after a successful purchase from the
    // onboarding paywall (main CTA or welcome offer) BEFORE the original
    // success path runs. Reframes the subscription as mission (the Bible Chat
    // pattern). Settings / feature-gate purchases keep the immediate dismiss —
    // those users are mid-task.
    private enum MissionResolution { case mainPurchase }
    @State private var showMissionScreen = false
    /// Exactly-once guard: the CTA tap and the 6-second auto-advance can race.
    @State private var missionContinued = false
    @State private var missionShownAt = Date()
    @State private var missionResolution: MissionResolution = .mainPurchase

    var callback: (() -> Void)?
    /// Where this paywall is being shown from. Drives the `source` property on
    /// paywall analytics events ('onboarding' | 'settings' | 'feature_gate').
    /// Default of 'settings' matches the dominant non-onboarding callsites
    /// (PremiumView, OptimizedSubscriptionView from HomeView).
    var source: String = "settings"

    /// When true at the callsite, the paywall *may* render hard (no close button).
    /// Actual hardness is gated by Remote Config `showPayWhatYouCanLink` (the
    /// soft-onboarding-paywall switch): hard only takes effect when that soft
    /// switch is OFF. When it's ON, the paywall keeps its close button and the
    /// one-time welcome-offer discount on dismiss. The visible "pay what you
    /// can" link is now a separate switch (`showPayWhatYouCanCTA`) and no longer
    /// affects hardness or the welcome offer.
    var isHardPaywall: Bool = false

    /// Effective hard-paywall state. Caller opts in via `isHardPaywall`, but the
    /// soft-onboarding-paywall Remote Config flag must also be OFF for the wall
    /// to actually render hard.
    private var effectiveIsHardPaywall: Bool {
        isHardPaywall && !subscriptionStore.showPayWhatYouCanLink
    }

    /// Variant string sent to Firebase Analytics on every paywall event. The
    /// "identity" segment marks this reposition's release point so the rollout
    /// reads as a before/after against the retired "pain" variant names, the
    /// same way "pain" read against "storm".
    ///
    /// Renamed because beat 1 changed sides. The pain names still resolve every
    /// personalized string on the screen and `pain` is still on every event —
    /// what stopped being true is that the *headline* names a problem, and a
    /// variant called `pain` sitting above an identity headline would quietly
    /// blend two different screens into one line on the chart.
    private var paywallVariant: String {
        if isCleanVariant {
            return isCleanDarkTheme ? "high_conversion_identity_clean_dark_v1" : "high_conversion_identity_clean_v1"
        }
        return "high_conversion_identity_v1"
    }

    /// Clean minimal layout A/B (Remote Config: useCleanPaywallVariant). Swaps
    /// the whole layout, so it wins over the succinct-props flag. Latched on
    /// first appear so a Remote Config activation while the paywall is on
    /// screen can't swap the layout mid-decision — which would also desync
    /// impression vs conversion variant attribution in the A/B readout.
    @State private var lockedCleanVariant: Bool?
    private var isCleanVariant: Bool {
        lockedCleanVariant ?? subscriptionStore.useCleanPaywallVariant
    }

    /// Dark skin for the clean layout (Remote Config: useCleanPaywallDarkTheme,
    /// only meaningful when the clean layout is on): same minimal format,
    /// themed with the high-conversion paywall's dark gradient + colors so the
    /// paywall keeps visual continuity with the dark onboarding flows. Latched
    /// alongside the layout for the same attribution reason.
    @State private var lockedCleanDarkTheme: Bool?
    private var isCleanDarkTheme: Bool {
        isCleanVariant && (lockedCleanDarkTheme ?? subscriptionStore.useCleanPaywallDarkTheme)
    }

    /// True when this paywall was opened from inside the app (settings, a
    /// feature gate, the upgrade screen) rather than at the end of onboarding.
    /// These users have used SpeakLife; the screen should not talk to them as
    /// if it has never met them.
    private var isReturningUser: Bool { source != "onboarding" }

    /// The pain the user's own in-app behaviour points at: the category they
    /// keep opening, not the one they named once.
    ///
    /// Gated on a real repeat count. One tap on `health` is a look; three is a
    /// pattern, and only a pattern earns a headline that says "you keep coming
    /// back". Below the threshold this returns nil and the screen falls back to
    /// the onboarding segment, then to generic copy — in that order, never
    /// upward into a claim the data does not support.
    private var trackedCategoryPain: UserPain? {
        guard let top = preferencesTracker.topCategories.first,
              top.count >= Self.returningCategoryThreshold,
              let type = UserPreferencesTracker.CategoryType(rawValue: top.category)
        else { return nil }
        return UserPain.from(category: type)
    }

    /// Category selections needed before behaviour counts as a pattern.
    private static let returningCategoryThreshold = 3

    /// The problem this user is carrying, or nil when we don't know.
    /// Everything personalized on this screen hangs off this one value — see
    /// the consistency rule in `docs/paywall-copy-research.md`; it is the
    /// single source of truth for the headline, the subhead, the rows, the
    /// testimonial and the `pain` analytics property, deliberately.
    ///
    /// Behaviour beats the segment for a returning user, and only for them.
    /// Someone who onboarded on `peace` six weeks ago and has opened `health`
    /// every morning since is carrying a health problem now; at the end of
    /// onboarding there is no behaviour yet and the segment is all there is.
    private var pain: UserPain? {
        if isReturningUser, let tracked = trackedCategoryPain { return tracked }
        return UserPain.from(segment: segmentParam)
    }

    /// The four mechanics, described against the user's actual problem when we
    /// know it and generically when we don't.
    private var solutionRows: [(icon: String, title: String, detail: String)] {
        pain?.solutions ?? UserPain.generalSolutions
    }

    /// Header over those rows. It used to answer "how does this fix MY thing?"
    /// and now answers "who does this make me?", which is the question the
    /// price is actually being weighed against.
    private var solutionHeader: String {
        pain?.solutionHeader ?? "Who you become"
    }

    /// Segment-tagged analytics property. Empty string when the user came through
    /// the Control onboarding so paywall events stay backward-compatible.
    private var segmentParam: String {
        appState.onboardingSegment
    }

    /// True when the user just completed PersonalDeclaration in the onboarding
    /// flow. This is the warmest emotional anchor in the funnel — they literally
    /// spoke their own declaration aloud seconds ago. We reference that moment
    /// in the paywall headline + subhead for max continuity.
    private var hasFreshPersonalDeclaration: Bool {
        if let belief = preferencesTracker.personalDeclarationBelief, !belief.isEmpty {
            return true
        }
        return false
    }

    /// Burden goal word (peace / healing / identity / etc.) — drives the
    /// continuity subhead for personal-declaration users so the promise is
    /// specific to what they actually need, not generic.
    private var burdenStyleLabel: String? {
        guard let goalWord = SurveyGoalWord(rawValue: appState.surveyGoalWord) else { return nil }
        return goalWord.styleLabel.lowercased()
    }

    /// Pain-led copy resolution. The headline names the problem; the subhead
    /// turns it and hands off to the mechanism.
    ///
    /// One exception keeps priority over the pain: a user who spoke their own
    /// declaration aloud seconds ago is the warmest moment in the funnel, and
    /// the strongest identity line available is the one they just proved about
    /// themselves. "You just spoke to your storm" is an identity headline —
    /// it names the authority they exercised ten seconds ago — so it stays, and
    /// the pain colours the subhead instead.
    private var resolvedHeadline: String {
        // Returning users first: the declaration branch below belongs to the
        // onboarding moment, and `personalDeclarationBelief` is in-memory only,
        // so it can still be set when the same session later opens settings.
        if isReturningUser {
            if let tracked = trackedCategoryPain { return tracked.returningProblem }
            // Used the app, but no category pattern to point at. Says the one
            // thing that is true of every free user without pretending to know
            // which problem sent them here — and it is the mechanism, which is
            // what this screen sells.
            return "You already have the Word. Start speaking it."
        }
        if hasFreshPersonalDeclaration { return "You just spoke to your storm." }
        // Generic fallback is the identity claim that is true of every believer
        // on this screen, rather than a guess at which one they need.
        return pain?.problem ?? "You carry the authority Jesus gave you."
    }
    private var resolvedSubheadline: String {
        if isReturningUser {
            if let tracked = trackedCategoryPain { return tracked.returningSolution }
            return "Unlock all of it and start living from who Jesus says you are."
        }
        if hasFreshPersonalDeclaration {
            // Falls through to the pain below when we have one. `burdenStyleLabel`
            // reads `surveyGoalWord`, which is written at the END of onboarding
            // — so at the paywall it is either empty or left over from an
            // EARLIER run. That is how a provision paywall shipped with "your
            // joy declarations" over provision rows and a provision closing
            // line: three sources of truth, one of them a run behind.
            if pain == nil, let burden = burdenStyleLabel {
                return "Declare your \(burden) every morning and live like it's done."
            }
            if pain == nil {
                return "Declare it every morning and live like it's already done."
            }
        }
        if let pain { return pain.solution }
        return "The exact Word for what you're facing, in your mouth every morning."
    }
    enum PlanType: String {
        case annual = "annual"
        case monthly = "monthly"
        case weekly = "weekly"
    }

    // MARK: - Prices
    // All amounts come straight from StoreKit (driven by the product IDs set in
    // Remote Config / App Store Connect). No hardcoded prices — if a product
    // hasn't loaded we show a neutral placeholder, never a fake amount.
    private let pricePlaceholder = "—"
    private var annualPrice: String { subscriptionStore.currentOfferedPremium?.displayPrice ?? pricePlaceholder }
    private var monthlyPrice: String { subscriptionStore.currentOfferedPremiumMonthly?.displayPrice ?? pricePlaceholder }
    private var annualPerMonth: String {
        guard let p = subscriptionStore.currentOfferedPremium else { return pricePlaceholder }
        return perMonthString(yearlyProduct: p) ?? pricePlaceholder
    }
    /// % saved on annual vs paying the non-annual plan (weekly×52 or monthly×12)
    /// for a year. nil if not computable.
    private var annualSavingsPercent: Int? {
        guard let annual = subscriptionStore.currentOfferedPremium,
              let a = Double(annual.price.description) else { return nil }
        let comparisonYearly: Double? = showWeeklyPlan
            ? subscriptionStore.currentOfferedWeekly.flatMap { Double($0.price.description) }.map { $0 * 52 }
            : subscriptionStore.currentOfferedPremiumMonthly.flatMap { Double($0.price.description) }.map { $0 * 12 }
        guard let yearly = comparisonYearly, yearly > 0 else { return nil }
        let pct = Int(((yearly - a) / yearly * 100).rounded())
        return pct > 0 ? pct : nil
    }
    /// Per-week equivalent of the annual price (clean variant's right-hand
    /// price on the Annual card). StoreKit price ÷ 52, product's own locale.
    private var annualPerWeek: String {
        guard let p = subscriptionStore.currentOfferedPremium,
              let s = localizedPrice(p.price / 52, in: p) else { return pricePlaceholder }
        return s
    }
    /// What a full year actually costs on the non-annual plan (weekly×52 or
    /// monthly×12). This is the clean variant's strikethrough anchor on the
    /// Annual card and the honesty subline on the non-annual card — a real
    /// derived cost, never an invented anchor price.
    private var nonAnnualYearlyEquivalent: String? {
        if showWeeklyPlan, let w = subscriptionStore.currentOfferedWeekly {
            return localizedPrice(w.price * 52, in: w)
        }
        if let m = subscriptionStore.currentOfferedPremiumMonthly {
            return localizedPrice(m.price * 12, in: m)
        }
        return nil
    }

    // Non-annual plan follows the useWeeklyPlan flag (Weekly vs Monthly), but
    // only honors Weekly when that product actually loaded from StoreKit —
    // otherwise it shows Monthly. This is what prevents displaying a price for a
    // product the store never returned (the source of the phantom "$4.99").
    private var showWeeklyPlan: Bool {
        subscriptionStore.useWeeklyPlan && subscriptionStore.currentOfferedWeekly != nil
    }
    /// Remote Config `onlyShowYearly`: sell the annual plan and nothing else.
    /// When on, the non-annual card is removed from both layouts and Annual is
    /// the only thing the user can select — the same flag and behavior as
    /// OptimizedSubscriptionViewV1, so a single switch covers every paywall.
    /// Annual stays the selection regardless (onAppear pins it), so no purchase
    /// path can end up on a plan that has no card on screen.
    private var onlyShowYearly: Bool { subscriptionStore.onlyShowYearly }
    private var nonAnnualTitle: String { showWeeklyPlan ? "Weekly" : "Monthly" }
    /// Plan identity of the non-annual card, so analytics report "weekly" (not
    /// "monthly") when the useWeeklyPlan flag is on.
    private var nonAnnualPlan: PlanType { showWeeklyPlan ? .weekly : .monthly }
    /// The cadence both plan cards quote in, so the two hero numbers are
    /// actually comparable. Follows the non-annual plan, since that is the one
    /// whose price is fixed to a cadence.
    private var cadenceUnit: String { showWeeklyPlan ? "/wk" : "/mo" }
    /// The annual plan expressed in that same cadence.
    private var annualComparablePrice: String { showWeeklyPlan ? annualPerWeek : annualPerMonth }
    private var nonAnnualPrice: String {
        showWeeklyPlan
            ? (subscriptionStore.currentOfferedWeekly?.displayPrice ?? pricePlaceholder)
            : monthlyPrice
    }

    private var selectedProduct: Product? {
        switch selectedPlan {
        case .annual:  return subscriptionStore.currentOfferedPremium
        case .weekly:  return subscriptionStore.currentOfferedWeekly
        case .monthly: return subscriptionStore.currentOfferedPremiumMonthly
        }
    }

    // MARK: - Trial Eligibility / Intro Offer
    /// Days in the introductory free-trial offer for the given product, read
    /// from the loaded StoreKit Product (never hardcoded). nil when this user
    /// isn't eligible for an intro offer on THIS product (per-product check
    /// done in refreshTrialEligibility) or when the product has no free-trial
    /// intro offer configured. Unknown/not-yet-checked products default to
    /// false, so trial copy never overpromises while eligibility loads.
    private func trialDays(for product: Product?) -> Int? {
        guard let product else { return nil }
        return introTrialDays(for: product, isEligible: trialEligibility[product.id] ?? false)
    }
    /// Trial length for the currently selected plan, nil when not trial-eligible.
    private var selectedPlanTrialDays: Int? { trialDays(for: selectedProduct) }
    /// Stable fingerprint of the three offered product ids; onChange watches it
    /// so eligibility re-runs when products finish loading after first render.
    private var offeredProductIDs: String {
        [
            subscriptionStore.currentOfferedPremium?.id,
            subscriptionStore.currentOfferedPremiumMonthly?.id,
            subscriptionStore.currentOfferedWeekly?.id
        ].map { $0 ?? "" }.joined(separator: "|")
    }
    // MARK: - Body
    var body: some View {
        ZStack {
            // The clean variant is light unless its dark theme is on; the
            // mission and welcome screens keep the dark gradient regardless.
            Group {
                if isCleanVariant && !isCleanDarkTheme && !showMissionScreen {
                    cleanBackground
                } else {
                    backgroundGradient
                }
            }
            .ignoresSafeArea()

            if showMissionScreen {
                // Post-purchase mission screen. Same state-swap pattern as the
                // welcome offer below; takes precedence over both because it
                // only ever appears after a successful purchase.
                PostPurchaseMissionView(onContinue: continueMission)
                    .transition(.opacity)
            } else {
                if isCleanVariant {
                    cleanVariantLayout
                } else {
                    VStack(spacing: 0) {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 0) {
                                headerSection
                                starsOnlyBanner.padding(.top, 20)
                                solutionSection.padding(.top, 24)
                                comparisonSection.padding(.top, 28)
                                remainingTestimonialsSection.padding(.top, DS.Spacing.lg)
                                // The matched review closes the proof, and the
                                // trial timeline sits last because the question
                                // it answers — "what happens to my card, and
                                // when" — is the one being asked at the price,
                                // not four screens earlier.
                                featuredTestimonial.padding(.top, DS.Spacing.lg)
                                trialTimelineSection.padding(.top, DS.Spacing.lg)
                                Spacer(minLength: 20)
                            }
                        }
                        stickyBottomSection
                    }
                }

                if showCloseButton && !effectiveIsHardPaywall { closeButton }
            }

            // Shared purchase spinner — covers both the paywall and the
            // welcome offer (the offer routes purchases through the same
            // declarationStore.isPurchasing flag).
            if declarationStore.isPurchasing { RotatingLoadingImageView() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .bottom)
        .onAppear(perform: onAppear)
        // Products can finish loading after onAppear (Remote Config + StoreKit
        // race the paywall presentation). Re-check eligibility whenever any of
        // the three offered product ids changes.
        .onChange(of: offeredProductIDs) { _ in
            Task { await refreshTrialEligibility() }
        }
        .alert("", isPresented: $isShowingError) {
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage) }
        .sheet(isPresented: $showPrivacyPolicy) { PrivacyPolicyView() }
        .sheet(isPresented: $showPayWhatYouCan) {
            PayWhatYouCanView(callback: callback)
                .environmentObject(subscriptionStore)
                .environmentObject(declarationStore)
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(red:0.07,green:0.10,blue:0.22), Color(red:0.12,green:0.07,blue:0.20), Color(red:0.04,green:0.04,blue:0.12)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    // MARK: - Header
    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            Image("starrySunrise")
                .resizable().aspectRatio(contentMode: .fill)
                .frame(height: 260).clipped()
            LinearGradient(colors: [.clear, Color(red:0.07,green:0.10,blue:0.22)], startPoint: .top, endPoint: .bottom)
                .frame(height: 120)
            VStack(spacing: DS.Spacing.xs) {
                Image("appIconDisplay")
                    .resizable().frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
                Text(resolvedHeadline)
                    .font(.system(size: 22, weight: .bold)).foregroundColor(.white)
                    .multilineTextAlignment(.center).padding(.horizontal, DS.Spacing.lg)
                Text(resolvedSubheadline)
                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center).padding(.horizontal, DS.Spacing.xl)
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Social Proof
    // The rating is the only claim made here. It is verifiable on the App Store
    // listing, which a subscriber count is not — and an unverifiable number
    // sitting next to a price is the kind of thing that costs trust exactly
    // where the screen can least afford it.
    private var starsOnlyBanner: some View {
        HStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(0..<5) { _ in Image(systemName: "star.fill").font(.system(size: 13)).foregroundColor(.yellow) }
            }
            Text("4.9 rating · App Store")
                .font(.system(size: 13, weight: .medium)).foregroundColor(.white.opacity(0.7))
        }
    }

    // MARK: - Solution (who the user becomes)
    // Beat 3. The headline named the problem and the subhead turned it; this is
    // where the screen says who they are on the other side of it. Each title is
    // the person, each detail is the mechanic that gets them there — the same
    // five capabilities every time (declarations, the morning minute, audio,
    // the daily plan, Bible chat), never named as features.
    private var solutionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(solutionHeader)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)

            ForEach(Array(solutionRows.enumerated()), id: \.offset) { _, row in
                HCPainSolutionRow(icon: row.icon, title: row.title, detail: row.detail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Comparison Grid (SpeakLife vs. Other apps)
    // Two-column grid that reframes the decision from "is this worth it?" to
    // "why pay the same or more elsewhere for less?". Always shown on the
    // high-conversion paywall.
    //
    // The row labels are outcomes, not features: "You speak it, not just read
    // it" rather than "Spoken declarations". A comparison table is the easiest
    // place on a paywall to slip back into a spec sheet, and a spec sheet
    // invites the reader to price-shop capabilities instead of weighing who
    // they become.
    //
    // Deliberately generic ("Other apps") rather than naming competitors: the
    // paywall ships through App Review and can't be hot-fixed, so a named claim
    // that goes stale becomes a false-advertising exposure on a surface we can't
    // quickly correct. Named, specific comparisons live on owned surfaces (ads,
    // landing pages) instead. The `.some` state keeps the journal row honest —
    // a few competitors do offer journaling.
    private enum OthersMark { case no, some, yes }
    private static let comparisonRows: [(feature: String, others: OthersMark)] = [
        ("You speak it, not just read it", .no),
        ("His Word in your ears all day",  .no),
        // Was "Chapter and verse in seconds" marked `.yes`: a checkmark in both
        // columns, on the one row where the difference is now real. Every faith
        // app has a chat that answers. This one ends the answer with a line to
        // speak and offers to save it as a declaration you hear daily, which is
        // the whole product in one row. Stated as what is actually being
        // compared rather than conceding the category.
        ("You leave with a line to speak",  .no),
        ("A record of what God did",       .some),
        ("Built for your exact fight",     .no)
    ]
    private static let comparisonColumnWidth: CGFloat = 92

    private var comparisonSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Why pay more for less?")
                .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                .padding(.bottom, DS.Spacing.md)

            comparisonHeaderRow
                .padding(.bottom, 6)
            Divider().background(Color.white.opacity(0.12))

            ForEach(Array(Self.comparisonRows.enumerated()), id: \.offset) { index, row in
                comparisonRow(feature: row.feature, others: row.others)
                if index < Self.comparisonRows.count - 1 {
                    Divider().background(Color.white.opacity(0.08))
                }
            }

            Text("Everything in one app — just \(annualPerMonth)/mo. Other apps charge up to $30/mo for less.")
                .font(.system(size: 12)).foregroundColor(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var comparisonHeaderRow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Text("SpeakLife")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Constants.DAMidBlue)
                .frame(width: Self.comparisonColumnWidth)
            Text("Other apps")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: Self.comparisonColumnWidth)
        }
    }

    private func comparisonRow(feature: String, others: OthersMark) -> some View {
        HStack(spacing: 0) {
            Text(feature)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.green)
                .frame(width: Self.comparisonColumnWidth)
            othersCell(others)
                .frame(width: Self.comparisonColumnWidth)
        }
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private func othersCell(_ mark: OthersMark) -> some View {
        switch mark {
        case .no:
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.22))
        case .some:
            Text("Some")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        case .yes:
            // Feature both apps have. Still a check, but muted so SpeakLife's
            // green "win" rows stay the visual focus.
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.55))
        }
    }

    // MARK: - Featured Testimonial (pain-matched, last proof before the price)
    // Matched to the problem the headline named, and moved to the bottom of the
    // scroll so it is the last thing read before the plan cards.
    //
    // It used to be a fixed anxiety review shown to everyone. That put fifteen
    // lines of copy written for this user's exact problem directly above
    // somebody else's problem, at the moment the screen most needs them to
    // believe it works for theirs. `PaywallTestimonial` does the matching
    // against real reviews only, and falls back to the quote that claims least
    // rather than inventing a match — see that file for which pains still have
    // no real review behind them.
    private var featured: PaywallTestimonial.Quote { PaywallTestimonial.featured(for: pain) }

    private var featuredTestimonial: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: 2) {
                ForEach(0..<5) { _ in Image(systemName: "star.fill").font(.system(size: 12)).foregroundColor(.yellow) }
            }
            Text("\"\(featured.text)\"")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(featured.author)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Remaining Testimonials
    // The wall, minus whichever review was promoted to the featured slot — the
    // same quote appearing twice on one screen reads as a shortage of them.
    private var remainingTestimonialsSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(PaywallTestimonial.supporting(excluding: featured)) { quote in
                testimonialCard(quote: quote.text, author: quote.author, stars: 5)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func testimonialCard(quote: String, author: String, stars: Int) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: 2) {
                ForEach(0..<stars) { _ in Image(systemName: "star.fill").font(.system(size: 10)).foregroundColor(.yellow) }
            }
            Text("\(quote)")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(author)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
    }

    // MARK: - Trial Timeline ("How your free trial works")
    // The single strongest documented paywall pattern in the category
    // (Blinkist: +23% trial starts, 55% fewer billing complaints) and the one
    // this screen was missing. The reason people refuse a free trial is not
    // price, it is the fear of forgetting to cancel — so the answer is not a
    // better argument, it is a calendar.
    //
    // **Every line of it is true for us.** Day 1 is real access, not a teaser.
    // The reminder is `TrialExperienceService`'s `trial_d2` push, scheduled at
    // 9am on day n-1 the moment the trial starts (and scheduled even while
    // notification permission is still undetermined, which matters because the
    // onboarding permission ask comes AFTER this screen — a pending request
    // added pre-authorization delivers normally once permission is granted).
    // The last row is the StoreKit contract itself.
    //
    // Nothing here is shown to a user who is not actually trial-eligible: the
    // whole block hangs off `selectedPlanTrialDays`, the same real per-product
    // eligibility check the CTA and the callout use.
    private var trialTimelineSteps: [(icon: String, day: String, text: String)]? {
        guard let days = selectedPlanTrialDays, days >= 1 else { return nil }
        var steps: [(icon: String, day: String, text: String)] = [
            ("lock.open.fill", "TODAY", "Everything unlocks. You are not charged a thing.")
        ]
        // The reminder row needs a day that is neither today nor the last day,
        // or it is describing a push that lands on a row already on screen.
        // `scheduleDay2Push` fires at day n-1, so that holds from n = 3 up.
        if days >= 3 {
            steps.append(("bell.fill", "DAY \(days - 1)", "We remind you the trial is ending, before it ends."))
        }
        steps.append(("star.fill", "DAY \(days)", "Your trial ends. Cancel any time before this and pay nothing."))
        return steps
    }

    /// True when the block is being drawn on the clean layout's light page.
    /// The timeline and the proof block below are the only two pieces shared
    /// verbatim between the dark and clean layouts, so they read their four
    /// colors from here instead of hardcoding white.
    private var onLightSurface: Bool { isCleanVariant && !isCleanDarkTheme }
    private var surfaceInk: Color { onLightSurface ? cleanInk : .white }
    private var surfaceSubInk: Color { onLightSurface ? cleanSubInk : .white.opacity(0.9) }
    private var surfaceMutedInk: Color { onLightSurface ? cleanSubInk.opacity(0.85) : .white.opacity(0.55) }
    private var surfaceCardFill: Color { onLightSurface ? .white : .white.opacity(0.06) }
    private var surfaceCardStroke: Color { onLightSurface ? cleanStroke : Constants.DAMidBlue.opacity(0.35) }

    @ViewBuilder
    private var trialTimelineSection: some View {
        if let steps = trialTimelineSteps {
            VStack(alignment: .leading, spacing: 14) {
                Text("How your free trial works")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(surfaceInk)

                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Constants.DAMidBlue.opacity(0.22))
                                .frame(width: 30, height: 30)
                            Image(systemName: step.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Constants.DAMidBlue)
                        }
                        .frame(width: 30, height: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.day)
                                .font(.system(size: 11, weight: .bold))
                                .kerning(0.8)
                                .foregroundColor(surfaceMutedInk)
                            Text(step.text)
                                .font(.system(size: 13.5))
                                .foregroundColor(surfaceSubInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(surfaceCardFill)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(surfaceCardStroke, lineWidth: 1))
            )
            .padding(.horizontal, DS.Spacing.lg)
        }
    }

    // MARK: - Compact Proof (clean layout)
    // The clean layout shipped with no social proof at all — no rating, no
    // review, nothing. That is not minimalism, it is a missing element: the
    // rating is the one claim on this screen a user can go and verify, and a
    // matched review is the answer to "does it work for MY thing", which is
    // the last question before a price. One small card carries both without
    // spending the layout's whole point.
    private var compactProofBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                HStack(spacing: 2) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill").font(.system(size: 11)).foregroundColor(.yellow)
                    }
                }
                Text("4.9 rating · App Store")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(surfaceMutedInk)
            }
            Text("\"\(featured.text)\"")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundColor(surfaceInk)
                .fixedSize(horizontal: false, vertical: true)
            Text("— \(featured.author)")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(surfaceMutedInk)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(surfaceCardFill)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(cleanStroke, lineWidth: 1))
        )
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Sticky Bottom
    private var stickyBottomSection: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, Color(red:0.07,green:0.10,blue:0.22).opacity(0.97)], startPoint: .top, endPoint: .bottom)
                .frame(height: 20)
            VStack(spacing: 18) {
                planSelectorSection
                trialCallout
               // closingLine
                ctaButton
                trialReassuranceLine
                closingAssuranceLine
                payWhatYouCanCTA
                bottomLinks
            }
            .padding(.horizontal, 20).padding(.vertical, DS.Spacing.md).padding(.bottom, DS.Spacing.xs)
            .background(Color(red:0.07,green:0.10,blue:0.22).opacity(0.97))
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Plan Selector
    // Two side-by-side cards when there is an actual choice to make. Under
    // `onlyShowYearly` there isn't one, so the card stops pretending to be a
    // selector: stretching the annual card to full width kept the 90pt selector
    // height and the 22pt price, which read as a second button competing with
    // the real CTA directly under it. Yearly-only gets one slim price row
    // instead — the price stays visible, the tap stays on the CTA.
    @ViewBuilder
    private var planSelectorSection: some View {
        if onlyShowYearly {
            yearlyOnlyPriceRow
        } else {
            GeometryReader { geo in
                let cardWidth = (geo.size.width - 10) / 2
                HStack(spacing: 10) {
                    planCard(
                        plan: nonAnnualPlan,
                        topLabel: nil,
                        title: nonAnnualTitle,
                        price: nonAnnualPrice,
                        unit: cadenceUnit,
                        struck: nil,
                        sub: "Billed \(showWeeklyPlan ? "weekly" : "monthly")."
                    )
                    .frame(width: cardWidth)
                    planCard(
                        plan: .annual,
                        topLabel: annualSavingsPercent.map { "SAVE \($0)%" } ?? "BEST VALUE",
                        title: "Annual",
                        price: annualComparablePrice,
                        unit: cadenceUnit,
                        // Same guard as the SAVE badge: the anchor only appears
                        // when annual is genuinely cheaper than a year of the
                        // other plan, and it is that real derived figure, never
                        // an invented "was" price.
                        struck: annualSavingsPercent != nil ? nonAnnualYearlyEquivalent : nil,
                        sub: "\(annualPrice) per year"
                    )
                    .frame(width: cardWidth)
                }
            }
            .frame(height: 104)
        }
    }

    /// The yearly-only price line. Not a button — Annual is already the pinned
    /// selection (onAppear) and there is nothing to switch to, so a tap target
    /// here would only steal taps from the CTA.
    private var yearlyOnlyPriceRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Annual")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text("\(annualPrice) per year · \(annualPerMonth)/mo")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.65))
            }
            Spacer(minLength: 0)
            if let pct = annualSavingsPercent {
                Text("SAVE \(pct)%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, DS.Spacing.xs).padding(.vertical, 3)
                    .background(Capsule().fill(Color.green))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Constants.DAMidBlue.opacity(0.18))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Constants.DAMidBlue.opacity(0.7), lineWidth: 1))
        )
    }

    /// Both cards quote the SAME cadence, which is the whole point of the
    /// rewrite.
    ///
    /// This selector used to put the annual card's **yearly total** beside the
    /// monthly card's **monthly** price, so the eye compared $9.99 to $59.99
    /// and the cheaper plan read as six times the price. The two numbers were
    /// never comparable; only one of them was a monthly cost. The clean layout
    /// had already solved this (per-week on both, with a real anchor) and is
    /// the layout that converts nearly twice as well — so it is not a
    /// coincidence worth leaving in place on the layout taking all the traffic.
    ///
    /// The billed amount does not disappear: it is the `sub` line on the annual
    /// card ("$59.99 per year"), directly under the per-month figure, which is
    /// also what keeps the price disclosure honest.
    private func planCard(plan: PlanType, topLabel: String?, title: String, price: String, unit: String, struck: String?, sub: String) -> some View {
        let isSelected = selectedPlan == plan
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { selectedPlan = plan }
            AnalyticsService.shared.track("paywall_plan_switched", parameters: ["plan": plan.rawValue, "variant": paywallVariant, "segment": segmentParam])
        }) {
            ZStack(alignment: .top) {
                VStack(spacing: 3) {
                    if topLabel != nil { Spacer().frame(height: DS.Spacing.sm) }
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(isSelected ? .white : .white.opacity(0.55))
                    (Text(price).font(.system(size: 22, weight: .bold))
                        + Text(unit).font(.system(size: 12, weight: .semibold)))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.45))
                    HStack(spacing: 4) {
                        if let struck {
                            Text(struck)
                                .strikethrough(true, color: isSelected ? .white.opacity(0.55) : .white.opacity(0.25))
                                .foregroundColor(isSelected ? .white.opacity(0.55) : .white.opacity(0.25))
                        }
                        Text(sub).foregroundColor(isSelected ? .white.opacity(0.7) : .white.opacity(0.3))
                    }
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
                }
                .padding(.vertical, 14).padding(.horizontal, DS.Spacing.xs)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Constants.DAMidBlue.opacity(0.25) : Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Constants.DAMidBlue : Color.white.opacity(0.15), lineWidth: isSelected ? 2 : 1))
                )
                if let label = topLabel {
                    Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, DS.Spacing.xs).padding(.vertical, 3)
                        .background(Capsule().fill(Color.green))
                        .offset(y: -10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Trial Callout (clarity-first: addresses the autocharge fear).
    // Day count is read from the selected plan's real StoreKit intro offer —
    // never hardcoded — and only shown when this user is actually eligible.
    // Only when there is no timeline to carry it. With the timeline on screen
    // this line said the same sentence as its last row, 40pt below it — and a
    // promise repeated verbatim reads as a script, not as reassurance. The
    // non-trial fallback ("Start today. Cancel anytime in Settings.") has no
    // timeline to defer to, so it still shows.
    @ViewBuilder
    private var trialCallout: some View {
        if trialTimelineSteps == nil {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 14))
                Text(trialCalloutText)
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.92))
            }
        }
    }

    private var trialCalloutText: String {
        if let days = selectedPlanTrialDays {
            return "Free for \(days) days. Cancel before day \(days) to pay nothing."
        }
        return "Start today. Cancel anytime in Settings."
    }

    // MARK: - Closing Line
    private var closingLine: some View {
        Text("God prepared the treasure chest.\nSpeakLife helps you open it — every single day.")
            .font(.system(size: 14, weight: .regular, design: .rounded))
            .foregroundColor(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - CTA
    // Free-anchored short CTA: the real StoreKit day count makes "free"
    // concrete ("Try 7 Days Free"); the non-trial fallback is a plain
    // "Continue" (the consistently winning minimal CTA). Shared by both
    // layouts' buttons.
    private var ctaText: String {
        if let days = selectedPlanTrialDays {
            return "Try \(days) Days Free"
        }
        return "Continue"
    }

    private var ctaButton: some View {
        Button(action: makePurchase) {
            Group {
                if declarationStore.isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(ctaText).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .background(RoundedRectangle(cornerRadius: 30).fill(LinearGradient(colors: [Constants.DAMidBlue, Constants.DAMidBlue.opacity(0.85)], startPoint: .leading, endPoint: .trailing)))
        }
        .disabled(declarationStore.isPurchasing)
        .opacity(declarationStore.isPurchasing ? 0.7 : 1.0)
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Reassurance Stack (under CTA, trial-eligible only)
    // Repeats the no-payment-now promise right at the moment of commitment.
    // Billed price in the plan cards stays the most conspicuous price element
    // (Apple 3.1.2) — this line carries no price at all.
    @ViewBuilder
    private var trialReassuranceLine: some View {
        if selectedPlanTrialDays != nil {
            HStack(spacing: 5) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                Text("No payment due now · Cancel anytime in Settings")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Closing Assurance (last line before the tap)
    // This slot used to carry the generosity/pay-what-you-can framing. That is
    // a meaning frame, not a decision frame — it tells a hesitating user what
    // their money does for someone else at the exact moment they are still
    // asking whether it does anything for them. It has not been lost: the
    // post-purchase mission screen carries it, which is where a "you did
    // something good" message actually lands.
    //
    // What belongs here is the last doubt, and the last doubt is not "is this
    // the right app" — it is "will anything actually move." So the line names
    // the mechanism instead of defending the product, and it makes the app's
    // own name the verb that does it. It is the same authority the onboarding
    // mechanism screen teaches, said once more at the tap.
    //
    // The promises are what gets activated, not heaven. Heaven already moved —
    // that is the whole enforcement frame the mechanism screen is built on —
    // and what the speaker takes hold of by speaking is the promise. A line
    // that activates heaven instead would quietly make the victory wait on the
    // user's performance, which is the one thing this app does not teach.
    //
    // It no longer varies by pain. The line above it, the four rows above that,
    // and the headline above those are all already pain-specific; by the time
    // the eye reaches this line the personalization has been made, and a flat
    // sentence lands harder here than a fifteenth tailored one.
    private var closingAssuranceLine: some View {
        HStack(alignment: .top, spacing: 6) {
            // Was a closed book, back when the line's argument was that the
            // guarantee is Scripture rather than the app. The argument is now
            // the speaking itself.
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 2)
            Text(UserPain.closingAssurance)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.sm)
    }

    // MARK: - Pay What You Can (secondary CTA, intentionally subordinate to main CTA)
    // Gated by its own Remote Config flag (showPayWhatYouCanCTA), independent of
    // the soft/hard wall and the welcome-offer discount. Default OFF, so the link
    // is hidden until Remote Config turns it on.
    @ViewBuilder
    private var payWhatYouCanCTA: some View {
        if subscriptionStore.showPayWhatYouCanCTA {
            Button(action: {
                AnalyticsService.shared.track("paywall_pay_what_you_can_tapped", parameters: [
                    "variant": paywallVariant,
                    "segment": segmentParam
                ])
                showPayWhatYouCan = true
            }) {
                Text("Can't afford full price? Pay what you can →")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isCleanVariant ? cleanSubInk : .white.opacity(0.7))
                    .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel(Text("Pay what you can option"))
        }
    }

    // MARK: - Bottom Links
    private var bottomLinks: some View {
        HStack(spacing: DS.Spacing.lg) {
            Button("Restore", action: restore)
            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            Button("Privacy") { showPrivacyPolicy = true }
        }
        .font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
    }

    // MARK: - Close Button
    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    // paywall_dismissed fires at the moment of dismissal —
                    // before the welcome offer (if any) is shown — so funnel
                    // numbers stay comparable to the pre-offer baseline.
                    AnalyticsService.shared.track("paywall_dismissed", parameters: [
                        "variant": paywallVariant,
                        "plan_viewed": selectedPlan.rawValue,
                        "seconds_on_paywall": Int(Date().timeIntervalSince(timeOnPaywall)),
                        "segment": segmentParam
                    ])
                    // Always the plain dismissal path now. The welcome offer
                    // that used to intercept this tap moved to the first Daily
                    // Burst (WelcomeOfferPresenter).
                    callback?()
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 28))
                        .foregroundColor(isCleanVariant && !isCleanDarkTheme ? Color.gray.opacity(0.45) : .white.opacity(0.6))
                        .background(Circle().fill(isCleanVariant && !isCleanDarkTheme ? Color.black.opacity(0.05) : Color.black.opacity(0.2)))
                }
                .padding(.top, 56).padding(.trailing, 20)
            }
            Spacer()
        }
        .transition(.opacity)
    }

    // MARK: - Clean Variant Layout (high_conversion_clean_v1 / _dark_v1)
    // Minimal format modeled on top-converting meditation-app paywalls:
    // wordmark → headline → illustration → Annual (anchored) vs non-annual plan
    // cards → Continue → legal links. Shares every handler with the classic
    // layout (makePurchase, restore, close, welcome offer, mission screen), so
    // only the presentation differs — analytics stay joinable via paywallVariant.
    //
    // The palette is theme-aware: light (white page, navy ink) by default, or
    // the high-conversion paywall's dark gradient + white ink when
    // useCleanPaywallDarkTheme is on — everything below reads these four
    // colors, so the whole layout reskins from this one spot.

    private var cleanBackground: Color { Color(red: 0.99, green: 0.99, blue: 1.0) }
    private var cleanInk: Color {
        isCleanDarkTheme ? .white : Color(red: 0.10, green: 0.12, blue: 0.18)
    }
    private var cleanSubInk: Color {
        isCleanDarkTheme ? .white.opacity(0.65) : Color(red: 0.44, green: 0.47, blue: 0.54)
    }
    private var cleanStroke: Color {
        isCleanDarkTheme ? .white.opacity(0.18) : Color(red: 0.87, green: 0.89, blue: 0.93)
    }
    /// Plan-card fill, mirroring the classic dark layout's card treatment when
    /// the dark theme is on (translucent white card, stronger selected tint).
    private func cleanCardFill(isSelected: Bool) -> Color {
        if isCleanDarkTheme {
            return isSelected ? Constants.DAMidBlue.opacity(0.22) : Color.white.opacity(0.06)
        }
        return isSelected ? Constants.DAMidBlue.opacity(0.06) : Color.white
    }

    private var cleanVariantLayout: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    cleanWordmark.padding(.top, 16)
                    cleanPageDots.padding(.top, 14)
                    Text(resolvedHeadline)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundColor(cleanInk)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28).padding(.top, 14)
                    Text(resolvedSubheadline)
                        .font(.system(size: 15))
                        .foregroundColor(cleanSubInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32).padding(.top, 6)
                    cleanIllustrationCard.padding(.top, 18)
                    cleanSolutionList.padding(.top, 20)
                    compactProofBlock.padding(.top, 22)
                    trialTimelineSection.padding(.top, 14)
                    Spacer(minLength: 16)
                }
            }
            cleanBottomSection
        }
    }

    private var cleanWordmark: some View {
        (Text("Speak").foregroundColor(cleanInk) + Text("Life").foregroundColor(Constants.DAMidBlue))
            .font(.system(size: 18, weight: .bold, design: .rounded))
    }

    // Decorative progress dots matching the reference format (paywall reads as
    // the current step of a short flow).
    private var cleanPageDots: some View {
        HStack(spacing: 6) {
            Capsule().fill(cleanInk.opacity(0.7)).frame(width: 18, height: 5)
            Circle().fill(cleanInk.opacity(0.22)).frame(width: 5, height: 5)
            Circle().fill(cleanInk.opacity(0.22)).frame(width: 5, height: 5)
        }
    }

    /// The clean layout's answer to the headline. Titles only, no detail lines
    /// and no header — this variant exists to test minimalism, so it gets the
    /// shortest form that still closes "how does this fix my thing?". Naming a
    /// problem and then showing nothing but a price is a worse screen than the
    /// one this replaced, which is why the minimal variant carries it too.
    private var cleanSolutionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(solutionRows.prefix(3).enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: row.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Constants.DAMidBlue)
                        .frame(width: 22)
                    Text(row.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(cleanInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 28)
    }

    private var cleanIllustrationCard: some View {
        Image("cleanPaywallHero")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(cleanStroke, lineWidth: 1))
            .padding(.horizontal, 24)
    }

    private var cleanBottomSection: some View {
        VStack(spacing: 12) {
            cleanPlanCard(
                plan: .annual,
                title: "Annual",
                rightPrice: annualPerWeek,
                rightUnit: "/week",
                // Anchor only shown when annual is genuinely cheaper than a
                // year of the non-annual plan (same guard as the SAVE badge).
                struck: annualSavingsPercent != nil ? nonAnnualYearlyEquivalent : nil,
                subline: "\(annualPrice) per year",
                badge: "MOST POPULAR"
            )
            .padding(.top, 10) // room for the badge overhang
            if !onlyShowYearly {
                cleanPlanCard(
                    plan: nonAnnualPlan,
                    title: nonAnnualTitle,
                    rightPrice: nonAnnualPrice,
                    rightUnit: showWeeklyPlan ? "/week" : "/month",
                    struck: nil,
                    subline: cleanNonAnnualSubline,
                    badge: nil
                )
            }
            cleanContinueButton
            cleanTrialLine
            // Same Remote Config-gated link as the dark layout, so enabling
            // showPayWhatYouCanCTA reaches both A/B arms.
            payWhatYouCanCTA
            cleanBottomLinks
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        // Outer view ignores the bottom safe area, so this must clear the
        // home indicator (34pt) on its own.
        .padding(.bottom, 34)
    }

    private var cleanNonAnnualSubline: String {
        let cadence = showWeeklyPlan ? "weekly" : "monthly"
        guard let yearly = nonAnnualYearlyEquivalent else { return "Billed \(cadence)." }
        return "\(yearly) /year if billed \(cadence)."
    }

    private func cleanPlanCard(plan: PlanType, title: String, rightPrice: String, rightUnit: String, struck: String?, subline: String, badge: String?) -> some View {
        let isSelected = selectedPlan == plan
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) { selectedPlan = plan }
            AnalyticsService.shared.track("paywall_plan_switched", parameters: ["plan": plan.rawValue, "variant": paywallVariant, "segment": segmentParam])
        }) {
            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundColor(isSelected ? Constants.DAMidBlue : cleanStroke)
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(cleanInk)
                        Spacer()
                        (Text(rightPrice).font(.system(size: 16, weight: .semibold))
                            + Text(" \(rightUnit)").font(.system(size: 13, weight: .medium)))
                            .foregroundColor(cleanInk)
                    }
                    HStack(spacing: 5) {
                        if let struck {
                            Text(struck)
                                .font(.system(size: 13))
                                .foregroundColor(cleanSubInk.opacity(0.8))
                                .strikethrough(true, color: cleanSubInk.opacity(0.8))
                        }
                        Text(subline)
                            .font(.system(size: 13))
                            .foregroundColor(cleanSubInk)
                    }
                    .padding(.leading, 26)
                }
                .padding(.horizontal, 14).padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(cleanCardFill(isSelected: isSelected))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Constants.DAMidBlue : cleanStroke, lineWidth: isSelected ? 1.5 : 1))
                )
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(Constants.DAMidBlue))
                        .offset(y: -11)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }

    // Same autocharge-fear reassurance as the dark layout — real per-plan
    // eligibility, real StoreKit day count, never hardcoded.
    //
    // With the timeline above the plan cards carrying the calendar, this line
    // stops repeating the day count and carries the promise instead, which is
    // what belongs at the button. It also moved below the CTA to match: the
    // documented pattern is reassurance *under* the tap, not above it.
    @ViewBuilder
    private var cleanTrialLine: some View {
        if selectedPlanTrialDays != nil {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Constants.DAMidBlue).font(.system(size: 13))
                Text(trialTimelineSteps == nil ? trialCalloutText : "No payment due now · Cancel anytime in Settings")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(cleanSubInk)
            }
        }
    }

    private var cleanContinueButton: some View {
        Button(action: makePurchase) {
            Group {
                if declarationStore.isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(ctaText)
                        .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [Constants.DAMidBlue, Constants.DAMidBlue.opacity(0.85)], startPoint: .leading, endPoint: .trailing))
            )
        }
        .disabled(declarationStore.isPurchasing)
        .opacity(declarationStore.isPurchasing ? 0.7 : 1.0)
        .buttonStyle(PlainButtonStyle())
    }

    private var cleanBottomLinks: some View {
        HStack(spacing: DS.Spacing.lg) {
            Button("Restore Purchases", action: restore)
            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            Button("Privacy") { showPrivacyPolicy = true }
        }
        .font(.system(size: 12)).foregroundColor(cleanSubInk)
    }

    // MARK: - Post-Purchase Mission Screen Routing
    /// Swaps in the mission screen after a successful purchase, remembering
    /// which success path to run when it continues. Callers clear the purchase
    /// spinner (declarationStore.isPurchasing) before invoking this, so the
    /// spinner never overlaps the mission screen. Auto-advances after 6
    /// seconds so the user is never trapped here.
    private func presentMissionScreen(_ resolution: MissionResolution) {
        missionResolution = resolution
        missionShownAt = Date()
        AnalyticsService.shared.track("post_purchase_mission_shown", parameters: [
            "variant": paywallVariant,
            "source": source
        ])
        withAnimation(.easeInOut(duration: 0.3)) { showMissionScreen = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { continueMission() }
    }

    /// Runs the original purchase success path exactly once, whether triggered
    /// by the mission CTA tap or the 6-second auto-advance (both can fire).
    private func continueMission() {
        guard !missionContinued else { return }
        missionContinued = true
        AnalyticsService.shared.track("post_purchase_mission_continue", parameters: [
            "seconds_on_screen": Int(Date().timeIntervalSince(missionShownAt))
        ])
        switch missionResolution {
        case .mainPurchase:
            callback?()
            dismiss()
        }
    }

    // MARK: - Lifecycle
    private func onAppear() {
        // Latch the layout variant and theme BEFORE the impression events
        // below fire, so every event this session reports the variant shown.
        if lockedCleanVariant == nil {
            lockedCleanVariant = subscriptionStore.useCleanPaywallVariant
        }
        if lockedCleanDarkTheme == nil {
            lockedCleanDarkTheme = subscriptionStore.useCleanPaywallDarkTheme
        }
        timeOnPaywall = Date()
        selectedPlan = .annual
        // Check actual trial eligibility from Apple (re-run via onChange when
        // products finish loading after the paywall is already on screen).
        Task { await refreshTrialEligibility() }
        // `pain` is the copy this user was actually shown, already resolved —
        // segment carries the same information but needs parsing, and the quiz
        // arm's segment names don't map to it by string at all. Breaking
        // conversion down by pain is the whole point of the reposition.
        let painParam = pain?.rawValue ?? "none"
        AnalyticsService.shared.trackPaywallImpression(paywallId: paywallVariant, metadata: [
            "variant": paywallVariant,
            "user_category": preferencesTracker.primaryCategory.rawValue,
            "initial_plan": "annual",
            "only_yearly": onlyShowYearly,
            "segment": segmentParam,
            "pain": painParam
        ])
        AnalyticsService.shared.track("paywall_shown", parameters: [
            "segment": segmentParam,
            "source": source,
            "variant": paywallVariant,
            "pain": painParam
        ])
        if !effectiveIsHardPaywall {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeIn(duration: 0.4)) { showCloseButton = true }
            }
        }
    }

    /// Asks Apple, per product, whether THIS user is eligible for the intro
    /// offer on every plan this paywall can sell (annual + monthly + weekly,
    /// whichever loaded). Latest write wins, which is race-safe enough here:
    /// eligibility for a given product id never changes mid-session.
    private func refreshTrialEligibility() async {
        let products = [
            subscriptionStore.currentOfferedPremium,
            subscriptionStore.currentOfferedPremiumMonthly,
            subscriptionStore.currentOfferedWeekly
        ].compactMap { $0 }
        var eligibility: [String: Bool] = [:]
        for product in products {
            eligibility[product.id] = await product.subscription?.isEligibleForIntroOffer ?? false
        }
        let resolved = eligibility
        await MainActor.run {
            trialEligibility.merge(resolved) { _, new in new }
        }
    }

    // MARK: - Purchase
    private func makePurchase() {
        guard let product = selectedProduct else {
            errorMessage = "Please select a subscription option."
            isShowingError = true
            return
        }
        Juice.play(.tapSolid)
        AnalyticsService.shared.track("paywall_cta_tapped", parameters: [
            "variant": paywallVariant,
            "plan": selectedPlan.rawValue,
            // Carried here as well as on the impression: without it, "does a
            // named pain convert better than none" needs a person-level join
            // against paywall_shown, which is exactly the cut this screen's
            // personalization has to justify itself on.
            "pain": pain?.rawValue ?? "none",
            "source": source,
            "user_category": preferencesTracker.primaryCategory.rawValue,
            "product_id": product.id,
            "segment": segmentParam
        ])
        AnalyticsService.shared.track("paywall_subscribe_tapped", parameters: [
            "segment": segmentParam,
            "plan": selectedPlan.rawValue,
            "variant": paywallVariant
        ])
        Task {
            await MainActor.run { declarationStore.isPurchasing = true }
            do {
                let purchased = try await subscriptionStore.purchase(product, paywallName: paywallVariant)
                if purchased {
                    let price = NSDecimalNumber(decimal: product.price).doubleValue
                    AnalyticsService.shared.trackPaywallConversion(
                        productId: product.id, paywallId: paywallVariant, price: price,
                        metadata: ["variant": paywallVariant, "plan": selectedPlan.rawValue,
                                   "user_category": preferencesTracker.primaryCategory.rawValue,
                                   "seconds_to_convert": Int(Date().timeIntervalSince(timeOnPaywall)),
                                   "segment": segmentParam]
                    )
                    // NOTE: trial_started is fired by SubscriptionStore.purchase —
                    // the single source of truth, correctly gated on the purchased
                    // product's intro offer + this user's eligibility. Firing it
                    // here too double-counted trials (and misfired for plans
                    // without an intro offer, since the old gate only checked the
                    // annual product).
                    await MainActor.run {
                        // Spinner clears before the mission screen swaps in.
                        declarationStore.isPurchasing = false
                        if source == "onboarding" {
                            // Onboarding buyers see the mission screen first;
                            // its continue path runs callback?() + dismiss().
                            presentMissionScreen(.mainPurchase)
                        } else {
                            // Settings / feature-gate buyers are mid-task —
                            // keep the immediate dismiss.
                            callback?(); dismiss()
                        }
                    }
                } else {
                    await MainActor.run { declarationStore.isPurchasing = false }
                }
            } catch {
                await MainActor.run {
                    declarationStore.isPurchasing = false
                    errorMessage = "Purchase failed. Please try again."
                    isShowingError = true
                }
            }
        }
    }

    // MARK: - Restore
    private func restore() {
        Task {
            await MainActor.run { declarationStore.isPurchasing = true }
            let restored = await subscriptionStore.restore()
            await MainActor.run {
                declarationStore.isPurchasing = false
                errorMessage = restored ? "Purchases restored" : "No purchases found to restore."
                isShowingError = true
            }
        }
    }
}

// MARK: - Succinct Benefit Row
/// A solution row: the mechanic on the first line, what it does about the
/// user's problem on the second. The detail line is the part that turns a
/// feature list into an answer, so it is not optional.
private struct HCPainSolutionRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Constants.DAMidBlue)
                .frame(width: 26)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Shared Intro-Offer Helper
/// Days in the introductory free-trial offer for the given product, read from
/// the loaded StoreKit Product (never hardcoded). nil when the user isn't
/// eligible for an intro offer (per-user check done by callers) or when the
/// product has no free-trial intro offer configured. Shared by the main
/// paywall and the decline-path WelcomeOfferView so trial copy can never
/// disagree between the two screens.
fileprivate func introTrialDays(for product: Product?, isEligible: Bool) -> Int? {
    guard isEligible,
          let offer = product?.subscription?.introductoryOffer,
          offer.paymentMode == .freeTrial else { return nil }
    switch offer.period.unit {
    case .day:   return offer.period.value
    case .week:  return offer.period.value * 7
    case .month: return offer.period.value * 30
    case .year:  return offer.period.value * 365
    @unknown default: return nil
    }
}

// MARK: - Shared Currency Helper
/// Formats an arbitrary derived amount (price ÷ 52, price × 12, …) with the
/// product's own storefront format style, so the currency symbol and locale
/// always match the product's real displayPrice — never a hardcoded "$" and
/// never the device locale's default currency.
fileprivate func localizedPrice(_ amount: Decimal, in product: Product) -> String? {
    amount.formatted(product.priceFormatStyle)
}

// MARK: - Shared Per-Month Price Helper
/// Per-month equivalent of a yearly product's price, formatted in the
/// product's own locale and currency (never a hardcoded "$"). Shared by the
/// main paywall and WelcomeOfferView. nil if formatting fails.
fileprivate func perMonthString(yearlyProduct: Product) -> String? {
    localizedPrice(yearlyProduct.price / 12, in: yearlyProduct)
}

// MARK: - Welcome Offer
/// Shown at most once ever (UserDefaults `welcomeOfferShown`), after the
/// user's first Daily Burst, to somebody who does not already have full
/// access. Presented by `WelcomeOfferPresenter`, which owns the trigger and
/// carries the anti-phantom-price guard this screen depends on: the Remote
/// Config discount annual must have actually loaded from StoreKit at a price
/// below the regular annual, or the offer never appears at all.
///
/// It used to fire on the onboarding paywall's decline path instead. Nothing
/// in this view changed when it moved — it takes its callbacks from whoever
/// presents it, which is the whole reason the move was cheap.
///
/// Exactly one step deep per Apple Guideline 5.6: purchase and "No thanks"
/// both resolve and no further offers follow. No countdown timer or fake
/// urgency; the framing line states plainly that it is a one-time offer. All
/// prices come straight from StoreKit.
struct WelcomeOfferView: View {
    @EnvironmentObject var declarationStore: DeclarationViewModel
    @EnvironmentObject var subscriptionStore: SubscriptionStore

    /// Paywall variant string, forwarded so offer analytics join cleanly with
    /// the paywall events that preceded them.
    let variant: String
    /// Onboarding segment, forwarded for the same reason.
    let segment: String
    /// Runs the original paywall dismissal path (onboarding callback +
    /// dismiss). The parent guards it so it can only ever fire once. Fired on
    /// decline ("No thanks, continue").
    let onResolve: () -> Void
    /// Fired on purchase success instead of onResolve, so the parent can show
    /// the post-purchase mission screen first. The mission screen's continue
    /// path then calls the same guarded resolve, preserving exactly-once
    /// semantics for the onboarding callback.
    let onPurchaseSuccess: () -> Void

    @State private var isShowingError = false
    @State private var errorMessage = ""
    @State private var showPrivacyPolicy = false
    @State private var isEligibleForTrial = false
    @State private var timeOnOffer = Date()

    // MARK: Products / Prices (all from StoreKit, never hardcoded)
    private let pricePlaceholder = "—"
    private var discountProduct: Product? { subscriptionStore.currentOfferedDiscount }
    private var regularProduct: Product? { subscriptionStore.currentOfferedPremium }
    private var discountPrice: String { discountProduct?.displayPrice ?? pricePlaceholder }
    private var regularPrice: String { regularProduct?.displayPrice ?? pricePlaceholder }
    private var discountPerMonth: String {
        guard let p = discountProduct else { return pricePlaceholder }
        return perMonthString(yearlyProduct: p) ?? pricePlaceholder
    }
    /// % saved vs the regular annual, computed from the real StoreKit prices.
    private var savingsPercent: Int? {
        guard let d = discountProduct.flatMap({ Double($0.price.description) }),
              let r = regularProduct.flatMap({ Double($0.price.description) }),
              r > 0, d < r else { return nil }
        return Int(((r - d) / r * 100).rounded())
    }
    /// Trial length of the discount product, nil when this user isn't eligible
    /// or the SKU has no free-trial intro offer.
    private var offerTrialDays: Int? {
        introTrialDays(for: discountProduct, isEligible: isEligibleForTrial)
    }
    private var ctaText: String {
        offerTrialDays != nil ? "Start Free Trial" : "Claim My Welcome Offer"
    }

    // MARK: Body
    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header
                        offerCard.padding(.top, 28)
                        honestyLine.padding(.top, 18)
                        if let days = offerTrialDays {
                            trialLine(days: days).padding(.top, 14)
                        }
                        Spacer(minLength: 20)
                    }
                }
                bottomSection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: onAppear)
        .alert("", isPresented: $isShowingError) {
            Button("OK", role: .cancel) { }
        } message: { Text(errorMessage) }
        .sheet(isPresented: $showPrivacyPolicy) { PrivacyPolicyView() }
    }

    // MARK: Chrome
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color(red:0.07,green:0.10,blue:0.22), Color(red:0.12,green:0.07,blue:0.20), Color(red:0.04,green:0.04,blue:0.12)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private var header: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image("appIconDisplay")
                .resizable().frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
            Text("BEFORE YOU GO")
                .font(.system(size: 12, weight: .bold))
                .tracking(2)
                .foregroundColor(Constants.DAMidBlue)
            Text("Speak life over your battle\nfor less.")
                .font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.lg)
        }
        .padding(.top, 56)
    }

    // MARK: Offer Card
    // The billed annual price is deliberately the most conspicuous price
    // element on the screen (Apple 3.1.2); the per-month equivalent is small
    // and clearly labeled as billed annually.
    private var offerCard: some View {
        VStack(spacing: 6) {
            if let pct = savingsPercent {
                Text("SAVE \(pct)%")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(Color.green))
            }
            Text("was \(regularPrice)")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .strikethrough(true, color: .white.opacity(0.5))
                .padding(.top, 10)
            Text("\(discountPrice)/year")
                .font(.system(size: 36, weight: .bold)).foregroundColor(.white)
            Text("\(discountPerMonth) per month, billed annually")
                .font(.system(size: 13)).foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, 22).padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Constants.DAMidBlue.opacity(0.6), lineWidth: 1))
        )
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: Honest Framing (no fake urgency, no countdown)
    private var honestyLine: some View {
        Text("A one time welcome offer for new believers in the app. No pressure, no tricks.")
            .font(.system(size: 13)).foregroundColor(.white.opacity(0.65))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 36)
    }

    private func trialLine(days: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 14))
            Text("Free for \(days) days. Cancel before day \(days) to pay nothing.")
                .font(.system(size: 13, weight: .semibold)).foregroundColor(.white.opacity(0.92))
        }
    }

    // MARK: Bottom (CTA + decline + links)
    private var bottomSection: some View {
        VStack(spacing: 14) {
            ctaButton
            noThanksButton
            bottomLinks
        }
        .padding(.horizontal, 20).padding(.top, DS.Spacing.xs).padding(.bottom, DS.Spacing.lg)
    }

    private var ctaButton: some View {
        Button(action: claimOffer) {
            Group {
                if declarationStore.isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(ctaText).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .background(RoundedRectangle(cornerRadius: 30).fill(LinearGradient(colors: [Constants.DAMidBlue, Constants.DAMidBlue.opacity(0.85)], startPoint: .leading, endPoint: .trailing)))
        }
        .disabled(declarationStore.isPurchasing)
        .opacity(declarationStore.isPurchasing ? 0.7 : 1.0)
        .buttonStyle(PlainButtonStyle())
    }

    private var noThanksButton: some View {
        Button(action: declineOffer) {
            Text("No thanks, continue")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(declarationStore.isPurchasing)
    }

    private var bottomLinks: some View {
        HStack(spacing: DS.Spacing.lg) {
            Button("Restore", action: restore)
            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            Button("Privacy") { showPrivacyPolicy = true }
        }
        .font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
    }

    // MARK: Lifecycle
    private func onAppear() {
        timeOnOffer = Date()
        // Per-user trial eligibility for the DISCOUNT product specifically —
        // it can differ from the main annual (same subscription group, but the
        // check is per user, not per product configuration).
        Task {
            let eligible = await subscriptionStore.currentOfferedDiscount?.subscription?.isEligibleForIntroOffer ?? false
            await MainActor.run { isEligibleForTrial = eligible }
        }
        AnalyticsService.shared.track("welcome_offer_shown", parameters: [
            "variant": variant,
            "segment": segment
        ])
    }

    // MARK: Purchase
    // On success SubscriptionStore.purchase fires trial_started /
    // subscription_started / premiumSucceeded itself — do NOT duplicate them
    // here (same single-source-of-truth rule as the main paywall CTA).
    private func claimOffer() {
        guard let product = discountProduct else {
            errorMessage = "This offer is unavailable right now. Please try again."
            isShowingError = true
            return
        }
        Juice.play(.tapSolid)
        AnalyticsService.shared.track("welcome_offer_cta_tapped", parameters: [
            "product_id": product.id
        ])
        Task {
            await MainActor.run { declarationStore.isPurchasing = true }
            do {
                let purchased = try await subscriptionStore.purchase(product, paywallName: "welcome_offer_v1")
                await MainActor.run {
                    declarationStore.isPurchasing = false
                    // Spinner cleared above; the parent swaps in the mission
                    // screen, whose continue path runs the guarded resolve.
                    if purchased { onPurchaseSuccess() }
                }
            } catch {
                await MainActor.run {
                    declarationStore.isPurchasing = false
                    errorMessage = "Purchase failed. Please try again."
                    isShowingError = true
                }
            }
        }
    }

    // MARK: Decline
    private func declineOffer() {
        AnalyticsService.shared.track("welcome_offer_dismissed", parameters: [
            "seconds_on_offer": Int(Date().timeIntervalSince(timeOnOffer))
        ])
        onResolve()
    }

    // MARK: Restore
    private func restore() {
        Task {
            await MainActor.run { declarationStore.isPurchasing = true }
            let restored = await subscriptionStore.restore()
            await MainActor.run {
                declarationStore.isPurchasing = false
                errorMessage = restored ? "Purchases restored" : "No purchases found to restore."
                isShowingError = true
            }
        }
    }
}

// MARK: - Post-Purchase Mission Screen
/// Brief, reverent thank-you state shown after a successful purchase from the
/// onboarding paywall (main CTA or welcome offer), BEFORE the original success
/// callback runs. Reframes the subscription as mission: paying members keep
/// the pay-what-you-can program viable. No confetti. TRUTHFULNESS: same
/// constraint as the paywall generosity line — never claim a one-for-one
/// donated subscription; no such program exists. Restore success and
/// settings / feature-gate purchases never route here. The parent auto-fires
/// onContinue after 6 seconds (exactly-once guarded) so nobody is trapped.
private struct PostPurchaseMissionView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(Constants.DAMidBlue)
                Text("WELCOME TO SPEAKLIFE")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Constants.DAMidBlue)
                Text("Your plan is ready.")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("You just did more than subscribe. Members like you keep SpeakLife within reach for believers walking through their hardest season. Now let's take some ground.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 36)
            Spacer()
            Button(action: onContinue) {
                Text("Start Speaking Life →")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(RoundedRectangle(cornerRadius: 30).fill(LinearGradient(colors: [Constants.DAMidBlue, Constants.DAMidBlue.opacity(0.85)], startPoint: .leading, endPoint: .trailing)))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}
