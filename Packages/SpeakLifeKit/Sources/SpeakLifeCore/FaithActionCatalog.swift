//
//  FaithActionCatalog.swift
//  SpeakLife
//
//  The eighth slat of the Daily Burst: one corresponding action, mapped to the
//  theme the user just spent seven declarations speaking over.
//
//  Why this exists. A burst can end as a purely verbal event — seven true things
//  said out loud, a streak incremented, and a day that looks exactly like the one
//  before it. James 2:17 is blunt about that: faith by itself, if it is not
//  accompanied by action, is dead. So the burst now closes by asking for one
//  physical thing that only makes sense if what they just declared is already
//  true. Someone who declared healing moves like a healed person. Someone who
//  declared provision gives something away. The act is the amen.
//
//  Scope: content only. Deciding WHICH theme a burst was about belongs to
//  `BurstThemeResolver`; this file answers "given that theme, what do we ask
//  for". Keeping them apart means the rules can change without touching 151
//  lines of copy, and the copy can change without touching the rules.
//
//  Copy rules, inherited from the declaration rules in CLAUDE.md and binding here
//  because this text sits in the same breath as the declarations:
//
//    · Never name the low thing. No action detail mentions sickness, debt,
//      anxiety, loneliness, or failure — not even to overrule it. The slide
//      assumes the higher reality and moves from it.
//    · Never promise what scripture does not. Nothing here says another free
//      person will change, return, or believe. Actions aimed at another person
//      (salvation, love, divorce, forgiveness) govern only the speaker's own
//      posture.
//    · Plain and instant. If a headline needs decoding, it has failed.
//    · Small enough to actually do today. An action they will not take is the
//      same as no action at all.
//    · Name the KIND of action, never the act and never a dose. "Walk for
//      fifteen minutes" is an errand handed down: it fits whoever wrote it and
//      nobody else, and someone who cannot walk fifteen minutes today has been
//      handed a failure instead of an invitation. "Do one thing today a healed
//      body does" is the same ask, owned by the speaker, and it fits the
//      marathoner and the person managing stairs equally. They know their life;
//      we know what they declared. `FaithActionCatalogTests` fails the build on
//      any measured unit or numeral in this copy.
//

import Foundation
import Combine

// MARK: - Faith Action

/// One corresponding action: the thing someone does today because the thing they
/// declared is already true.
public struct FaithAction: Equatable {
    /// SF Symbol shown on the action card.
    public let icon: String
    /// The invitation itself. Imperative, short enough to read in one glance.
    public let headline: String
    /// One line naming the belief the act is enacting. Never explains the joke.
    public let detail: String

    public init(icon: String, headline: String, detail: String) {
        self.icon = icon
        self.headline = headline
        self.detail = detail
    }
}

/// The full ask for one theme: the truth being stood on, plus the actions that
/// stand on it.
public struct FaithActionSet: Equatable {
    /// Two beats: what is already true, and the move that follows from it.
    /// Shown above the action card as the frame for the whole slide.
    public let premise: String
    /// Always non-empty. Multiple entries so the ask rotates day to day rather
    /// than becoming wallpaper.
    public let actions: [FaithAction]

    public init(premise: String, actions: [FaithAction]) {
        self.premise = premise
        self.actions = actions
    }
}

// MARK: - Catalog

public enum FaithActionCatalog {

    /// The anchor verse for the entire screen. Fixed, not rotated: it is the
    /// thesis of the slide, and the one place we say out loud why we are asking
    /// for an action at all.
    public static let anchorVerse = "Faith by itself, if it is not accompanied by action, is dead."
    public static let anchorBook = "James 2:17"

    // MARK: Action selection

    /// The action to ask for today.
    ///
    /// Seeded by the day so it is stable across re-renders within a session — the
    /// ask must not shuffle underneath someone who is reading it — and different
    /// tomorrow, so a returning user is not handed the same errand every morning.
    public static func action(for category: DeclarationCategory, on date: Date = Date()) -> FaithAction {
        let actions = actionSet(for: category).actions
        // A set authored with no actions would trap on the modulo below, and it
        // would do it one line after the streak was written — the worst possible
        // moment to lose the app. Content should never ship an empty set, but a
        // typo in the catalog must not be able to crash the burst.
        guard !actions.isEmpty else { return emergencyAction }

        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return actions[abs(day) % actions.count]
    }

    /// Every category resolves to a set. Unmapped and Bible-book categories fall
    /// through to faith rather than returning nil, so the slide can never render
    /// empty.
    public static func actionSet(for category: DeclarationCategory) -> FaithActionSet {
        sets[category] ?? sets[.faith] ?? Self.faithFallback
    }

