#!/usr/bin/env python3
"""
Patch January devotionals with rewritten entries.
Targets: 1,400–1,600 chars, 7-paragraph structure, quality checklist compliant.
"""

import json

DEVOTIONALS = {
"01-01": """God's compassions are not recycled — every morning you wake up to mercy that has never been used before.

Jeremiah wrote Lamentations sitting in the rubble of Jerusalem. He watched the city burn. He buried people he loved. And from inside that devastation, he makes this startling discovery: we are not consumed. Not were not — are not. Present tense. God's love was holding him together right now, in the middle of the ruin.

Then the detail that changes everything: they are new every morning. Not mercy stretched thin from last week. Not compassion borrowed from someone else's prayer. New mercy, freshly prepared, for this specific day. The same way the sun rises new every morning and never borrows yesterday's light.

Jeremiah didn't find this because things improved. He found it while still sitting in ashes. The testimony isn't that God removed the suffering — it's that His love was sufficient inside it. His faithfulness is called great. Not adequate. Not barely enough. Great.

You don't earn today's mercy by doing yesterday right. You receive less because last month was a failure. The supply is governed by His character, not your consistency. And His character is faithful — it cannot be otherwise.

Whatever feels depleted in you right now — bring it here. The God who names Himself the Father of compassion has already prepared fresh mercy for today. He knew what you'd be walking into before your alarm went off. His supply is ready.

Father, thank You for mercy that didn't carry over from yesterday — compassion made fresh this morning, for me. I receive it fully. Not because I earned it, but because Your faithfulness is great and Your compassions never fail. You are holding me together right now. Amen. 💜""",

"02-01": """The God who made everything has looked at your life and said something staggering: I am making everything new.

In Revelation 21, John sees a vision so overwhelming that description nearly fails him. Heaven and earth are being renewed. The old order is passing away. And then from the throne itself — not a messenger, not an angel, but the One who sits on the throne — a voice breaks through: I am making everything new.

Then comes the detail that stops everything. God says: write this down. The Creator of all things pauses to make sure something gets documented. Because He knows us. He knows that in a month, when circumstances are still messy and hope feels thin, we'll need something written — not a feeling, not a memory, but a word preserved on a page.

He adds the guarantee: these words are trustworthy and true. That phrase is the backbone of this promise. The newness isn't optimism. It isn't God hoping for the best while things quietly stay the same. It is the word of the One who spoke galaxies into existence — and He is speaking it over whatever has grown old and broken in you.

New is one of God's native languages. He doesn't patch and repair and hope for the best. He makes new. Not restored to what it was. New — a quality that didn't exist before.

Maybe what's old in you is a wound carried too long. A dream gone quiet. Hope itself — the capacity to expect anything good. All of it falls under one word: everything. He said everything.

Lord, You are making everything new in my life. I receive this not because circumstances have changed yet, but because You said it and You are trustworthy. I bring You the old — the broken, the worn out, the things I've stopped hoping about — and I trust You to speak new life. Amen. 💜""",

"03-01": """The same God who started something in you has staked His entire faithfulness on completing it.

Paul writes Philippians from prison. He is chained to a Roman soldier, his ministry interrupted, his freedom stripped away. And yet he writes with stunning confidence about the people he loves: he who began a good work in you will carry it on to completion until the day of Christ Jesus.

Notice the structure. The confidence isn't based on the Philippians' consistency. It isn't conditioned on their performance. It rests entirely on the character of the One who started it. He began it. He will complete it. Both verbs belong to God — not to you.

This is profoundly different from how we usually think. We imagine God started something in us, and now it's our job to maintain it — to not lose ground, to keep performing, to prove we're worthy of the investment. But Paul says God is both the author and the finisher. Your transformation is not a project you've been handed and might botch. It's a work He initiated and has committed to finishing.

The timeline is "until the day of Christ Jesus." Not until you reach a spiritual milestone. Not until your consistency earns it. Until He returns. The work continues regardless of how messy the middle looks.

You may feel unfinished today. You may feel like you've been the same stuck version of yourself for too long. But unfinished is not abandoned. An artist working on a masterpiece looks like an incomplete canvas at every stage until it isn't. God's hands have not left this canvas.

Father, I am confident — not in my ability to hold it together, but in Your faithfulness to finish what You started. I am still in process, and I trust You with the outcome. You don't abandon Your work. Finish what You began in me. Amen. 💜""",

"04-01": """The desire you feel to do what's right — that's not coming from you alone. God is already working inside you.

Philippians 2 contains one of the most clarifying truths in all of Scripture about how transformation actually works. Paul tells believers to work out their salvation with reverence — and then immediately explains why: because it is God who works in you to will and to act in order to fulfill His good purpose.

Break that apart carefully. God works in your will — the part of you that wants, that desires, that chooses. When you find yourself genuinely wanting to forgive someone you have every human reason to resent, that desire is God working in you. When you feel drawn to pray when everything in you would rather not — that's not willpower. That's God. He is the engine behind your wanting.

And He works in your acting — giving you the power to follow through on what He's already stirred in you. The gap between what you want to do and what you actually do is something He has committed to closing.

Reverence in this context isn't about cowering before an angry God. It's the awareness that something eternal is happening in the ordinary moments of your life. A holy God is actively working through your daily choices. That sobers you without crushing you.

This reframes the entire experience of growth. You are not alone in the effort. You are not straining toward a God who is watching to see if you measure up. You are cooperating with a God who has already moved into the process and is committed to His good purpose through your life.

Father, You are at work in me — changing what I want, empowering how I act. I stop straining in my own strength and start cooperating with what You're already doing. Work in my will. Fulfill Your purpose through my life. Amen. 💜""",

"05-01": """God did not choose you in spite of your weakness — He chose you specifically because of it.

The church in Corinth was not impressive by worldly standards. Paul says it directly: not many were wise by human standards, not many were influential, not many were of noble birth. He doesn't soften it. These were people the world had passed over. And then Paul makes the move that changes everything: but God chose the foolish things of the world to shame the wise. He chose the weak things to shame the strong.

This wasn't accidental. It was strategic. The logic is explicit: so that no one may boast before Him. God deliberately builds with materials the world has rejected so that when something extraordinary happens, the source cannot be misattributed. When the weak person does something that requires supernatural strength, nobody congratulates them on their ability. They look for another explanation. They find God.

Your limitation is not a disqualifier. It is the exact context in which God's power gets displayed most clearly. Paul would later describe this as carrying treasure in jars of clay — common containers that make the surpassing value undeniable. The clay doesn't become impressive. The treasure becomes unmistakable.

Stop apologizing for what you don't have. Stop waiting until you feel ready. The gap between what you can do and what God is calling you to isn't a problem — it's the space where He shows up. The people He's used most dramatically have always had the clearest view of their own inadequacy.

You were chosen knowing every weakness you have. That wasn't an oversight. That was the point.

Father, You chose me knowing every limitation I have. I stop hiding my weakness and start offering it. My inadequacy is the canvas for Your power. Use what I am to display what You are. Amen. 💜""",

"06-01": """God looked at everything you would ever need and placed it all inside one Person — and then placed you inside Him.

In the ancient world, wisdom was the most coveted possession a person could have. Philosophers built schools around it. Kings paid fortunes to acquire it. Righteousness — standing right before God — was something generations of priests labored to maintain through endless sacrifice and ceremony.

Then Paul writes one sentence that collapses all of it: it is because of Him that you are in Christ Jesus, who has become for us wisdom from God — that is, our righteousness, holiness and redemption.

Not that Jesus taught wisdom. Not that He modeled righteousness. He became those things for you. He is your wisdom — so every time you are at a loss, every time the path is unclear, you are not without resource. You are in the One who is wisdom itself. You have direct access to the mind that made the universe.

He is your righteousness — meaning your standing before God is not a score you're accumulating. It's a person. And that person is perfect, seated at the Father's right hand, and you are in Him.

He is your holiness — the sacred quality that sets you apart for God isn't your track record of good behavior. It's the nature of the One you're placed inside.

He is your redemption — what was lost has been bought back at the highest price ever paid.

You are not lacking. Whatever you need today, it's already in Him — and you're already in Him.

Jesus, You are everything I need. Wisdom when I'm lost. Righteousness when I feel unworthy. Holiness I couldn't earn. Redemption I couldn't afford. I am in You, and You have become all of this for me. That is enough. Amen. 💜""",

"07-01": """There is one thing worth building your life around — and it has nothing to do with what you've accomplished.

Paul is writing to a church that has fractured over personalities. Some claim Paul as their leader. Others follow Apollos. Others Cephas. They are measuring their spiritual standing by which teacher they belong to. Into this pride-fracture, Paul drops a quote from Jeremiah: let the one who boasts boast in the Lord.

The original context in Jeremiah 9 is devastating. God has just told Israel He is about to judge the nation. And He names the things people typically boast about — wisdom, strength, riches — and says none of it will hold in the day of reckoning. The only boast that stands is knowing Him. Not accumulating impressive theology. Not building a spiritual résumé. Knowing the God who is actually worth knowing.

This is a profound reorientation. The competitive Christianity that compares spiritual depth and ministry output and doctrinal credentials misses the entire point. Your one boast is that you know the God who chose to be known. And He's not a prize you earned — He's a Person who chose you.

There is deep freedom in this. You are released from the exhausting work of maintaining an impressive spiritual record. You don't need to perform for anyone's admiration. You don't need to defend your credentials. You just know Him. And knowing Him is more than enough.

What are you most tempted to build your identity on? Those things will shift and change and eventually fail. But the God you know is the same yesterday, today, and forever. That's the only boast that holds.

Lord, I release every other source of identity. My boast is not what I've done, not how spiritual I appear, not which camp I belong to. My boast is that I know You. And You are more than worth knowing. Amen. 💜""",

"08-01": """You don't have to figure God out — His Spirit has already gone into the deep places and brought back what you need.

The Spirit searches all things, even the deep things of God. That single statement in 1 Corinthians 2:10 changes everything about how you approach knowing God. The Holy Spirit — the third person of the Trinity — actively, continuously searches the depths of the Father's heart, and then shares what He finds with you.

Think about what that means practically. The most profound truths about God's nature, His purposes, His specific thoughts toward you — these are not locked in a vault you have to earn access to. The Spirit has already entered those depths. And He lives inside every believer, carrying that searched-out knowledge with Him.

Paul makes a striking comparison: no one knows the thoughts of a person except that person's own spirit. Another human can observe you, guess, infer — but can never actually enter your mind. Now apply that to God. His thoughts would be permanently hidden, permanently beyond reach — except that you have received the very Spirit who has searched those depths and is now releasing them to you.

This is why Scripture isn't just information. When you read it with an open heart, you're not studying ancient religious text — you're receiving what the Spirit brought back from the deep places of God. He is your access, your interpreter, your guide into the heart of the Father.

You don't have to feel far from God. The One who knows Him most intimately has already moved inside you.

Holy Spirit, thank You for going into the depths of God on my behalf. Open my heart to receive what You've searched out — the things God has prepared for those who love Him. I am not left to guess. You are my direct access to the Father's heart. Amen. 💜""",

"09-01": """The same mind that designed the cosmos has been given to you — not as a metaphor, but as a reality.

Paul asks the rhetorical question straight from Isaiah: who has known the mind of the Lord so as to instruct Him? The expected answer is obvious — no one. The gap between human reasoning and divine wisdom is so vast it's almost absurd to compare them. God's ways are higher than our ways. His thoughts are higher than ours.

And then, without pausing, Paul adds four words that overturn the entire question: but we have the mind of Christ.

Not access to. Not proximity to. We have it. The mind of Christ — the mind that understood the Father perfectly, that saw every situation with eternal clarity, that knew what was truly happening beneath every surface — has been given to every person who is in Christ.

This doesn't mean you're suddenly omniscient. It means you have the capacity to receive divine perspective on any situation when you turn toward the Spirit who lives inside you. When Paul faced imprisonment and death, he had genuine peace — because he was thinking from a different vantage point than his circumstances could provide. The mind of Christ gave him access to a perspective his natural reasoning couldn't reach.

Practically, this means you are not at the mercy of your own thinking when decisions are hard, when confusion is thick, when you don't know what to do. The Holy Spirit, who carries the mind of Christ, is already inside you, ready to illuminate what you cannot see on your own.

You don't have to figure everything out alone. You have the mind of the One who already has.

Jesus, You have given me Your mind. Not my natural thoughts elevated — Your thoughts made available. When I'm confused, when I'm fearful, when I cannot see clearly — let Your mind be the lens through which I see. Amen. 💜""",

"10-01": """Right now, in this moment, you are the place where God has chosen to make His home.

There was a time when the presence of God was localized — contained in a tent, then a temple, then behind a thick curtain in the Holy of Holies. Access was restricted. Protocols were precise. Priests entered with trembling because the holiness there was not safe to approach carelessly.

Then Paul writes to ordinary people in Corinth — not religious professionals, but rough-around-the-edges everyday believers — and asks a question that changes everything: don't you know that you yourselves are God's temple and that God's Spirit dwells in your midst?

Temple. Not a meeting space. Not a gathering room. A temple — a structure built for the permanent habitation of divine presence. The same word used for where the Shekinah glory settled. God is no longer in a building. He is in you.

You are not going to God when you pray. You are recognizing the One already present. You are not trying to enter His presence — you already live there. Every moment of your day, whether you feel it or not, you are a walking dwelling place of the Most High God.

And because you are His temple, you are sacred. Set apart. Marked for His use. God treats you with the care that holy things deserve — because He has moved in and made you His home.

This means you carry something extraordinary into every room today. Every conversation. Every ordinary moment. The presence of God travels with you because you are His address.

Holy Spirit, I receive this fully — You dwell in me, not metaphorically but actually. I am Your temple. Let that truth change how I see myself today, how I walk into rooms, how I handle what I carry. I am not empty. I am inhabited. Amen. 💜""",

"11-01": """The Christian life is not a path toward abundance — it is the life of someone who already has everything.

Paul delivers one of the most audacious statements in all of Scripture at the end of 1 Corinthians 3: all things are yours. He lists what he means — the apostles, the world, life, death, the present, the future. Everything. Yours.

The Corinthians had been organizing themselves by which human leader they followed. Paul finds this tragically backwards. These leaders don't own you — they serve you. The world isn't your threat — it belongs to you. Even death holds nothing over you — it is your final promotion, not your ending.

The logic is airtight: you are of Christ, and Christ is of God. Everything in the chain flows to you. Because you belong to the One who owns everything, you have access to everything. You are an heir, not a beggar.

This changes how you meet a day. Not as someone scraping for enough, nervously watching resources, hoping circumstances cooperate. But as someone who moves through the world knowing the Father's estate is behind every situation. Difficulty is never the final word — because the future belongs to you too.

Life and death are both yours. Think about what that does to fear. If life is yours, then every good thing God has in store is accessible. If death is yours, then even your last breath is a door to more — not a loss. Nothing in the created order has authority over you, because all of it falls within your inheritance.

You are not poor. You are not lacking. You are an heir. Live from that today.

Father, all things are mine through Christ. I release the scarcity mindset. I am an heir of everything — Your life, Your future, Your estate. Let me walk today with the confidence of someone who knows who their Father is. Amen. 💜""",

"12-01": """God didn't just save you from something — He entrusted you with something the angels longed to understand.

Paul opens 1 Corinthians 4 with a reframe so radical it would have shocked his readers. In a culture obsessed with status, where people positioned themselves by social rank, Paul says: regard us as servants of Christ and stewards of the mysteries of God.

Mysteries. In the New Testament context, a mystery isn't something unknowable — it's something hidden in ages past that has now been revealed in Christ. The plan of salvation that prophets strained to see, that angels wondered about, that God held in reserve through the long centuries of human history — that has been entrusted to ordinary people like you.

You are not just saved. You are a steward. A steward in the ancient world was a manager given authority over someone else's household — trusted to act on their behalf. You have been handed the mystery of the gospel — the news that God reconciled the world to Himself in Christ — and commissioned to manage it faithfully.

The requirement Paul names is simple but weighty: those who have been given a trust must prove faithful. Not spectacular. Not impressive. Faithful. Consistent. Reliable in the things that matter most.

This is your identity in a world longing for something true. You carry what people have searched for their whole lives — not a better philosophy or improved religion, but the actual mystery of God, alive and accessible, held in the ordinary container of your daily life.

What does faithfulness look like for you today with what you've been given?

Father, I have been entrusted with the most precious thing in existence — the mystery of who You are and what You've done in Christ. Let me hold it faithfully. Not impressively — faithfully. Make me a steward worthy of what You've placed in my hands. Amen. 💜""",

"13-01": """The night death moved through Egypt, it passed over every door marked with blood — and nothing has changed about how God protects.

When God prepared Israel for their exodus from Egypt, He gave precise instructions. A lamb, without defect. Blood applied to the doorframes. And the promise: when I see the blood, I will pass over you. The destroyer could not enter a home that was marked. The blood wasn't a ritual — it was the visible sign that a substitutionary death had already occurred in that household. The lamb died so the firstborn would not.

Paul identifies Jesus with stunning directness: Christ, our Passover lamb, has been sacrificed. He is not drawing a loose analogy. He is saying every detail of that night in Egypt was pointing forward to a Friday afternoon outside Jerusalem. The lamb on the altar. The blood poured out. The firstborn spared.

You are the one who was marked. Not with the blood of an animal hastily applied to wood, but with the blood of the Son of God — applied permanently, irrevocably, eternally to your life. Every accusation that would condemn you, every consequence you deserve — death passed over you because a Lamb already died in your place.

This is not religion. This is rescue. And it is finished. Done. Sealed.

Paul's response to this is telling: therefore let us keep the Festival with sincerity and truth. The appropriate response to being covered by the Passover Lamb is to live with the authenticity that honors what was paid.

The blood still speaks. Over every guilty memory, every shame, every accusing voice — it says one thing: already covered. Already paid.

Jesus, You are my Passover Lamb. The death that should have been mine became Yours. I receive the full weight of that exchange — fully covered, fully free. Let me live with the sincerity that honors what You gave. Amen. 💜""",

"14-01": """God set the price on your life — and He paid it without hesitation. That number tells you exactly what you're worth to Him.

In the ancient Roman world, slaves were purchased, and the price paid reflected the buyer's judgment of their value. A high price meant the buyer considered the purchase worth it. Paul takes this economic language and charges it with something extraordinary: you were bought at a price. And the price was not silver or gold — it was the life of the Son of God.

That is the number God placed on your worth. That is what He determined you were valuable enough to pay. He didn't negotiate. He didn't look for a discount. He paid everything.

The implication Paul draws from this is staggering in its practical weight: you are not your own. Not in the sense of being controlled — but in the sense that your identity and worth are no longer determined by what the world says about you. The Roman slave's value was set by what the market would pay. Your value was set by what God paid. And He paid the highest price in existence.

So Paul adds: do not become slaves of human beings. Once you know who purchased you, you stop letting every opinion, every criticism, every approval or rejection from people around you determine how you see yourself. You were bought by a different buyer. Your identity comes from that transaction — not from the marketplace of human opinion.

Honoring God with your body flows naturally from understanding this. It's not a burden — it's a logical response. When you know you were purchased by love for an eternal purpose, you want to live in a way that honors the love that bought you.

Father, You paid the ultimate price for me — and that price tells me my worth. I stop letting human opinion set the value You already established. I am Yours. Purchased by love. Amen. 💜""",

"15-01": """The church is the most unlikely community in human history — and that was always exactly the point.

Corinth in Paul's day was a cosmopolitan city: Roman citizens, Greek merchants, freed slaves, Jewish synagogue members, wealthy patrons and struggling laborers. When Paul says we were all baptized by one Spirit into one body — whether Jews or Gentiles, slave or free — he is describing something that could not happen by natural social forces. These groups didn't mix. Status differences in the ancient world were legally and culturally enforced at every level of daily life.

And the Spirit decided to put them all in the same body.

The human body Paul uses as his image is brilliant precisely because you don't choose your parts. Your hand didn't interview for the position. Your eye didn't apply. They were placed — intentionally, purposefully, in relationship to everything else. The ear cannot decide it would rather be an eye. The foot cannot opt out because it isn't a hand.

This isn't a metaphor for passive acceptance. It's a vision of intentional community built on a foundation no human organizer would have chosen. The unity of the body of Christ is not the result of finding people who are like you. It's the result of being placed by the same Spirit into something larger than your preferences.

In a world that fragments endlessly — along racial lines, economic lines, cultural lines — the church is living proof that another kind of community is possible. Not because we decided to be diverse, but because the Spirit of God moved through every human barrier and declared: one body.

Your brothers and sisters may not look like you or think like you. They were placed in your life by the same Spirit who placed you in theirs.

Holy Spirit, You have made me part of something I could never have built. I receive every person You've placed in this body with me. Let the unity You created be something I protect and celebrate. Amen. 💜""",

"16-01": """Every gift you have, every position you're in, every capacity that feels ordinary to you — God put it there on purpose.

Paul is addressing a tension in the Corinthian church: the spectacular gifts feel more important than the quiet ones. The miraculous feels more significant than the steady. The visible seems more valuable than the hidden. And Paul interrupts this entire hierarchy with a simple statement: but in fact God has placed the parts in the body, every one of them, just as He wanted them to be.

Just as He wanted. Not just as was available. Not just as He had to work with. As He wanted — the language of intention, design, a Creator working from a clear vision.

Your placement in the body of Christ is not random spiritual assignment. It is the result of a God who looked at what He was building — the whole, the complete, the beautiful thing He had in mind — and determined exactly where you belong in it. The gifts you have, the temperament you carry, the particular way you see and serve — these are His wanted design for a purpose only you can fill.

Which means the person who feels like a background part is not less important — they are differently essential. A lung doesn't get the credit a hand gets. A kidney works in complete obscurity. But remove either one and the body dies. God places the parts as He wants because He can see the whole — and every single one is necessary.

Stop evaluating your contribution by whether it gets noticed. Stop comparing your placement to someone else's. The One who placed you had the full picture in view when He did it. Your role is exactly where He wanted His body to have that particular function.

You are not an afterthought. You are a wanted design.

Father, You placed me exactly where You wanted me — in this body, with these gifts, in this time. I stop comparing and start functioning. I am needed exactly where You put me. Let me serve faithfully from the place You designed for me. Amen. 💜""",

"17-01": """God's economy inverts everything — the ones the world considers least significant are often the ones He calls most indispensable.

Paul is making a counterintuitive argument in 1 Corinthians 12. The Corinthians were elevating the dramatic gifts — tongues, prophecy, miracles — and devaluing the quieter ones. The visible work felt more important. The public-facing gifts seemed more spiritual.

Paul responds by talking about anatomy. The parts of the body that seem weaker are indispensable. The parts we consider less honorable we treat with special honor. The body actually goes out of its way to protect what seems least impressive.

Think about which organs are hidden versus visible. Your liver never appears in a photograph. Your kidneys work in complete obscurity. But a failing liver kills you. A failing kidney kills you. The hidden, unglamorous, unnoticed work is the work that keeps everything else alive.

God designed the body — spiritual and physical — this way deliberately. He gives greater honor to the parts that lack it so that there should be no division in the body, and so its parts have equal concern for each other.

This is not encouragement for introverts — it is a theological statement about how God values things. The world honors the prominent. God honors the faithful. The world notices the spectacular. God notices the consistent. The world celebrates the visible. God celebrates what happens in secret.

If you have been doing quiet, unnoticed work — praying without acknowledgment, serving in the background, giving without recognition — God does not miss this. He not only sees it. He honors it.

Father, You see the parts that go unnoticed — including me when I feel overlooked. You have not missed a single quiet act of faithfulness. Help me value what You value, honor what You honor, and serve from a place that doesn't need to be seen. Amen. 💜""",

"18-01": """When Paul puts three of the greatest spiritual realities side by side and says love is the greatest, he is telling you something about the nature of God Himself.

Faith moves mountains — Scripture says so. Genuine faith is one of the most significant forces available to a human being. Hope anchors the soul. The writer of Hebrews calls it a firm and secure anchor, something that holds you steady when everything else is unstable.

And Paul says love is greater than both.

Why? Because faith is the means. Hope is the posture. But love is the nature of God. When John writes that God is love — not just loving, but love itself — he is identifying love as the deepest reality in the universe. Faith will eventually give way to sight. Hope will give way to fulfillment. Love is what remains when everything else has been completed.

In the love chapter, Paul has just described what love looks like in action: patient, kind, not envious, not self-seeking. It bears all things, believes all things, endures all things. And then the famous line: love never fails.

This is not a sentiment for greeting cards. It is the most radical claim in existence. In a world where everything eventually fails — bodies, systems, relationships, certainties — love never does. Because love is grounded in the character of a God who cannot change, who is not love's practitioner but love's source.

To love well is not simply a nice thing. It is to participate in the fundamental nature of God Himself — the only thing that will remain when time has finished its work.

Father, You are love, and love is the greatest thing. Grow in me a love that bears all things and never quits. I want to participate in the nature that defines You. Let love be the deepest reality of my life. Amen. 💜""",

"19-01": """Every other force in the universe has a limit. Love is the only one that doesn't.

Paul makes a stunning contrast in 1 Corinthians 13. Prophecies will cease. Tongues will be stilled. Knowledge — even partial knowledge of spiritual things — will pass away. These are not bad things. Prophecy is powerful. Knowledge enables ministry. Tongues can be the Spirit's language in a human mouth. And yet all of them have an end. They serve their purpose and give way to something fuller.

Except love. Love never fails.

The Greek word Paul uses — pipte — means to fall, to drop, to lose effectiveness. Love never drops. Never runs out. Never loses its power to do what it was designed to do. When the age is complete and every spiritual gift has finished its work, love will still be running. Because love is not a means to an end. It is the end.

This is deeply personal. The love God has for you does not have an off switch. It doesn't diminish when you fail repeatedly. It doesn't reset when you go through a season of distance. It doesn't cool off when you stop performing. His love for you cannot fail — and to lose consistency would constitute love failing. That cannot happen.

You are loved with a love that will still be operating when prophecy has finished, when tongues have ceased, when every partial thing has given way to the complete. The most durable force in existence is aimed directly at you.

Nothing can interrupt it. Nothing can outlast it. Nothing can cause it to drop.

Father, Your love for me never fails. I stop treating it as something I have to maintain or earn back. You love me with the only love in the universe that has no off switch. Let that security sink deep into me today. Amen. 💜""",

"20-01": """There is one fact at the center of everything — and if you lose hold of it, nothing else holds together.

Paul is very careful with his language in 1 Corinthians 15. He uses the language of transmission: what I received I passed on to you. This isn't his theological opinion. This is the kerygma — the core proclamation handed down from eyewitnesses. And he names what is of first importance.

Not great importance. Not significant importance. First importance. The primary thing. The thing everything else orbits.

Christ died for our sins. He was buried. He was raised on the third day. Three facts — and Paul says they happened according to the Scriptures. In other words, this was not a surprise ending. This was the story God had been telling since the beginning — through the Passover lamb, through temple sacrifice, through the prophet who said He was pierced for our transgressions — all pointing to this one moment in history.

The burial matters because it confirms the death was real. A body was placed in a sealed tomb. And on the third day, in a specific garden outside Jerusalem, on a specific Sunday morning — the tomb was empty. Over five hundred people saw Him alive afterward. Paul mentions this because the witnesses were still alive when he wrote. You could have gone and asked them.

This is what everything stands on. Not inspiring teaching, not a moral system, not a spiritual philosophy — a Person who died for specific sins and came back from specific death.

That is the center. Everything else radiates from there.

Jesus, Your death and resurrection are of first importance — and I make them first in my life. Every truth I believe radiates from this: You died. You rose. You changed everything forever. Amen. 💜""",

"21-01": """The first Adam received life. The last Adam became the source of it — and this difference changes everything about who you are.

Paul draws one of the most theologically loaded contrasts in all of his letters. The first man Adam became a living being — direct from Genesis. God breathed into his nostrils and dust became a person. Adam received life. He was a recipient — something that began from outside himself and was given to him.

But the last Adam — Jesus — is a life-giving spirit. He does not receive life. He dispenses it. He is the source. When Lazarus lay in a tomb four days dead, Jesus didn't ask for help or borrow power. He simply said: come forth. And life moved. That is not a man who has life — that is a man who is life.

Paul notes the order: the natural came first, then the spiritual. You were born into Adam first. Dust, mortality, a nature that strains and fails and eventually gives way. Every human being enters the world on Adam's terms — receiving a life that is already counting down.

But in Christ, you are connected to the last Adam — the One who is not a recipient but life's eternal source. You carry now not just the breath of God in your nostrils but the Spirit of the risen Christ inside you. A different nature. A different origin. A different kind of life altogether.

You bear both images — Adam's and Christ's. But the work of the Spirit is to increasingly express the image you were remade for: the image of the heavenly man.

You are not just dust with a ceiling. You are being conformed to the image of the One who gives life itself.

Jesus, You are the last Adam — not a recipient of life, but its source. I am connected to You. I carry Your nature, not just Adam's. Transform my living into something that reflects the image of heaven. Amen. 💜""",

"22-01": """Death had a weapon. Christ took it — and death has been standing in the ring unarmed ever since.

Paul breaks into one of the most ecstatic passages in all of his letters. He has just finished explaining the resurrection — the transformation from perishable to imperishable, from mortal to immortal. And then, like someone who cannot contain himself, he turns and taunts death directly: Where, O death, is your victory? Where, O death, is your sting?

This is a legitimate, Spirit-fueled taunt. Because death has been defeated and Paul cannot help but say so.

The sting of death is sin. Death's power — its ability to bring ultimate separation and ultimate consequence — came from sin. Sin gave death its authority. Remove sin's grip and death becomes a door rather than a grave.

Then: the power of sin is the law. The law could name the violation but couldn't provide the solution. It could specify the debt but couldn't pay it. Which is exactly what Christ did — He fulfilled the law, absorbed its full condemnation, died the death sin required, and rose out from under it entirely.

Death has nothing left. The sting is gone. The victory is gone. What remains is a door — and on the other side of that door is imperishable, immortal, resurrection life.

You don't have to be afraid of death. Not because death isn't real, but because it has been definitively disarmed. The worst it can do is release you into more of what you already have in Christ.

Thanks be to God — He gives us the victory through our Lord Jesus Christ.

Jesus, death has no sting for me — You removed it. Sin has no condemnation for me — You bore it. I live free of death's fear. You've already won, and I share in that victory. Thanks be to God. Amen. 💜""",

"23-01": """The resurrection is not just a future hope — it is the present foundation that makes you impossible to shake.

Paul ends his great resurrection chapter not with a philosophical conclusion but with a practical instruction: therefore, stand firm. Let nothing move you. Always give yourselves fully to the work of the Lord, because you know that your labor in the Lord is not in vain.

The word therefore carries enormous weight. It connects everything Paul just said about resurrection to how you live right now. Because death has been defeated. Because the imperishable is coming. Because what was sown mortal will be raised immortal. Therefore — stand firm.

Stand firm is a military image — a soldier who will not be moved from position. Unmoved by opposition, by pressure, by discouragement, by the enemy's tactics. Not stubbornness — rootedness. And the root is the certainty of the empty tomb. Nothing that comes against you can dislodge you from that.

Let nothing move you. Think about what tries. Fear of the future. Weariness from prolonged effort with no visible results. The feeling that your work doesn't matter, that no one noticed, that it amounted to nothing. Paul answers all of it in one line: your labor in the Lord is not in vain.

Not a single prayer. Not a single act of faithfulness. Not a single sacrifice. Not a single word spoken in love. None of it disappears. In a world where so much human effort dissolves into nothing, God has established this: what is done in Him has eternal weight.

The resurrection means your work outlasts your death. That's not sentiment — that's the logic of the empty tomb.

Father, I stand firm — not because I'm strong, but because the resurrection is certain. My labor in You is not wasted. I give myself fully to what You've called me to, knowing that what is done in You lasts forever. Amen. 💜""",

"24-01": """God does not comfort you by removing the trouble — He comforts you by entering it with you.

Paul opens 2 Corinthians with a word of praise — but the praise he chooses is unexpected. He doesn't thank God for eliminating his hardships. He praises the Father of compassion and the God of all comfort, who comforts us in all our troubles.

All our troubles. Not some. Not the ones big enough to qualify. All. The Greek word — thlipsis — means pressure, affliction, the crushing kind of difficulty that has weight. God comforts in that. In the middle of it. Not only after it passes — but inside it, while it's still happening.

Then Paul reveals a dimension to this comfort that makes it even more significant: so that we can comfort those in any trouble with the comfort we ourselves receive from God. The comfort God gives you is not just for you — it moves through you. Your suffering, and God's presence inside it, equips you to stand with someone else in a way that generic sympathy cannot.

Paul knew this firsthand. He was not writing from an armchair about hypothetical hardship. He was writing from prison, from beatings, from shipwreck, from the daily pressure of churches full of people who needed more than he had. And he found God there — not a God who explained the suffering or eliminated it, but a God who showed up inside it with tangible, personal comfort.

Your trouble is not a sign that God has stepped back. It is the context in which you may most clearly experience the God who calls Himself the God of all comfort.

Father of compassion, I bring You my trouble — not asking You to explain it or remove it immediately, but asking You to be present in it. Comfort me so I can comfort others. Be God in my exact situation today. Amen. 💜""",

"25-01": """Every promise God has ever made carries a signature — and the signature is Jesus.

In the ancient world, a letter was only as reliable as the seal attached to it. Break it open and see the king's seal, and you knew the content carried authority. It came from the source. It had backing behind it.

Paul says something extraordinary about the promises of God: no matter how many promises God has made, they are Yes in Christ. Every single one. Not the impressive ones and not the smaller ones. Not the ones from Isaiah and not the ones from Deuteronomy and not the ones scattered through the Psalms. Every one. Yes.

The mechanism is Christ. He didn't just teach about the promises — He fulfilled them. His obedience, His sacrifice, His resurrection activated the inheritance of every covenant word God had ever spoken. Your response is Amen — so be it — spoken through Him, to the glory of God.

Then Paul adds something personal and profound: God has anointed you, set His seal of ownership on you, and put His Spirit in your hearts as a deposit. Three things — anointed, sealed, given the Spirit as a down payment. You are not just told that the promises are yes. You are stamped with the guarantee. The Spirit inside you is the first installment of a transaction that will be fully completed when Christ returns.

This matters on difficult mornings, when the promises feel distant and circumstances feel loud. You go back to the seal. You go back to the Spirit inside you — who is himself the proof that God's yes is already active in your life.

The promises are not maybe. They are Yes — signed with the most authoritative name in the universe.

Father, all Your promises are Yes in Christ — and I say Amen. I receive them not because circumstances support them today, but because Your seal is on my life and Your Spirit is Your guarantee in me. Amen. 💜""",

"26-01": """There is a kind of religion that kills the people it touches — and then there is the Spirit, who does the opposite.

Paul makes a stark contrast in 2 Corinthians 3. He is reflecting on two covenants — the old, written on stone; the new, written by the Spirit. And he draws the most arresting line: the letter kills, but the Spirit gives life.

The letter here is not Scripture itself — it is law without grace, religion stripped of relationship, requirements without the resource to meet them. The Pharisees in Jesus' day were experts at the letter. They could parse the law to its finest detail. And Jesus looked at the people they produced and said they were twice as burdened as before. The letter, applied without the Spirit, produces condemnation, shame, exhaustion, and finally death.

But the Spirit gives life. The same Spirit who hovered over formless chaos in Genesis 1 and brought order and life out of nothing — that Spirit is at work in you, not to condemn but to transform. Not to demand but to empower. Not to expose your failures without provision, but to lead you into the truth that sets you free.

Paul says God has made us competent ministers of this new covenant — not the letter, but the Spirit. Which means when you bring your faith into someone else's life, the most powerful thing you can do is not provide a stricter standard or a better argument. It is to carry the life-giving presence of the Spirit into the room.

You are not a prosecutor. You are a life-giver. You carry the new covenant — not the one that condemns, but the one that sets free.

Holy Spirit, I don't want to minister the letter — I want to bring life. Flow through me with new covenant freedom. Let what I carry into rooms make people more alive, not more burdened. Amen. 💜""",

"27-01": """Transformation doesn't announce itself — it moves like light filling a room as the sun rises.

Paul describes something in 2 Corinthians 3:18 that is easy to underestimate: with unveiled faces we all reflect the Lord's glory and are being transformed into His image with ever-increasing glory. The transformation is real. It is happening. But its mode is not sudden or dramatic — it's progressive. Glory to glory. More of His image, continually, through continued exposure to Him.

The contrast Paul sets up is with Moses, who came down from meeting God with a radiance that terrified the people — and then faded. Moses wore a veil because the glory was diminishing and he didn't want Israel to see it fade. The old covenant produced moments of brightness that couldn't be sustained.

But the new covenant produces something entirely different: ongoing, cumulative transformation. Not a flash of brightness that dims, but a process that moves in one direction — more of His image, more of His character, more of His glory reflected in your actual daily life.

Where the Spirit of the Lord is, there is freedom. This is the environment in which transformation happens — not under compulsion or fear, but in the freedom of relationship. You are not being forced into conformity. You are beholding Someone and becoming what you see. The most natural process in the world.

This means you don't manufacture spiritual transformation or engineer it through discipline alone. You need to look. Fix your gaze on who He is — in Scripture, in prayer, in the moments you recognize Him in your day. Stay there. The transformation follows the beholding.

Holy Spirit, I trust the process. I stop straining and start beholding. Do what only You can do — transform me from glory to glory into the image of the One I keep looking at. Amen. 💜""",

"28-01": """You were not made to search for your purpose — you were made to walk into what God already prepared.

The Greek word Paul uses in Ephesians 2:10 for what we are is poiema — the same root we get poem from. You are not a product on an assembly line. You are a crafted work. Something made with intention, care, and artistry by a Creator who knows exactly what He is doing.

And this poem was written for a purpose. Created in Christ Jesus to do good works, which God prepared in advance for us to do. Prepared in advance. The works are not improvised as you go. They were laid out, made ready, before you arrived at the moment that requires them. The works exist. They are waiting.

This changes the entire weight of the question most people carry: what is my purpose? The question assumes purpose is something you discover or create, something you might find if you search long enough. But Paul says the works were already prepared. Your role is not to invent them — it is to walk into them.

This does something significant to how you meet a day. When you step out your door in the morning, you are not going into randomness hoping something meaningful happens. You are stepping into a prepared landscape — one in which the Craftsman has already placed the work that your particular shape fits. Not someone else's shape. Yours.

People who walk in purpose are not people who figured something out that others haven't. They are people who stopped asking whether they have a purpose and started paying attention to what is already prepared in front of them.

You are His poem. Walk into the stanzas He's already written.

Father, I am Your crafted work — made with intention for works You already prepared. I stop searching anxiously and start walking attentively into what You've laid out. The prepared works will become clear as I follow You. Amen. 💜""",

"29-01": """The love that brought you to life didn't wait for you to deserve it — it moved first, while you were still dead.

Paul's construction in Ephesians 2 is precise and devastating in the best way. He starts with what you were before: dead in transgressions and sins, following the ways of this world, gratifying the cravings of your sinful nature. He does not soften this. Dead. Not struggling. Not spiritually suboptimal. Dead.

And then come two words that change everything: but God.

Not but you decided to change. Not but you eventually showed up. But God. He acts first. He moves into death before there is any sign of life to encourage Him. Because of His great love for us, God, who is rich in mercy, made us alive with Christ.

Rich in mercy. Not sufficient mercy. Not occasional mercy. Rich — overflowing, abundant, in excess of what was asked. The mercy God brought to your deadness was not the bare minimum required. He brought everything.

And the timing exposes the nature of the love: while you were dead. Not while you were improving. Not after you showed promise. While you were spiritually lifeless, unresponsive, and in no position to offer anything back. That is when He moved.

This is what grace means in its most fundamental form. It precedes your response because it doesn't require your response to begin. God initiated. You were the one raised. You are not the hero of your own salvation story — you are the one who came back from the dead, carried entirely by love that needed no reason beyond itself.

Father, You loved me back to life when I was dead — not when I improved, not when I showed up. Your great love and rich mercy acted first. I am alive because You moved. All credit belongs to You. Amen. 💜""",

"30-01": """You are not working your way up to a seat at God's table — you are already seated, and the chair is permanent.

Paul describes something in Ephesians 2:6 with past-tense verbs that describe a completed action with ongoing results: God raised us up with Christ and seated us with Him in the heavenly realms in Christ Jesus. Raised. Seated. Both finished. Both still in force.

Your position is not a ladder you are climbing. It is a reality you have been placed into. When you came to faith in Christ, you weren't positioned at the bottom of a spiritual hierarchy with the chance to work your way toward significance. You were seated — the same word used for a king taking his throne — in Christ, in the heavenly realms, right now.

Then Paul gives the purpose: in the coming ages, God will show the incomparable riches of His grace, expressed in His kindness to us in Christ Jesus. You are not just saved — you are a demonstration. Your life is an ongoing exhibit of what God's grace looks like when it operates. In the ages to come, your story will be evidence of His kindness.

Think about that. The eternal God chose to make His grace visible in the universe by seating the unworthy in places of honor. You are one of those. Your seat at the table is not evidence of how good you are — it is evidence of how good He is.

Live from that seat today. Not striving toward it. Not wondering if you've earned it. Not afraid you might lose it. Seated. Secure. Permanently placed in the position love prepared.

Father, I am already seated with Christ — not working toward it, but placed in it. Let me live from that security today. I am a display of Your grace. Let my life show people what Your kindness looks like. Amen. 💜""",

"31-01": """If salvation could be earned, it wouldn't be a gift — and God chose to give, not to sell.

Paul's statement in Ephesians 2:8-9 is one of the most quoted in Scripture, and one of the most misunderstood. For it is by grace you have been saved, through faith — and this is not from yourselves, it is the gift of God — not by works, so that no one may boast.

Every human religious system, regardless of tradition, shares a common logic: you perform the right things and accumulate standing. You do well enough and the divine accepts you. The quality of your behavior determines the quality of your position before God.

Paul says the gospel is the radical inversion of this logic. Saved by grace — God's unearned, undeserved favor was the mechanism. Through faith — the posture that receives rather than performs. And then, in case anyone thinks faith counts as the work that earns the gift: this is not from yourselves. Even the faith is not something you generated. It is the gift of God.

The purpose is explicit: so that no one may boast. The entire structure is designed to eliminate spiritual pride at its root. If you contributed ten percent to your salvation, you'd have grounds for ten percent of the boasting. But if the whole transaction — grace, faith, completion — was God's gift, then all the boasting belongs to Him.

This is freedom. Not because standards don't matter, but because your standing before God is not determined by how well you maintain them. You are not saved by performance, sustained by performance, or one failure away from losing what grace freely gave.

Father, I receive what I cannot earn. Salvation is Your gift — not my achievement. I bring no boast except in what You have freely given. Thank You for the grace that saves completely. Amen. 💜"""
}

