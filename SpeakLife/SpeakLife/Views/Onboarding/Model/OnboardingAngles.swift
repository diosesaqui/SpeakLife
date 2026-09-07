//
//  OnboardingAngles.swift
//  SpeakLife
//
//  Every onboarding angle's copy, in one place. See `OnboardingAngle` for the
//  model and `AngleOnboardingView` for the driver that renders it.
//
//  BROAD ARMS (promises / warfare / outcomes) argue the mechanism from a
//  different emotional entry point and then let the user name their own area:
//  promises leads with a settled fact, warfare with the fight for what is
//  already yours, outcomes with the won life. Their picker lists one row per
//  HeaviestBurden. All three are ports of the hand-written views that preceded
//  this file, copy and step order preserved exactly so the live A/B funnels
//  still join.
//
//  SINGLE-ISSUE ARMS (healing / provision / anxiety / renewal / purpose / joy /
//  more) exist to be deep
//  linked from an angle-matched ad: `?ob=healing` on the install link and the
//  whole arc, picker included, is about healing. Their picker rows all resolve
//  to the SAME burden, so the feed, pushes and named plan stay on the angle the
//  ad promised, and they separate themselves with `segmentLabel` so ad-level
//  intent still reaches `onboardingSegment` and the completion event.
//
//  Adding an angle: add a constant here, a case to
//  `SubscriptionStore.OnboardingVariant`, a line to `HomeView.onboardingFlow`,
//  and its code to `DebugFlagPanel.onboardingVariants`.
//

import Foundation

enum OnboardingAngles {

    /// Every angle, keyed by `id` (which is also the `?ob=` deep-link code).
    static let all: [String: OnboardingAngle] = Dictionary(
        uniqueKeysWithValues: [promises, warfare, outcomes,
                               healing, provision, anxiety, renewal, purpose, joy, more]
            .map { ($0.id, $0) }
    )

    static func angle(id: String) -> OnboardingAngle? { all[id] }

    // MARK: - Promises (ported)

    // A trust-and-activation arm. Where outcomes leads with the WIN and warfare
    // with the FIGHT, this leads with a settled fact and a single question:
    // God's promises always work, and the only variable is whether you'll trust
    // them and put them to work over your own life.
    static let promises = OnboardingAngle(
        id: "promises",
        flow: "promises",
        // 3 = storm opener prepended as step 0 (2 = testimonial wall inserted
        // before paywall, 1 = original promises arc). Bump when the step order changes.
        flowSchema: 3,
        opensWithStormScreen: true,
        scenes: [
            AngleScene(
                symbol: "checkmark.seal.fill",
                // Screen one is the storm opener; this is the thesis, not the doorway.
                eyebrow: "WHAT YOU'RE STANDING ON",
                title: "God's promises have\nnever failed. Not once.",
                body: "Every word He spoke has come to pass. Not one has fallen to the ground. The promises were settled long before you ever needed them.",
                verse: "Not one word has failed of all the good promises he gave.",
                reference: "1 Kings 8:56",
                analyticsEvent: "promise_scene_shown",
                analyticsParameters: ["scene": "proven"]
            ),
            AngleScene(
                symbol: "questionmark.circle.fill",
                eyebrow: "THE REAL QUESTION",
                title: "It was never\nif they work.",
                body: "They always work. The only question left is whether you'll trust them, and put them to work, over your own life.",
                verse: "For no matter how many promises God has made, they are 'Yes' in Christ.",
                reference: "2 Corinthians 1:20",
                analyticsEvent: "promise_scene_shown",
                analyticsParameters: ["scene": "question"]
            ),
            AngleScene(
                symbol: "person.fill.checkmark",
                eyebrow: "THE PART MOST PEOPLE MISS",
                title: "Every promise\nhas your name on it.",
                body: "It's easy to believe God comes through for someone else. Everything changes the moment you believe He meant them for you, over your body, your home, your future.",
                verse: "He has given us his very great and precious promises.",
                reference: "2 Peter 1:4",
                analyticsEvent: "promise_scene_shown",
                analyticsParameters: ["scene": "yours"]
            ),
            AngleScene(
                symbol: "waveform",
                eyebrow: "HOW A PROMISE GOES TO WORK",
                // The opener already taught "speak it, don't beg for it." This screen
                // moves the idea forward to the daily rhythm instead of restating it.
                title: "You speak it until\nit settles in you.",
                body: "One promise, out loud, over your own life, every day. Not to convince God. To settle it in you, until your heart catches up to what's already yours.",
                verse: "The tongue has the power of life and death.",
                reference: "Proverbs 18:21",
                analyticsEvent: "promise_scene_shown",
                analyticsParameters: ["scene": "activate"]
            ),
            AngleScene(
                symbol: "sparkles",
                eyebrow: "OVER EVERY AREA",
                title: "Nothing is left\noutside the promise.",
                body: "Your peace. Your health. Your family. Your provision. There's no corner of your life His Word doesn't reach. You activate it one area at a time.",
                verse: "His divine power has given us everything we need for a godly life.",
                reference: "2 Peter 1:3",
                buttonLabel: "I'm Ready to Trust Them →",
                analyticsEvent: "promise_scene_shown",
                analyticsParameters: ["scene": "every_area"]
            ),
        ],
        picker: AnglePicker(
            headline: "Which promise will you\nactivate first?",
            subtitle: "We'll build your daily declarations around it\nand put it to work over your life.",
            analyticsEvent: "promise_picker_shown",
            // Ordered by the priority the broad arms share.
            choices: [
                AnglePickerChoice(id: "health", burden: .health,
                                  statement: "Healing over my body",
                                  subtitle: "His promise of wholeness, activated",
                                  symbol: "heart.fill"),
                AnglePickerChoice(id: "abundance", burden: .abundance,
                                  statement: "Provision over my finances",
                                  subtitle: "His promise to supply every need",
                                  symbol: "key.fill"),
                AnglePickerChoice(id: "peace", burden: .peace,
                                  statement: "Peace over my home",
                                  subtitle: "His promise of rest, settling in",
                                  symbol: "house.fill"),
                AnglePickerChoice(id: "more", burden: .allOfIt,
                                  statement: "Victory over what's against me",
                                  subtitle: "His promise that no weapon prospers",
                                  symbol: "bolt.fill"),
                AnglePickerChoice(id: "identity", burden: .identity,
                                  statement: "Knowing who I am in Christ",
                                  subtitle: "His promise that I am His, secured",
                                  symbol: "crown.fill"),
                AnglePickerChoice(id: "purpose", burden: .purpose,
                                  statement: "Purpose over my future",
                                  subtitle: "His promise to finish what He started",
                                  symbol: "flag.fill"),
                AnglePickerChoice(id: "joy", burden: .joy,
                                  statement: "Joy that holds",
                                  subtitle: "His promise of unshakeable gladness",
                                  symbol: "sun.max.fill"),
            ]
        )
    )