    /// Every theme with its own hand-written actions. Everything else borrows
    /// faith's. Exposed so tests can sweep the whole catalog for copy hygiene.
    public static var mappedThemes: [DeclarationCategory] {
        Array(sets.keys)
    }

    /// The ask that always exists. Reached only if the catalog is ever authored
    /// into a state that has nothing to offer, so it is written to fit anyone.
    private static let emergencyAction = FaithAction(
        icon: "figure.walk",
        headline: "Take one step you have been praying about",
        detail: "Do the small piece you can do today. God meets movement."
    )

    private static let faithFallback = FaithActionSet(
        premise: "God is already at work. Move like you believe it.",
        actions: [emergencyAction]
    )

    // MARK: - The sets

    private static let sets: [DeclarationCategory: FaithActionSet] = [

        // MARK: The body

        .health: FaithActionSet(
            premise: "You are healed. Now move like it.",
            actions: [
                FaithAction(
                    icon: "figure.walk",
                    headline: "Do one thing today a healed body does",
                    detail: "You know what that looks like for you. Go do it."
                ),
                FaithAction(
                    icon: "calendar.badge.plus",
                    headline: "Make a plan that assumes you are well",
                    detail: "Commit to something ahead of you. Plan like you will be there."
                ),
                FaithAction(
                    icon: "heart.fill",
                    headline: "Treat this body like it carries His life",
                    detail: "One choice today that honors what it is."
                )
            ]
        ),
        .wellness: FaithActionSet(
            premise: "This body is God's temple. Treat it like the temple it is.",
            actions: [
                FaithAction(
                    icon: "figure.strengthtraining.traditional",
                    headline: "Do something today that builds strength",
                    detail: "Stewardship is what you do with what God gave you."
                ),
                FaithAction(
                    icon: "drop.fill",
                    headline: "Give your body one thing it actually needs",
                    detail: "You already know which one. Give it today."
                ),
                FaithAction(
                    icon: "moon.stars.fill",
                    headline: "Guard your rest tonight",
                    detail: "Rest is obedience. God restores you while you sleep."
                )
            ]
        ),
        .mentalHealth: FaithActionSet(
            premise: "You have the mind of Christ. Clear, sound, and at rest.",
            actions: [
                FaithAction(
                    icon: "sun.max.fill",
                    headline: "Do the thing that clears your head",
                    detail: "You know what steadies you. Go do that today."
                ),
                FaithAction(
                    icon: "person.2.fill",
                    headline: "Let one safe person know how you are",
                    detail: "Light does its best work out in the open."
                ),
                FaithAction(
                    icon: "square.and.pencil",
                    headline: "Put something true where you can read it",
                    detail: "Give a sound mind something solid to hold."
                )
            ]
        ),

        // MARK: The mind and the heart

        .anxiety: FaithActionSet(
            premise: "The peace of God guards your heart. Live at that pace.",
            actions: [
                FaithAction(
                    icon: "wind",
                    headline: "Slow your body to the pace of your peace",
                    detail: "Let your day agree with what you spoke."
                ),
                FaithAction(
                    icon: "iphone.slash",
                    headline: "Give yourself a stretch of quiet today",
                    detail: "Guard what you were given. No screen outranks it."
                ),
                FaithAction(
                    icon: "checkmark.circle.fill",
                    headline: "Do what a settled heart would do",
                    detail: "Unhurried and done. That is you today."
                )
            ]
        ),
        .rest: FaithActionSet(
            premise: "He gives you rest on every side. Take it.",
            actions: [
                FaithAction(
                    icon: "moon.stars.fill",
                    headline: "Take some of the rest He already gave",
                    detail: "Receive it. Rest is handed to you, not earned."
                ),
                FaithAction(
                    icon: "hand.raised.fill",
                    headline: "Say no to one thing today",
                    detail: "One decline protects what God already handed you."
                ),
                FaithAction(
                    icon: "bed.double.fill",
                    headline: "Protect your sleep tonight",
                    detail: "He gives to His beloved even while they sleep."
                )
            ]
        ),
        .joy: FaithActionSet(
            premise: "The joy of the Lord is your strength. Spend some of it today.",
            actions: [
                FaithAction(
                    icon: "music.note",
                    headline: "Do something today purely for the joy of it",
                    detail: "Delight is not a reward for finishing. It is yours now."
                ),
                FaithAction(
                    icon: "face.smiling.fill",
                    headline: "Put some of your joy on someone else",
                    detail: "Joy is contagious on purpose. Hand some away."
                ),
                FaithAction(
                    icon: "sparkles",
                    headline: "Let today look like what you carry",
                    detail: "Strength this good belongs on your face."
                )
            ]
        ),
        .hope: FaithActionSet(
            premise: "Your future is good, and God is already in it.",
            actions: [
                FaithAction(
                    icon: "pencil.and.list.clipboard",
                    headline: "Put what you are believing for into words",
                    detail: "Hope gets specific before it gets seen."
                ),
                FaithAction(
                    icon: "calendar",
                    headline: "Plan something you are looking forward to",
                    detail: "Expectation is faith with a date on it."
                ),
                FaithAction(
                    icon: "photo.fill",
                    headline: "Put the promise somewhere you will see it",
                    detail: "Let it catch your eye all day."
                )
            ]
        ),
        .innerHealing: FaithActionSet(
            premise: "He heals the brokenhearted. You are whole in His hands.",
            actions: [
                FaithAction(
                    icon: "square.and.pencil",
                    headline: "Say the honest thing to God today",
                    detail: "He can hold all of it."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Let one person in today",
                    detail: "Wholeness grows in company."
                ),
                FaithAction(
                    icon: "door.left.hand.open",
                    headline: "Pick back up something you set down",
                    detail: "A healed heart takes its life back."
                )
            ]
        ),
        .grief: FaithActionSet(
            premise: "God is close to you, and joy is coming in the morning.",
            actions: [
                FaithAction(
                    icon: "heart.text.square.fill",
                    headline: "Remember them out loud today",
                    detail: "Say their name. Love keeps speaking."
                ),
                FaithAction(
                    icon: "leaf.fill",
                    headline: "Get yourself somewhere gentle today",
                    detail: "Let the air and the light reach you. God is closest here."
                ),
                FaithAction(
                    icon: "person.2.fill",
                    headline: "Let someone be with you today",
                    detail: "You were never meant to carry this alone."
                )
            ]
        ),
        .anger: FaithActionSet(
            premise: "You are ruled by the Spirit. Gentle, steady, in control.",
            actions: [
                FaithAction(
                    icon: "figure.run",
                    headline: "Put your strength somewhere good today",
                    detail: "Give it a place to go that builds something."
                ),
                FaithAction(
                    icon: "clock.fill",
                    headline: "Take the pause before you answer today",
                    detail: "Self control is a muscle. Today you use it."
                ),
                FaithAction(
                    icon: "bubble.left.and.bubble.right.fill",
                    headline: "Have the calm conversation you keep avoiding",
                    detail: "Low voice, plain words. Peace is the strongest thing here."
                )
            ]
        ),

        // MARK: The fight

        .fear: FaithActionSet(
            premise: "God gave you power, love, and a sound mind. Walk in it today.",
            actions: [
                FaithAction(
                    icon: "phone.fill",
                    headline: "Do the thing you have been putting off",
                    detail: "Courage is obedience with its shoes on."
                ),
                FaithAction(
                    icon: "figure.wave",
                    headline: "Take a step that stretches you",
                    detail: "Pick the thing at the edge of comfort and step over."
                ),
                FaithAction(
                    icon: "megaphone.fill",
                    headline: "Say the bold thing today",
                    detail: "Ask for it, offer it, name it. Boldness is yours."
                )
            ]
        ),
        .confidence: FaithActionSet(
            premise: "You are bold as a lion. Show up like it.",
            actions: [
                FaithAction(
                    icon: "hand.raised.fill",
                    headline: "Use your voice in the room today",
                    detail: "Say what you would normally keep to yourself."
                ),
                FaithAction(
                    icon: "paperplane.fill",
                    headline: "Ask for what you actually want",
                    detail: "The ask is the act of faith."
                ),
                FaithAction(
                    icon: "figure.stand",
                    headline: "Carry yourself like who you are",
                    detail: "A child of the King. Let your posture agree."
                )
            ]
        ),
        .warfare: FaithActionSet(
            premise: "The victory is already yours. Take the ground today.",
            actions: [
                FaithAction(
                    icon: "shield.lefthalf.filled",
                    headline: "Declare out loud over the ground you hold",
                    detail: "Your home, your family, your day. Say it is His."
                ),
                FaithAction(
                    icon: "trash.fill",
                    headline: "Clear out something that does not belong",
                    detail: "Victory keeps a clean house."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Fight for someone else today",
                    detail: "Ground gets taken when you cover another person."
                )
            ]
        ),
        .hardtimes: FaithActionSet(
            premise: "God is your strength, and He is holding you right now.",
            actions: [
                FaithAction(
                    icon: "list.bullet",
                    headline: "Do the next right thing and only that",
                    detail: "Not the whole mountain. One step is the assignment."
                ),
                FaithAction(
                    icon: "person.2.fill",
                    headline: "Tell one person what you need",
                    detail: "God moves through people who know."
                ),
                FaithAction(
                    icon: "book.fill",
                    headline: "Let the Word carry you today",
                    detail: "Read it out loud. Say it like it is yours."
                )
            ]
        ),
        .godsprotection: FaithActionSet(
            premise: "You dwell in the shelter of the Most High. No weapon prospers.",
            actions: [
                FaithAction(
                    icon: "house.fill",
                    headline: "Cover your household out loud today",
                    detail: "Name each person."
                ),
                FaithAction(
                    icon: "car.fill",
                    headline: "Go do what you have been holding back on",
                    detail: "Go. You are covered on every side."
                ),
                FaithAction(
                    icon: "message.fill",
                    headline: "Put that shelter over someone else today",
                    detail: "Send them what you are standing on."
                )
            ]
        ),

        // MARK: Freedom

        .addiction: FaithActionSet(
            premise: "You are free. Live today like the free person you are.",
            actions: [
                FaithAction(
                    icon: "trash.fill",
                    headline: "Close a door you know should be closed",
                    detail: "Freedom takes ground."
                ),
                FaithAction(
                    icon: "person.line.dotted.person.fill",
                    headline: "Tell your person where you are at",
                    detail: "Freedom stays free in the light."
                ),
                FaithAction(
                    icon: "figure.run",
                    headline: "Fill that space with something good",
                    detail: "Put something better there before anything else gets in."
                )
            ]
        ),
        .purity: FaithActionSet(
            premise: "You are clean before God. Guard what you were given.",
            actions: [
                FaithAction(
                    icon: "eye.slash.fill",
                    headline: "Choose what your eyes get today",
                    detail: "You decide what goes in. Guard them on purpose."
                ),
                FaithAction(
                    icon: "lock.shield.fill",
                    headline: "Put a guardrail in place today",
                    detail: "Build the fence now, not later."
                ),
                FaithAction(
                    icon: "book.closed.fill",
                    headline: "Fill the quiet with the Word tonight",
                    detail: "A full heart is a guarded heart."
                )
            ]
        ),
        .forgiveness: FaithActionSet(
            premise: "You are free of it. Walk today with open hands.",
            actions: [
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Bless them out loud today",
                    detail: "Blessing is how you set your own heart down."
                ),
                FaithAction(
                    icon: "flame.fill",
                    headline: "Put it down for good today",
                    detail: "It is not yours to carry."
                ),
                FaithAction(
                    icon: "figure.walk.departure",
                    headline: "Go back to the good thing you stopped",
                    detail: "Freedom shows up in your calendar first."
                )
            ]
        ),
        .grace: FaithActionSet(
            premise: "You stand righteous before God. Nothing to prove today.",
            actions: [
                FaithAction(
                    icon: "figure.arms.open",
                    headline: "Receive something today without earning it",
                    detail: "Take it and say thank you."
                ),
                FaithAction(
                    icon: "heart.fill",
                    headline: "Give someone the grace you were given",
                    detail: "Let one thing go without making them pay."
                ),
                FaithAction(
                    icon: "person.crop.circle.badge.checkmark",
                    headline: "Come to God before you clean yourself up",
                    detail: "The door is already open."
                )
            ]
        ),

