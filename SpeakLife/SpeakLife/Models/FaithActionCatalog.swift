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
//  true. Someone who declared healing goes for a walk. Someone who declared
//  provision gives something away. The act is the amen.
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
//

import Foundation
import Combine

// MARK: - Faith Action

/// One corresponding action: the thing someone does today because the thing they
/// declared is already true.
struct FaithAction: Equatable {
    /// SF Symbol shown on the action card.
    let icon: String
    /// The invitation itself. Imperative, short enough to read in one glance.
    let headline: String
    /// One line naming the belief the act is enacting. Never explains the joke.
    let detail: String
}

/// The full ask for one theme: the truth being stood on, plus the actions that
/// stand on it.
struct FaithActionSet: Equatable {
    /// Two beats: what is already true, and the move that follows from it.
    /// Shown above the action card as the frame for the whole slide.
    let premise: String
    /// Always non-empty. Multiple entries so the ask rotates day to day rather
    /// than becoming wallpaper.
    let actions: [FaithAction]
}

// MARK: - Catalog

enum FaithActionCatalog {

    /// The anchor verse for the entire screen. Fixed, not rotated: it is the
    /// thesis of the slide, and the one place we say out loud why we are asking
    /// for an action at all.
    static let anchorVerse = "Faith by itself, if it is not accompanied by action, is dead."
    static let anchorBook = "James 2:17"

    // MARK: Theme resolution

    /// The theme the burst was actually about.
    ///
    /// Precedence is deliberate:
    ///
    ///   1. An active Enforcement owns the burst — `loadDynamicDeclarations`
    ///      already fills all seven slots from the campaign, so the campaign's
    ///      theme is the only honest answer.
    ///   2. Otherwise the dominant category among the spoken declarations, which
    ///      is what the user just actually said regardless of what is selected in
    ///      the picker.
    ///   3. Otherwise whatever category is selected.
    ///   4. Otherwise faith, which has actions that fit anyone.
    ///
    /// Bible-book categories fold to `.faith`: someone reading through Romans has
    /// no single life situation to act on, and "read Romans" is not a corresponding
    /// action, it is the thing they were already doing.
    static func resolveTheme(
        enforcement: DeclarationCategory?,
        spoken: [DeclarationCategory],
        selected: DeclarationCategory?
    ) -> DeclarationCategory {
        if let enforcement, isActionable(enforcement) {
            return enforcement
        }
        if let dominant = dominantCategory(in: spoken) {
            return dominant
        }
        if let selected, isActionable(selected) {
            return selected
        }
        return .faith
    }

    /// True when a category names a life situation someone can take a step in
    /// today. Bible books, the favorites bin, and the user's own bucket are all
    /// containers rather than themes, so they never win theme resolution.
    static func isActionable(_ category: DeclarationCategory) -> Bool {
        if category.isBibleBook { return false }
        switch category {
        case .favorites, .myOwn, .general: return false
        default: return true
        }
    }

    /// Most frequent actionable category, ties broken by first appearance so the
    /// result is stable for a given burst rather than dependent on dictionary
    /// ordering.
    private static func dominantCategory(in spoken: [DeclarationCategory]) -> DeclarationCategory? {
        let actionable = spoken.filter(isActionable)
        guard !actionable.isEmpty else { return nil }

        var counts: [DeclarationCategory: Int] = [:]
        for category in actionable {
            counts[category, default: 0] += 1
        }
        var best: DeclarationCategory?
        var bestCount = 0
        for category in actionable where counts[category, default: 0] > bestCount {
            best = category
            bestCount = counts[category, default: 0]
        }
        return best
    }

    // MARK: Action selection

    /// The action to ask for today.
    ///
    /// Seeded by the day so it is stable across re-renders within a session — the
    /// ask must not shuffle underneath someone who is reading it — and different
    /// tomorrow, so a returning user is not handed the same errand every morning.
    static func action(for category: DeclarationCategory, on date: Date = Date()) -> FaithAction {
        let set = actionSet(for: category)
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let index = abs(day) % set.actions.count
        return set.actions[index]
    }

    /// Every category resolves to a set. Unmapped and Bible-book categories fall
    /// through to faith rather than returning nil, so the slide can never render
    /// empty.
    static func actionSet(for category: DeclarationCategory) -> FaithActionSet {
        sets[category] ?? sets[.faith] ?? Self.faithFallback
    }

    /// Every theme with its own hand-written actions. Everything else borrows
    /// faith's. Exposed so tests can sweep the whole catalog for copy hygiene.
    static var mappedThemes: [DeclarationCategory] {
        Array(sets.keys)
    }

    private static let faithFallback = FaithActionSet(
        premise: "God is already at work. Move like you believe it.",
        actions: [
            FaithAction(
                icon: "figure.walk",
                headline: "Take one step you have been praying about",
                detail: "Do the small piece you can do today. God meets movement."
            )
        ]
    )