    // MARK: - Warfare (ported)

    // Built on the core SpeakLife angle: you are fighting for what is ALREADY
    // yours. Fear-of-loss up front (the thief), then the burden-matched victory
    // vision after the picker so the arc carries the dream as well as the fight.
    static let warfare = OnboardingAngle(
        id: "warfare",
        flow: "warfare",
        // 4 = testimonial wall inserted before paywall (3 = victory-vision inserted
        // after the picker, 2 = pre-victory-vision, 1 = pre-renumbering).
        flowSchema: 4,
        iconStyle: .ember,
        scenes: [
            AngleScene(
                symbol: "exclamationmark.shield.fill",
                eyebrow: "THERE'S A FIGHT OVER YOUR LIFE",
                title: "The thief came\nto take it all.",
                body: "Your health. Your provision. Your peace. The enemy comes only to steal, kill, and destroy. Every attack is aimed at something that was meant to be yours.",
                verse: "The thief comes only to steal and kill and destroy; I have come that they may have life, and have it to the full.",
                reference: "John 10:10",
                analyticsEvent: "warfare_scene_shown",
                analyticsParameters: ["scene": "thief"]
            ),
            AngleScene(
                symbol: "checkmark.seal.fill",
                eyebrow: "BUT IT'S ALREADY YOURS",
                title: "Already bought.\nAlready paid for.",
                body: "Healing, provision, peace, freedom. Jesus already purchased every one of them at the cross. You're not begging God for what He's already given. You're an heir defending an inheritance.",
                verse: "He who did not spare his own Son, but gave him up for us all, how will he not also, along with him, graciously give us all things?",
                reference: "Romans 8:32",
                analyticsEvent: "warfare_scene_shown",
                analyticsParameters: ["scene": "paid_for"]
            ),
            AngleScene(
                symbol: "bolt.fill",
                eyebrow: "THIS IS HOW YOU FIGHT BACK",
                title: "You take it back\nby speaking.",
                body: "Death and life are in the power of your tongue. You stand your ground and refuse to let the enemy keep what was bought for you. Every word you speak in faith drives him back.",
                verse: "Death and life are in the power of the tongue, and those who love it will eat its fruit.",
                reference: "Proverbs 18:21",
                analyticsEvent: "warfare_scene_shown",
                analyticsParameters: ["scene": "weapon"]
            ),
            AngleScene(
                symbol: "arrow.down.circle.fill",
                eyebrow: "ACTIVATE WHAT'S ALREADY YOURS",
                title: "Pull heaven down\ninto your life.",
                body: "In Christ you already have it in the spirit. Speaking is what activates it here, in your body, your home, your finances. You call what's already true in heaven down into your everyday life.",
                verse: "Your kingdom come, your will be done, on earth as it is in heaven.",
                reference: "Matthew 6:10",
                buttonLabel: "I'm Ready to Fight →",
                analyticsEvent: "warfare_scene_shown",
                analyticsParameters: ["scene": "activation"]
            ),
        ],
        picker: AnglePicker(
            headline: "What is the enemy trying\nto steal from you right now?",
            subtitle: "We'll arm you with daily declarations\nto take it back and stand your ground.",
            analyticsEvent: "warfare_picker_shown",
            choices: [
                AnglePickerChoice(id: "health", burden: .health,
                                  statement: "My health and strength",
                                  subtitle: "Take back the healing already paid for",
                                  symbol: "heart.fill"),
                AnglePickerChoice(id: "abundance", burden: .abundance,
                                  statement: "My provision",
                                  subtitle: "Take back open doors and overflow",
                                  symbol: "key.fill"),
                AnglePickerChoice(id: "peace", burden: .peace,
                                  statement: "My peace and my home",
                                  subtitle: "Take back calm where there's chaos",
                                  symbol: "house.fill"),
                AnglePickerChoice(id: "more", burden: .allOfIt,
                                  statement: "Victory over the attack",
                                  subtitle: "Stand in authority, the enemy flees",
                                  symbol: "bolt.fill"),
                AnglePickerChoice(id: "identity", burden: .identity,
                                  statement: "Who I am in Christ",
                                  subtitle: "Take back my secure identity",
                                  symbol: "crown.fill"),
                AnglePickerChoice(id: "purpose", burden: .purpose,
                                  statement: "My calling and destiny",
                                  subtitle: "Take back the future God promised",
                                  symbol: "flag.fill"),
                AnglePickerChoice(id: "joy", burden: .joy,
                                  statement: "My joy",
                                  subtitle: "Take back joy nothing can steal",
                                  symbol: "sun.max.fill"),
            ]
        ),
        // The warfare arc nails the fear-of-loss trigger but stops short of
        // painting the won life. This flips the chosen burden forward: once you
        // take it back, THIS is what you're standing in.
        burdenScene: AngleBurdenScene(
            eyebrow: "WHAT TAKING IT BACK LOOKS LIKE",
            buttonLabel: "This Is What I'm Fighting For →",
            analyticsEvent: "warfare_victory_vision_shown",
            // `.peace` lives in defaultContent, not the dictionary: it is what an
            // unlisted burden falls back to, and duplicating it in both would let
            // the two copies drift apart.
            defaultContent: .init(
                symbol: "house.fill",
                title: "Your home,\nat peace again.",
                body: "The tension breaks. The arguments quiet. Your home becomes the calm place, anchored, where anxiety used to live.",
                verse: "You will keep in perfect peace those whose minds are steadfast, because they trust in you.",
                reference: "Isaiah 26:3"),
            content: [
                .health: .init(
                    symbol: "heart.fill",
                    title: "Your body,\ntaken back.",
                    body: "The diagnosis loses its grip. Strength returns. You wake up in a body that lines up with the healing Jesus already paid for.",
                    verse: "By his wounds you have been healed.",
                    reference: "1 Peter 2:24"),
                .abundance: .init(
                    symbol: "key.fill",
                    title: "Your provision,\nrecovered.",
                    body: "The right call. The unexpected open door. Provision arriving ahead of the need. You live from overflow, not lack.",
                    verse: "And my God will meet all your needs according to the riches of his glory in Christ Jesus.",
                    reference: "Philippians 4:19"),
                .allOfIt: .init(
                    symbol: "bolt.fill",
                    title: "The attack,\nbroken.",
                    body: "You stand your ground and the enemy flees. You stop fighting for the victory and start living from it. The ground he took is yours again.",
                    verse: "In all these things we are more than conquerors through him who loved us.",
                    reference: "Romans 8:37"),
                .identity: .init(
                    symbol: "crown.fill",
                    title: "You, standing in\nwho you really are.",
                    body: "The lies fall silent. The labels lose their hold. You live secure, chosen, and redeemed, the new creation God already made you.",
                    verse: "If anyone is in Christ, the new creation has come: The old has gone, the new is here.",
                    reference: "2 Corinthians 5:17"),
                .purpose: .init(
                    symbol: "flag.fill",
                    title: "Your calling,\nreclaimed.",
                    body: "The distractions lose their pull. You step back onto the path God set for you and walk in the future He promised, on purpose.",
                    verse: "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you.",
                    reference: "Jeremiah 29:11"),
                .joy: .init(
                    symbol: "sun.max.fill",
                    title: "Your joy,\nback for good.",
                    body: "The heaviness lifts. Joy returns and roots down deep, the kind nothing and no one can steal from you again.",
                    verse: "The joy of the Lord is your strength.",
                    reference: "Nehemiah 8:10"),
            ]
        )
    )