        // MARK: Provision

        .wealth: FaithActionSet(
            premise: "God supplies all your needs. Handle money like a son, not a beggar.",
            actions: [
                FaithAction(
                    icon: "gift.fill",
                    headline: "Give something away today",
                    detail: "Giving is what an heir does."
                ),
                FaithAction(
                    icon: "chart.line.uptrend.xyaxis",
                    headline: "Look at what you are stewarding",
                    detail: "Stewards know exactly what they hold."
                ),
                FaithAction(
                    icon: "banknote.fill",
                    headline: "Sow something today, whatever the size",
                    detail: "Sowing is a decision, not an amount."
                )
            ]
        ),
        .debt: FaithActionSet(
            premise: "You are the lender and not the borrower. Move toward freedom today.",
            actions: [
                FaithAction(
                    icon: "list.number",
                    headline: "Put the whole picture in front of you",
                    detail: "You cannot take ground you will not look at."
                ),
                FaithAction(
                    icon: "phone.fill",
                    headline: "Make one move that lowers what you owe",
                    detail: "Freedom gets built in small moves."
                ),
                FaithAction(
                    icon: "arrow.down.circle.fill",
                    headline: "Send something extra toward it today",
                    detail: "Any amount. Momentum starts where you add to it."
                )
            ]
        ),
        .housing: FaithActionSet(
            premise: "God is preparing a place for you, and He knows the address.",
            actions: [
                FaithAction(
                    icon: "magnifyingglass",
                    headline: "Go look at what is out there today",
                    detail: "Faith goes and looks."
                ),
                FaithAction(
                    icon: "doc.text.fill",
                    headline: "Get something ready for the yes",
                    detail: "Prepare like it is coming."
                ),
                FaithAction(
                    icon: "shippingbox.fill",
                    headline: "Start getting ready to move",
                    detail: "Pack like you are going somewhere, because you are."
                )
            ]
        ),
        .work: FaithActionSet(
            premise: "You work for the Lord, and He promotes. Do today's work like His.",
            actions: [
                FaithAction(
                    icon: "paperplane.fill",
                    headline: "Put yourself in front of the opportunity",
                    detail: "Favor lands on things already in motion."
                ),
                FaithAction(
                    icon: "star.fill",
                    headline: "Do today's work better than it has to be",
                    detail: "Excellence is worship. He has already noticed."
                ),
                FaithAction(
                    icon: "person.2.wave.2.fill",
                    headline: "Reach out to someone in your field",
                    detail: "God opens doors through people."
                )
            ]
        ),
        .business: FaithActionSet(
            premise: "Your plans are diligent, and diligent plans lead to profit.",
            actions: [
                FaithAction(
                    icon: "phone.arrow.up.right.fill",
                    headline: "Get in front of a customer today",
                    detail: "The business grows where the conversation is."
                ),
                FaithAction(
                    icon: "hammer.fill",
                    headline: "Ship something today, even unfinished",
                    detail: "Diligence beats polish."
                ),
                FaithAction(
                    icon: "dollarsign.circle.fill",
                    headline: "Ask for the sale today",
                    detail: "You have something worth paying for."
                )
            ]
        ),
        .favor: FaithActionSet(
            premise: "Favor surrounds you like a shield. Walk through the open door.",
            actions: [
                FaithAction(
                    icon: "door.left.hand.open",
                    headline: "Walk through the door already open",
                    detail: "You know the one."
                ),
                FaithAction(
                    icon: "hand.raised.fill",
                    headline: "Ask for the thing you assumed was a no",
                    detail: "Favor answers questions that get asked."
                ),
                FaithAction(
                    icon: "person.crop.circle.badge.plus",
                    headline: "Put yourself in a new room today",
                    detail: "Favor travels through rooms you walk into."
                )
            ]
        ),
        .education: FaithActionSet(
            premise: "God gives you knowledge and understanding. Sit down and take it.",
            actions: [
                FaithAction(
                    icon: "book.fill",
                    headline: "Sit down and do the work today",
                    detail: "Wisdom rewards whoever shows up."
                ),
                FaithAction(
                    icon: "questionmark.circle.fill",
                    headline: "Ask for help where you are stuck",
                    detail: "Understanding comes through people too."
                ),
                FaithAction(
                    icon: "calendar.badge.clock",
                    headline: "Get the week in order today",
                    detail: "Order is how a mind stays clear."
                )
            ]
        ),