    // MARK: - The sets

    private static let sets: [DeclarationCategory: FaithActionSet] = [

        // MARK: The body

        .health: FaithActionSet(
            premise: "You are healed. Now move like it.",
            actions: [
                FaithAction(
                    icon: "figure.walk",
                    headline: "Walk for fifteen minutes today",
                    detail: "Move the way a healthy body moves. Your steps agree with what you spoke."
                ),
                FaithAction(
                    icon: "calendar.badge.plus",
                    headline: "Put one thing back on your calendar",
                    detail: "Schedule something you want to be doing next month. Plan like you will be there."
                ),
                FaithAction(
                    icon: "carrot.fill",
                    headline: "Feed your body one good meal today",
                    detail: "Treat this body like what it is. A temple carrying the life of Christ."
                )
            ]
        ),

        .wellness: FaithActionSet(
            premise: "This body is God's temple. Treat it like the temple it is.",
            actions: [
                FaithAction(
                    icon: "figure.strengthtraining.traditional",
                    headline: "Train for twenty minutes today",
                    detail: "Strength is stewardship. Spend twenty minutes building what God gave you."
                ),
                FaithAction(
                    icon: "drop.fill",
                    headline: "Drink water every time you think of this",
                    detail: "Small faithfulness, repeated, is how a body changes."
                ),
                FaithAction(
                    icon: "bed.double.fill",
                    headline: "Go to bed thirty minutes earlier tonight",
                    detail: "Rest is obedience. God restores you while you sleep."
                )
            ]
        ),

        .mentalHealth: FaithActionSet(
            premise: "You have the mind of Christ. Clear, sound, and at rest.",
            actions: [
                FaithAction(
                    icon: "sun.max.fill",
                    headline: "Get ten minutes of sunlight today",
                    detail: "Step outside and let your body catch up to what your spirit already knows."
                ),
                FaithAction(
                    icon: "person.2.fill",
                    headline: "Tell one safe person how you are really doing",
                    detail: "Light does its best work out in the open. Say it to someone today."
                ),
                FaithAction(
                    icon: "square.and.pencil",
                    headline: "Write down three things God has done",
                    detail: "Give your sound mind something true to hold and read it back."
                )
            ]
        ),

        // MARK: The mind and the heart

        .anxiety: FaithActionSet(
            premise: "The peace of God guards your heart. Live at that pace.",
            actions: [
                FaithAction(
                    icon: "wind",
                    headline: "Breathe slowly for two full minutes",
                    detail: "Let your body move at the speed of the peace you just declared."
                ),
                FaithAction(
                    icon: "iphone.slash",
                    headline: "Put your phone down for one hour today",
                    detail: "Guard the quiet you were given. Nothing on that screen outranks it."
                ),
                FaithAction(
                    icon: "checkmark.circle.fill",
                    headline: "Do the one thing you have been putting off",
                    detail: "Ten minutes on it. A settled heart moves without hurry."
                )
            ]
        ),

        .rest: FaithActionSet(
            premise: "He gives you rest on every side. Take it.",
            actions: [
                FaithAction(
                    icon: "moon.stars.fill",
                    headline: "Sit still for ten minutes with nothing on",
                    detail: "No screen, no noise. Rest is something you receive, not something you earn."
                ),
                FaithAction(
                    icon: "hand.raised.fill",
                    headline: "Say no to one thing today",
                    detail: "One decline protects the rest God already handed you."
                ),
                FaithAction(
                    icon: "bed.double.fill",
                    headline: "Protect your sleep tonight",
                    detail: "Lights off early. He gives to His beloved even while they sleep."
                )
            ]
        ),

        .joy: FaithActionSet(
            premise: "The joy of the Lord is your strength. Spend some of it today.",
            actions: [
                FaithAction(
                    icon: "music.note",
                    headline: "Play the song that lifts you and sing it loud",
                    detail: "Joy gets louder when you use it. Sing where someone can hear you."
                ),
                FaithAction(
                    icon: "face.smiling.fill",
                    headline: "Make one person laugh today",
                    detail: "Joy is contagious on purpose. Hand some of yours away."
                ),
                FaithAction(
                    icon: "figure.dance",
                    headline: "Do one thing today purely because you enjoy it",
                    detail: "Delight is not a reward for finishing. It is yours now."
                )
            ]
        ),

        .hope: FaithActionSet(
            premise: "Your future is good, and God is already in it.",
            actions: [
                FaithAction(
                    icon: "pencil.and.list.clipboard",
                    headline: "Write down what you are believing for",
                    detail: "Put it in writing today. Hope gets specific before it gets seen."
                ),
                FaithAction(
                    icon: "calendar",
                    headline: "Plan something to look forward to",
                    detail: "Get one good thing on the calendar. Expectation is faith with a date on it."
                ),
                FaithAction(
                    icon: "photo.fill",
                    headline: "Put the promise somewhere you will see it",
                    detail: "Set it on your lock screen or your mirror. Look at it all day."
                )
            ]
        ),

        .innerHealing: FaithActionSet(
            premise: "He heals the brokenhearted. You are whole in His hands.",
            actions: [
                FaithAction(
                    icon: "square.and.pencil",
                    headline: "Write God one honest page today",
                    detail: "Say the real thing to Him. He can hold all of it."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Let one person in today",
                    detail: "Call the friend you have been meaning to call. Wholeness grows in company."
                ),
                FaithAction(
                    icon: "door.left.hand.open",
                    headline: "Do one thing you loved before",
                    detail: "Go back to it today. A healed heart picks its life back up."
                )
            ]
        ),

        .grief: FaithActionSet(
            premise: "God is close to you, and joy is coming in the morning.",
            actions: [
                FaithAction(
                    icon: "heart.text.square.fill",
                    headline: "Tell someone one story worth remembering",
                    detail: "Say their name out loud today. Love keeps speaking."
                ),
                FaithAction(
                    icon: "leaf.fill",
                    headline: "Get outside for a slow walk",
                    detail: "Let the air and the light reach you. God is closest here."
                ),
                FaithAction(
                    icon: "person.2.fill",
                    headline: "Let one person sit with you today",
                    detail: "Text them and say come. You were never meant to carry this alone."
                )
            ]
        ),

        .anger: FaithActionSet(
            premise: "You are ruled by the Spirit. Gentle, steady, in control.",
            actions: [
                FaithAction(
                    icon: "figure.run",
                    headline: "Burn the energy off in twenty minutes of movement",
                    detail: "Run it, lift it, walk it out. Give your strength somewhere good to go."
                ),
                FaithAction(
                    icon: "clock.fill",
                    headline: "Wait ten seconds before you answer today",
                    detail: "Ten seconds, every time. Self control is a muscle and today you use it."
                ),
                FaithAction(
                    icon: "bubble.left.and.bubble.right.fill",
                    headline: "Have the calm conversation you have been avoiding",
                    detail: "Low voice, plain words. Peace is the strongest thing in the room."
                )
            ]
        ),

        .fear: FaithActionSet(
            premise: "God gave you power, love, and a sound mind. Walk in it today.",
            actions: [
                FaithAction(
                    icon: "phone.fill",
                    headline: "Make the call you have been putting off",
                    detail: "Today. Courage is just obedience with a phone in its hand."
                ),
                FaithAction(
                    icon: "figure.wave",
                    headline: "Do one thing that stretches you",
                    detail: "Pick the thing on the edge of your comfort and step over the line."
                ),
                FaithAction(
                    icon: "megaphone.fill",
                    headline: "Say the bold thing out loud today",
                    detail: "Ask for it, offer it, name it. Boldness is yours."
                )
            ]
        ),

        .confidence: FaithActionSet(
            premise: "You are bold as a lion. Show up like it.",
            actions: [
                FaithAction(
                    icon: "hand.raised.fill",
                    headline: "Speak up once in the room today",
                    detail: "Say the thing you would normally keep to yourself. Your voice belongs there."
                ),
                FaithAction(
                    icon: "paperplane.fill",
                    headline: "Ask for what you actually want",
                    detail: "Send it today. The ask is the act of faith."
                ),
                FaithAction(
                    icon: "figure.stand",
                    headline: "Take up your full space today",
                    detail: "Shoulders back, chin level, eyes up. Carry yourself like a child of the King."
                )
            ]
        ),

        // MARK: The fight

        .warfare: FaithActionSet(
            premise: "The victory is already yours. Take the ground today.",
            actions: [
                FaithAction(
                    icon: "shield.lefthalf.filled",
                    headline: "Walk your home and declare it His",
                    detail: "Room by room, out loud. This ground belongs to the Lord."
                ),
                FaithAction(
                    icon: "trash.fill",
                    headline: "Remove one thing you know does not belong",
                    detail: "Delete it, unfollow it, throw it out. Victory keeps a clean house."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Pray out loud over someone else today",
                    detail: "Cover somebody. Ground gets taken when you fight for another person."
                )
            ]
        ),

        .hardtimes: FaithActionSet(
            premise: "God is your strength, and He is holding you right now.",
            actions: [
                FaithAction(
                    icon: "list.bullet",
                    headline: "Do the next right thing and only that",
                    detail: "One task. Not the whole mountain. Faithful in the small is the whole assignment."
                ),
                FaithAction(
                    icon: "person.2.fill",
                    headline: "Tell one person what you need",
                    detail: "Ask plainly today. God moves through people who know."
                ),
                FaithAction(
                    icon: "book.fill",
                    headline: "Read one psalm out loud",
                    detail: "Let David's words carry you today. Say them like they are yours."
                )
            ]
        ),

        .godsprotection: FaithActionSet(
            premise: "You dwell in the shelter of the Most High. No weapon prospers.",
            actions: [
                FaithAction(
                    icon: "house.fill",
                    headline: "Pray over your household out loud",
                    detail: "Name each person. Cover them by name today."
                ),
                FaithAction(
                    icon: "car.fill",
                    headline: "Go do the thing you have been hesitant to do",
                    detail: "Go. You are covered on every side."
                ),
                FaithAction(
                    icon: "message.fill",
                    headline: "Send one person the psalm you are standing on",
                    detail: "Put the shelter over somebody else today."
                )
            ]
        ),

        .addiction: FaithActionSet(
            premise: "You are free. Live today like the free person you are.",
            actions: [
                FaithAction(
                    icon: "trash.fill",
                    headline: "Remove one access point today",
                    detail: "Delete the app, block the number, clear the shelf. Freedom takes ground."
                ),
                FaithAction(
                    icon: "person.line.dotted.person.fill",
                    headline: "Tell your person where you are at",
                    detail: "One honest text today. Freedom stays free in the light."
                ),
                FaithAction(
                    icon: "figure.run",
                    headline: "Replace one hour with something good",
                    detail: "Gym, walk, work, a friend. Fill the space before anything else does."
                )
            ]
        ),

        .purity: FaithActionSet(
            premise: "You are clean before God. Guard what you were given.",
            actions: [
                FaithAction(
                    icon: "eye.slash.fill",
                    headline: "Clean out one feed today",
                    detail: "Unfollow what you know pulls at you. Guard your eyes on purpose."
                ),
                FaithAction(
                    icon: "lock.shield.fill",
                    headline: "Put one guardrail in place today",
                    detail: "A filter, an accountability partner, a rule about nights. Build the fence now."
                ),
                FaithAction(
                    icon: "book.closed.fill",
                    headline: "Fill the quiet with the Word tonight",
                    detail: "Read or listen for ten minutes before bed. A full heart is a guarded heart."
                )
            ]
        ),

        .forgiveness: FaithActionSet(
            premise: "You are free of it. Walk today with open hands.",
            actions: [
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Say their name to God and bless them",
                    detail: "Out loud, once, today. Blessing is how you set your own heart down."
                ),
                FaithAction(
                    icon: "flame.fill",
                    headline: "Write it out and then get rid of the page",
                    detail: "Say the whole thing on paper, then tear it up. It is not yours to carry."
                ),
                FaithAction(
                    icon: "figure.walk.departure",
                    headline: "Do the good thing you stopped doing",
                    detail: "Go back to it today. Freedom shows up in your calendar first."
                )
            ]
        ),