    // MARK: - Outcomes (ported)

    // Leads with the WIN: each screen demonstrates the best-case life speaking
    // God's Word produces. The stakes screen up front gives the dream-first arm
    // its fear-of-loss beat, so it fires both triggers.
    static let outcomes = OnboardingAngle(
        id: "outcomes",
        flow: "outcomes",
        // 4 = storm opener prepended as step 0 (3 = testimonial wall inserted before
        // paywall, 2 = matched-to-warfare layout, 1 = original short outcomes flow).
        flowSchema: 4,
        opensWithStormScreen: true,
        scenes: [
            // The outcome visions deliver the dream; this cold open gives the flow
            // its fear-of-loss beat first (a someday you keep postponing is a cost,
            // not a neutral) before it pivots to the life that's available.
            AngleScene(
                symbol: "hourglass",
                eyebrow: "BEFORE WE SHOW YOU WHAT'S POSSIBLE",
                title: "How much longer\nwill you wait?",
                body: "The healing. The open doors. The peace at home. They were never meant to be someday promises. Every day you settle for less is a day the enemy keeps what was already bought for you.",
                verse: "The thief comes only to steal and kill and destroy; I have come that they may have life, and have it to the full.",
                reference: "John 10:10",
                buttonLabel: "Show Me What's Possible →",
                analyticsEvent: "outcome_stakes_shown"
            ),
            AngleScene(
                symbol: "heart.fill",
                eyebrow: "WHAT HAPPENS WHEN YOU SPEAK",
                title: "Your body,\nrestored.",
                body: "The diagnosis loses its grip. Strength comes back. You wake up in a body that lines up with the healing Jesus already paid for.",
                verse: "By his wounds you have been healed.",
                reference: "1 Peter 2:24",
                analyticsEvent: "outcome_vision_shown",
                analyticsParameters: ["outcome": "health"]
            ),
            AngleScene(
                symbol: "key.fill",
                eyebrow: "WHAT HAPPENS WHEN YOU SPEAK",
                title: "Doors you couldn't open,\nopening.",
                body: "The right call. The unexpected offer. Provision arriving ahead of the need. You walk in opportunity, not lack.",
                verse: "And my God will meet all your needs according to the riches of his glory in Christ Jesus.",
                reference: "Philippians 4:19",
                analyticsEvent: "outcome_vision_shown",
                analyticsParameters: ["outcome": "provision"]
            ),
            AngleScene(
                symbol: "house.fill",
                eyebrow: "WHAT HAPPENS WHEN YOU SPEAK",
                title: "Peace settling\nover your home.",
                body: "The tension breaks. The arguments quiet. Your home becomes the calm place, anchored, where anxiety used to live.",
                verse: "You will keep in perfect peace those whose minds are steadfast, because they trust in you.",
                reference: "Isaiah 26:3",
                analyticsEvent: "outcome_vision_shown",
                analyticsParameters: ["outcome": "peace"]
            ),
            AngleScene(
                symbol: "crown.fill",
                eyebrow: "WHAT HAPPENS WHEN YOU SPEAK",
                title: "Standing in who\nyou really are.",
                body: "The lies fall silent. The enemy flees at your voice. You stop fighting for victory and start living from it, as the redeemed child of God you already are.",
                verse: "In all these things we are more than conquerors through him who loved us.",
                reference: "Romans 8:37",
                buttonLabel: "This Is the Life I Want →",
                analyticsEvent: "outcome_vision_shown",
                analyticsParameters: ["outcome": "identity"]
            ),
        ],
        picker: AnglePicker(
            headline: "Which breakthrough do you\nmost need to see first?",
            subtitle: "We'll build your daily declarations around it\nand start calling it into your life.",
            analyticsEvent: "outcome_picker_shown",
            choices: [
                AnglePickerChoice(id: "health", burden: .health,
                                  statement: "Healing in my body",
                                  subtitle: "Restored, whole, strong again",
                                  symbol: "heart.fill"),
                AnglePickerChoice(id: "abundance", burden: .abundance,
                                  statement: "Open doors and provision",
                                  subtitle: "Opportunity and overflow, not lack",
                                  symbol: "key.fill"),
                AnglePickerChoice(id: "peace", burden: .peace,
                                  statement: "Peace in my home",
                                  subtitle: "The storm stilled, relationships mended",
                                  symbol: "house.fill"),
                AnglePickerChoice(id: "more", burden: .allOfIt,
                                  statement: "Victory over what's against me",
                                  subtitle: "Standing in authority, the enemy flees",
                                  symbol: "bolt.fill"),
                AnglePickerChoice(id: "identity", burden: .identity,
                                  statement: "Knowing who I am in Christ",
                                  subtitle: "Secure, chosen, redeemed",
                                  symbol: "crown.fill"),
                AnglePickerChoice(id: "purpose", burden: .purpose,
                                  statement: "Walking in my calling",
                                  subtitle: "Stepping into what God made me for",
                                  symbol: "flag.fill"),
                AnglePickerChoice(id: "joy", burden: .joy,
                                  statement: "Joy that holds",
                                  subtitle: "Unshakeable, whatever comes",
                                  symbol: "sun.max.fill"),
            ]
        )
    )

    // MARK: - Healing (single-issue, deep link ?ob=healing)