        // MARK: Who I am and where I am going

        .identity: FaithActionSet(
            premise: "You are God's own, chosen and loved. Live from that today.",
            actions: [
                FaithAction(
                    icon: "mirror.side.left",
                    headline: "Say it to your own face today",
                    detail: "Let your own eyes hear it."
                ),
                FaithAction(
                    icon: "hand.thumbsup.fill",
                    headline: "Act like the person God says you are",
                    detail: "Stop asking the room for permission. You have it."
                ),
                FaithAction(
                    icon: "heart.circle.fill",
                    headline: "Tell someone else who they are in God",
                    detail: "Identity spreads when it is spoken."
                )
            ]
        ),
        .destiny: FaithActionSet(
            premise: "God has good works prepared for you. Start one today.",
            actions: [
                FaithAction(
                    icon: "flag.fill",
                    headline: "Take the first step on what you keep sensing",
                    detail: "The smallest real version of it. Begin."
                ),
                FaithAction(
                    icon: "square.and.pencil",
                    headline: "Put your calling into words today",
                    detail: "Clarity comes to the page."
                ),
                FaithAction(
                    icon: "person.fill.questionmark",
                    headline: "Get near someone already walking it",
                    detail: "Purpose gets clearer in their company."
                )
            ]
        ),
        .newSeason: FaithActionSet(
            premise: "God is doing a new thing, and it is already springing up.",
            actions: [
                FaithAction(
                    icon: "sparkles",
                    headline: "Start one new rhythm today",
                    detail: "New seasons need new habits."
                ),
                FaithAction(
                    icon: "archivebox.fill",
                    headline: "Clear out space for what is coming",
                    detail: "Make room."
                ),
                FaithAction(
                    icon: "person.crop.circle.badge.plus",
                    headline: "Say yes to something new today",
                    detail: "New ground has new people on it."
                )
            ]
        ),
        .wisdom: FaithActionSet(
            premise: "God gives you wisdom generously. Use it on today's decision.",
            actions: [
                FaithAction(
                    icon: "checkmark.circle.fill",
                    headline: "Make the decision you keep circling",
                    detail: "You already have the wisdom you asked for."
                ),
                FaithAction(
                    icon: "ear.fill",
                    headline: "Get counsel from someone wise today",
                    detail: "Wisdom comes through many advisers."
                ),
                FaithAction(
                    icon: "book.closed.fill",
                    headline: "Sit in Proverbs today",
                    detail: "Wisdom is handed to whoever sits down for it."
                )
            ]
        ),
        .miracles: FaithActionSet(
            premise: "Nothing is too hard for God. Prepare like the breakthrough is here.",
            actions: [
                FaithAction(
                    icon: "hammer.fill",
                    headline: "Prepare today for the answer",
                    detail: "Do what only makes sense if it comes."
                ),
                FaithAction(
                    icon: "megaphone.fill",
                    headline: "Tell someone what God has already done",
                    detail: "Testimony builds the room's faith and yours."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Believe for someone else's breakthrough",
                    detail: "God moves in both directions."
                )
            ]
        ),