        .grace: FaithActionSet(
            premise: "You stand righteous before God. Nothing to prove today.",
            actions: [
                FaithAction(
                    icon: "figure.arms.open",
                    headline: "Receive one thing today without earning it",
                    detail: "Take the compliment, the gift, the help. Say thank you and keep it."
                ),
                FaithAction(
                    icon: "heart.fill",
                    headline: "Give someone the grace you have been given",
                    detail: "Let one thing go today without making them pay for it."
                ),
                FaithAction(
                    icon: "person.crop.circle.badge.checkmark",
                    headline: "Come to God before you clean yourself up",
                    detail: "Pray as you are, right now. The door is already open."
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
                    detail: "Money, a meal, a tank of gas. Giving is what an heir does."
                ),
                FaithAction(
                    icon: "chart.line.uptrend.xyaxis",
                    headline: "Look at your numbers for ten minutes",
                    detail: "Open the account and look. Stewards know exactly what they are holding."
                ),
                FaithAction(
                    icon: "banknote.fill",
                    headline: "Put something aside today, however small",
                    detail: "Any amount. Sowing is a decision, not an amount."
                )
            ]
        ),

        .debt: FaithActionSet(
            premise: "You are the lender and not the borrower. Move toward freedom today.",
            actions: [
                FaithAction(
                    icon: "list.number",
                    headline: "Write down every balance in one place",
                    detail: "All of it on one page today. You cannot take ground you refuse to look at."
                ),
                FaithAction(
                    icon: "phone.fill",
                    headline: "Make one call about a rate or a plan",
                    detail: "One call today. Freedom is built in phone calls."
                ),
                FaithAction(
                    icon: "arrow.down.circle.fill",
                    headline: "Send one extra payment, any size",
                    detail: "Five dollars counts. Momentum starts the day you add to it."
                )
            ]
        ),