    // For healing creative. Settles the two questions that stop people from
    // standing on healing at all: was it actually paid for, and is He willing.
    // Every picker row seeds `health`, so the feed and the named plan match the
    // ad that brought them in.
    static let healing = OnboardingAngle(
        id: "healing",
        flow: "healing",
        flowSchema: 1,
        opensWithStormScreen: true,
        scenes: [
            AngleScene(
                symbol: "checkmark.seal.fill",
                eyebrow: "IT WAS ALREADY PAID FOR",
                title: "Your healing was\nbought at the cross.",
                body: "The stripes on His back were not decoration. Healing was purchased the same hour forgiveness was, with the same blood, for you.",
                verse: "By his wounds we are healed.",
                reference: "Isaiah 53:5",
                analyticsEvent: "healing_scene_shown",
                analyticsParameters: ["scene": "paid"]
            ),
            AngleScene(
                symbol: "hand.raised.fill",
                eyebrow: "THE QUESTION HE ALREADY ANSWERED",
                title: "He is willing.\nHe said it out loud.",
                body: "A man knelt and said, if you are willing, you can make me clean. Jesus did not hesitate. He reached out, touched him, and said I am willing. That answer still stands over you.",
                verse: "Jesus reached out his hand and touched the man. 'I am willing,' he said. 'Be clean!'",
                reference: "Matthew 8:3",
                analyticsEvent: "healing_scene_shown",
                analyticsParameters: ["scene": "willing"]
            ),
            AngleScene(
                symbol: "waveform",
                eyebrow: "HOW HEALING TRAVELS",
                title: "He sent His word,\nand it healed them.",
                body: "God did not send a feeling or a formula. He sent His Word, and His Word is what did the healing. That same Word is what goes in your mouth every day.",
                verse: "He sent out his word and healed them; he rescued them from the grave.",
                reference: "Psalm 107:20",
                analyticsEvent: "healing_scene_shown",
                analyticsParameters: ["scene": "sent"]
            ),
            AngleScene(
                symbol: "heart.fill",
                eyebrow: "WHERE IT GOES TO WORK",
                title: "Speak it over the\nbody you have now.",
                body: "His words are life to those who find them and health to a person's whole body. You say them out loud over yourself daily, until what God said carries more weight than what you feel.",
                verse: "For they are life to those who find them and health to one's whole body.",
                reference: "Proverbs 4:22",
                analyticsEvent: "healing_scene_shown",
                analyticsParameters: ["scene": "daily"]
            ),
            AngleScene(
                symbol: "sun.max.fill",
                eyebrow: "ALL OF YOU, NOT PART",
                title: "Restored,\nand kept whole.",
                body: "Strength back in your body. Rest that actually restores. Mornings you meet standing up. God restores health, and He does it in every part of you.",
                verse: "I will restore you to health and heal your wounds, declares the Lord.",
                reference: "Jeremiah 30:17",
                buttonLabel: "I'm Standing on This →",
                analyticsEvent: "healing_scene_shown",
                analyticsParameters: ["scene": "whole"]
            ),
        ],
        picker: AnglePicker(
            headline: "What are you believing\nGod for right now?",
            subtitle: "We'll build your daily healing declarations\naround it and put His Word to work.",
            analyticsEvent: "healing_picker_shown",
            choices: [
                AnglePickerChoice(id: "own_body", burden: .health,
                                  statement: "My body, made whole",
                                  subtitle: "Full healing, in every part",
                                  symbol: "heart.fill", segmentLabel: "own_body"),
                AnglePickerChoice(id: "diagnosis", burden: .health,
                                  statement: "A report I was given",
                                  subtitle: "God's Word outranks the diagnosis",
                                  symbol: "doc.text.fill", segmentLabel: "diagnosis"),
                AnglePickerChoice(id: "pain", burden: .health,
                                  statement: "Relief that finally holds",
                                  subtitle: "Living in a body at rest",
                                  symbol: "leaf.fill", segmentLabel: "pain"),
                AnglePickerChoice(id: "strength", burden: .health,
                                  statement: "Strength and energy back",
                                  subtitle: "Rising with power for my day",
                                  symbol: "bolt.heart.fill", segmentLabel: "strength"),
                AnglePickerChoice(id: "sleep", burden: .health,
                                  statement: "Sleep that restores me",
                                  subtitle: "Nights that put me back together",
                                  symbol: "moon.stars.fill", segmentLabel: "sleep"),
                AnglePickerChoice(id: "loved_one", burden: .health,
                                  statement: "Someone I love",
                                  subtitle: "Standing in faith for their healing",
                                  symbol: "person.2.fill", segmentLabel: "loved_one"),
            ]
        )
    )

    // MARK: - Provision (single-issue, deep link ?ob=provision)