        // MARK: People

        .marriage: FaithActionSet(
            premise: "God is in your marriage, and He gives you everything to love well.",
            actions: [
                FaithAction(
                    icon: "heart.text.square.fill",
                    headline: "Tell your spouse what you see in them",
                    detail: "Marriages grow where the words go."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Pray together before the day ends",
                    detail: "The strongest thing you will do today."
                ),
                FaithAction(
                    icon: "fork.knife",
                    headline: "Make time for the two of you",
                    detail: "Attention is how love stays alive."
                )
            ]
        ),
        .relationship: FaithActionSet(
            premise: "God leads you in this, and His way is good.",
            actions: [
                FaithAction(
                    icon: "bubble.left.and.bubble.right.fill",
                    headline: "Have the honest conversation today",
                    detail: "Good things are built on plain words."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Pray for them by name today",
                    detail: "Ask God for their good, not just yours."
                ),
                FaithAction(
                    icon: "checklist",
                    headline: "Name the standard you are holding",
                    detail: "Clarity now saves you a year later."
                )
            ]
        ),
        .love: FaithActionSet(
            premise: "God's love for you is settled. Live full, not waiting.",
            actions: [
                FaithAction(
                    icon: "figure.2",
                    headline: "Go be around people today",
                    detail: "A full life is the best possible ground."
                ),
                FaithAction(
                    icon: "heart.fill",
                    headline: "Love someone well today without being asked",
                    detail: "This is who you already are."
                ),
                FaithAction(
                    icon: "sparkles",
                    headline: "Build the life you would want to share",
                    detail: "God is not waiting on anyone else to start."
                )
            ]
        ),
        .parenting: FaithActionSet(
            premise: "Your children are taught by the Lord, and great is their peace.",
            actions: [
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Bless your child out loud today",
                    detail: "They will remember your voice saying it."
                ),
                FaithAction(
                    icon: "gamecontroller.fill",
                    headline: "Give them your undivided attention",
                    detail: "Phone down, their terms. Presence is the gift."
                ),
                FaithAction(
                    icon: "ear.fill",
                    headline: "Ask one real question and listen",
                    detail: "No fixing today. Let them finish."
                )
            ]
        ),
        .singleParent: FaithActionSet(
            premise: "God is a father to your children and a help to you.",
            actions: [
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Bless your children out loud by name",
                    detail: "Your voice carries His."
                ),
                FaithAction(
                    icon: "person.2.fill",
                    headline: "Take or ask for the help today",
                    detail: "Receiving is how God sends most of what He sends."
                ),
                FaithAction(
                    icon: "cup.and.saucer.fill",
                    headline: "Take some time that belongs to you",
                    detail: "You are worth tending to. Take it without apologizing."
                )
            ]
        ),
        .friendship: FaithActionSet(
            premise: "God sets you in a family. You belong to people.",
            actions: [
                FaithAction(
                    icon: "message.fill",
                    headline: "Reach out to someone today",
                    detail: "Friendship is built out of small contact."
                ),
                FaithAction(
                    icon: "calendar.badge.plus",
                    headline: "Get something real on the calendar",
                    detail: "Community happens on purpose."
                ),
                FaithAction(
                    icon: "building.2.fill",
                    headline: "Show up somewhere in person",
                    detail: "Go where the people are."
                )
            ]
        ),
        .divorce: FaithActionSet(
            premise: "God restores your life, and your future is His to build.",
            actions: [
                FaithAction(
                    icon: "sparkles",
                    headline: "Make one thing yours today",
                    detail: "Build the life in front of you."
                ),
                FaithAction(
                    icon: "person.2.fill",
                    headline: "Reach for someone who is for you",
                    detail: "Restoration comes with company."
                ),
                FaithAction(
                    icon: "figure.walk",
                    headline: "Take it to God today",
                    detail: "He has good ahead of you."
                )
            ]
        ),
        .fertility: FaithActionSet(
            premise: "God makes the barren woman a joyful mother of children.",
            actions: [
                FaithAction(
                    icon: "gift.fill",
                    headline: "Set something aside for the child",
                    detail: "Prepare like the promise is coming, because it is."
                ),
                FaithAction(
                    icon: "heart.fill",
                    headline: "Treat your body like the promise is coming",
                    detail: "Steward it now."
                ),
                FaithAction(
                    icon: "square.and.pencil",
                    headline: "Write to the child today",
                    detail: "Faith puts things in writing."
                )
            ]
        ),
        .salvation: FaithActionSet(
            premise: "God pursues them harder than you do, and He is faithful.",
            actions: [
                FaithAction(
                    icon: "message.fill",
                    headline: "Reach out with no agenda in it",
                    detail: "Love them today. Nothing to convince, nothing to fix."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Pray for them and then release it",
                    detail: "He is the one who draws hearts."
                ),
                FaithAction(
                    icon: "fork.knife",
                    headline: "Invite them into something ordinary",
                    detail: "Presence preaches."
                )
            ]
        ),

        // MARK: Walking with God

        .faith: FaithActionSet(
            premise: "God is already at work. Move like you believe it.",
            actions: [
                FaithAction(
                    icon: "figure.walk",
                    headline: "Take a step toward what you are believing for",
                    detail: "Faith moves before it sees."
                ),
                FaithAction(
                    icon: "megaphone.fill",
                    headline: "Tell someone what God is doing in you",
                    detail: "Faith grows in your own ears."
                ),
                FaithAction(
                    icon: "hand.raised.fill",
                    headline: "Obey the one thing you already know",
                    detail: "You have been thinking about it all week."
                )
            ]
        ),
        .spiritualGrowth: FaithActionSet(
            premise: "You are growing in Him. Feed what is growing.",
            actions: [
                FaithAction(
                    icon: "book.fill",
                    headline: "Get into the Word today",
                    detail: "Roots go down where they are watered."
                ),
                FaithAction(
                    icon: "clock.fill",
                    headline: "Give God the first part of tomorrow",
                    detail: "First is a decision you make the day before."
                ),
                FaithAction(
                    icon: "person.2.fill",
                    headline: "Bring someone along with you",
                    detail: "Teaching is how it sinks in."
                )
            ]
        ),
        .obedience: FaithActionSet(
            premise: "His way is best, and you trust Him with it.",
            actions: [
                FaithAction(
                    icon: "checkmark.seal.fill",
                    headline: "Do the thing you have been delaying",
                    detail: "You already know what it is."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Hand Him the decision out loud",
                    detail: "Surrender is spoken before it is felt."
                ),
                FaithAction(
                    icon: "arrow.uturn.backward",
                    headline: "Make one thing right today",
                    detail: "Go do it."
                )
            ]
        ),
        .gratitude: FaithActionSet(
            premise: "God has been good to you, and you can name it.",
            actions: [
                FaithAction(
                    icon: "square.and.pencil",
                    headline: "Write down what He has done",
                    detail: "Gratitude gets strong when it gets specific."
                ),
                FaithAction(
                    icon: "message.fill",
                    headline: "Thank someone who will not expect it",
                    detail: "Say exactly what they did."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Thank Him before you ask for anything",
                    detail: "Name what He has already done."
                )
            ]
        ),
        .praise: FaithActionSet(
            premise: "He is worthy, and praise belongs in your mouth today.",
            actions: [
                FaithAction(
                    icon: "music.note",
                    headline: "Praise Him out loud today",
                    detail: "Full voice, wherever you are."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Praise Him before the answer comes",
                    detail: "That is faith singing."
                ),
                FaithAction(
                    icon: "megaphone.fill",
                    headline: "Tell someone what God has done",
                    detail: "Praise gets loud when it is shared."
                )
            ]
        ),
        .godsheart: FaithActionSet(
            premise: "God delights in you. Spend time with the One who does.",
            actions: [
                FaithAction(
                    icon: "clock.fill",
                    headline: "Be with God with nothing to ask for",
                    detail: "Nothing on the list. Only Him."
                ),
                FaithAction(
                    icon: "heart.fill",
                    headline: "Love someone the way He loves you",
                    detail: "Do the undeserved kind thing today."
                ),
                FaithAction(
                    icon: "book.closed.fill",
                    headline: "Sit in what He says about you",
                    detail: "Read it slowly. Let it land."
                )
            ]
        ),
        .heaven: FaithActionSet(
            premise: "Your citizenship is in heaven. Live today from up there.",
            actions: [
                FaithAction(
                    icon: "arrow.up.heart.fill",
                    headline: "Do something today that only matters forever",
                    detail: "Invest where nothing rusts."
                ),
                FaithAction(
                    icon: "hand.raised.fill",
                    headline: "Let go of something that will not last",
                    detail: "It is not going with you."
                ),
                FaithAction(
                    icon: "person.2.fill",
                    headline: "Point someone toward Jesus today",
                    detail: "People last forever."
                )
            ]
        ),
        .speaklife: FaithActionSet(
            premise: "Your words carry life. Spend them well today.",
            actions: [
                FaithAction(
                    icon: "megaphone.fill",
                    headline: "Speak life over someone out loud",
                    detail: "Tell them what you see in them."
                ),
                FaithAction(
                    icon: "text.bubble.fill",
                    headline: "Speak over your day before it starts",
                    detail: "Set the tone with your own mouth."
                ),
                FaithAction(
                    icon: "message.fill",
                    headline: "Pass on the words you needed",
                    detail: "Life multiplies when it is spoken."
                )
            ]
        ),
        .blood: FaithActionSet(
            premise: "The blood of Jesus covers you. Live like a covered person.",
            actions: [
                FaithAction(
                    icon: "shield.lefthalf.filled",
                    headline: "Speak His covering over your household",
                    detail: "Say what the blood already bought."
                ),
                FaithAction(
                    icon: "figure.arms.open",
                    headline: "Come to God with your head up",
                    detail: "The price is paid and the door is open."
                ),
                FaithAction(
                    icon: "hand.raised.fill",
                    headline: "Put down what was already paid for",
                    detail: "It was settled at the cross."
                )
            ]
        ),
        .nameOfJesus: FaithActionSet(
            premise: "You carry the name above every name. Use it today.",
            actions: [
                FaithAction(
                    icon: "megaphone.fill",
                    headline: "Pray in His name over something today",
                    detail: "The name is authority, not decoration."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Pray for someone in front of you",
                    detail: "Right there, out loud."
                ),
                FaithAction(
                    icon: "text.bubble.fill",
                    headline: "Speak His name over your day",
                    detail: "Everything bows to it."
                )
            ]
        )
    ]
}