        .housing: FaithActionSet(
            premise: "God is preparing a place for you, and He knows the address.",
            actions: [
                FaithAction(
                    icon: "magnifyingglass",
                    headline: "Look at one place today",
                    detail: "Search it, drive it, tour it. Faith goes and looks."
                ),
                FaithAction(
                    icon: "doc.text.fill",
                    headline: "Get one document ready",
                    detail: "Pull the paperwork today. Prepare like the yes is coming."
                ),
                FaithAction(
                    icon: "shippingbox.fill",
                    headline: "Pack one box",
                    detail: "One box today. Pack like you are going somewhere, because you are."
                )
            ]
        ),

        .work: FaithActionSet(
            premise: "You work for the Lord, and He promotes. Do today's work like His.",
            actions: [
                FaithAction(
                    icon: "paperplane.fill",
                    headline: "Send the application or the ask today",
                    detail: "One send. Favor lands on things that are in motion."
                ),
                FaithAction(
                    icon: "star.fill",
                    headline: "Do one piece of work better than required",
                    detail: "Excellence is worship. Someone will notice, and He already has."
                ),
                FaithAction(
                    icon: "person.2.wave.2.fill",
                    headline: "Reach out to one person in your field",
                    detail: "A message today. God opens doors through people."
                )
            ]
        ),