    // For provision creative. Moves the person off their paycheck as their
    // source and onto God as their source, then hands them the mechanism.
    // Every picker row seeds `abundance` → the `wealth` category.
    static let provision = OnboardingAngle(
        id: "provision",
        flow: "provision",
        flowSchema: 1,
        opensWithStormScreen: true,
        scenes: [
            AngleScene(
                symbol: "mountain.2.fill",
                eyebrow: "WHERE IT ACTUALLY COMES FROM",
                title: "Your paycheck is\nnot your source.",
                body: "A job is a channel. God is the source, and He is the one who gives you the ability to produce wealth. When a channel narrows, the source has not moved.",
                verse: "Remember the Lord your God, for it is he who gives you the ability to produce wealth.",
                reference: "Deuteronomy 8:18",
                analyticsEvent: "provision_scene_shown",
                analyticsParameters: ["scene": "source"]
            ),
            AngleScene(
                symbol: "checkmark.seal.fill",
                eyebrow: "THE SIZE OF THE PROMISE",
                title: "Every need.\nNot most of them.",
                body: "He does not meet your needs out of what is left over. He meets them out of the riches of His glory, and that account has never once run low.",
                verse: "And my God will meet all your needs according to the riches of his glory in Christ Jesus.",
                reference: "Philippians 4:19",
                analyticsEvent: "provision_scene_shown",
                analyticsParameters: ["scene": "supply"]
            ),
            AngleScene(
                symbol: "key.fill",
                eyebrow: "HE OPENS WHAT YOU CANNOT",
                title: "Doors you could\nnever open yourself.",
                body: "Favor goes ahead of you and opens what effort alone never could. The right call. The unexpected offer. Provision arriving before the due date.",
                verse: "See, I have placed before you an open door that no one can shut.",
                reference: "Revelation 3:8",
                analyticsEvent: "provision_scene_shown",
                analyticsParameters: ["scene": "open_door"]
            ),
            AngleScene(
                symbol: "waveform",
                eyebrow: "HOW IT COMES DOWN",
                title: "You decree it,\nand it stands.",
                body: "You are not hoping something shows up. You speak what God already said about your provision, out loud, over your own accounts, and heaven backs the word.",
                verse: "What you decide on will be done, and light will shine on your ways.",
                reference: "Job 22:28",
                analyticsEvent: "provision_scene_shown",
                analyticsParameters: ["scene": "decree"]
            ),
            AngleScene(
                symbol: "sparkles",
                eyebrow: "ENOUGH, AND THEN SOME",
                title: "Enough to live on.\nEnough to give from.",
                body: "God's aim was never bare survival. It is grace abounding to you, so you have all you need and plenty left over for every good work.",
                verse: "And God is able to bless you abundantly, so that in all things at all times, having all that you need, you will abound in every good work.",
                reference: "2 Corinthians 9:8",
                buttonLabel: "This Is What I'm Believing For →",
                analyticsEvent: "provision_scene_shown",
                analyticsParameters: ["scene": "overflow"]
            ),
        ],
        picker: AnglePicker(
            headline: "What are you believing\nGod to provide?",
            subtitle: "We'll build your daily provision declarations\naround it and put His Word to work.",
            analyticsEvent: "provision_picker_shown",
            choices: [
                AnglePickerChoice(id: "margin", burden: .abundance,
                                  statement: "Room at the end of the month",
                                  subtitle: "Every bill covered, and margin left",
                                  symbol: "calendar", segmentLabel: "margin"),
                AnglePickerChoice(id: "income", burden: .abundance,
                                  statement: "A job, a raise, a promotion",
                                  subtitle: "Doors opening ahead of me",
                                  symbol: "briefcase.fill", segmentLabel: "income"),
                AnglePickerChoice(id: "debt", burden: .abundance,
                                  statement: "Debt cleared for good",
                                  subtitle: "Free, with nothing owed over me",
                                  symbol: "scissors", segmentLabel: "debt"),
                AnglePickerChoice(id: "business", burden: .abundance,
                                  statement: "My business thriving",
                                  subtitle: "Increase on the work of my hands",
                                  symbol: "chart.line.uptrend.xyaxis", segmentLabel: "business"),
                AnglePickerChoice(id: "family", burden: .abundance,
                                  statement: "Provision for my family",
                                  subtitle: "Every need met in my home",
                                  symbol: "house.fill", segmentLabel: "family"),
                AnglePickerChoice(id: "overflow", burden: .abundance,
                                  statement: "Overflow, so I can give",
                                  subtitle: "More than enough, on purpose",
                                  symbol: "gift.fill", segmentLabel: "overflow"),
            ]
        )
    )

    // MARK: - Anxiety (single-issue, deep link ?ob=anxiety)

    // For anxiety and overwhelm creative. Per the SpeakLife rule of calling
    // higher, the copy declares the peace rather than dwelling on the anxiety:
    // scripture names it, the screens claim what displaces it. Every picker row
    // seeds `peace` → the `anxiety` category.
    static let anxiety = OnboardingAngle(
        id: "anxiety",
        flow: "anxiety",
        flowSchema: 1,
        opensWithStormScreen: true,
        scenes: [
            AngleScene(
                symbol: "leaf.fill",
                eyebrow: "ALREADY HANDED TO YOU",
                title: "Peace was left\nto you on purpose.",
                body: "Jesus never told you to manufacture peace. He said He was leaving His own with you. Already given. Already yours. Not the kind the world hands out and takes back.",
                verse: "Peace I leave with you; my peace I give you. I do not give to you as the world gives.",
                reference: "John 14:27",
                analyticsEvent: "anxiety_scene_shown",
                analyticsParameters: ["scene": "given"]
            ),
            AngleScene(
                symbol: "shield.fill",
                eyebrow: "IT STANDS GUARD",
                title: "A peace that\nguards your mind.",
                body: "God's peace is not a mood. It is a guard posted over your heart and your thoughts, and it holds the line in the middle of things you cannot explain.",
                verse: "And the peace of God, which transcends all understanding, will guard your hearts and your minds in Christ Jesus.",
                reference: "Philippians 4:7",
                analyticsEvent: "anxiety_scene_shown",
                analyticsParameters: ["scene": "guarded"]
            ),
            AngleScene(
                symbol: "arrow.up.circle.fill",
                eyebrow: "YOU WERE NEVER MEANT TO CARRY IT",
                title: "Hand it over.\nHe already has you.",
                body: "Everything you have been carrying alone has somewhere to go. You cast it on Him, out loud, because He cares for you that personally.",
                verse: "Cast all your anxiety on him because he cares for you.",
                reference: "1 Peter 5:7",
                analyticsEvent: "anxiety_scene_shown",
                analyticsParameters: ["scene": "carried"]
            ),
            AngleScene(
                symbol: "waveform",
                eyebrow: "HOW A MIND GETS STEADY",
                title: "Perfect peace follows\nwhat you fix on.",
                body: "A mind stayed on Him is kept in perfect peace. Speaking His Word out loud daily is how your mind gets stayed, and how peace stops being a good day and becomes your normal.",
                verse: "You will keep in perfect peace those whose minds are steadfast, because they trust in you.",
                reference: "Isaiah 26:3",
                analyticsEvent: "anxiety_scene_shown",
                analyticsParameters: ["scene": "stayed"]
            ),
            AngleScene(
                symbol: "moon.stars.fill",
                eyebrow: "WHAT YOUR DAYS LOOK LIKE",
                title: "Rest that reaches\nall the way down.",
                body: "Sleep that actually restores. Mornings that start settled. A home where calm is the baseline. This is the rest Jesus offers by name.",
                verse: "Come to me, all you who are weary and burdened, and I will give you rest.",
                reference: "Matthew 11:28",
                buttonLabel: "This Is the Peace I Want →",
                analyticsEvent: "anxiety_scene_shown",
                analyticsParameters: ["scene": "rest"]
            ),
        ],
        picker: AnglePicker(
            headline: "Where do you most\nneed His peace?",
            subtitle: "We'll build your daily peace declarations\naround it and put His Word to work.",
            analyticsEvent: "anxiety_picker_shown",
            choices: [
                AnglePickerChoice(id: "nights", burden: .peace,
                                  statement: "My nights and my sleep",
                                  subtitle: "Lying down and resting deeply",
                                  symbol: "moon.stars.fill", segmentLabel: "nights"),
                AnglePickerChoice(id: "mind", burden: .peace,
                                  statement: "My thoughts through the day",
                                  subtitle: "A mind that stays clear and settled",
                                  symbol: "brain.head.profile", segmentLabel: "mind"),
                AnglePickerChoice(id: "home", burden: .peace,
                                  statement: "My home and my family",
                                  subtitle: "Calm where the tension has been",
                                  symbol: "house.fill", segmentLabel: "home"),
                AnglePickerChoice(id: "work", burden: .peace,
                                  statement: "My work and my calendar",
                                  subtitle: "Steady under real pressure",
                                  symbol: "briefcase.fill", segmentLabel: "work"),
                AnglePickerChoice(id: "waiting", burden: .peace,
                                  statement: "Waiting on news or results",
                                  subtitle: "Peace that holds while I wait",
                                  symbol: "heart.text.square.fill", segmentLabel: "waiting"),
                AnglePickerChoice(id: "future", burden: .peace,
                                  statement: "What's ahead of me",
                                  subtitle: "Facing tomorrow settled and sure",
                                  symbol: "sunrise.fill", segmentLabel: "future"),
            ]
        )
    )