// MARK: - Commitment Store

/// What the user said yes to today.
///
/// Deliberately not a checklist. There is no "did you do it?" and no way to fail
/// this — a commitment that can be marked incomplete turns a grace-first invitation
/// into one more thing someone is behind on, which is the exact inversion of the
/// feature. Only today's yes is kept, so the slate is genuinely clean each morning.
public final class FaithActionCommitmentStore: ObservableObject {

    public static let shared = FaithActionCommitmentStore()

    public struct Commitment: Codable, Equatable {
        /// `DeclarationCategory` rawValue.
        public let theme: String
        public let headline: String
        public let committedAt: Date

        public init(theme: String, headline: String, committedAt: Date) {
            self.theme = theme
            self.headline = headline
            self.committedAt = committedAt
        }
    }

    /// Nil unless the user committed to an action today.
    @Published public private(set) var todaysCommitment: Commitment?

    private let defaults: UserDefaults
    private let calendar = Calendar.current
    private static let storageKey = "sl_faithActionCommitment_v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        todaysCommitment = Self.loadIfToday(from: defaults, calendar: calendar)
    }

    public func commit(to action: FaithAction, theme: DeclarationCategory, on date: Date = Date()) {
        let commitment = Commitment(
            theme: theme.rawValue,
            headline: action.headline,
            committedAt: date
        )
        todaysCommitment = commitment
        if let encoded = try? JSONEncoder().encode(commitment) {
            defaults.set(encoded, forKey: Self.storageKey)
        }
    }

    /// Yesterday's yes is not today's. Reading through this keeps a stale
    /// commitment from surfacing on a later day.
    public func hasCommittedToday(on date: Date = Date()) -> Bool {
        guard let commitment = todaysCommitment else { return false }
        return calendar.isDate(commitment.committedAt, inSameDayAs: date)
    }

    private static func loadIfToday(from defaults: UserDefaults, calendar: Calendar) -> Commitment? {
        guard let data = defaults.data(forKey: storageKey),
              let commitment = try? JSONDecoder().decode(Commitment.self, from: data),
              calendar.isDateInToday(commitment.committedAt) else { return nil }
        return commitment
    }
}