def main():
    filepath = 'SpeakLife/SpeakLife/Preview Content/AffirmationData/devotionals.json'
    
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    devs = data['devotionals']
    jan_dates = [d['date'] for d in devs if d['date'].endswith('-01')]
    
    print(f"Found {len(jan_dates)} January entries")
    print()
    
    # Check all dates in DEVOTIONALS match january entries
    missing = set(jan_dates) - set(DEVOTIONALS.keys())
    extra = set(DEVOTIONALS.keys()) - set(jan_dates)
    if missing:
        print(f"WARNING: Missing devotionals for: {missing}")
    if extra:
        print(f"WARNING: Extra devotionals not in file: {extra}")
    
    # Patch
    updated = 0
    for d in devs:
        date = d['date']
        if date in DEVOTIONALS:
            d['devotionalText'] = DEVOTIONALS[date]
            updated += 1
    
    # Save
    with open(filepath, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"Updated {updated} January entries")
    print()
    
    # Verify
    print("=== VERIFICATION ===")
    failures = []
    for d in data['devotionals']:
        date = d['date']
        if date.endswith('-01'):
            text = d.get('devotionalText', '')
            char_count = len(text)
            ends_amen = text.strip().endswith('Amen. 💜')
            has_tabs = '\t' in text
            in_range = 1400 <= char_count <= 1600
            status = "✅" if (in_range and ends_amen and not has_tabs) else "❌"
            if not (in_range and ends_amen and not has_tabs):
                failures.append(date)
            print(f"{status} {date} | {char_count} chars | amen:{ends_amen} | tabs:{has_tabs}")
    
    print()
    if failures:
        print(f"FAILURES: {failures}")
    else:
        print("ALL JANUARY ENTRIES PASS VALIDATION ✅")

if __name__ == '__main__':
    main()