    // MARK: - Renewal of the mind (single-issue, deep link ?ob=renewal)

    // For renew-your-mind creative, the mechanism SpeakLife is built on. Every
    // picker row seeds `identity`: Romans 12:2 renewal is finally about replacing
    // what you believe about yourself, which is where the identity set lives.
    static let renewal = OnboardingAngle(
        id: "renewal",
        flow: "renewal",
        flowSchema: 1,
        opensWithStormScreen: true,
        scenes: [
            AngleScene(
                symbol: "arrow.triangle.2.circlepath",
                eyebrow: "WHERE CHANGE ACTUALLY HAPPENS",
                title: "Your life follows\nyour mind.",
                body: "God does not change you by rearranging your circumstances. He transforms you by renewing your mind, and everything downstream of that starts to move.",
                verse: "Do not conform to the pattern of this world, but be transformed by the renewing of your mind.",
                reference: "Romans 12:2",
                analyticsEvent: "renewal_scene_shown",
                analyticsParameters: ["scene": "transformed"]
            ),
            AngleScene(
                symbol: "lock.open.fill",
                eyebrow: "YOU HAVE AUTHORITY HERE",
                title: "Every thought\nanswers to you.",
                body: "You are not at the mercy of whatever runs through your head. You take each thought captive and make it obey Christ. You decide what stays.",
                verse: "We take captive every thought to make it obedient to Christ.",
                reference: "2 Corinthians 10:5",
                analyticsEvent: "renewal_scene_shown",
                analyticsParameters: ["scene": "captive"]
            ),
            AngleScene(
                symbol: "brain.head.profile",
                eyebrow: "WHAT YOU ALREADY CARRY",
                title: "You have the\nmind of Christ.",
                body: "Not one day. Now. Clear, sound, and at rest is not something you are working toward. It is what you already have in Him, waiting for you to agree with it.",
                verse: "But we have the mind of Christ.",
                reference: "1 Corinthians 2:16",
                analyticsEvent: "renewal_scene_shown",
                analyticsParameters: ["scene": "mind_of_christ"]
            ),
            AngleScene(
                symbol: "waveform",
                eyebrow: "HOW A MIND GETS RENEWED",
                title: "It renews by\nwhat you say.",
                body: "Your mind believes what it hears you say most. Speaking God's Word out loud daily is how the old pattern gets replaced, one honest sentence at a time.",
                verse: "Keep this Book of the Law always on your lips; meditate on it day and night.",
                reference: "Joshua 1:8",
                analyticsEvent: "renewal_scene_shown",
                analyticsParameters: ["scene": "mechanism"]
            ),
            AngleScene(
                symbol: "person.fill.checkmark",
                eyebrow: "WHO YOU PUT ON",
                title: "Made new in the\nattitude of your mind.",
                body: "You put on the new self, created to be like God. The way you see yourself catches up to the way He has always seen you, and it holds.",
                verse: "To be made new in the attitude of your minds; and to put on the new self, created to be like God.",
                reference: "Ephesians 4:23-24",
                buttonLabel: "I'm Ready to Renew My Mind →",
                analyticsEvent: "renewal_scene_shown",
                analyticsParameters: ["scene": "new_self"]
            ),
        ],
        picker: AnglePicker(
            headline: "Where does your mind\nmost need renewing?",
            subtitle: "We'll build your daily declarations around it\nand rebuild what you believe with His Word.",
            analyticsEvent: "renewal_picker_shown",
            choices: [
                AnglePickerChoice(id: "self_image", burden: .identity,
                                  statement: "How I see myself",
                                  subtitle: "Seeing what God sees when He looks at me",
                                  symbol: "person.fill.checkmark", segmentLabel: "self_image"),
                AnglePickerChoice(id: "gods_view", burden: .identity,
                                  statement: "What I believe God thinks of me",
                                  subtitle: "Secure, chosen, fully loved",
                                  symbol: "crown.fill", segmentLabel: "gods_view"),
                AnglePickerChoice(id: "self_talk", burden: .identity,
                                  statement: "What I say about myself",
                                  subtitle: "Words that build instead of tear down",
                                  symbol: "waveform", segmentLabel: "self_talk"),
                AnglePickerChoice(id: "old_story", burden: .identity,
                                  statement: "An old story I keep replaying",
                                  subtitle: "New creation, and the old is gone",
                                  symbol: "arrow.triangle.2.circlepath", segmentLabel: "old_story"),
                AnglePickerChoice(id: "future_view", burden: .identity,
                                  statement: "How I think about my future",
                                  subtitle: "Expecting good, on His authority",
                                  symbol: "sunrise.fill", segmentLabel: "future_view"),
                AnglePickerChoice(id: "focus", burden: .identity,
                                  statement: "Where my mind goes all day",
                                  subtitle: "Thoughts that stay on what is true",
                                  symbol: "brain.head.profile", segmentLabel: "focus"),
            ]
        )
    )

    // MARK: - Purpose (single-issue, deep link ?ob=purpose)

