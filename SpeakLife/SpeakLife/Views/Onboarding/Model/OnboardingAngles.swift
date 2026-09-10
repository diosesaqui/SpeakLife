//
//  OnboardingAngles.swift
//  SpeakLife
//
//  Every onboarding angle's copy, in one place. See `OnboardingAngle` for the
//  model and `AngleOnboardingView` for the driver that renders it.
//
//  BROAD ARMS (promises / warfare / outcomes / command) argue the mechanism from
//  a different emotional entry point and then let the user name their own area:
//  promises leads with a settled fact, warfare with the fight for what is
//  already yours, outcomes with the won life, command with the first sixty
//  seconds of the morning. Their picker lists one row per HeaviestBurden. The
//  first three are ports of the hand-written views that preceded this file, copy
//  and step order preserved exactly so the live A/B funnels still join.
//
//  SINGLE-ISSUE ARMS (healing / provision / anxiety / renewal) exist to be deep
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
        uniqueKeysWithValues: [promises, warfare, outcomes, command, healing, provision, anxiety, renewal]
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

    // MARK: - Command your day (morning ritual, deep link ?ob=command)

    // A RITUAL arm, and the only one whose hook is WHEN rather than WHAT. Every
    // other angle argues what already belongs to you; this one argues that the
    // day is decided in its first sixty seconds. Before the phone, the news and
    // the to-do list get a vote, you command your finances, your body and your
    // household out loud, or you spend the rest of the day answering whatever
    // shows up.
    //
    // It sells the exact behaviour retention is built on: a sixty-second morning
    // declaration. So the arc and the product promise are the same sentence,
    // which is what the promises/warfare/outcomes arms have to bridge and this
    // one does not.
    //
    // DEPTH IS PART OF THE ANGLE HERE. A 24-screen flow selling a sixty-second
    // habit argues against itself, so this arm runs lean: no storm opener, no
    // product recap, three scenes instead of five, the two quiz questions whose
    // answers outlive onboarding instead of all seven, and no plan loader. 14
    // screens against the other broad arms' 22 to 23. What it keeps is
    // everything that either seeds the app or sells: the picker, the payoff, the
    // taste, record-your-own, the plan reveal and the testimonial wall.
    //
    // The cost is deliberate: `battle_duration`, `already_tried`, `hits_hardest`
    // and `belief` land as "unknown" on this arm's completion event, because the
    // screens that collected them are gone. Nothing else read them.
    //
    // Broad arm: one picker row per HeaviestBurden, framed as the area you
    // command FIRST tomorrow morning. The burden-matched payoff then hands the
    // user the actual words they will speak over it, so the sixty seconds stops
    // being an idea before they ever reach the paywall.
    static let command = OnboardingAngle(
        id: "command",
        flow: "command",
        flowSchema: 1,
        opensWithStormScreen: false,
        showsExperienceScreen: false,
        scenes: [
            AngleScene(
                symbol: "sunrise.fill",
                // Screen one, with no storm opener in front of it, so it has to
                // be the doorway as well as the first beat of the argument.
                eyebrow: "HOW JESUS STARTED HIS DAY",
                title: "He set the day\nbefore it set Him.",
                body: "Long before sunrise, while the house was still dark, Jesus was already up and with the Father. He did not ask the day to go well. He settled it first.",
                verse: "Very early in the morning, while it was still dark, Jesus got up, left the house and went off to a solitary place, where he prayed.",
                reference: "Mark 1:35",
                analyticsEvent: "command_scene_shown",
                analyticsParameters: ["scene": "morning"]
            ),
            AngleScene(
                symbol: "bolt.fill",
                // Carries the mechanism (it is in your mouth) AND all three
                // areas, which were a screen each before the trim.
                eyebrow: "YOU HAVE THE AUTHORITY",
                title: "You don't ask the day.\nYou tell it.",
                body: "God put the outcome of your day in your own mouth. You speak over your finances, over your body, over everyone under your roof, and what you decide on is what stands.",
                verse: "What you decide on will be done, and light will shine on your ways.",
                reference: "Job 22:28",
                analyticsEvent: "command_scene_shown",
                analyticsParameters: ["scene": "authority"]
            ),
            AngleScene(
                symbol: "timer",
                // The cost objection is the whole reason this arm exists. It gets
                // the last screen, right before the picker.
                eyebrow: "IT TAKES SIXTY SECONDS",
                title: "One minute out loud,\nand the day is yours.",
                body: "Not an hour. Not a study plan. Sixty seconds of God's Word over your money, your body and your household, and you walk into the day already standing on victory.",
                verse: "Satisfy us in the morning with your unfailing love, that we may sing for joy and be glad all our days.",
                reference: "Psalm 90:14",
                buttonLabel: "I'm Ready to Command My Day →",
                analyticsEvent: "command_scene_shown",
                analyticsParameters: ["scene": "sixty_seconds"]
            ),
        ],
        picker: AnglePicker(
            headline: "What are you commanding\nfirst tomorrow morning?",
            subtitle: "We'll build your sixty seconds around it\nand have it waiting when you wake up.",
            analyticsEvent: "command_picker_shown",
            // Finances, body and protection lead, in the order this arm argues
            // them, rather than the broad arms' health-first order.
            choices: [
                AnglePickerChoice(id: "abundance", burden: .abundance,
                                  statement: "My finances",
                                  subtitle: "Provision called in before the day starts",
                                  symbol: "key.fill"),
                AnglePickerChoice(id: "health", burden: .health,
                                  statement: "My body",
                                  subtitle: "Healing and strength, first thing",
                                  symbol: "heart.fill"),
                AnglePickerChoice(id: "more", burden: .allOfIt,
                                  statement: "My protection",
                                  subtitle: "My household covered before we walk out",
                                  symbol: "shield.lefthalf.filled"),
                AnglePickerChoice(id: "peace", burden: .peace,
                                  statement: "My mind and my home",
                                  subtitle: "Peace set before the noise starts",
                                  symbol: "house.fill"),
                AnglePickerChoice(id: "identity", burden: .identity,
                                  statement: "Who I am today",
                                  subtitle: "Standing as His before I step out",
                                  symbol: "crown.fill"),
                AnglePickerChoice(id: "purpose", burden: .purpose,
                                  statement: "My steps",
                                  subtitle: "Ordered before I take the first one",
                                  symbol: "flag.fill"),
                AnglePickerChoice(id: "joy", burden: .joy,
                                  statement: "My joy",
                                  subtitle: "Strength decided for the whole day",
                                  symbol: "sun.max.fill"),
            ]
        ),
        // The arm promises sixty seconds, so the screen right after the picker
        // spends them: the actual words for the area just chosen, before any
        // quiz question or paywall. Same slot warfare uses for its victory
        // vision.
        burdenScene: AngleBurdenScene(
            eyebrow: "TOMORROW MORNING, THIS IS WHAT YOU SAY",
            buttonLabel: "That's What I'm Speaking →",
            analyticsEvent: "command_first_words_shown",
            // `.peace` lives here rather than in the dictionary: it is what an
            // unlisted burden falls back to, and two copies would drift apart.
            defaultContent: .init(
                symbol: "house.fill",
                title: "Your mind and\nyour home, first.",
                body: "You say it before the noise starts. I have the mind of Christ, my mind is clear and at rest, and peace rules my home today. Sixty seconds, and the day walks in on your terms.",
                verse: "You will keep in perfect peace those whose minds are steadfast, because they trust in you.",
                reference: "Isaiah 26:3"),
            content: [
                .abundance: .init(
                    symbol: "key.fill",
                    title: "Your finances,\nsettled first.",
                    body: "You say it before you check a single balance. My God supplies every need of mine, my work prospers, and increase finds me today. Sixty seconds, and provision goes ahead of you into the day.",
                    verse: "And my God will meet all your needs according to the riches of his glory in Christ Jesus.",
                    reference: "Philippians 4:19"),
                .health: .init(
                    symbol: "heart.fill",
                    title: "Your body,\nbefore you stand up.",
                    body: "You say it before your feet touch the floor. By His wounds I am healed, this body is strong, and strength rises in me today. Sixty seconds, and you meet the day standing up.",
                    verse: "He sent out his word and healed them; he rescued them from the grave.",
                    reference: "Psalm 107:20"),
                .allOfIt: .init(
                    symbol: "shield.lefthalf.filled",
                    title: "Your household,\ncovered.",
                    body: "You say it before anyone walks out the door. No weapon formed against me prospers, angels guard my household, and everyone under this roof is covered today. Sixty seconds, and protection goes out ahead of them.",
                    verse: "No weapon forged against you will prevail.",
                    reference: "Isaiah 54:17"),
                .identity: .init(
                    symbol: "crown.fill",
                    title: "Who you are,\nsettled early.",
                    body: "You say it before the day tries to tell you otherwise. I am chosen, I am His, and I am a new creation today. Sixty seconds, and you step out already sure of who you are.",
                    verse: "If anyone is in Christ, the new creation has come: The old has gone, the new is here.",
                    reference: "2 Corinthians 5:17"),
                .purpose: .init(
                    symbol: "flag.fill",
                    title: "Your steps,\nordered first.",
                    body: "You say it before you take one. My steps are ordered by God, my plans succeed, and I walk in the calling He gave me today. Sixty seconds, and the day has direction before it starts.",
                    verse: "In their hearts humans plan their course, but the Lord establishes their steps.",
                    reference: "Proverbs 16:9"),
                .joy: .init(
                    symbol: "sun.max.fill",
                    title: "Your joy,\nchosen first.",
                    body: "You say it before you look at your phone. The joy of the Lord is my strength, this is the day the Lord has made, and I am glad in it. Sixty seconds, and joy is decided before anything else gets a vote.",
                    verse: "The joy of the Lord is your strength.",
                    reference: "Nehemiah 8:10"),
            ]
        ),
        // Two questions, not seven: the ones whose answers outlive onboarding
        // (`ConnectStyle` and `DailyTimeBudget`, both read by TaskLibrary). The
        // four analytics-only questions and the no-input insight screen are what
        // the sixty-second pitch could not afford.
        quizSteps: OnboardingAngle.leanQuiz,
        // The loader is theatre, and this arm's claim is speed.
        showsPlanBuilding: false
    )
}
