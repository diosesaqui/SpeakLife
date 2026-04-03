#!/usr/bin/env python3
"""Patch December devotionals in devotionals.json"""
import json, sys

FILE = "SpeakLife/SpeakLife/Preview Content/AffirmationData/devotionals.json"

rewrites = {
"01-12": """God's heart toward you was so committed to your transformation that He engineered His own departure as the supreme gift. When Jesus said "It is for your good that I go away," He wasn't abandoning the people who loved Him. He was trading one kind of presence for a better one.

The Greek word "allos" — another of the exact same kind. Not a substitute. Not a downgrade. The same quality of help, the same power that calmed seas and raised the dead, but with one world-changing difference: the Spirit would live inside every believer simultaneously, without limit, without distance.

Jesus was external — with them. The Spirit is internal — in you. Jesus was present for three years. The Spirit is present forever. Every decision you face today has a divine Counselor already present inside you. Every fear that whispers at 3am has the Spirit of truth already active to counter it.

This means you are never spiritually unequipped for what you're walking into. You have an Advocate — the same word used for a legal defender, someone who stands in your corner without condition.

You can trust this because Jesus staked His departure on the Spirit's arrival. He said it was better for you. The One who loved you to the cross gets to define "better," and He called this better.

Stop operating like someone figuring it out alone. You have been inhabited by God Himself. That's not religious language — that's the most practical fact about your entire day.

Holy Spirit, I receive You — not as a concept but as a Person alive within me. Today I stop striving in my own strength and lean into Yours. You are my Advocate, my truth, my ever-present companion. I am never alone. Amen.""",

"02-12": """God's heart toward you is so thoughtful that He didn't just save you and leave you to figure out the rest — He installed a Teacher inside you before you knew what questions to ask.

The Holy Spirit will teach you "all things." Not some things. Not only the spiritual things. Not just the crises. All things — your calling, your marriage, the conversation you've been dreading, the decision that's been paralyzing you. He is qualified for every subject and never runs out of time for your specific situation.

But here's what most people overlook: the Spirit also promises to remind you. That means everything you've ever read, heard, or received from God is archived — stored with perfect precision, ready to be surfaced at exactly the moment you need it. The verse you memorized and forgot? Still filed. The truth that shifted something in you years ago? Still accessible. When you need it most, the Spirit pulls it up.

This is your advantage on the worst day. When you don't know what to do, you have a Teacher who does. When you've run out of wisdom, you have a Counselor with infinite supply. When circumstances are screaming, the Spirit is still speaking.

You can trust this because Jesus said plainly: "I will not leave you as orphans." Orphans fend for themselves. You don't. You have a divine tutor present in every moment.

Today is a classroom. The Teacher is already in session. He's not waiting for you to be more spiritual to begin.

Holy Spirit, I come as Your student today. Teach me what I need to know and remind me of Your promises when I forget. I'm listening. Bring truth at exactly the right moment. Amen.""",

"03-12": """God's heart toward you is so generous that He didn't simply hand you a map — He sent a Guide to walk you personally into truth, step by step, for the rest of your life.

The Spirit of truth doesn't lecture from a distance. He guides. That word carries the image of someone walking beside you on a path — pointing out what you would have missed, steering you gently from what would have hurt you, making sure you don't get lost in the dark. This is not impersonal instruction. This is a Person walking with you.

And notice what He guides you into: all truth. Not fragments. Not selective revelation for the spiritually advanced. Everything you need — for your relationships, your calling, your confusion, your grief, the area of your life that feels completely murky right now. Nothing is withheld from you.

He speaks only what He hears from the Father. Your Guide isn't improvising. He carries direct intelligence from the throne room of heaven and delivers it to you in plain language, at the right moment. When He speaks, you are hearing what God Himself says about your situation.

You can trust this because Jesus promised it before He left — not as an afterthought but as the central reason His departure would be worth it. The Spirit's guidance is your inheritance, fully purchased.

You are not wandering. You are not guessing. You have a Guide who doesn't get tired, doesn't miss details, and never loses the way.

Spirit of truth, guide me today. Lead me into what I need to know. When I'm confused, I trust You to bring clarity. When the path isn't clear, I trust You to light it. You know the way — I'll follow. Amen.""",

"04-12": """God's heart toward you is so practical that He didn't commission you to represent Jesus in the world and then leave you to manage it in your own strength — He sent power to match the assignment.

The word "dunamis" — explosive, life-altering power. This isn't a trickle. This isn't spiritual energy reserved for crisis moments. This is the same force that raised Jesus from the dead, made available to you the moment the Spirit arrives. And He hasn't just arrived — He dwells in you permanently.

Notice how it works: the Spirit "comes upon" you. Not just in you — on you. He clothes you with ability that isn't naturally yours. You don't manufacture this power. You receive it. Like putting on a garment, the Spirit's power covers you and carries you beyond what you could do on your own.

But power without purpose is just noise. The assignment is specific: "You will be my witnesses." Your life becomes demonstration. Not performance — demonstration. The way you love, speak, persist, forgive — it all bears witness to the reality of Jesus.

You can trust this because it was the last thing Jesus said before ascending. Of everything He could have ended with, He chose this promise. He wanted you equipped before you took another step.

You do not operate in your own strength today. The power you need for what you're facing is already resident within you.

Holy Spirit, clothe me with power today. Not the power to impress — the power to represent Jesus well. Let everything I do bear witness to His reality. I receive what You've already given. Amen.""",

"05-12": """God's heart toward you is so committed that He chose to make your body His home — and He didn't send a diminished version of Himself to do it.

The Spirit living in you is the Spirit "of Him who raised Jesus from the dead." Read that slowly. Not a similar spirit. Not a comparable force. The exact same power that broke open the tomb, that reversed death itself, that sent Roman soldiers falling backward — that Spirit has taken up permanent residence inside you.

And Paul doesn't stop at spiritual implications. He says this Spirit gives life to your mortal body. Not just your soul. Your physical body — the one that gets tired, the one that gets sick, the one that sometimes feels like it's failing you — is the dwelling place of resurrection power.

This changes everything about how you see your limitations. Exhaustion meets the Spirit of life. Weakness meets the power that shattered death. Your body is not just biological matter. It is the temple of the God who raised Jesus.

You can trust this because Paul stakes the entire argument on the resurrection. If God raised Jesus, He will also give life to you — through that same Spirit. The logic is airtight and the guarantee is the empty tomb.

You carry infinity inside you. Live accordingly.

Holy Spirit, I receive the life You're giving my body right now. Resurrection power lives in me — not someday, but today. Every limitation I face meets a God who has already conquered the ultimate limitation. I am not just surviving. I am inhabited by life itself. Amen.""",

"06-12": """God's heart toward you goes deeper than surface-level help — He fortifies you from the inside out, at the very core of who you are, where your battles are actually won or lost.

Paul prays that God would strengthen you "in your inner being" — the command center of your existence, the wellspring of every thought, decision, and response. And the word he uses for "strengthen" is krataioo — conquest-level fortification. Not just endurance. Prevailing strength. The kind that doesn't just survive but dominates.

This matters because inner strength determines everything. You can win every external argument and lose the inner war. You can look composed and be crumbling. God aims His power at the deepest place — because that's where it does the most good.

The goal of this fortification is personal: Christ dwelling in your heart and feeling completely at home there. Every strengthening of your inner being creates more space for His presence. Every spiritual muscle built becomes new territory for Him to occupy.

Paul wrote this from a prison cell, chains on his wrists. He knew what it meant to need inner strength when outer circumstances were broken. He prayed this for you because he knew it worked.

You are being built from the inside. Not renovated on the surface — fortified in the foundation.

Holy Spirit, invade my inner being with Your power right now. Strengthen me beyond what my own resolve could ever achieve. Make my heart an unshakeable home for Christ. Root me so deep in love that no storm today can move me. I am being fortified. Amen.""",

"07-12": """God's heart toward you operates on a scale your imagination hasn't caught up with yet — and He is actively working to exceed every expectation you've ever held.

Paul reaches for a word that almost breaks under the weight of what he's trying to say: "hyperekperissou." Exceeding abundantly beyond. Over and above. More than more than more. It is a stacked superlative designed to communicate that God doesn't just meet expectations — He obliterates the category entirely.

Your biggest dreams were built inside the container of your experience. Your grandest vision is still constrained by what you've seen, what you know, what you've been told is possible. God works outside every container you've ever known. He doesn't just answer prayers — He answers them in ways you wouldn't have known to request.

The same power that spoke galaxies into being from nothing, that reversed death on a Sunday morning, that transformed water into wine at a wedding — that power is not dormant. It is actively at work within you. Present tense. Right now. Producing something you cannot yet see.

You can trust this because the power is already in operation. Paul says "at work within us" — not potentially available, not reserved for special moments. Already working.

Stop scaling your faith to fit your experience. His math doesn't work on your calculator.

Lord, shatter my limited thinking. You are doing immeasurably more than I can currently picture. I release my small calculations and embrace Your limitless possibility. Work in me and through me beyond anything I could plan or imagine. Amen.""",

"08-12": """God's heart toward you is precise — every promise He has spoken over your life is not a wish, it is an assignment, and it will not return until it has accomplished what He sent it to do.

His word is not vague inspiration. It is a divine force with a specific mission. The prophet Isaiah uses language of purpose and completion: what goes out from God's mouth will accomplish what He desires and achieve the purpose for which He sent it. There is no failure rate. No abandoned promises. No words that get lost in transit.

Like rain that falls on drought-hardened ground — it soaks in deeper than you can see. For weeks, nothing appears. Then suddenly, green. The word of God works the same way. Some promises mature quickly. Others work in dimensions invisible to you, arranging circumstances you can't arrange, aligning timing you can't control.

Every promise spoken over your life is currently en route to manifestation. The word doesn't pause because your situation looks stuck. It doesn't stall because you've lost hope. It accomplishes what God intended on God's timeline, not yours.

You can trust this because the integrity of God's word is tied to His name. He cannot speak and fail. That's not who He is.

The silence is not failure. The mission is still running.

Father, Your word spoken over me is on assignment right now. It will accomplish everything You intended — in Your time, in Your way. I stop judging progress by what I can see and start trusting what You've already set in motion. Your word does not return empty. Amen.""",

"09-12": """God's heart toward you is so near that He didn't place His word at a philosophical distance — He put it in your mouth and wrote it on your heart, close enough to speak and deep enough to guide.

The Hebrew phrase "qarov elayka" means intimately near — not just accessible in theory, but available right now, without preparation, without a search. God designed obedience to be easier than disobedience by making His word your closest companion.

In your mouth means the word is ready for activation. Every promise you speak releases Kingdom reality into your circumstances. Your voice becomes the delivery system for Heaven's declarations. In your heart means the word has become your internal compass. Not external instruction you have to remember — instinct you can trust.

Most people spend their lives searching for revelation they already possess. They wait for a dramatic sign when the word is already speaking. They look for a new word when the one inside them just needs to be activated.

You don't need more information today. You need more trust in what's already there. The breakthrough you're asking God for isn't hiding somewhere beyond your reach — it's in your mouth right now.

You can trust this because God designed this access on purpose. He wanted you equipped. He wanted the word near. He positioned it inside you so nothing could separate you from it.

Stop searching in distant places for what's already planted within you.

Father, Your word is in me — ready, alive, and sufficient. Today I stop looking for what I already have. I activate Your word by speaking it, trusting it, living from it. What I need is near. Amen.""",

"10-12": """God's heart toward you is so respectful of your freedom that He placed the power of life and blessing directly in your hands — and then openly told you which one to choose.

Heaven and earth as witnesses. The stakes could not be higher. Life and death, blessing and curse — set before you like two paths, two harvests, two different kinds of future. And God, who could have made the choice for you, handed you the decision and said: "Now choose life."

He doesn't hide His preference. He campaigns for your flourishing. He advocates for the blessing. He points clearly at the path and says: this one. That kind of transparent love is rare — a God who wants your best and tells you exactly how to get there.

Your choice today creates ripples you can't fully trace. When you choose the patterns of life — choosing God, listening to His voice, holding fast to Him — you break generational curses and establish generational blessings. The effects of your decision outlast your lifetime.

Choosing life isn't just a moral category. God says: "He is your life." Choosing Him is choosing your source, your strength, your sustenance. You don't choose a lifestyle — you choose a Person.

You can trust this because God wouldn't give you the power to choose if He hadn't also given you the ability to choose well. The same Spirit who raised Jesus from the dead helps you walk in life every day.

Today, every decision is a vote. Vote for life.

Lord, I choose life — deliberately, completely, today. Every decision I make, I align with Your way. You are my life, my blessing, my inheritance. I choose You. Amen.""",

"11-12": """God's heart toward you is so strategic that He never sends you somewhere He hasn't already been — He goes before you, fights for you, and secures territory before you even arrive at the edge of it.

The Hebrew word "halak" means He walks before you — not just ahead, but as a military advance. He scouts the terrain. He removes obstacles. He neutralizes threats. He prepares victory before you encounter the battle. You are not walking into unknown territory. You are walking into pre-conquered ground.

"He will fight for you." The word "lacham" means to actively wage war. God doesn't wait to see how the battle develops before deciding to act. He attacks the things that oppose your purpose before you even see them forming. Every enemy that hasn't reached you — He stopped it. Every situation that didn't break you — He fought first.

Remember Egypt. Remember the sea parting. Remember an army swallowed and a people walking out free with the wealth of their enemies. That same God who staged visible miracles for Israel is staging invisible ones for you right now. The miracles you'll describe later are already in motion.

You can trust this because His track record is perfect. He has never lost a battle He entered on behalf of His people. He has never abandoned the field. He has never been outmaneuvered.

Fear has no legal ground when God is your warrior.

Lord, You go before me. Right now, in what's ahead today, You are already there. I walk in boldness because You've already secured the path. Thank You for fighting battles I'll never even know about. Amen.""",

"12-12": """God's heart toward you is not conditional presence — it is covenant permanence, and He staked His reputation on it before you ever needed to hear it.

"Never leave nor forsake" carries double weight in the Hebrew. The word "lo" is absolute negation — never, under no circumstances, not ever. Layered on top of two words: "azab" (abandon) and "natash" (forsake, let go). God uses both words, doubled by absolute negation. This is the strongest possible oath any language can form. He is staking His name on His commitment to you.

"Goes with you" means synchronized movement. He doesn't just watch from a safe distance — He moves when you move, stands when you stand, advances when you advance. You and God operate as a unified force through everything.

The promise was first spoken before war — before Israel entered a territory full of enemies bigger and stronger than them. Moses didn't say "God will come with you if you perform well." He said: "He will not leave you." That promise had nothing to do with their track record and everything to do with His character.

Your failures don't disqualify you from this promise. Your doubts don't drive Him away. Your inadequacies have never made Him reconsider. His commitment is not based on your faithfulness — it's anchored in His.

Be courageous. Not because the road is easy. Because you're never on it alone.

Lord, Your presence is my permanent reality. You don't leave when I fail or retreat when I struggle. Your commitment to me is unbreakable. I walk into today strong — not because I feel strong, but because You are with me forever. Amen.""",

"13-12": """God's faithfulness is not a variable that fluctuates with circumstances — it is His nature, unchangeable and unshakeable, and your hope can stand on it with full weight.

The word "unswervingly" in the Greek is "aklines" — without bending, without deviation. It describes something structurally immovable. That's the standard to which God's own faithfulness holds. And it's the kind of grip He calls you to have on the hope He has given you.

The hope you profess isn't wishful thinking. It's confident expectation based on divine commitment. Every promise you've received from God, every truth you've spoken in faith, every future you've embraced — these are not dreams. They are destinies backed by the character of the One who made them.

Here is the freedom inside this truth: your grip doesn't need to be perfect because His grip never fails. Your faith might wobble. Your confidence might waver. Your emotions might scream the opposite of what He said. None of that changes His faithfulness by one degree.

Every delay is not a denial. Every silence is not abandonment. God's faithfulness works behind the scenes — in dimensions you can't see, arranging circumstances you can't arrange, holding the end of a thread you lost track of.

Stop measuring God's faithfulness by your timeline. Start measuring your confidence by His character. He has never failed anyone who trusted Him.

Father, Your faithfulness is my anchor when my feelings fail me. I hold unswervingly to what You promised — not because my grip is strong, but because Your character makes failure impossible. You are faithful. That is enough. Amen.""",

"14-12": """God designed faith not as wishful thinking or emotional intensity — but as actual substance, a spiritual reality that exists before your eyes can confirm it.

The Greek word "hypostasis" means foundation, underlying reality, the concrete basis beneath what appears. Faith is the hypostasis of things hoped for. What you believe God for isn't floating in some vague realm of possibility — it has substance in the spiritual dimension, waiting to be made visible in the natural.

The ancients knew this. They didn't receive what was promised in their lifetimes, yet they were commended for their faith. They lived with evidence their eyes couldn't see. They operated from the substance of invisible realities. And the record says God was pleased.

The universe itself was spoken from nothing visible into everything seen. God's spoken word created substance from void. That same creative principle is active in your life. What you're believing God for doesn't need to be created — it needs to be revealed.

Faith isn't straining harder to believe. Faith is resting in the reality that already exists in the spirit, trusting that the visible will catch up with the invisible on God's schedule.

You can trust this because faith has always worked this way — for Abraham, for Moses, for the whole cloud of witnesses who lived and died before the fulfillment arrived. They weren't foolish. They were right.

Father, my faith is the substance of things hoped for. What I'm believing You for already exists in the spiritual realm. I am not hoping for creation — I am trusting for manifestation. My faith connects the invisible to the visible. Amen.""",

"15-12": """God built His Kingdom on a faith-access protocol — and He rewards, without exception, every person who approaches Him through it.

Faith is not one option among several approaches to God. It is the only entry point into His pleasure, the non-negotiable gateway. Without it, impossibility becomes the ceiling. With it, possibility opens without limit.

To believe He exists means more than acknowledging His reality from a safe intellectual distance. It means banking your actual decisions, your actual day, your actual crisis on His active involvement. That's not philosophy — that's operational trust. You live as if He's really there because He really is.

To believe He rewards means understanding God as a compensator. He doesn't merely notice your seeking. He responds to it. He doesn't appreciate your hunger and do nothing about it. "Ekzeteo" — the Greek word used here — means to seek diligently, to crave earnestly. God doesn't reward spiritual tourists. He rewards the desperately hungry.

Your faith pleases God because it affirms both His presence and His generosity. When you come to Him believing He exists and believes He rewards, you're declaring exactly what He wants declared about Himself.

You can trust this because His response to faith is not a decision He makes case by case — it is His nature. He cannot overlook earnest seeking. It is constitutionally impossible.

Faith opens what nothing else can open. And you have it.

Father, I come through the gateway of faith — believing You are real and that You reward those who seek You. Today I seek You earnestly, expectantly, confidently. I trust Your generous nature to respond. Amen.""",

"16-12": """In a world that revises itself constantly — updates, corrections, reversals, contradictions — Jesus Christ remains permanently the same, and everything He ever did is still available now.

"Yesterday" means every biblical account of His power is current documentation, not ancient history. When you read about the blind receiving sight, that is a preview of available capacity. When you read about storms going silent at His word, that is a testimony of present willingness. Scripture isn't a museum of what God used to do — it's a catalogue of what He still does.

"Today" means the Jesus who calmed Galilee walks into your chaos right now. The Jesus who called Lazarus from four days of death speaks into your dead situations today. Same Jesus. Same character. Same authority. Same willingness.

"Forever" locks His nature across all time. His love won't depreciate. His power won't weaken with age. His promises won't expire. Ten thousand years from now, He will be exactly what He is today — fully God, fully for you, fully the same.

This immutability is your confidence when everything else is shifting. While circumstances fluctuate and the world rewrites its definitions of truth, Jesus remains the fixed point. He is not subject to revision.

You can trust this because immutability is His nature, not His mood. It doesn't depend on how your week is going.

Jesus, You are the same yesterday, today, and forever. What You were willing to do in Scripture, You are able to do now. I bring my situation to a God who doesn't change — and I rest in that. Amen.""",

"17-12": """God's heart toward you is responsive — He doesn't maintain a fixed distance while you strain to get closer. He moves toward you as you move toward Him.

James makes it simple and direct: "Draw near to God and He will draw near to you." The Greek word "eggizo" carries the same weight for both movements — your approach and His. When you take a step toward God, He takes a step toward you. Divine proximity is not a reward for spiritual performance. It's a response to spiritual pursuit.

But He asks for a real approach, not a posture. Clean hands — your external life aligned. Pure heart — your internal life honest. "Dipsychos" — double-souled — is what He asks you to move away from. A divided heart, split between God and the world, doesn't experience full nearness. Not because He withdraws, but because proximity requires presence. You cannot be half-present in a relationship.

Here's what this means on a hard day: the distance you feel from God is never His doing. He has not moved. He has not grown cold. He has not forgotten your address. The invitation remains open and the promise stands: take one step, He takes one step.

You can trust this because the promise is unconditional in its direction. Approach is met with approach, every single time. That is who He is.

The nearness you're longing for isn't something you have to earn. It's something you simply have to pursue.

Father, I draw near to You today — with honest hands and a whole heart. No divided loyalties, no performance, just pursuit. Draw near to me as I draw near to You. I want Your presence more than anything else. Amen.""",

"18-12": """Your prayers carry weight — not the weight of your own spiritual resume, but the weight of the righteousness of Jesus Christ, which is yours entirely.

The Greek word "energeo" is where we get "energy." Righteous prayer is not passive petition. It is an active force. When you pray from the righteousness Christ has given you, things move. Circumstances shift. Atmospheres change. Prayer isn't hoping something will happen — it is applying a force that produces results.

Elijah was "homoiopathes" — of like passions, subject to the same emotions you experience. He got discouraged. He ran from Jezebel. He sat under a broom tree and asked God to take his life. He was not a superhero. He was a human being with a prayer life — and his prayers locked and unlocked the sky for three and a half years.

You are not praying as a sinner hoping for God's attention. You are praying as a righteous person, because Christ's righteousness has been credited to your account. That changes your posture entirely. You don't approach the throne nervously hoping to be heard. You approach with confidence because your legal standing is Jesus Himself.

You can trust this because your prayer authority is not built on your track record — it's built on His. And His never fails.

You are not begging for change today. You are authorizing it.

Lord, I pray with the authority of Christ's righteousness. My prayers are powerful and effective — not because of who I am, but because of whose I am. I bring my specific needs before You with confidence. You hear me. You respond. Amen.""",

"19-12": """God's heart toward you ensured that when you were born again, you were born from something that cannot die — imperishable seed, incorruptible source, eternal origin.

Peter makes the contrast sharp: perishable seed and imperishable seed. Everything born of natural process carries mortality markers. Every human cell is engineered for decay. But your spiritual rebirth came from the living and enduring Word of God — seed that contains no death gene, no corruption sequence, no expiration code.

This means your spiritual life is indestructible. Not just long-lasting. Not just resilient. Indestructible. The Word that birthed you is the same Word that upholds the universe. When everything around you fades like grass and falls like flowers, what God planted inside you keeps growing.

Consider what this means for your worst days. The parts of you that feel most broken — the faith that feels thin, the hope that feels worn down — those are not your deepest reality. Your deepest reality is imperishable genetics: born of God, sustained by God, carrying the DNA of eternity.

You can trust this because Peter explicitly anchors your rebirth to the living and enduring Word. God's Word outlasts everything. What it creates, it sustains.

You carry immortality within mortality. The eternal has moved into the temporary. What God has born in you cannot be destroyed.

Father, I am born of imperishable seed. The life You placed in me cannot decay. While circumstances change and my emotions fluctuate, my spiritual foundation is indestructible. I stand on what You built — and it holds forever. Amen.""",

"20-12": """God chose your identity before you had the chance to define yourself — and every name He gave you belongs to the highest order in existence.

Four declarations in one breath: chosen people, royal priesthood, holy nation, God's special possession. Not aspirational titles. Not what you're working toward. What you already are, by the decision of God, purchased at the price of His Son.

"Chosen people" — selected by divine decree, handpicked from the mass of humanity. "Royal priesthood" — you carry both crown and altar, governmental authority and intimate access to God in the same person. "Holy nation" — belonging to a sacred society operating under heavenly constitution. "God's special possession" — the word means acquired treasure, something purchased specifically because it was wanted.

And all of this has a purpose: to declare His excellencies. Your life becomes His advertisement. Every breakthrough you experience is His reputation made visible. Every act of love you extend under pressure is His nature on display.

He called you out of darkness into His wonderful light. That migration was not accidental. He moved toward you specifically, chose you specifically, named you specifically.

You can trust this because this identity wasn't offered on probation. It was declared over you permanently by the God who does not revoke His words.

You are not trying to become special. You are special. Live from that.

Father, I receive my true identity — chosen, royal, holy, and treasured. Not what I hope to become, but what You've already declared I am. Let my life today declare Your excellencies. I am Yours. Amen.""",

"21-12": """God's love didn't find you when you had something to offer — it chose you when you had nothing, and that's what makes it unassailable.

"Once you were not a people" — no identity, no belonging, no standing. Spiritual orphans without a home in God. And then mercy moved. Not because you improved, not because you believed correctly, not because you showed potential — but because God decided to make you His. You went from "not a people" to "the people of God" in one act of pure, unearned love.

That's what mercy actually is: not the reduction of the penalty you deserve, but the gift of belonging you could never purchase. He didn't just forgive your past — He gave you a new present. A new identity. A new family. A new future. All of it given, none of it earned.

Here's what this means for today: if you are having the worst possible morning, if you have failed in every way you know how to fail, your standing with God is unchanged. He chose you before you were anything. He is not choosing you on the basis of what you are today. The love that found you when you were "not a people" is the same love holding you right now.

You can trust this because His love didn't start conditional and it hasn't become conditional. It started as pure gift. It remains pure gift.

You didn't earn your way in. Love welcomed you. And Love keeps you there.

Father, You chose me when I had nothing to offer. Your mercy made me Yours before I deserved it. Today I rest in that — not in my performance, but in Your decision to love me. I am Yours, and that never changes. Amen.""",

"22-12": """God's divine power didn't hand you a starting kit and wish you luck — it gave you everything you would ever need for life and godliness, before you even knew what you'd need.

"Everything pertaining to life and godliness" — that word "everything" is doing heavy lifting. Not most things. Not enough to get by. Everything. Every resource for navigating your actual life — your relationships, your purpose, your spiritual formation, your daily decisions — has already been provided through your knowledge of Him.

Notice how access works: not through performance, not through accumulated spiritual achievement, but through knowing Him. The more intimately you know God's character, the more of what He's already provided you begin to recognize and receive. Relationship is the key. Intimacy unlocks provision.

He called you by His own glory and goodness — not by your track record. Your invitation into this abundance wasn't based on what you'd done or could do. It was based entirely on who He is.

This changes how you approach today's challenges. You are not hoping God will provide enough to get through. He already has. You are not asking Him to equip you. You are already equipped. The question is whether you'll draw on what's already yours.

You can trust this because His generosity is an expression of His nature, not His mood. It doesn't fluctuate.

Father, You have already given me everything I need. Today I draw on what's already mine — through knowing You, trusting You, staying close to You. I am fully equipped for what's ahead. Thank You for Your extravagant provision. Amen.""",

"23-12": """God's love for you is so extravagant that sharing blessings with you wasn't enough — He gave you a share in His own nature.

This is the most remarkable sentence in the New Testament. Not "you will receive gifts from God." Not "you will experience God's presence." Participate in the divine nature. Present tense. Already true. You are a sharer in what God is, not just what He gives.

The pathway is His precious promises. Every promise you believe pulls you deeper into the reality of who God is. Faith isn't just a tool for getting answers — it's the mechanism by which you commune with God's own character. When you trust His faithfulness, you experience His faithfulness. When you receive His peace, you touch His nature. Promise by promise, you go deeper in.

And simultaneously, you have escaped the corruption that is destroying the world around you. Not escaped it by moving away from the world — escaped it from the inside out. The imperishable has taken up residence in the perishable. The divine nature has moved into the human frame.

When you forgive someone who doesn't deserve it, that's His nature flowing through you. When you love generously under pressure, that's His character expressing itself. You're not imitating God — you're participating in who He is.

You can trust this because what God shares, He shares permanently. His nature cannot be partially given and then withdrawn.

Father, I am a partaker of Your divine nature — right now, today. Every promise I believe draws me closer to who You are. I receive Your nature, I live from Your nature, I express Your nature to a world that needs it. Amen.""",

"24-12": """God doesn't simply possess love as one quality among many — love is what He is made of, and everything He has ever done toward you flows from that essential nature.

When John writes "God is love," he means it literally and completely. Not "God is loving" — God is love itself. The source, the substance, the definition of love originates in Him. When you encounter genuine love anywhere in the universe, you are touching something that came from God. He is the origin of it all.

And He proved this love not with words but with the most costly gesture in history: "He sent His one and only Son into the world so that we might live through Him." His only. His most precious. Not a representative, not an ambassador — His Son. The One who was with Him before creation, sent into mortality to give you life. That is not the act of a God who merely feels affection. That is the act of a God who is Love.

You were loved before you existed. You were pursued before you turned. You were redeemed before you deserved it. This love didn't start when you said yes — it started before time and has never wavered.

You can trust this because Love Himself cannot contradict His own nature. He cannot stop loving you any more than He can stop being God. His love is as eternal as He is.

You are not loved by someone who might change their mind. You are held by Love Himself.

Father, You ARE love — not just loving, but love itself. Everything You do toward me flows from that nature. I receive it fully today — not as something I earned but as something You simply are. Thank You for being Love. Amen.""",

"25-12": """God's love toward you is not just strong — it is perfect, and perfect love carries a quality nothing else has: it drives out fear completely.

John makes this personal in a way that should stop you: "In this world we are like Jesus." Not in heaven. Not after we've grown enough. Right now, today, in the middle of your actual life, you share Jesus's standing before the Father. You are as loved, as accepted, as secure as God's own Son. That is your present reality, not your future aspiration.

Fear has a root: the expectation of punishment. The fear that God is disappointed in you, that He might withdraw His favor, that you've gone too far. Perfect love deals with that root at the cross — every punishment was absorbed there. There is nothing left to fear when the One who loves you is also the One who already dealt with everything that could condemn you.

"We love because He first loved us." This sequence matters. You are not the initiator of this relationship. You are the responder. The love that matters most in your life arrived before you — it didn't wait for your move. And it has been moving toward you ever since.

You can trust this because the love that drives out fear is not your love for God — it's His love for you. Your love wavers. His doesn't.

You don't have to manage your fear. Perfect Love drives it out.

Father, Your perfect love is my peace. Right now, in this world, I am like Jesus — completely loved, nothing held against me. Fear has no ground to stand on in the presence of Your love. I receive it fully. Every fear is driven out. Amen.""",

"26-12": """God's love for you is not conditional on circumstances — in every situation, through every storm, you are not just surviving His love but overwhelmingly conquering through it.

Paul doesn't say "nothing bad will happen to you." He says something better: in all these things — tribulation, distress, danger, sword — you are more than a conqueror. The Greek word is "hypernikao": to overwhelmingly triumph, to be completely victorious beyond measure. Not barely making it through. Overwhelmingly winning.

Then Paul names every threat and strips each one of power. Death. Life. Angels. Demons. Present. Future. Height. Depth. Nothing in all creation. He builds an exhaustive list — and at the end of every item, the verdict is the same: cannot separate you from the love of God in Christ Jesus. He covers everything so nothing is left unnamed and unclaimed.

This means your worst days are not outside God's love — they're inside it. The love doesn't pause when circumstances get brutal. It becomes the force through which you conquer what's trying to break you.

"I am convinced" — Paul uses the Greek for complete persuasion, rational certainty. He staked his testimony on this. So can you.

You are not holding on to God hoping He doesn't let go. He is holding you with a grip that nothing in all creation can break.

Father, nothing can separate me from Your love — not my failures, not my fears, not what's happening around me right now. I am more than a conqueror through You. Your love holds me with a grip that will never release. I rest in that completely. Amen.""",

"27-12": """Your Father's giving record is perfect — every good thing in your life can be traced directly to His generous hand, and He has never given anything less than good.

James makes the connection without ambiguity: "Every good and perfect gift is from above, coming down from the Father of lights." Every good thing. Not most good things. Not the obviously spiritual ones. Every good thing — the relationships that sustain you, the moments of unexpected provision, the door that opened when every other door was closed, the peace that arrived when it made no sense. All of it, from your Father.

He is the Father of lights — the source of all illumination, all beauty, all radiance. Every sunrise, every moment of clarity, every creative idea, every time the darkness lifted — it came down from Him. He is the original giver, and generosity is His nature, not His occasional mood.

And He doesn't change like shifting shadows. The generosity you experience today is the same generosity that has always characterized Him. He will be equally generous tomorrow. His track record of giving good and perfect gifts has no gaps, no asterisks, no exceptions.

You can trust this because His giving is an expression of who He is, not a calculation of what you deserve. If He only gave based on merit, you'd have nothing. He gives based on love, and His love is as constant as He is.

Look at what's good in your life today. It came from your Father — every single bit of it.

Father, every good thing I have comes from You. Your generosity is perfect and permanent. Today I receive what You've given with gratitude, knowing it came from love and not from luck. Thank You for being a Father who only gives good gifts. Amen.""",

"28-12": """God didn't measure out love carefully and send you your portion — He lavished it, poured it extravagantly, without restraint, without limit, with the kind of excess that only a Father could justify.

The word "lavish" implies overflow — more than expected, more than enough, more than could be contained. God didn't love you efficiently. He loved you wastefully, scandalously, in a way that makes careful observers uncomfortable. And what did that lavish love produce? Not just forgiveness. Not just access. Sonship — you are called children of God.

John can barely write the next line without an exclamation: "And that is what we are!" He stops to make sure you don't skim past it. This isn't aspirational language. This isn't what you hope to become once you've grown enough. Right now, today, you are God's child. The Creator of the universe claims you as family.

The world doesn't recognize you for the same reason it didn't recognize Jesus — you belong to a kingdom it can't see. Your deepest identity isn't visible to people operating on the world's terms. But it is utterly real.

You can trust this because the love that established your identity didn't count the cost and proceed cautiously. It lavished. And lavish love doesn't take things back.

You are not an orphan hoping to belong. You are a beloved child swimming in love that has no bottom.

Father, You have lavished such great love on me. I am Your child — not someday, not maybe, but now, completely, forever. I rest in the lavishness of Your love today, not striving for more belonging but receiving what You've already given. Amen.""",

"29-12": """God's plans for you stretch so far beyond your current season that they haven't been fully disclosed yet — and what has been revealed is already more than you can imagine.

"What we will be has not yet been made known." Your future glory exceeds your current capacity to picture it. What God is doing in you and for you is larger than the container of your present understanding. The glimpses you've had are real. They are also incomplete. There is more coming than you have seen.

But this much is certain: when Christ appears, you will be like Him. Not similar to Him. Not improved in the same direction. Like Him — completely, permanently, gloriously transformed into the image of the One who is love and light and life. That is your guaranteed destination.

And here's where this gets practical: this future reality is working backward into today. "Everyone who has this hope in Him purifies himself." The certainty of who you're becoming shapes who you are right now. You're not frozen in your current limitations — you're actively being transformed toward the likeness of Jesus, starting now.

You can trust this because the transformation is guaranteed not by your effort but by what you will see. One look at Jesus as He is, and the work is complete. That's how powerful He is.

Your destiny is sealed. Your future is secure. Live from that certainty today.

Father, I am already Your child and my glorious future is guaranteed. I don't have to wonder if I'll make it — You've already decided I will. Today I live from the certainty of what's coming, becoming who You're transforming me into. Amen.""",

"30-12": """God's children don't merely endure the world — they overcome it, and overcoming isn't something you achieve. It's something you were born into.

"Everyone born of God overcomes the world." That word "everyone" eliminates all exceptions. Not the especially faithful. Not the spiritually gifted. Not the ones who have had years of victory and no doubt. Everyone. If you are born of the Spirit, you are an overcomer — that is your identity by birthright.

The victory is already won. You are not climbing toward it. You are not working to accumulate enough faith to finally achieve it. The victory that overcomes the world is your faith — specifically your faith in Jesus, who already overcame. You don't need more faith. You need to fix your faith on the One who has already won.

"Who is it that overcomes the world? Only the one who believes that Jesus is the Son of God." The overcomer is not someone with a perfect record. It's someone with a right confession. You believe Jesus is the Son of God. That belief is itself the victory. It connects you to the One who has already triumphed over everything the world throws at you.

You can trust this because the overcomer at the center of this promise is not you — it is Christ in you. And He has never lost.

You are not hoping to overcome someday. You are an overcomer today. That is who you are.

Father, I am born of You — and everyone born of You overcomes the world. I don't fight for victory; I fight from it. Jesus has already won, and I am in Him. Whatever faces me today meets an overcomer. Amen.""",

"31-12": """God's definition of eternal life will surprise you — it isn't a destination you arrive at after death. It is a relationship that begins the moment you know Him.

Jesus prays in the garden: "This is eternal life: that they know You, the only true God, and Jesus Christ, whom You have sent." Not "eternal life is going to heaven." Not "eternal life is living forever." Eternal life is knowing God and Jesus Christ personally, intimately, in ongoing relationship.

The Greek word for "know" here is "ginosko" — experiential, relational knowledge. Not knowledge about God. Not theological information. Actual communion. The kind of knowing that comes from time spent together, from trust built through experience, from a relationship that deepens over years.

This means eternal life isn't waiting for you on the other side of death. It's available to you right now, in this moment, in this ordinary day. Every prayer where you sense His presence — that's eternal life. Every moment of genuine worship — eternal life. Every time the Word comes alive and you recognize His voice — that is eternity breaking into your morning.

You can trust this because Jesus defined it this way in His own prayer. He didn't say: work toward this. He said: this is what it already is.

The most valuable thing about today is not what you accomplish. It's how deeply you know Him.

Father, eternal life is knowing You — and I know You. Right now, today, I am already living in eternity through this relationship. Let me know You more today than I did yesterday. Every moment I spend in Your presence is eternal life happening in real time. Amen."""
}

with open(FILE) as f:
    data = json.load(f)

devs = data["devotionals"]
updated = 0
for entry in devs:
    date = entry.get("date", "")
    if date in rewrites:
        entry["devotionalText"] = rewrites[date]
        updated += 1

data["devotionals"] = devs
with open(FILE, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"Updated {updated} entries.")