    // For calling and direction creative. The person is not in crisis, they are
    // off-course: years in, unsure what they were made for. Settles that the
    // calling was assigned before they arrived, then hands them the mechanism.
    // Every picker row seeds `purpose` → the `destiny` category.
    static let purpose = OnboardingAngle(
        id: "purpose",
        flow: "purpose",
        flowSchema: 1,
        opensWithStormScreen: true,
        scenes: [
            AngleScene(
                symbol: "book.closed.fill",
                eyebrow: "SETTLED BEFORE YOU GOT HERE",
                title: "Your days were written\nbefore you lived one.",
                body: "You are not a late start or a leftover. Every day of your life was written in His book before one of them came to be, and He has never lost the page.",
                verse: "All the days ordained for me were written in your book before one of them came to be.",
                reference: "Psalm 139:16",
                analyticsEvent: "purpose_scene_shown",
                analyticsParameters: ["scene": "written"]
            ),
            AngleScene(
                symbol: "flag.fill",
                eyebrow: "WHY YOU WERE CALLED",
                title: "He called you\non purpose.",
                body: "The calling on your life did not depend on your resume, your record, or how the last few years went. He called you because of His own purpose and grace.",
                verse: "He has saved us and called us to a holy life, not because of anything we have done but because of his own purpose and grace.",
                reference: "2 Timothy 1:9",
                analyticsEvent: "purpose_scene_shown",
                analyticsParameters: ["scene": "called"]
            ),
            AngleScene(
                symbol: "hammer.fill",
                eyebrow: "HE DOES NOT LEAVE IT HALF BUILT",
                title: "He finishes\nwhat He starts.",
                body: "What God began in you is not stalled and it is not abandoned. He carries it on to completion, and He is the one responsible for the finish.",
                verse: "He who began a good work in you will carry it on to completion until the day of Christ Jesus.",
                reference: "Philippians 1:6",
                analyticsEvent: "purpose_scene_shown",
                analyticsParameters: ["scene": "finished"]
            ),
            AngleScene(
                symbol: "waveform",
                eyebrow: "HOW A CALLING COMES OUT",
                title: "You call it out\nbefore you see it.",
                body: "God speaks to things that are not yet as though they already are. You say what He called you before the proof shows up, and your steps start lining up with it.",
                verse: "The God who gives life to the dead and calls into being things that were not.",
                reference: "Romans 4:17",
                analyticsEvent: "purpose_scene_shown",
                analyticsParameters: ["scene": "call_it"]
            ),
            AngleScene(
                symbol: "map.fill",
                eyebrow: "WHAT YOUR YEARS LOOK LIKE",
                title: "Every step\nordered by Him.",
                body: "Direction you can act on. Doors opening at the right hour. Work that finally matters. The Lord makes firm the steps of the one who delights in Him.",
                verse: "The Lord makes firm the steps of the one who delights in him.",
                reference: "Psalm 37:23",
                buttonLabel: "This Is What I'm Called To →",
                analyticsEvent: "purpose_scene_shown",
                analyticsParameters: ["scene": "ordered"]
            ),
        ],
        picker: AnglePicker(
            headline: "Where do you most need\nHim to open your calling?",
            subtitle: "We'll build your daily destiny declarations\naround it and put His Word to work.",
            analyticsEvent: "purpose_picker_shown",
            choices: [
                AnglePickerChoice(id: "direction", burden: .purpose,
                                  statement: "Clear direction for my next step",
                                  subtitle: "Knowing exactly where He is leading",
                                  symbol: "location.north.line.fill", segmentLabel: "direction"),
                AnglePickerChoice(id: "calling", burden: .purpose,
                                  statement: "The work I was made for",
                                  subtitle: "Walking in what He assigned me",
                                  symbol: "flag.fill", segmentLabel: "calling"),
                AnglePickerChoice(id: "doors", burden: .purpose,
                                  statement: "Doors only God can open",
                                  subtitle: "Favor going ahead of me",
                                  symbol: "key.fill", segmentLabel: "doors"),
                AnglePickerChoice(id: "courage", burden: .purpose,
                                  statement: "Boldness to actually begin",
                                  subtitle: "Starting what He told me to start",
                                  symbol: "bolt.fill", segmentLabel: "courage"),
                AnglePickerChoice(id: "timing", burden: .purpose,
                                  statement: "My season opening up",
                                  subtitle: "Right on time, nothing delayed",
                                  symbol: "clock.fill", segmentLabel: "timing"),
                AnglePickerChoice(id: "impact", burden: .purpose,
                                  statement: "Impact beyond myself",
                                  subtitle: "A life that leaves something behind",
                                  symbol: "person.3.fill", segmentLabel: "impact"),
            ]
        )
    )

    // MARK: - Joy (single-issue, deep link ?ob=joy)

    // For heaviness and grief creative. Per the rule of calling higher, the
    // screens claim the joy rather than dwelling on the weight: scripture names
    // the trade, the copy declares what it is traded for. Every picker row
    // seeds `joy` → the `joy` category.
    static let joy = OnboardingAngle(
        id: "joy",
        flow: "joy",
        flowSchema: 1,
        opensWithStormScreen: true,
        scenes: [
            AngleScene(
                symbol: "sun.max.fill",
                eyebrow: "IT WAS NEVER YOURS TO MANUFACTURE",
                title: "His joy is\nyour strength.",
                body: "Joy is not a mood you work up on a good day. It is His, given to you, and it is the very thing that holds you up when nothing else does.",
                verse: "Do not grieve, for the joy of the Lord is your strength.",
                reference: "Nehemiah 8:10",
                analyticsEvent: "joy_scene_shown",
                analyticsParameters: ["scene": "strength"]
            ),
            AngleScene(
                symbol: "arrow.triangle.swap",
                eyebrow: "HE TRADES",
                title: "He turns mourning\ninto dancing.",
                body: "God does not ask you to carry heavy things quietly. He takes them off you and puts gladness on you in their place. That is the trade He makes.",
                verse: "You turned my wailing into dancing; you removed my sackcloth and clothed me with joy.",
                reference: "Psalm 30:11",
                analyticsEvent: "joy_scene_shown",
                analyticsParameters: ["scene": "trade"]
            ),
            AngleScene(
                symbol: "sunrise.fill",
                eyebrow: "THE MORNING IS COMING",
                title: "Rejoicing comes\nin the morning.",
                body: "Nights end. God set a limit on them. What you have been through has an expiration date, and gladness is what is waiting on the other side of it.",
                verse: "Weeping may stay for the night, but rejoicing comes in the morning.",
                reference: "Psalm 30:5",
                analyticsEvent: "joy_scene_shown",
                analyticsParameters: ["scene": "morning"]
            ),
            AngleScene(
                symbol: "waveform",
                eyebrow: "HOW JOY COMES BACK",
                title: "You speak to\nyour own soul.",
                body: "David did not wait to feel better. He talked to himself out loud, put his hope in God, and said I will yet praise Him. Your soul listens to your voice.",
                verse: "Why, my soul, are you downcast? Put your hope in God, for I will yet praise him.",
                reference: "Psalm 42:5",
                analyticsEvent: "joy_scene_shown",
                analyticsParameters: ["scene": "speak"]
            ),
            AngleScene(
                symbol: "sparkles",
                eyebrow: "WHAT YOUR DAYS LOOK LIKE",
                title: "Fullness of joy,\nnot a good day here and there.",
                body: "Mornings you are glad to be in. Laughter back in your house. A gladness that holds when the week does not cooperate. In His presence there is fullness of joy.",
                verse: "You make known to me the path of life; you will fill me with joy in your presence.",
                reference: "Psalm 16:11",
                buttonLabel: "This Is the Joy I Want →",
                analyticsEvent: "joy_scene_shown",
                analyticsParameters: ["scene": "fullness"]
            ),
        ],
        picker: AnglePicker(
            headline: "Where do you most\nneed His joy?",
            subtitle: "We'll build your daily joy declarations\naround it and put His Word to work.",
            analyticsEvent: "joy_picker_shown",
            choices: [
                AnglePickerChoice(id: "mornings", burden: .joy,
                                  statement: "Waking up glad again",
                                  subtitle: "Mornings I am happy to be in",
                                  symbol: "sunrise.fill", segmentLabel: "mornings"),
                AnglePickerChoice(id: "home", burden: .joy,
                                  statement: "Laughter back in my home",
                                  subtitle: "Gladness where my family lives",
                                  symbol: "house.fill", segmentLabel: "home"),
                AnglePickerChoice(id: "loss", burden: .joy,
                                  statement: "Something I lost",
                                  subtitle: "Comfort and joy after grief",
                                  symbol: "heart.circle.fill", segmentLabel: "loss"),
                AnglePickerChoice(id: "delight", burden: .joy,
                                  statement: "Delight in my everyday life",
                                  subtitle: "Loving the days I am actually in",
                                  symbol: "leaf.fill", segmentLabel: "delight"),
                AnglePickerChoice(id: "worship", burden: .joy,
                                  statement: "Praise that rises easily",
                                  subtitle: "Worship that comes from the heart",
                                  symbol: "music.note", segmentLabel: "worship"),
                AnglePickerChoice(id: "strength", burden: .joy,
                                  statement: "Strength to keep going",
                                  subtitle: "His joy holding me up daily",
                                  symbol: "bolt.fill", segmentLabel: "strength"),
            ]
        )
    )

