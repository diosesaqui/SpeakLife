#!/usr/bin/env python3
import json

march_rewrites = {

"01-03": """The cross isn't a decoration. It's a declaration. God looked at every system humanity invented to measure worth — achievement, status, religion, performance — and destroyed every single one through a single act of love at Calvary.

That's who God is toward you: a Father so committed to your freedom that He didn't offer a better ladder to climb. He tore the ladder down. Paul understood this. After a lifetime of elite religious achievement, he counted it all as worthless compared to the cross. Not because effort is wrong, but because the cross made striving for acceptance completely unnecessary.

Think about the scorecards you carry today. The ones whispering you're behind, not enough, or still unproven. The cross answered every single one of them before you woke up this morning. When Jesus said "It is finished," the world's entire grading system shut down.

This means you are free. Free from chasing approval. Free from fearing rejection. The world's applause was never the point. Because of the cross, you're a new creation — and that identity doesn't shift with your circumstances or your performance.

You can trust this because Paul wrote it from prison. Not from a comfortable study. He boasted in the cross when it cost him everything. If the cross held through that, it will hold through whatever you're facing today.

Let the cross be your only trophy. Not what you achieved this week. Not what you survived. Just the cross. Just Christ. That is enough. That is everything.

Lord Jesus, I boast only in Your cross. The world's verdict no longer defines me. Through Your cross I am free — a brand-new creation, fully accepted, fully alive. That's my identity and my confidence today. Amen.""",

"02-03": """You didn't wake up this morning needing to earn blessing. You woke up already blessed — fully, permanently, in every dimension that matters. God didn't hold any back. He released every spiritual blessing into your life the moment He placed you in Christ.

That's who God is toward you: a Father whose nature is to give completely, not partially. The verse says He "has blessed" — past tense, finished action. Heaven's treasury was opened over your life before your feet hit the floor today. Not because you performed well yesterday. Because you belong to Christ.

This is how it works on a normal, Monday-morning kind of day. You feel the weight of what you lack. You see what's missing. But God sees something entirely different. He sees a child He chose before the world existed, already clothed in every spiritual blessing He ever intended to give.

Because of this, you don't need to beg God for what He already gave. You can thank Him for what is already yours. That shift — from begging to receiving — changes the entire posture of your prayer life. You're not a beggar. You're an heir who already inherited everything.

You can trust this because God's choosing happened "before the creation of the world." He wasn't responding to you. He was initiating. That kind of love doesn't fluctuate based on your morning. It was settled in eternity.

Open your hands today. Not to grasp for more, but to receive what's already yours. You are fully blessed. Completely chosen. Thoroughly loved — before you ever did anything to deserve it.

Father, You have blessed me with every spiritual blessing in Christ! I am not waiting for favor — I already have it all. Thank You for choosing me before creation. I receive what You've already given with a grateful and open heart. Amen.""",

"03-03": """Adoption is the most extravagant legal act a parent can choose. Nobody adopts by accident. It is deliberate, costly, and motivated entirely by love. And that is exactly how God brought you into His family — with full intention, at great cost, driven by love alone.

That's who God is: a Father who wanted you so specifically that He planned your adoption before time began. This wasn't a rescue operation that happened because things went sideways. Paul says God predestined this "in accordance with His pleasure." It pleased Him. He wanted this. He chose you on purpose.

And this isn't a lesser form of family membership. Adopted children in the Roman world received full legal rights — same inheritance, same name, same standing as biological children. You are not a second-tier son or daughter. You are a full heir. Everything that belongs to Jesus belongs to you by virtue of your adoption.

This means when life feels like you don't belong anywhere, you have a permanent address: the family of God. When you feel unworthy of love, remember — your worthiness isn't the reason you were chosen. His love is. And His love doesn't change.

You can trust this because it cost God everything. Redemption through Christ's blood isn't a cheap transaction. It's the full price of your full belonging. He didn't adopt you halfway. He went all the way.

You are wanted. Not tolerated. Wanted. Chosen. Fully included. Let that settle in your chest right now and change how you walk through this day.

Father, You adopted me as Your own child — and it was Your pleasure, Your plan, Your joy. Thank You for redemption through Jesus' blood and forgiveness according to the riches of Your grace. I am Your child, fully belonging, fully loved. Amen.""",

"04-03": """God doesn't save you and then wonder if you'll make it. He saves you and seals you. The moment you believed, the Holy Spirit Himself became the mark of divine ownership on your life — and nothing has the authority to remove that seal.

That's who God is: a Father so committed to keeping you that He didn't just give you a promise to hold onto. He gave you a Person. The Holy Spirit living inside you is not a feeling. He is a covenant guarantee. A legal deposit on your eternal inheritance, placed there by God Himself.

Think about what a seal meant in Paul's day. It marked ownership. It guaranteed authenticity. It couldn't be broken without consequence. When God sealed you with His Spirit, He was declaring to all of heaven and earth: "This one is Mine." You carry that mark right now, on your worst day, in your most uncertain season.

This means your standing with God is not based on your consistency. It's based on His seal. You didn't earn the Holy Spirit by being faithful enough — you received Him the moment you believed. And He remains not because you've maintained Him but because God's word doesn't break.

You can trust this because a deposit guarantees what's coming. You already have the down payment of glory inside you. That's not wishful language. That's a legal term — an ironclad promise that everything God has prepared is on its way to you.

You are sealed. Marked. Secured. The Holy Spirit is not your guest — He is your guarantee. He is the proof that you belong to God, today and forever.

Holy Spirit, You are my seal and my guarantee. Thank You for marking me as God's own from the moment I believed. My inheritance is secured, my belonging is certain, and Your presence in me is the proof. I am Yours. Amen.""",

"05-03": """There is a hope attached to your life that the enemy doesn't want you to see clearly. It's not wishful thinking. It's a specific, God-assigned calling backed by incomparable power — and God wants the eyes of your heart wide open to it.

That's who God is: a Father so invested in your spiritual vision that He sends His Spirit to illuminate what your natural eyes can't see. Paul prays this over the Ephesians not because they lack intelligence but because the deepest truths of God's love require supernatural sight. God wants you to see what He sees when He looks at your life.

Here's what He sees: an inheritance so rich it can only be called "glorious." A calling loaded with purpose. And the same resurrection power that rolled the stone away from the tomb — working right now on your behalf. That power isn't reserved for special occasions. It's the ongoing atmosphere of the life He's called you into.

This means you are not limited by what you see in the natural today. Your circumstances are not your ceiling. God has assigned incomparable power to your life — the same power that defeated death itself — and it's available not someday, but now.

You can trust this because resurrection power is not a metaphor. It reversed the irreversible. It conquered what nothing else could touch. If God can raise the dead, He can handle what you're facing this morning.

Open the eyes of your heart today. There is more happening in your life than what you can see. Your calling is real. Your inheritance is glorious. The power inside you is greater than anything in front of you.

Father, open the eyes of my heart to see the hope of my calling and the riches of my inheritance. The same power that raised Christ from the dead is working in me right now. I receive that revelation with gratitude and awe. Amen.""",

"06-03": """Every power that has ever threatened you — every voice that said you're too small, every force that pressed against you, every name invoked to intimidate — operates far beneath the One seated at God's right hand. Jesus is not just above some authorities. He is above all of them. Every single one.

That's who God is: a Victor who didn't just win the battle — He was exalted to the seat of all authority in the universe. Paul reaches for the most expansive language he can find: every rule, every authority, every power, every dominion, every name — not just now, but in the age to come. He's leaving nothing out. Jesus is above it all.

This truth was written to people living under real pressure — the Roman Empire, spiritual opposition, social persecution. Paul wanted them to see that every power they feared was already under the feet of their Savior. The same is true for you. Whatever threatens your peace today exists in a realm where Jesus reigns supreme.

Because of this, you don't have to live in fear of what feels bigger than you. Fear assumes that the threat is the highest power in the room. But you belong to the One who is seated far above every name that can be named. That changes the entire calculation.

You can trust this because this isn't a future promise — it's a present reality. Jesus is seated now. The victory is not pending. All things are already under His feet. You live under the authority of the One who has already won.

You are not at the mercy of forces beyond your control. You are under the protection of the One who controls everything. Rest in that today.

Father, Jesus is far above every power and authority — and I am in Him. Nothing that threatens me today has authority over my life that You haven't already defeated. I stand in the victory of Christ, confident and free. Amen.""",

"07-03": """God has a plan. Not a rough outline, not a contingency strategy — a specific, beautiful, long-purposed mystery that He has been moving toward since before time began. And He didn't keep it secret from you. He made it known.

That's who God is: a Father who invites you into the depth of His purposes rather than leaving you guessing at the edges. The mystery Paul describes isn't cosmic trivia. It's the revelation that everything — absolutely everything in heaven and on earth — is being brought into unity under Christ. History has a destination. And it's glorious.

This means your life isn't a random collection of moments. Every season you've walked through, every detour you didn't choose, every door that closed — God's hand has been weaving you toward something. He purposed this "in Christ" before the foundation of the world. You are not an accident. You are part of the greatest story ever told.

Because of this, you can release the anxiety of trying to make sense of everything right now. You don't have to understand the whole chapter to trust the Author. God's pleasure and will are carrying you toward a fulfillment you cannot yet fully see — but that He has already secured.

You can trust this because He revealed the mystery rather than hiding it. A God who opens His purposes to you is a God who wants you to know where you stand. You're not outside His plan — you're woven into it.

The plan is good. The Author is faithful. The ending is already written. Walk through today knowing you are held in the middle of a story that God Himself is telling.

Father, thank You for making known the mystery of Your will. My life is not random — it's purposeful. I am part of Your great story, moving toward fulfillment in Christ. I trust Your plan completely, in every season. Amen.""",

"08-03": """The two most important words in your theology might be these: But God. Before you could do anything right, before you could clean yourself up, before you had any spiritual momentum at all — But God. He moved first.

That's who God is: a Father who is rich in mercy and whose great love acts on your behalf even when you are dead in sin. This is the sequence Paul gives us. Dead in trespasses. Then — not after improvement, not after effort — God made you alive. The initiative was entirely His. The power was entirely His. The only thing you brought to your salvation was the need for it.

This is what grace looks like in practice. You were spiritually lifeless, and God didn't send a self-help program. He breathed resurrection life into you. Made you alive together with Christ. Not ahead of schedule because you showed promise — but by grace, freely, completely.

This means no matter how dead something in your life feels right now, it is not beyond the God who raises the dead. That relationship. That hope. That area you've written off. God specializes in the "even when." Even when it looks impossible. Even when you're out of ideas. Even when you can't believe it anymore.

You can trust this because He didn't wait for you to deserve His mercy. Rich in mercy means His supply never runs low. Great love means the motivation never fades. He loved you when you were at your worst — He hasn't changed now.

"But God" is still the most powerful phrase in the room. Whatever sentence describes your situation today, that phrase rewrites the ending.

Father, even when I was spiritually dead, You made me alive with Christ. Your mercy is rich and Your love is great. Thank You for acting before I could. Thank You for the grace that changed everything. I am alive because of You. Amen.""",

"09-03": """God is not done with you. He is not watching from a distance, wondering how you'll turn out. He is actively at work inside you — through the Spirit, through the Word, through every circumstance — forming Christ in you with the intensity of a loving parent who will not give up.

That's who God is: a Father whose investment in your transformation is personal and relentless. Paul describes himself in the pains of childbirth — that's not casual language. That's the picture of someone who cannot rest until the work is complete. God's commitment to your formation is that passionate. That specific. That unwilling to settle.

Christ formed in you is not a metaphor for being nicer or trying harder. It's a supernatural process happening in the deepest part of who you are — your thinking, your desires, your responses, your identity. The Holy Spirit is conforming you, from the inside out, to the image of Jesus Himself.

This means that the frustrating season you're in right now might be exactly where the deepest formation happens. Pressure reveals character — but more than that, pressure is often where God's hand does its most precise work. He is not punishing you in hard seasons. He is forming you.

You can trust this because God doesn't start what He doesn't finish. He who began a good work in you will carry it to completion. The formation of Christ in you is His project, not yours — and His projects don't fail.

You are a work in progress and a masterpiece at the same time. Both are true. The One forming you knows exactly what He's doing.

Lord, thank You that You are forming Christ in me with passion and purpose. I trust the process even when it's uncomfortable. You started this work and You will complete it. Shape me, Lord — I am Yours. Amen.""",

"10-03": """Freedom is not a reward for the spiritually advanced. It is your birthright as a child of God, secured by Christ on the cross and released to you the moment you believed. You were called to it. Not called toward it — called to it. You already live there.

That's who God is: a Liberator who called you to freedom, not to a stricter version of religion. The call Paul describes is a legal summons to a new way of existing. Not "try to become free someday" — you were called to freedom. The verb is already complete. The freedom is already yours.

Here's how this plays out on a real Tuesday. The guilt from yesterday pulls at you. The old patterns whisper you're still bound. The law voice says you haven't done enough. And into all of that, the gospel speaks: you are free. Not because your behavior finally qualified, but because Christ's cross was sufficient.

This freedom changes how you relate to other people too. People who know they're free don't need to control. People secure in their identity don't have to compete. The fruit of real freedom is love — the kind that serves without keeping score, gives without expecting return.

You can trust this because freedom was the point of the cross all along. "It is for freedom that Christ has set us free." Not freedom to drift, but freedom to love. Not freedom from responsibility, but freedom from the crushing weight of performance-based worth.

Walk in your freedom today. Not recklessly. Not selfishly. But boldly — the way someone walks who knows they've been permanently liberated by the most powerful act in history.

Lord Jesus, I was called to freedom and You secured it at the cross. I refuse the weight of condemnation and the chains of performance. I walk free today — and from that freedom, I love. Thank You for this gift. Amen.""",

"11-03": """The Holy Spirit is not a force you manipulate. He is a Person you walk with. And He didn't come into your life to give occasional assistance — He came to be your life source, the very breath of your new existence in Christ.

That's who God is: a Father who sent His Spirit not as a distant helper but as a daily companion for the journey. "Since we live by the Spirit" — that's your identity. You are a Spirit-alive person. This isn't a level of Christianity you graduate into. It's what happened the moment you believed. The Spirit came to live in you, and now His life powers yours.

Keeping in step with the Spirit is the most natural thing a Spirit-alive person can do. Not striving, not performing — walking. One step at a time. Staying close enough to hear, sensitive enough to respond, trusting enough to follow even when the path doesn't make sense yet.

This means today's decisions don't have to feel overwhelming. You're not navigating alone. The Spirit of God who raised Jesus from the dead is actively guiding you, speaking to your heart, aligning your steps with God's purposes. You have access to divine wisdom in every ordinary moment.

You can trust this because the Spirit's guidance is not conditional on your perfection. He lives in you by grace, not by merit. And His presence is permanent — Jesus called Him the Spirit of truth who would be with you forever.

You are not alone today. You are Spirit-led, Spirit-empowered, and Spirit-kept. Keep in step. Stay close. The One walking with you knows every step of the path ahead.

Holy Spirit, I live by You and I walk with You. Thank You for being my daily companion, not just my occasional helper. I stay in step with You today, trusting Your lead in every decision, every conversation, every moment. Amen.""",

"12-03": """Nobody was designed to carry everything alone. God wired you for community specifically because some weights are too heavy for one person — and the act of sharing them is how the love of Christ becomes visible in the earth.

That's who God is: a Father who built the capacity to bear one another's burdens right into the design of the body of Christ. When Paul says this fulfills the "law of Christ," he's pointing to Jesus' own command to love one another as He loved us. The heaviest love Jesus showed was carrying what we couldn't. You are invited into that same love.

Burden-bearing looks like showing up when it costs you something. It looks like sitting with someone in their grief without rushing to fix it. It looks like asking "how are you really?" and waiting for the true answer. It looks like carrying someone in prayer when their faith feels too small to believe for themselves.

This means you don't have to pretend your burdens don't exist, and you don't have to perform strength you don't have. Real community creates space to set things down. And real maturity looks like accepting that help — letting someone else step in and carry what's too heavy for you today.

You can trust this because Jesus Himself is the ultimate burden-bearer. He took on the weight of sin, shame, and separation — none of which were His to carry. That same Spirit of selfless love lives in every believer and is calling us into the same practice.

Let someone carry something with you today. Let someone in. The body of Christ was built for exactly this moment.

Lord Jesus, thank You for bearing what I couldn't. Give me the humility to let others help carry my burdens, and the love to bear theirs without hesitation. This is how Your love becomes real. Amen.""",

"13-03": """Your most important identity is not what you used to do, where you came from, or what religion you practiced. It's this: you are a new creation. Not a reformed version of the old one. Not an improved edition. Something entirely new — brought into existence by God Himself the moment you believed.

That's who God is: a Father who doesn't renovate — He creates. The Greek word Paul uses is kainos, meaning new in quality and kind. God didn't take your old life and make it better. He made you something the world has never seen before — a person who is alive with the life of Jesus Himself.

This is the thing that counts, Paul says. Not religion. Not ethnicity. Not your track record. Not your past sins or present failures. What counts is the new creation. And you are that. Right now. On your worst day. In your weakest moment. The verdict hasn't changed: you are new.

This means the old labels don't get to define you anymore. The shame from your past doesn't have jurisdiction over your present identity. The person who used to react that way, used to struggle with that thing, used to believe those lies — that person was crucified with Christ. What you're looking at in the mirror today is a new creation.

You can trust this because God declared it, not you. And God's declarations don't get overruled by your feelings, your failures, or anyone else's opinion.

You are new. Not almost new. Not new in progress. New — completely and permanently. Walk in it today.

Father, thank You that I am a new creation in Christ. The old is gone. The new has come. My identity isn't built on what I used to be — it's built on what You made me. I walk in my new creation identity today with confidence and joy. Amen.""",

"14-03": """Peace and mercy aren't rewards handed out to people who finally get it right. They are the signature blessings of a God who moves first — dispensed freely, to all who live by the rule of grace, not the rule of performance.

That's who God is: a God of peace and mercy whose nature is to bless. The blessing Paul pronounces isn't a hope — it's a declaration. Peace. Mercy. Right now. To everyone who follows the way of grace. Not after enough effort. Not after enough time. Now.

Peace means the war is over. The striving is finished. The need to prove yourself to God has been completely removed by the cross. You don't have to earn your standing — it's a gift. And mercy means that even the days when you fall short don't separate you from God's covering. His mercy meets you exactly where you are.

This is what a grace-saturated life feels like on an ordinary day: you can stop bracing for punishment and start living in the open air of God's favor. You don't have to earn His peace — you receive it. You don't have to qualify for His mercy — you rest in it.

You can trust this because God's peace surpasses understanding. It doesn't make sense by the world's logic. You shouldn't feel settled in the middle of uncertainty — but you do, because it comes from the Prince of Peace Himself.

Let peace rule today. Not the peace that comes from everything going well, but the peace that comes from knowing you are in the hands of a good God whose mercy never runs out.

Father, Your peace and mercy are mine through Christ. The war is over. I don't have to earn what You've already given. I receive Your peace in my heart right now and rest in Your mercy that never runs out. Amen.""",

"15-03": """Grace is not just the door you walked through to enter salvation. Grace is the atmosphere you live in every single day. It follows you into Monday morning. It's present in your failure. It covers your uncertainty. It is with your spirit — the most intimate part of who you are.

That's who God is: a God whose grace is not a one-time transaction but a permanent companion. "The grace of our Lord Jesus Christ be with your spirit" — this is the last thing Paul says to the Galatians. The final word. The thing he wants ringing in their ears as they close the letter. Grace. Not try harder. Not do better. Grace.

Grace with your spirit means God's favor is operating at the deepest level of your being. Not just blessing your behavior or your ministry — blessing the real you, the innermost you, the you that nobody else sees. His grace reaches that far. And it stays there.

This means you don't have to perform for grace. You don't have to sustain it. You don't have to earn its continued presence. It is a gift that keeps giving, a river that keeps flowing, a love that keeps showing up — whether you feel worthy of it or not.

You can trust this because grace is defined by what it costs the giver, not what it requires of the receiver. Jesus paid everything. Your only response is to receive it with open hands and a grateful heart.

Let grace be the first thing you breathe in today. Not effort. Not guilt. Not pressure. Grace — freely given, deeply personal, right here with your spirit.

Lord Jesus, Your grace is with my spirit today. Not because I earned it — because You gave it. I receive it fully. It covers me, strengthens me, and keeps me. Your grace is enough. Your grace is everything. Amen.""",

"16-03": """In Christ, you are not becoming complete. You are not working toward fullness. You already have been brought to fullness. The Greek is past perfect — a completed action with ongoing results. You were completed, and you remain complete. Right now. Today.

That's who God is: a God who makes complete, not partial. In Christ lives the fullness of God — every attribute of divinity, every ounce of divine nature, inhabiting Him in bodily form. And Paul's next breath is: and in Christ, you have been brought to that fullness. Whatever is in Christ belongs to you because you are in Christ.

Think about what that means for the moment you're in. You feel spiritually inadequate? You are complete in Him. You feel like something is missing? You have been brought to fullness. You feel like you lack what it takes? Every resource of heaven is yours in Christ — not as a future promise, but as a present possession.

This is the radical claim of the gospel: your spiritual supply is not based on your spiritual performance. You don't have to fill a deficit. You are already full. You carry the fullness of Christ everywhere you go, into every meeting, every conversation, every moment of weakness.

You can trust this because the fullness of deity dwells in Christ, and He lives in you. That's not hype. That's the settled reality of what happened when you believed.

Walk through today as a complete person. Not striving toward fullness — walking from it. You lack nothing that matters. You are filled with the One who fills all things.

Father, thank You that I have been brought to fullness in Christ. I am not incomplete or lacking. Everything I need is already mine in Him. I walk through today confident in the fullness You've placed in me. Amen.""",

"17-03": """Death couldn't hold Jesus. And it didn't hold you either. When He went into the grave, you went with Him. When He walked out three days later in resurrection power, you walked out too. That's not metaphor — that's your actual biography in Christ.

That's who God is: a Father who didn't just rescue you from sin — He brought you through death into brand-new life. Baptism pictures the reality: buried with Him, raised with Him. Your old self — with all its debt, its shame, its bondage — went into that grave. What came out is a resurrection person, alive with the same power that rolled away the stone.

This changes how you face what feels like dead ends today. The empty tomb is the proof that God specializes in what looks finished. What the enemy calls over, God calls the starting point for something new. Resurrection isn't just a historical event — it's the ongoing pattern of how God operates in the lives of His people.

Because of this, you can face what is dying in your life without fear. Your marriage, your hope, your faith, your sense of purpose — nothing is too far gone for the God who raised Jesus. He is still in the resurrection business.

You can trust this because the working of God is the same power that raised Christ from the dead. Paul doesn't say similar power or inspired power. Same power. The exact same resurrection force that defeated death is at work in your life.

You are a resurrection person. Buried with Christ, raised with Christ, alive in Christ — right now, on whatever ordinary or impossible day this is for you.

Father, I was buried with Christ and raised with Him to new life. The same power that raised Jesus operates in me right now. I declare that no dead end in my life is final, because You are a resurrection God. Amen.""",

"18-03": """The debt was real. The charges against you were documented, itemized, and legal. And then God did something so decisive, so final, that there is nothing left to argue about: He canceled it. Not deferred it. Not restructured it. Canceled — and nailed the record to the cross as a public declaration that it is gone forever.

That's who God is: a Father who doesn't hold spiritual debt over His children. The word Paul uses for "canceled" is the Greek word for wiping a slate completely clean — the way you'd erase writing from a wax tablet until nothing remained. God looked at every charge against you and obliterated the record.

This is what the cross accomplished: the legal case against you was dismissed. Not reduced. Not appealed. Dismissed. Jesus didn't just pay your debt — He destroyed the documentation. When the enemy whispers your past failures back at you, he's reading from a document that no longer exists. The record was nailed to the cross.

Because of this, you never have to carry guilt about sins you've confessed. The forgiveness God offered isn't conditional on how you feel about it. The cancellation is complete regardless of whether you feel forgiven this morning. Your feelings don't reverse God's legal declaration.

You can trust this because the cross is a public event in history. It happened. It is done. The debt was real and the cancellation was real — equally real, equally permanent.

Walk out from under guilt today. It has no legal claim on you. The record is canceled. The case is closed. The debt is gone. That is the unchangeable verdict of the cross.

Father, thank You for canceling every charge against me and nailing it to the cross. The debt is gone — completely, permanently. I refuse to carry what You have already cancelled. I walk free in the finished work of Christ. Amen.""",

"19-03": """Nobody gets to move the goalposts that God has already declared null and void. The rules of the old covenant — festivals, dietary laws, Sabbath regulations — were shadows pointing toward something. The something they were pointing to has arrived. His name is Jesus. And the shadow disappears when the real thing shows up.

That's who God is: a God who fulfills and supersedes, who replaced the shadow with reality. The Law was never the destination — it was a sign. And now that Christ has come, you don't live by the sign anymore. You live by the reality the sign was always pointing toward.

This means nobody has the spiritual authority to evaluate your standing with God based on your religious compliance. Not fasting schedules. Not meeting attendance. Not dietary choices. Not ritual observances. The measuring stick has been abolished. Christ is the reality, and if you are in Him, you pass every test.

Because of this, you can stop auditing your own spiritual performance against checklists that were never meant to be permanent. God's delight in you is not indexed to your religious output. You are in Christ — and in Him, you are fully accepted, fully righteous, fully pleasing to God.

You can trust this because Paul's language is decisive: these things are "a shadow of what is to come; the substance belongs to Christ." When you have the substance, you don't need the shadow anymore. Christ is your reality.

Live in the reality today. Not under the shadow of performance. In the light of the One who fulfilled every requirement and freely gives you His standing.

Lord Jesus, You are my reality — the fulfillment of everything the Law pointed toward. I stand in Your righteousness, not a checklist of my own. No one can judge my standing in God because You are my standard and my surety. Amen.""",

"20-03": """You are not living under old rules that no longer apply to you. You died with Christ to the elemental forces of this world. That death was real. The old system lost its claim on you at the cross, and going back to live under it isn't humility — it's amnesia.

That's who God is: a Liberator who didn't just forgive your sin — He severed the power structure that sin operated within. The "elemental spiritual forces" Paul describes were the basic frameworks of the world's system — religious performance, rule-keeping, status-seeking. They can't save you. They never could. And you died to them.

This is what it looks like practically: rules like "do not handle, do not taste, do not touch" had an appearance of wisdom and self-discipline. But they couldn't deal with the heart. They couldn't transform desire. They only managed behavior from the outside. God's way goes deeper — it changes who you actually are.

Because of this, you don't need to manage your spiritual life with an ever-growing list of external restrictions. The life Christ gives you isn't about what you can't do — it's about who you have become. Identity changes behavior far more powerfully than rules ever could.

You can trust this because you died with Christ, and that death was complete. You cannot be half-dead to the world's system. You are either under it or free from it — and if Christ is your life, you are free.

Live from your identity today. You are not a rule-keeper straining under the old system. You are a new creation who died with Christ and now lives with Him. That is your actual address.

Father, I died with Christ to the old system that could never save me. I don't live there anymore. My life is hidden with Christ in God. I live today from that freedom, not from the pressure of rules that have no power over me. Amen.""",

"21-03": """You have been raised with Christ. That sentence changes everything about where you live mentally, emotionally, and spiritually. You are not down here, struggling to get up there. You are up there, seated with Him — and the invitation is to set your heart and mind on the reality of where you actually are.

That's who God is: a Father who raised you with His Son and seated you in heavenly places. Your address has changed. You are not just trying to survive this life — you are living from the resources of a higher kingdom. The throne room of God is your reference point, not the chaos of today's circumstances.

Setting your heart on things above isn't spiritual escape from real life. It's getting your perspective calibrated to the highest reality so that the lower realities stop running you. When you know you're seated with Christ, the opinions of people lose their grip. When you see from heaven's vantage point, the mountains that loom large look different.

Because of this, you have access to a perspective that your circumstances can't provide. Peace that doesn't make sense. Hope that doesn't depend on good news. Confidence that isn't shaken by what you see — because what you see isn't the whole picture.

You can trust this because God placed you there — in Christ, in the heavenly realms. This isn't a position you climb to. It's a position you were raised into. And raised people don't have to scramble.

Lift your eyes today. Set your heart on things above — not as an escape, but as a homecoming. You live up there. That's your permanent address.

Father, I have been raised with Christ and seated in heavenly places. I set my heart on things above today — where Christ is, where I truly live. Thank You that my perspective comes from the throne room, not from my circumstances. Amen.""",

"22-03": """Grace is not permission to stay the same. It's the power to actually change. God doesn't free you from sin so you can keep indulging it — He frees you so you can finally put to death the things that were killing you. And He gives you the resurrection power to actually do it.

That's who God is: a Father who offers real transformation, not just legal acquittal. Paul's language is strong — "put to death." Not "manage carefully" or "be careful around." Put to death. The old patterns, the old cravings, the old gravitational pulls — they don't have to be permanent roommates. The same power that raised Jesus from the dead is available to you for this work.

Here's the order that makes this possible: identity first, behavior second. Paul doesn't say "stop doing bad things so God will accept you." He says "you have been raised with Christ — now put to death what belongs to your earthly nature." The acceptance came first. The transformation flows from it.

This means you're not fighting these battles in your own strength, trying to be good enough. You're living from a new nature that genuinely desires better. The Holy Spirit in you doesn't just tell you what to stop — He gives you the desire and the power to actually stop it.

You can trust this because God finishes what He starts. He didn't set you free from sin's penalty only to leave you helpless before sin's power. He conquered both. The same cross that forgave you is the same cross that empowers you.

You have the power to lay down what was destroying you. Not through willpower — through the Spirit of the living God who dwells in you.

Father, I have resurrection power available to me. I choose to put to death what belongs to my old nature — not in my own strength, but through Your Spirit who lives in me. Thank You for making real transformation possible. Amen.""",

"23-03": """Who you used to be has been taken off — like a coat you shed at the door. Who you are now is who Christ made you: new, renewed, being transformed daily into the very image of the God who created you. You are not the same person who walked in before Christ. You have a new self. Wear it.

That's who God is: a Creator who is actively renewing you into His image. The renewal Paul describes isn't passive — it's ongoing. "Being renewed" is present-tense, active-voice transformation. God didn't fix you once and step back. He is constantly at work, bringing you deeper into alignment with your true self — the self He designed you to be.

The old self came with its old practices: deception, pretension, the exhausting performance of being whoever the room needed you to be. But the new self doesn't need to perform. It doesn't have to manage its image or protect its reputation. It can tell the truth — because its identity is secured not by others' opinions but by God's declaration.

Because of this, you can stop pretending. You can drop the mask. The person you've been hiding — the real, honest, struggling-but-loved version of you — is exactly the person Christ died for. And exactly the person God is renewing into glory.

You can trust this because the renewal isn't based on your consistency. It's based on His. The One who began this work in you is faithful to complete it.

You are clothed with the new self today. Put it on fully. Wear your identity in Christ without apology, without pretense, without fear. You are being renewed into the image of your Creator.

Father, thank You for giving me a new self in Christ. I put off the old and put on the new — renewed in knowledge, transformed into Your image. I walk today as the person You made me to be, not the person I used to be. Amen.""",

"24-03": """Before God tells you how to live, He tells you who you are. You are chosen. You are holy. You are dearly loved. These aren't goals you're working toward — they're the identity you already carry. And it is from this identity that every virtue flows.

That's who God is: a Father who clothes His children with identity before He calls them into character. Notice the order Paul uses. He doesn't say "be compassionate so God will love you." He says "as God's chosen people, holy and dearly loved — clothe yourselves with compassion." The who comes before the how, every single time.

This changes everything about how you approach this day. Compassion, kindness, humility, gentleness, patience — these aren't performance requirements for someone trying to earn love. They're the natural clothing of someone who knows they are already loved. A child secure in their parent's love doesn't perform. They simply live from what they know.

Because of this, even the hard things — bearing with people who frustrate you, forgiving those who hurt you — become possible when you're living from the right foundation. Forgiveness flows naturally from someone who knows they've been forgiven. The Lord forgave you freely. That freedom makes it possible to offer the same.

You can trust this because God didn't call you "chosen" and "dearly loved" based on your progress report. He called you that based on what Christ did. That foundation doesn't shift.

You are chosen, holy, and dearly loved — right now, today, as you are. Live from that. Everything else will follow.

Father, I am Your chosen one — holy and dearly loved. I live today from that identity, not from performance. Out of the love You've poured over me, I clothe myself with compassion, kindness, humility, and grace. Thank You for loving me first. Amen.""",

"25-03": """Peace is not the absence of conflict. It is a Person — and He wants to sit on the throne of your heart and govern every decision, every reaction, every fear. The peace of Christ isn't a feeling you work up. It's a Ruler you let in.

That's who God is: a God of peace who designed your inner life to be ruled by something stronger than anxiety. Paul's word for "rule" is the Greek term for an umpire who calls the game. The peace of Christ is meant to be the umpire of your heart — calling safe or out, green or red, move forward or stop. When His peace rules, you don't have to figure everything out yourself.

This is what it looks like in real life: you're facing a decision and you don't know which way to go. You're in a conversation that could go badly. You're carrying news that could unravel things. In all of it, the peace of Christ is available as your inner guide — not feelings of ease, but a settled knowing that comes from trusting the One who holds everything.

Because of this, you can stop operating from anxiety as your default. Anxiety asks "what if everything goes wrong?" Peace answers "God is still God, and His goodness doesn't depend on this going right." That's not denial — that's the umpire making a call.

You can trust this because you were called to peace — it's your design. God didn't wire you for perpetual stress. He called you to live in the atmosphere of Christ's peace as a natural state.

Let peace rule today. Open the throne room of your heart to the One who was born Prince of Peace. He governs well.

Father, I let the peace of Christ rule in my heart today. Not just visit — rule. I release every anxious thought to You and receive the peace that surpasses understanding. You are my peace, and I trust You completely. Amen.""",

"26-03": """Nothing in your day is secular to God. Not the emails, not the commute, not the meeting you're dreading, not the meal you'll cook tonight. Every single thing you do can be done in the name of Jesus — and when it is, the ordinary becomes sacred and the mundane becomes worship.

That's who God is: a God who inhabits all of your life, not just the spiritual parts of it. "Whatever you do" — Paul leaves nothing out. Word or deed, public or private, meaningful or mundane. All of it can be offered to God in Jesus' name. All of it can carry the weight of eternity when it's done for Him.

Living in Jesus' name means living with His authority, His character, and His purpose as the backdrop of everything. It means the way you treat the difficult coworker is a spiritual act. The way you handle the frustrated customer is a form of ministry. The patience you show in traffic is an act of grace that reflects the nature of Jesus Himself.

Because of this, no part of your day is wasted. No ordinary moment is beneath God's attention. When you give thanks to the Father through Jesus in the midst of the routine, you are participating in something much larger than you can see.

You can trust this because God crafted you for a whole life — not a bifurcated one with a spiritual compartment and a secular one. His lordship is comprehensive. His name covers everything.

Every word today. Every action today. All of it in Jesus' name. All of it an offering. All of it worship.

Lord Jesus, I do everything today in Your name — with Your authority, for Your glory, as an act of worship. No part of my day is outside Your presence. I give thanks to the Father through You in all of it. Amen.""",

"27-03": """You are not working for a human audience. Your real employer is Jesus Christ — and He is both the most demanding and the most generous master who has ever existed. He sees every effort you make, honors every act of integrity nobody else notices, and guarantees an inheritance that no company could ever offer.

That's who God is: a God who sees and rewards faithfully, who doesn't miss a single thing done for His name. The reward Paul describes isn't a metaphor — it's an inheritance. A family asset passed from father to child. You are working today not for a performance review or a year-end bonus. You are building toward an eternal inheritance that God Himself has secured for you.

This changes how you show up when nobody is watching. When the task is invisible and the appreciation is absent. When you're doing the thing that doesn't get acknowledged or applauded — God sees. He is keeping a record of faithfulness that the world will never see but that heaven has fully documented.

Because of this, you can pour everything you have into today. Not out of drivenness or striving — but out of joy, knowing that your work in Jesus' name is never wasted. Even the small things done wholeheartedly for God carry eternal weight.

You can trust this because God's reward system is not based on outcomes — it's based on faithfulness. You might not see the results of your faithfulness today. But the One you're serving sees, and His reward is certain.

Work with all your heart today. Every task, every hour, every honest effort — you are serving Christ. And He is a master who rewards generously and remembers completely.

Lord, I work today as working for You, not for human recognition. You see every act of faithfulness, and Your reward is sure. I give my whole heart to whatever is in front of me today, knowing I serve the most generous Master there is. Amen.""",

"28-03": """Your life is hidden. Tucked away in the safest place in the universe — inside Christ, inside God. The enemy cannot reach you there. Failure cannot define you there. The world's noise cannot penetrate where you truly live. You are hidden with Christ in God, and that is the most secure address in existence.

That's who God is: a Father who hides and protects and holds. Your life isn't exposed and vulnerable to the forces trying to take you out. It's concealed in the One who conquered death. You died to the old life and your real life is now stored somewhere your circumstances cannot touch.

Think about the weight that removes. You don't have to protect your reputation — it's hidden in Christ. You don't have to defend your worth — it's secured in God. You don't have to grasp for significance — you already have it in Him. The things the world says you should fight hardest to hold, God has already safely placed beyond reach of anything that could destroy them.

Because of this, you can hold the things of this world with open hands. When you know your real life is hidden with Christ, you don't have to grip so tightly. The loss of something temporary doesn't threaten what is eternally secure.

You can trust this because when Christ — who is your life — appears, you will appear with Him in glory. That's the end of the story. And it's a good one.

Your true life is safe. It is held. It is hidden in the most unassailable place there is. Nothing that happens today can touch where you truly live.

Father, my life is hidden with Christ in You. I am safe, secured, and held. I release the things I've been gripping too tightly, knowing my true identity and worth are beyond the reach of anything that could take them. Christ is my life. Amen.""",

"29-03": """In Christ, every wall that divided humanity collapses. The distinctions that the world uses to sort and rank and separate — ethnicity, background, status, history — all of them dissolve in the presence of One who is all and is in all. There is no hierarchy in the body of Christ. There is only Christ.

That's who God is: a unifier who is himself the great equalizer. When Paul lists the divisions that no longer count — Gentile, Jew, barbarian, Scythian, slave, free — he is tearing down the deepest fault lines of his world. And the thing that replaces all of it isn't a new set of categories. It's a Person. Christ is all. And Christ is in all.

This is what the kingdom looks like on a real Tuesday: the person you'd normally dismiss has Christ in them. The person whose story is nothing like yours carries the same Spirit you carry. The unity God calls you to isn't based on common background or shared opinions. It's based on a common Lord who indwells every believer.

Because of this, you can see people differently. Not through the lens of what separates you, but through the lens of who unites you. Christ is in them. The same grace that reached you reached them. The same blood that purchased your freedom purchased theirs.

You can trust this because Christ being "all in all" is not a feeling — it's a fact. His presence is not selective. His indwelling is not partial. Where the Spirit is, He is fully present.

Look for Christ in the people around you today. You'll be surprised where He's been hiding — in plain sight, in the people you least expected.

Father, Christ is all and is in all. Thank You that in Him, every dividing wall has fallen. I choose to see people through the lens of Christ today — the One who unites us, indwells us, and makes us one. Amen.""",

"30-03": """Everything else you wear is incomplete without it. Compassion without love becomes cold and mechanical. Humility without love slides into self-deprecation. Patience without love turns into quiet resentment. But love — the love Paul describes here — binds everything together into something that is actually whole. It is the outermost layer that holds it all in place.

That's who God is: a God who is love, and whose love is the unifying force behind all virtue. The image Paul uses is striking — love as a belt or outer garment that binds everything else into perfect unity. Without it, the other virtues scatter. With it, they become a seamless expression of Christ's own character in you.

This isn't the love you manufacture on a good day. It's the love that flows from being loved first. The sequence in Scripture is always the same: we love because He first loved us. The love of God, poured out in your heart by the Holy Spirit, becomes the source from which all other love flows.

Because of this, the love you're called to show today — to difficult people, in frustrating situations, when it costs you something — is not something you have to conjure up alone. You are loved perfectly and permanently by God Himself. That love overflows into how you treat others when you're connected to the Source.

You can trust this because God's love never fails. It never runs dry. It never gets tired of you. And the same love that covers you is the love He places in you to give away.

Put on love today. Last layer. Most important layer. The one that holds everything else together in perfect unity.

Father, I put on love — Your love — as the outermost layer of everything I wear today. It binds together every other virtue. I love because You first loved me, and Your love never runs out. Amen.""",

"31-03": """The Word of Christ was never meant to be stored in a book on a shelf. It was meant to move into you — to take up residence in the depths of your thinking, your praying, your singing — and dwell there richly. Not thinly. Not occasionally. Richly. Like a deep-rooted tree that shapes everything it grows through.

That's who God is: a Father who wants His Word to be fully at home in you, not just visited on Sundays. The word "dwell" Paul uses means to be at home — to inhabit, to settle, to be permanently resident. God's desire is for the message of Christ to be so thoroughly woven into your inner life that it naturally overflows into everything you say and sing and teach.

This is what it looks like when the Word dwells richly: you reach for truth instinctively in the moment of crisis. You sing in the hard moments because worship is the language of someone whose heart is full of something better than fear. You encourage others from the overflow, not from an empty tank.

Because of this, the time you spend in Scripture is never wasted. Every verse that goes in is a seed taking root. Every psalm you sing strengthens the soil. The richness of what dwells in you determines the richness of what comes out of you.

You can trust this because the Word of God doesn't return empty. When it dwells in you, it does what it was designed to do — transform, strengthen, renew, and ground you in what is true and unshakeable.

Let the Word of Christ dwell in you richly today. Open the door wide. Let it in all the way. Let it change what you think, what you say, and what you sing.

Father, let the message of Christ dwell in me richly today. Not thinly — richly. I open every room of my heart to Your Word. Fill me with wisdom that overflows into worship, gratitude, and life-giving words for those around me. Amen."""

}

# Load the full JSON
with open('SpeakLife/Preview Content/AffirmationData/devotionals.json') as f:
    data = json.load(f)

# Update March entries
updated = 0
for entry in data['devotionals']:
    if entry['date'].endswith('-03') and entry['date'] in march_rewrites:
        entry['devotionalText'] = march_rewrites[entry['date']]
        updated += 1

print(f"Updated {updated} March entries")

# Save
with open('SpeakLife/Preview Content/AffirmationData/devotionals.json', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print("Saved successfully")

# Verify char counts
for entry in data['devotionals']:
    if entry['date'].endswith('-03'):
        chars = len(entry.get('devotionalText', ''))
        status = "✅" if chars >= 1400 else "❌"
        print(f"{status} {entry['date']} | {chars} chars")