        .business: FaithActionSet(
            premise: "Your plans are diligent, and diligent plans lead to profit.",
            actions: [
                FaithAction(
                    icon: "phone.arrow.up.right.fill",
                    headline: "Talk to one customer today",
                    detail: "Call, message, ask. The business grows where the conversation is."
                ),
                FaithAction(
                    icon: "hammer.fill",
                    headline: "Ship one thing today, even unfinished",
                    detail: "Get it out the door. Diligence beats polish."
                ),
                FaithAction(
                    icon: "dollarsign.circle.fill",
                    headline: "Make one ask for the sale",
                    detail: "Ask plainly today. You have something worth paying for."
                )
            ]
        ),

        .favor: FaithActionSet(
            premise: "Favor surrounds you like a shield. Walk through the open door.",
            actions: [
                FaithAction(
                    icon: "door.left.hand.open",
                    headline: "Walk through the door that is already open",
                    detail: "You know the one. Take the step today."
                ),
                FaithAction(
                    icon: "hand.raised.fill",
                    headline: "Ask for the thing you assumed was a no",
                    detail: "Ask anyway today. Favor answers questions that get asked."
                ),
                FaithAction(
                    icon: "person.crop.circle.badge.plus",
                    headline: "Introduce yourself to one new person",
                    detail: "Favor travels through rooms you actually walk into."
                )
            ]
        ),

        .education: FaithActionSet(
            premise: "God gives you knowledge and understanding. Sit down and take it.",
            actions: [
                FaithAction(
                    icon: "book.fill",
                    headline: "Study for twenty-five focused minutes",
                    detail: "Timer on, phone away. Wisdom rewards the one who shows up."
                ),
                FaithAction(
                    icon: "questionmark.circle.fill",
                    headline: "Ask for help on the thing you are stuck on",
                    detail: "Email the teacher, text the classmate. Understanding comes through people too."
                ),
                FaithAction(
                    icon: "calendar.badge.clock",
                    headline: "Map out the week's work today",
                    detail: "Fifteen minutes of planning. Order is how a mind stays clear."
                )
            ]
        ),

        // MARK: Who I am and where I am going

        .identity: FaithActionSet(
            premise: "You are God's own, chosen and loved. Live from that today.",
            actions: [
                FaithAction(
                    icon: "mirror.side.left",
                    headline: "Say it to your own face in the mirror",
                    detail: "Out loud, once today. Let your own eyes hear it."
                ),
                FaithAction(
                    icon: "hand.thumbsup.fill",
                    headline: "Act like the person God says you are",
                    detail: "Stop asking the room for permission. You already have it."
                ),
                FaithAction(
                    icon: "heart.circle.fill",
                    headline: "Tell someone else who they are in God",
                    detail: "Say it plainly today. Identity spreads when it is spoken."
                )
            ]
        ),

        .destiny: FaithActionSet(
            premise: "God has good works prepared for you. Start one today.",
            actions: [
                FaithAction(
                    icon: "flag.fill",
                    headline: "Take the first step on the thing you keep sensing",
                    detail: "The smallest possible version of it, today. Just begin."
                ),
                FaithAction(
                    icon: "square.and.pencil",
                    headline: "Write down what you believe you are called to",
                    detail: "Put it in words today. Clarity comes to the page."
                ),
                FaithAction(
                    icon: "person.fill.questionmark",
                    headline: "Talk to someone already doing it",
                    detail: "Reach out today. Purpose gets clearer in the presence of people walking it."
                )
            ]
        ),