    // MARK: - More of God (single-issue, deep link ?ob=more)

    // The one growth-track arm. For creative aimed at the believer who is not in
    // crisis and knows there is more of God available than they are living in.
    // Every picker row seeds `allOfIt` → the `faith` category.
    static let more = OnboardingAngle(
        id: "more",
        flow: "more",
        flowSchema: 1,
        opensWithStormScreen: true,
        scenes: [
            AngleScene(
                symbol: "magnifyingglass",
                eyebrow: "HE IS NOT HIDING IT",
                title: "Seek Him and\nyou will find Him.",
                body: "God never made nearness a guessing game. He promised that the one who looks for Him with a whole heart finds Him, every time, without exception.",
                verse: "You will seek me and find me when you seek me with all your heart.",
                reference: "Jeremiah 29:13",
                analyticsEvent: "more_scene_shown",
                analyticsParameters: ["scene": "find"]
            ),
            AngleScene(
                symbol: "arrow.right.circle.fill",
                eyebrow: "HE MOVES WHEN YOU MOVE",
                title: "Come near,\nand He comes near.",
                body: "One step toward Him is answered with a step toward you. Closeness with God is not reserved for a few people. It is offered to whoever comes.",
                verse: "Come near to God and he will come near to you.",
                reference: "James 4:8",
                analyticsEvent: "more_scene_shown",
                analyticsParameters: ["scene": "near"]
            ),
            AngleScene(
                symbol: "infinity",
                eyebrow: "THE SIZE OF WHAT'S AVAILABLE",
                title: "Immeasurably more\nthan you've asked for.",
                body: "Whatever you have been believing God for, He is able to do beyond it. Not slightly past your prayers. Immeasurably more than you know how to ask.",
                verse: "Now to him who is able to do immeasurably more than all we ask or imagine.",
                reference: "Ephesians 3:20",
                analyticsEvent: "more_scene_shown",
                analyticsParameters: ["scene": "more"]
            ),
            AngleScene(
                symbol: "waveform",
                eyebrow: "HOW FAITH GROWS",
                title: "Faith comes\nby hearing.",
                body: "Faith is not something you strain for. It comes by hearing the Word of God, and the voice you hear say it most is your own. Daily, out loud, is how it grows.",
                verse: "Faith comes from hearing the message, and the message is heard through the word about Christ.",
                reference: "Romans 10:17",
                analyticsEvent: "more_scene_shown",
                analyticsParameters: ["scene": "hearing"]
            ),
            AngleScene(
                symbol: "sparkles",
                eyebrow: "WHAT HE CAME TO GIVE",
                title: "Life to the full.\nNothing held back.",
                body: "Jesus said He came so you would have life, and have it to the full. Not managed. Not maintained. Full, in every area He touches.",
                verse: "I have come that they may have life, and have it to the full.",
                reference: "John 10:10",
                buttonLabel: "I Want All of It →",
                analyticsEvent: "more_scene_shown",
                analyticsParameters: ["scene": "full"]
            ),
        ],
        picker: AnglePicker(
            headline: "What do you want\nmore of from God?",
            subtitle: "We'll build your daily declarations around it\nand put His Word to work in your life.",
            analyticsEvent: "more_picker_shown",
            choices: [
                AnglePickerChoice(id: "nearness", burden: .allOfIt,
                                  statement: "Closeness with God every day",
                                  subtitle: "Walking with Him, not just about Him",
                                  symbol: "heart.fill", segmentLabel: "nearness"),
                AnglePickerChoice(id: "hearing", burden: .allOfIt,
                                  statement: "Hearing His voice clearly",
                                  subtitle: "Knowing it is Him when He speaks",
                                  symbol: "ear.fill", segmentLabel: "hearing"),
                AnglePickerChoice(id: "faith", burden: .allOfIt,
                                  statement: "Faith that moves things",
                                  subtitle: "Believing God and seeing it happen",
                                  symbol: "mountain.2.fill", segmentLabel: "faith"),
                AnglePickerChoice(id: "rhythm", burden: .allOfIt,
                                  statement: "A daily rhythm that sticks",
                                  subtitle: "Time in the Word I actually keep",
                                  symbol: "calendar", segmentLabel: "rhythm"),
                AnglePickerChoice(id: "boldness", burden: .allOfIt,
                                  statement: "Boldness in how I live",
                                  subtitle: "Unashamed, everywhere I go",
                                  symbol: "bolt.fill", segmentLabel: "boldness"),
                AnglePickerChoice(id: "everything", burden: .allOfIt,
                                  statement: "All of it, every area",
                                  subtitle: "Nothing left outside His hand",
                                  symbol: "sparkles", segmentLabel: "everything"),
            ]
        )
    )
}