        .newSeason: FaithActionSet(
            premise: "God is doing a new thing, and it is already springing up.",
            actions: [
                FaithAction(
                    icon: "sparkles",
                    headline: "Start one new rhythm today",
                    detail: "A walk, a page, a prayer at the same hour. New seasons need new habits."
                ),
                FaithAction(
                    icon: "archivebox.fill",
                    headline: "Clear out one space today",
                    detail: "A drawer, a closet, an inbox. Make room for what is coming."
                ),
                FaithAction(
                    icon: "person.crop.circle.badge.plus",
                    headline: "Say yes to one invitation",
                    detail: "Go today. New ground has new people on it."
                )
            ]
        ),

        .wisdom: FaithActionSet(
            premise: "God gives you wisdom generously. Use it on today's decision.",
            actions: [
                FaithAction(
                    icon: "checkmark.circle.fill",
                    headline: "Make the decision you have been circling",
                    detail: "Decide today. You already have the wisdom you have been asking for."
                ),
                FaithAction(
                    icon: "ear.fill",
                    headline: "Ask one wise person for counsel",
                    detail: "Make the call today. Wisdom comes through many advisers."
                ),
                FaithAction(
                    icon: "book.closed.fill",
                    headline: "Read one chapter of Proverbs",
                    detail: "Ten minutes today. Wisdom is handed to whoever sits down for it."
                )
            ]
        ),

        .miracles: FaithActionSet(
            premise: "Nothing is too hard for God. Prepare like the breakthrough is here.",
            actions: [
                FaithAction(
                    icon: "hammer.fill",
                    headline: "Prepare for the answer today",
                    detail: "Do the thing that only makes sense if it comes. Get ready."
                ),
                FaithAction(
                    icon: "megaphone.fill",
                    headline: "Tell someone what God has already done",
                    detail: "Say it out loud today. Testimony builds the room's faith and yours."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Pray for someone else's breakthrough",
                    detail: "Cover somebody today. God moves in both directions."
                )
            ]
        ),

        // MARK: People

        .marriage: FaithActionSet(
            premise: "God is in your marriage, and what He joined stands.",
            actions: [
                FaithAction(
                    icon: "heart.text.square.fill",
                    headline: "Tell your spouse one thing you admire in them",
                    detail: "Say it out loud today. Marriages grow where the words go."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Pray together for two minutes tonight",
                    detail: "Two minutes, holding hands. This is the strongest thing you will do today."
                ),
                FaithAction(
                    icon: "fork.knife",
                    headline: "Plan time with just the two of you",
                    detail: "Put it on the calendar today. Attention is how love stays alive."
                )
            ]
        ),

        .relationship: FaithActionSet(
            premise: "God leads you in this, and His way is good.",
            actions: [
                FaithAction(
                    icon: "bubble.left.and.bubble.right.fill",
                    headline: "Have the honest conversation today",
                    detail: "Say the true thing kindly. Good things are built on plain words."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Pray for them by name today",
                    detail: "Ask God for their good, not just yours."
                ),
                FaithAction(
                    icon: "checklist",
                    headline: "Write down the standard you are holding",
                    detail: "Name it today. Clarity now saves you a year later."
                )
            ]
        ),

        .love: FaithActionSet(
            premise: "God's love for you is settled. Live full, not waiting.",
            actions: [
                FaithAction(
                    icon: "figure.2",
                    headline: "Go be around people today",
                    detail: "Show up somewhere. A full life is the best possible ground."
                ),
                FaithAction(
                    icon: "heart.fill",
                    headline: "Love one person well today without being asked",
                    detail: "Do the quiet thing for somebody. This is who you already are."
                ),
                FaithAction(
                    icon: "sparkles",
                    headline: "Build something you would want to share",
                    detail: "Work on your own life today. God is not waiting on someone else to start."
                )
            ]
        ),

        .parenting: FaithActionSet(
            premise: "Your children are taught by the Lord, and great is their peace.",
            actions: [
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Lay a hand on your child and bless them",
                    detail: "By name, today. They will remember your voice saying it."
                ),
                FaithAction(
                    icon: "gamecontroller.fill",
                    headline: "Give fifteen minutes of undivided attention",
                    detail: "Phone down, their game, their terms. Presence is the whole gift."
                ),
                FaithAction(
                    icon: "ear.fill",
                    headline: "Ask one real question and just listen",
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
                    detail: "Speak it over them today. Your voice carries God's."
                ),
                FaithAction(
                    icon: "person.2.fill",
                    headline: "Accept or ask for one piece of help",
                    detail: "Ask today. Receiving is not weakness, it is how God sends things."
                ),
                FaithAction(
                    icon: "cup.and.saucer.fill",
                    headline: "Take thirty minutes that belong only to you",
                    detail: "You are worth tending too. Take it without apologizing."
                )
            ]
        ),

        .friendship: FaithActionSet(
            premise: "God sets you in a family. You belong to people.",
            actions: [
                FaithAction(
                    icon: "message.fill",
                    headline: "Text one person you have been meaning to text",
                    detail: "Send it today. Friendship is built out of small contact."
                ),
                FaithAction(
                    icon: "calendar.badge.plus",
                    headline: "Put a real plan on the calendar",
                    detail: "Pick a day today. Community happens on purpose."
                ),
                FaithAction(
                    icon: "building.2.fill",
                    headline: "Show up somewhere in person this week",
                    detail: "Church, group, gym, table. Go where the people are."
                )
            ]
        ),

        .divorce: FaithActionSet(
            premise: "God restores your life, and your future is His to build.",
            actions: [
                FaithAction(
                    icon: "sparkles",
                    headline: "Do one thing that makes your space yours",
                    detail: "Move it, paint it, clear it. Build the life in front of you."
                ),
                FaithAction(
                    icon: "person.2.fill",
                    headline: "Reach out to one person who is for you",
                    detail: "Call them today. Restoration comes with company."
                ),
                FaithAction(
                    icon: "figure.walk",
                    headline: "Take a walk and pray the whole way",
                    detail: "Twenty minutes with God. He has good ahead of you."
                )
            ]
        ),

        .fertility: FaithActionSet(
            premise: "God makes the barren woman a joyful mother of children.",
            actions: [
                FaithAction(
                    icon: "gift.fill",
                    headline: "Buy or set aside one small thing for the child",
                    detail: "One item today. Prepare like the promise is coming, because it is."
                ),
                FaithAction(
                    icon: "heart.fill",
                    headline: "Treat your body like the promise is coming",
                    detail: "Eat well, walk, rest. Steward the promise now."
                ),
                FaithAction(
                    icon: "square.and.pencil",
                    headline: "Write the child a letter",
                    detail: "Write to them today. Faith puts things in writing."
                )
            ]
        ),

        .salvation: FaithActionSet(
            premise: "God pursues them harder than you do, and He is faithful.",
            actions: [
                FaithAction(
                    icon: "message.fill",
                    headline: "Send them a text with no agenda in it",
                    detail: "Just love today. Nothing to convince, nothing to fix."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Pray for them by name and then release it",
                    detail: "Hand them back to God today. He is the one who draws hearts."
                ),
                FaithAction(
                    icon: "fork.knife",
                    headline: "Invite them to something ordinary",
                    detail: "A meal, a walk, a game. Presence preaches."
                )
            ]
        ),

        // MARK: Walking with God

        .faith: FaithActionSet(
            premise: "God is already at work. Move like you believe it.",
            actions: [
                FaithAction(
                    icon: "figure.walk",
                    headline: "Take one step toward what you are believing for",
                    detail: "The smallest real step, today. Faith moves before it sees."
                ),
                FaithAction(
                    icon: "megaphone.fill",
                    headline: "Tell one person what God is doing in you",
                    detail: "Say it out loud today. Faith grows in your own ears."
                ),
                FaithAction(
                    icon: "hand.raised.fill",
                    headline: "Obey the one thing you already know to do",
                    detail: "You have been thinking about it all week. Do it today."
                )
            ]
        ),

        .spiritualGrowth: FaithActionSet(
            premise: "You are growing in Him. Feed what is growing.",
            actions: [
                FaithAction(
                    icon: "book.fill",
                    headline: "Read one chapter today",
                    detail: "Ten minutes in the Word. Roots go down where they are watered."
                ),
                FaithAction(
                    icon: "clock.fill",
                    headline: "Give God the first fifteen minutes tomorrow",
                    detail: "Set the alarm tonight. First is a decision you make the day before."
                ),
                FaithAction(
                    icon: "person.2.fill",
                    headline: "Bring one person along with you",
                    detail: "Share what you are learning today. Teaching is how it sinks in."
                )
            ]
        ),

        .obedience: FaithActionSet(
            premise: "His way is best, and you trust Him with it.",
            actions: [
                FaithAction(
                    icon: "checkmark.seal.fill",
                    headline: "Do the thing you have been delaying",
                    detail: "You already know what it is. Today is the day."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Hand Him the decision out loud",
                    detail: "Say it plainly today. Surrender is spoken before it is felt."
                ),
                FaithAction(
                    icon: "arrow.uturn.backward",
                    headline: "Make one thing right today",
                    detail: "The apology, the repayment, the correction. Go do it."
                )
            ]
        ),

        .gratitude: FaithActionSet(
            premise: "God has been good to you, and you can name it.",
            actions: [
                FaithAction(
                    icon: "square.and.pencil",
                    headline: "Write down five things from this week",
                    detail: "Five specific ones today. Gratitude gets strong when it gets detailed."
                ),
                FaithAction(
                    icon: "message.fill",
                    headline: "Thank one person who will not expect it",
                    detail: "Send it today. Say exactly what they did."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Thank God out loud before you ask for anything",
                    detail: "Start there today. Name what He has already done."
                )
            ]
        ),

        .praise: FaithActionSet(
            premise: "He is worthy, and praise belongs in your mouth today.",
            actions: [
                FaithAction(
                    icon: "music.note",
                    headline: "Sing one song out loud today",
                    detail: "Car, shower, kitchen. Full voice."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Praise Him before the answer comes",
                    detail: "Thank Him now for the thing not yet seen. That is faith singing."
                ),
                FaithAction(
                    icon: "megaphone.fill",
                    headline: "Tell someone one thing God has done",
                    detail: "Say it today. Praise gets loud when it is shared."
                )
            ]
        ),

        .godsheart: FaithActionSet(
            premise: "God delights in you. Spend time with the One who does.",
            actions: [
                FaithAction(
                    icon: "clock.fill",
                    headline: "Sit with God for ten quiet minutes",
                    detail: "No asking, no list. Just be with Him today."
                ),
                FaithAction(
                    icon: "heart.fill",
                    headline: "Love one person the way He loves you",
                    detail: "Do the undeserved kind thing today."
                ),
                FaithAction(
                    icon: "book.closed.fill",
                    headline: "Read one passage about His love and sit in it",
                    detail: "Read it slowly today. Let it land before you move on."
                )
            ]
        ),

        .heaven: FaithActionSet(
            premise: "Your citizenship is in heaven. Live today from up there.",
            actions: [
                FaithAction(
                    icon: "arrow.up.heart.fill",
                    headline: "Do one thing today that only matters forever",
                    detail: "Give it, pray it, say it. Invest where nothing rusts."
                ),
                FaithAction(
                    icon: "hand.raised.fill",
                    headline: "Let go of one thing that will not last",
                    detail: "Release the grudge, the worry, the item. It is not going with you."
                ),
                FaithAction(
                    icon: "person.2.fill",
                    headline: "Point one person toward Jesus today",
                    detail: "A word, a prayer, an invitation. People last forever."
                )
            ]
        ),

        .speaklife: FaithActionSet(
            premise: "Your words carry life. Spend them well today.",
            actions: [
                FaithAction(
                    icon: "megaphone.fill",
                    headline: "Speak life over one person out loud",
                    detail: "Tell them today what you see in them. Say it to their face."
                ),
                FaithAction(
                    icon: "text.bubble.fill",
                    headline: "Say your declaration over your day out loud",
                    detail: "Before you walk out. Set the tone with your own mouth."
                ),
                FaithAction(
                    icon: "message.fill",
                    headline: "Send one person the line you needed",
                    detail: "Pass it on today. Life multiplies when it is spoken."
                )
            ]
        ),

        .blood: FaithActionSet(
            premise: "The blood of Jesus covers you. Live like a covered person.",
            actions: [
                FaithAction(
                    icon: "shield.lefthalf.filled",
                    headline: "Speak His covering over your household out loud",
                    detail: "Name each person today. Say what the blood has already bought."
                ),
                FaithAction(
                    icon: "figure.arms.open",
                    headline: "Come to God with your head up today",
                    detail: "No pleading for entry. The price is paid and the door is open."
                ),
                FaithAction(
                    icon: "hand.raised.fill",
                    headline: "Let go of one thing already paid for",
                    detail: "Stop carrying it today. It was settled at the cross."
                )
            ]
        ),

        .nameOfJesus: FaithActionSet(
            premise: "You carry the name above every name. Use it today.",
            actions: [
                FaithAction(
                    icon: "megaphone.fill",
                    headline: "Pray out loud in His name over one situation",
                    detail: "Say it plainly today. The name is not decoration, it is authority."
                ),
                FaithAction(
                    icon: "hands.and.sparkles.fill",
                    headline: "Pray for someone in front of you today",
                    detail: "Ask if you can, then do it right there."
                ),
                FaithAction(
                    icon: "text.bubble.fill",
                    headline: "Say His name over your day before it starts",
                    detail: "Out loud, once. Everything bows to it."
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
final class FaithActionCommitmentStore: ObservableObject {

    static let shared = FaithActionCommitmentStore()

    struct Commitment: Codable, Equatable {
        /// `DeclarationCategory` rawValue.
        let theme: String
        let headline: String
        let committedAt: Date
    }

    /// Nil unless the user committed to an action today.
    @Published private(set) var todaysCommitment: Commitment?

    private let defaults: UserDefaults
    private let calendar = Calendar.current
    private static let storageKey = "sl_faithActionCommitment_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        todaysCommitment = Self.loadIfToday(from: defaults, calendar: calendar)
    }

    func commit(to action: FaithAction, theme: DeclarationCategory, on date: Date = Date()) {
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
    func hasCommittedToday(on date: Date = Date()) -> Bool {
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
