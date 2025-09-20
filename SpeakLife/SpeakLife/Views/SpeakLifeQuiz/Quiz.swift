//
//  Untitled.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 5/13/25.
//

import Foundation

struct Quiz: Identifiable {
    let id: UUID = UUID()
    let title: String
    let questions: [(String, [String], Int, String)]
}

let questions = [
    (
        "The enemy whispers, 'You're not good enough.' What do you do?",
        ["Agree and try harder", "Ignore it", "Speak God's truth aloud", "Complain to a friend"],
        2,
        "Declare with authority: 'I am the righteousness of God in Christ' (2 Cor. 5:21). You’re not fighting for worth — you're standing in what Jesus already finished."
    ),
    (
        "Anxiety begins to rise — what’s your first response?",
        ["Accept it as normal", "Declare 'God has not given me a spirit of fear'", "Distract yourself", "Call someone"],
        1,
        "Your words are weapons. Speak 2 Tim. 1:7 — and peace will silence the storm. Fear has no legal ground."
    ),
    (
        "Symptoms hit your body suddenly — how do you respond?",
        ["Panic", "Pray silently", "Declare healing Scriptures", "Search online for answers"],
        2,
        "Isaiah 53:5 isn’t a maybe — it’s a blood-bought fact. Speak it: 'By His wounds, I AM healed.' The Word carries the healing itself."
    ),
    (
        "The devil says, 'You’ll never change.' What’s the truth?",
        ["Maybe that’s true", "Say nothing", "Declare 'I am a new creation in Christ'", "Try to prove him wrong"],
        2,
        "2 Cor. 5:17 — You're not improving the old you; you’re living from a completely new nature."
    ),
    (
        "Your finances look hopeless — what do you say?",
        ["Cry", "Declare God is your provider", "Blame yourself", "Work more hours"],
        1,
        "Declare: 'My God shall supply all my needs' (Phil. 4:19). God isn’t reacting to need — He responds to faith in His promise."
    ),
    (
        "In the middle of a trial, how do you honor God?",
        ["Complain", "Stay silent", "Worship and give thanks", "Wait to see what happens"],
        2,
        "Psalm 34:1 — Praise turns pressure into breakthrough. Your worship is warfare."
    ),
    (
        "The devil whispers, 'You're alone.' What do you speak?",
        ["It's true", "Call a friend", "Declare 'God will never leave me'", "Cry it out"],
        2,
        "Hebrews 13:5 — God promised never to leave you. Say it until your feelings bow to it."
    ),
    (
        "You feel shame from your past. What do you declare?",
        ["Own it", "Bury it", "Speak 'I’m forgiven and free'", "Try harder to be better"],
        2,
        "Romans 8:1 — There’s zero condemnation in Christ. Shame has no voice when grace is spoken."
    ),
    (
        "How do you renew your mind and transform your life?",
        ["Ignore bad thoughts", "Think positive", "Read and speak God’s Word aloud", "Pray only at church"],
        2,
        "Romans 12:2 — Transformation flows from hearing and declaring truth, not just thinking it."
    ),
    (
        "The enemy says, 'Your future is doomed.' What’s your reply?",
        ["Believe it", "Speak Jeremiah 29:11", "Worry silently", "Wait and see"],
        1,
        "Speak life: 'God’s plans are for my hope and future.' Faith doesn’t echo feelings — it echoes God's voice."
    ),
    (
        "You feel unworthy to pray — what do you declare?",
        ["Stay silent", "Try to fix yourself", "Declare your righteousness in Christ", "Ask someone else to pray"],
        2,
        "Hebrews 4:16 — Boldness isn’t arrogance, it’s confidence in Jesus’ finished work. You’re always welcome."
    ),
    (
        "Healing feels slow — what should you keep doing?",
        ["Doubt it", "Keep declaring the Word", "Complain", "Give up"],
        1,
        "Hebrews 10:23 — Hold fast your confession. The healing began when you believed, not when you felt it."
    ),
    (
        "Symptoms return after prayer. What do you speak?",
        ["Accept them", "Stand on God's promise", "Search for other options", "Blame yourself"],
        1,
        "Symptoms don’t override the Word — the Word overrides symptoms. Speak healing until your body agrees."
    ),
    (
        "The enemy says, 'You’ll always be stuck.' What do you declare?",
        ["Maybe he’s right", "Hope it gets better", "Declare freedom in Jesus", "Stay quiet"],
        2,
        "John 8:36 — 'Whom the Son sets free is free indeed.' Speak it until you see it."
    ),
    (
        "You don’t see change yet — what do you believe?",
        ["It’s not working", "God’s Word is still true", "I must be missing something", "Quit"],
        1,
        "Isaiah 55:11 — The Word never returns void. Keep watering your promise — harvest is coming."
    )
]


let healingQuizQuestions = [
    (
        "What’s the first step to walking in divine healing?",
        ["Beg God to heal you", "Keep reading healing testimonies", "Hear and believe God’s Word", "Try natural remedies"],
        2,
        "Healing doesn’t start with begging — it begins with revelation. Romans 10:17: 'Faith comes by hearing.' You can’t believe what you haven’t heard."
    ),
    (
        "Symptoms return — what’s your first move?",
        ["Accept them", "Speak God's Word louder", "Change your prayer", "Try harder"],
        1,
        "Symptoms are lies trying to reclaim territory. Speak louder: 'By His stripes, I was healed' (Isaiah 53:5). Truth spoken resists deception."
    ),
    (
        "What does it really mean to prioritize God’s Word?",
        ["Make time when convenient", "Read it once a week", "Feed on it daily like food", "Quote it only in emergencies"],
        2,
        "Proverbs 4:22 says His Word is life and health. If your body needs daily nourishment, your spirit needs daily Word intake to sustain healing."
    ),
    (
        "Lying symptoms show up. What do you do?",
        ["Trust what you feel", "Google them", "Speak the truth in faith", "Call your doctor immediately"],
        2,
        "Symptoms are temporary facts. Truth is eternal. Say what God says until every fact submits."
    ),
    (
        "What’s the real danger of focusing on how you feel?",
        ["You might feel worse", "It helps nothing", "It empowers doubt", "It’s natural"],
        2,
        "Your attention feeds your reality. The more you focus on symptoms, the more authority you give them. Focus on the promise instead."
    ),
    (
        "How do you stay healed after receiving?",
        ["Rest and eat well", "Keep hearing and speaking the Word", "Tell no one", "Keep testing yourself"],
        1,
        "Joshua 1:8 — Meditate day and night. Healing that flows by faith is sustained by Word saturation."
    ),
    (
        "What did Jesus say made people whole?",
        ["Hope", "Touching His garment", "Faith in Him", "Being good enough"],
        2,
        "Over and over, Jesus said: 'Your faith has made you whole.' Your faith plugs into what grace has already provided."
    ),
    (
        "When do you stop speaking healing Scriptures?",
        ["When you feel better", "After 3 days", "When symptoms leave", "Never"],
        3,
        "God's Word is your medicine (Proverbs 4:22). You don’t stop speaking truth — you live from it."
    ),
    (
        "How often should you listen to healing Word?",
        ["Every Sunday", "Occasionally", "Daily", "When you're sick"],
        2,
        "Faith doesn’t come from what you heard once. Romans 10:17 — 'Faith comes by hearing' (present tense)."
    ),
    (
        "Why speak the same healing Scriptures over and over?",
        ["It helps memory", "It impresses others", "It builds unshakable faith", "It’s tradition"],
        2,
        "Romans 12:2 — Repetition renews the mind. Your faith isn’t built on feelings but formed by the Word heard and spoken consistently."
    ),
    (
        "God’s Word is medicine. How should you take it?",
        ["With food", "Once in crisis", "Consistently, with faith", "At night only"],
        2,
        "Proverbs 4:22 — Take it morning, noon, and night. It's spiritual medicine with no side effects, but powerful results."
    ),
    (
        "Discouraged by progress? What do you do?",
        ["Stop trying", "Look for a new teaching", "Speak God’s promises again", "Rest more"],
        2,
        "1 Samuel 30:6 — David encouraged himself in the Lord. You win this war with your mouth, not your mood."
    ),
    (
        "Healing seems slow. What’s the right posture?",
        ["Doubt", "Press in more to the Word", "Give it a break", "Try something new"],
        1,
        "Keep sowing, keep watering. God gives the increase (1 Cor. 3:6). If symptoms persist, double your dosage of Scripture."
    ),
    (
        "You still feel pain. Are you healed?",
        ["You don't know", "Speak what God said", "You ask others", "Wait for proof"],
        1,
        "We walk by faith, not by sight (2 Cor. 5:7). Pain doesn’t prove God lied — it proves you need to speak again."
    ),
    (
        "What should your words align with — always?",
        ["Feelings", "Doctor’s report", "God’s report", "What seems likely"],
        2,
        "Psalm 107:2 — 'Let the redeemed of the Lord say so.' Don’t echo what you feel — echo what God says until your body obeys."
    )
]

let peaceQuizQuestions = [
    (
        "Someone cuts you off in traffic. What do you do?",
        ["Yell at them", "Bless them and speak peace", "Let it ruin your day", "Hold it in"],
        1,
        "Luke 6:28 — 'Bless those who curse you.' Every moment is a chance to shift the atmosphere with your mouth, not mirror the madness."
    ),
    (
        "Your day feels rushed and overwhelming. What’s your first move?",
        ["Power through", "Take a deep breath and give it to Jesus", "Complain", "Multitask harder"],
        1,
        "1 Peter 5:7 — 'Cast your cares on Him.' Peace begins the moment you surrender control and trust God’s pacing."
    ),
    (
        "You feel irritated for no clear reason. What should you speak?",
        ["This day is ruined", "I just need coffee", "I have the mind of Christ", "I’m so done"],
        2,
        "1 Cor. 2:16 — 'We have the mind of Christ.' Identity overrides emotion. Speak who you are, not how you feel."
    ),
    (
        "Your schedule is disrupted. How do you stay grounded?",
        ["Panic", "Reset and speak God’s promises", "Blame others", "Skip your quiet time"],
        1,
        "Isaiah 26:3 — Peace isn’t found in control. It’s found in staying anchored to God’s unchanging Word."
    ),
    (
        "What’s the true root of perfect peace?",
        ["Having control", "No interruptions", "Trusting in God", "Zero problems"],
        2,
        "Isaiah 26:3 — Perfect peace is not the absence of chaos, but the presence of trust. Keep your mind stayed on Him."
    ),
    (
        "How do you guard your peace during the day?",
        ["Isolate", "Avoid people", "Speak Scripture throughout the day", "Ignore feelings"],
        2,
        "Psalm 119:165 — 'Great peace have those who love Your law.' Peace isn’t protected by withdrawal, but by truth-filled repetition."
    ),
    (
        "You wake up anxious. What do you do first?",
        ["Scroll your phone", "Speak Psalm 23:1", "Rush to work", "Get distracted"],
        1,
        "'The Lord is my Shepherd, I shall not want.' Don’t just feel your way into the day — speak your way into peace."
    ),
    (
        "Someone says something rude. How do you respond?",
        ["Fire back", "Walk away", "Speak, 'I’m unoffendable in Christ'", "Ignore them"],
        2,
        "Proverbs 15:1 — 'A gentle answer turns away wrath.' Speaking truth silences offense and keeps you in peace territory."
    ),
    (
        "What happens when you keep speaking peace?",
        ["You fake it", "Nothing", "Peace multiplies in your life", "You become passive"],
        2,
        "2 Peter 1:2 — Grace and peace are multiplied through knowledge. The more you know Him, the more peace grows through your mouth."
    ),
    (
        "You’re tired, but someone needs help. What now?",
        ["Ignore them", "Help and grumble", "Speak grace and serve with joy", "Say you’re busy"],
        2,
        "2 Cor. 12:9 — His grace is your strength. Don’t serve from your flesh; serve from overflow."
    ),
    (
        "Your thoughts won’t stop racing. How do you calm them?",
        ["Sleep", "Talk to a friend", "Speak God’s promises out loud", "Scroll Instagram"],
        2,
        "Philippians 4:7 — Peace doesn’t just show up. It guards your heart when you speak God’s Word aloud."
    ),
    (
        "What should you do with small frustrations?",
        ["Suppress it", "Rant about it", "Cast it on Jesus", "Hold it in until later"],
        2,
        "Matthew 11:28 — Bring Him the small and the heavy. Peace flows to those who offload early."
    ),
    (
        "Someone tries to steal your peace — what do you say?",
        ["They’re so annoying", "Why me?", "I choose peace — nothing missing, nothing broken", "I’ll get even later"],
        2,
        "Colossians 3:15 — Let peace rule. Don’t let people write your script — speak what Heaven already declared."
    ),
    (
        "You forgot to pray this morning. What now?",
        ["Feel guilty", "Start right now", "Blame your schedule", "Hope God understands"],
        1,
        "Isaiah 30:15 — 'In returning and rest is your salvation.' Peace isn’t lost. Just return and reset your focus."
    ),
    (
        "What’s a powerful peace confession to speak daily?",
        ["I hope this day goes well", "I'm just trying to survive", "I live in perfect peace — my mind is on Jesus", "No one better mess with me today"],
        2,
        "Confession brings possession. Isaiah 26:3 — Speak it until your emotions catch up to your position in Christ."
    )
]

let protectionQuizQuestions = [
    (
        "What should you declare when you feel unsafe?",
        ["I hope nothing bad happens", "God is my refuge and fortress", "It’s out of my control", "I’ll just avoid danger"],
        1,
        "'He is my refuge and my fortress' — Psalm 91:2. Speak it and rest in His covering."
    ),
    (
        "What protects you more than locks or alarms?",
        ["Being alert", "Common sense", "God’s angels", "Staying home"],
        2,
        "Psalm 91:11 — 'He will command His angels concerning you.' His protection is supernatural."
    ),
    (
        "When trouble comes near, what do you speak?",
        ["Hope for the best", "Let’s see what happens", "No weapon formed against me shall prosper", "It is what it is"],
        2,
        "Isaiah 54:17 — Declare victory before you see it. No weapon will succeed."
    ),
    (
        "You’re traveling alone. What truth do you stand on?",
        ["I’m vulnerable", "I trust my driver", "The Lord goes with me", "I stay quiet and watchful"],
        2,
        "Deuteronomy 31:6 — He goes with you, never leaving or forsaking."
    ),
    (
        "What surrounds you according to Psalm 91?",
        ["Uncertainty", "Dangers", "God’s faithfulness and angels", "Protection when you're good enough"],
        2,
        "You’re covered by His feathers and shielded by truth — Psalm 91:4."
    ),
    (
        "What should you believe about your home?",
        ["Hope it’s safe", "Install more cameras", "No evil will befall it", "Just pray sometimes"],
        2,
        "Psalm 91:10 — 'No evil shall befall you, nor shall any plague come near your dwelling.'"
    ),
    (
        "What’s your response to a scary news headline?",
        ["Panic", "Share it", "Declare Psalm 91", "Ignore it"],
        2,
        "News doesn’t override God’s promises. Speak Psalm 91 with authority."
    ),
    (
        "How do you activate God's protection daily?",
        ["Think positive", "Speak protection Scriptures", "Watch the news", "Stay hidden"],
        1,
        "God’s Word is your shield — speak it and activate it (Ephesians 6:17)."
    ),
    (
        "What does the blood of Jesus do for your safety?",
        ["Forgives you", "Makes you feel loved", "Marks you as protected", "Only helps when sick"],
        2,
        "Just like Israel marked their doors, you can plead the blood over your life (Exodus 12:13)."
    ),
    (
        "What should your heart posture be under attack?",
        ["Worry", "Boldness", "Hope it ends", "Fear"],
        1,
        "Be bold and confident — 'The Lord is my helper; I will not fear' (Hebrews 13:6)."
    ),
    (
        "You're walking through a dark place. What do you say?",
        ["This is scary", "I wish I was home", "Even though I walk through the valley, I will fear no evil", "It’ll be fine eventually"],
        2,
        "Psalm 23:4 — Declare it even in the dark: God is with you."
    ),
    (
        "What’s the most powerful shield you have?",
        ["Alarm system", "Street smarts", "Faith", "Family support"],
        2,
        "Ephesians 6:16 — 'Take up the shield of faith… to extinguish all the flaming darts.'"
    ),
    (
        "How should you speak over your children?",
        ["I hope they stay safe", "You never know these days", "I plead the blood over them", "I tell them to be careful"],
        2,
        "Declare Psalm 91 and plead the blood — it’s not fear, it’s faith in action."
    ),
    (
        "What surrounds the one who fears the Lord?",
        ["Worry", "Hardship", "The angel of the Lord", "Uncertainty"],
        2,
        "Psalm 34:7 — 'The angel of the Lord encamps around those who fear Him, and delivers them.'"
    ),
    (
        "What happens when you dwell in the secret place?",
        ["You become religious", "You gain spiritual strength", "You abide under God's shadow", "You avoid problems"],
        2,
        "Psalm 91:1 — Abiding in Him brings divine protection and rest."
    )
]


let destinyQuizQuestions = [
    (
        "What should you believe about your life?",
        ["It’s random", "It’s up to fate", "God has a plan and purpose", "It’s probably too late"],
        2,
        "Jeremiah 29:11 — 'I know the plans I have for you… to give you a future and a hope.'"
    ),
    (
        "You feel behind in life. What do you speak?",
        ["I missed my chance", "God’s timing is perfect", "Maybe it wasn’t meant to be", "Everyone is ahead of me"],
        1,
        "God makes everything beautiful in its time (Ecclesiastes 3:11)."
    ),
    (
        "How do you step into your calling?",
        ["Wait until everything is perfect", "Trust and obey step by step", "Figure it out yourself", "Compare your path to others"],
        1,
        "Proverbs 3:5-6 — 'Trust in the Lord… He will direct your paths.'"
    ),
    (
        "What does delay mean in God’s eyes?",
        ["It’s denial", "It’s a test", "It means you failed", "It’s preparation"],
        3,
        "Delay is not denial. God prepares you before He promotes you (James 1:4)."
    ),
    (
        "When you feel unqualified, what truth should you speak?",
        ["Maybe I’m not called", "God chooses the weak", "Others are more gifted", "I'll stay quiet"],
        1,
        "1 Corinthians 1:27 — 'God chose the foolish things… to shame the wise.'"
    ),
    (
        "What do you declare in a season of waiting?",
        ["Nothing’s happening", "God’s working behind the scenes", "I’m stuck", "This is unfair"],
        1,
        "Faith sees what God promised — even when you can’t yet see it (2 Cor. 5:7)."
    ),
    (
        "How does God prepare you for your purpose?",
        ["Through success only", "By isolating you", "By refining and equipping you", "By blessing your plans"],
        2,
        "Romans 8:28 — 'All things work together for good… to those called according to His purpose.'"
    ),
    (
        "What’s your role in discovering God’s will?",
        ["Make your own path", "Ask others for their plan", "Surrender and renew your mind", "Work until you're exhausted"],
        2,
        "Romans 12:2 — Be transformed… then you’ll know His good and perfect will."
    ),
    (
        "What should you say when doors close?",
        ["God must not want me to succeed", "I’ll never get another chance", "God is redirecting me", "I should’ve tried harder"],
        2,
        "Closed doors protect destiny. He opens the right ones no one can shut (Rev. 3:7)."
    ),
    (
        "What qualifies you for your calling?",
        ["Perfection", "Trying really hard", "Faith in Jesus", "Approval from people"],
        2,
        "God qualifies the called — it's His grace, not your performance (2 Tim. 1:9)."
    ),
    (
        "What if you’ve made mistakes in the past?",
        ["You're disqualified", "You missed your chance", "God can still use you", "You have to earn it back"],
        2,
        "Romans 11:29 — 'The gifts and calling of God are irrevocable.'"
    ),
    (
        "How do you stay in step with God’s plan?",
        ["Push doors open", "Pray then follow peace", "Compare with others", "Always say yes"],
        1,
        "Colossians 3:15 — Let peace rule in your heart and guide your decisions."
    ),
    (
        "You feel overlooked. What do you speak?",
        ["No one sees me", "God sees and knows me", "It’s not fair", "I’m wasting my time"],
        1,
        "God sees in secret and rewards openly (Matthew 6:6)."
    ),
    (
        "When you don't feel ready, what’s the truth?",
        ["I need more time", "God equips those He calls", "I might fail", "This is too big for me"],
        1,
        "Hebrews 13:21 — 'May He equip you with everything good for doing His will.'"
    ),
    (
        "What happens when you say yes to God?",
        ["He tests you", "You sacrifice everything", "He empowers you", "Life gets harder"],
        2,
        "Philippians 2:13 — 'It is God who works in you to will and to act.'"
    )
]

let wordsQuizQuestions = [
    (
        "What does Proverbs 18:21 say about your tongue?",
        ["It helps you communicate", "It reflects your heart", "It carries life and death", "It’s hard to control"],
        2,
        "'Life and death are in the power of the tongue…' — Your words are never neutral."
    ),
    (
        "What happens when you speak life over your situation?",
        ["Nothing changes", "You feel better", "Faith is activated", "It helps others only"],
        2,
        "Mark 11:23 — 'Whoever says to this mountain… it will be done for him.'"
    ),
    (
        "Why should you guard your words?",
        ["To sound wise", "To avoid trouble", "They shape your future", "It’s polite"],
        2,
        "James 3 — The tongue is like a rudder that steers your whole life."
    ),
    (
        "You feel sick. What do you say?",
        ["I'm always getting sick", "Hope I feel better", "By His stripes I’m healed", "This always happens"],
        2,
        "Speak healing, not symptoms — Isaiah 53:5 is your authority."
    ),
    (
        "When you’re frustrated, what’s the best habit?",
        ["Vent it", "Speak peace over yourself", "Stay silent", "Post about it"],
        1,
        "Proverbs 15:1 — 'A gentle answer turns away wrath.' Words release peace or pain."
    ),
    (
        "What makes your declarations powerful?",
        ["Emotion", "Volume", "Faith and truth", "Repetition only"],
        2,
        "Power doesn’t come from shouting — it comes from believing (2 Cor. 4:13)."
    ),
    (
        "What happens when you constantly speak fear?",
        ["It helps you prepare", "You stay realistic", "You attract what you say", "It doesn’t matter"],
        2,
        "Job 3:25 — 'What I feared has come upon me.' Your words build your reality."
    ),
    (
        "What did Jesus use to defeat the devil?",
        ["Prayer", "Silence", "Scripture spoken aloud", "His presence"],
        2,
        "In Matthew 4, Jesus said 'It is written' three times and shut the devil down."
    ),
    (
        "When should you speak God's Word?",
        ["At church", "In emergencies", "All day, every day", "Before bed"],
        2,
        "Deuteronomy 6:7 — Talk of the Word 'when you walk… lie down… rise up…'"
    ),
    (
        "You spoke negatively — what now?",
        ["Just move on", "Hope it’s okay", "Repent and speak life", "Do nothing"],
        2,
        "Cancel wrong words by speaking truth. James 3:10 — blessings and curses shouldn’t mix."
    ),
    (
        "Why are your words spiritual?",
        ["They affect your mood", "They sound powerful", "They come from your heart", "They carry faith or fear"],
        3,
        "Jesus said, 'Out of the abundance of the heart, the mouth speaks' (Luke 6:45)."
    ),
    (
        "How do you shift your atmosphere?",
        ["Take deep breaths", "Control others", "Speak Scripture boldly", "Play music"],
        2,
        "Words create worlds — Hebrews 11:3. Speak the Word and change the room."
    ),
    (
        "What should your mouth be full of?",
        ["News", "Opinion", "Praise and promises", "Complaints"],
        2,
        "Psalm 34:1 — 'I will bless the Lord at all times; His praise shall continually be in my mouth.'"
    ),
    (
        "What do your words reveal?",
        ["Your personality", "Your past", "Your heart condition", "Your thoughts"],
        2,
        "Luke 6:45 — What you truly believe will always find its way into your mouth."
    ),
    (
        "What does faith do with God’s Word?",
        ["Reads it", "Thinks about it", "Speaks it", "Sings it"],
        2,
        "2 Corinthians 4:13 — 'I believed, and therefore I spoke.' Faith speaks!"
    )
]

let joyQuizQuestions = [
    (
        "What does James 1:2 say to do when you face trials?",
        ["Complain", "Run from them", "Count it all joy", "Ignore them"],
        2,
        "'Count it all joy… knowing the testing of your faith produces endurance.' Joy shifts perspective."
    ),
    (
        "Why can we have joy during hard times?",
        ["We fake it", "We hope for escape", "God is working something good", "It distracts us"],
        2,
        "Romans 8:28 — 'All things work together for good to those who love God.'"
    ),
    (
        "What should your mouth speak when life gets tough?",
        ["It’s too much", "I can’t do this", "God is with me and joy is my strength", "Just survive it"],
        2,
        "Nehemiah 8:10 — 'The joy of the Lord is your strength.'"
    ),
    (
        "You’re facing delays and disappointments. What now?",
        ["Give up", "Count them as joy", "Get frustrated", "Compare with others"],
        1,
        "Joy is a spiritual choice — it releases strength and endurance."
    ),
    (
        "What does rejoicing in trials produce?",
        ["Relief", "Confusion", "Endurance and maturity", "Weakness"],
        2,
        "James 1:4 — 'Let endurance have its full effect, that you may be perfect and complete.'"
    ),
    (
        "What does joy look like under pressure?",
        ["Denial", "Laughing at pain", "Confidence in God's faithfulness", "Pretending to be okay"],
        2,
        "Joy isn't fake — it's faith. It says, 'I trust God’s goodness even now.'"
    ),
    (
        "How did Paul respond in prison?",
        ["Gave up", "Wrote angry letters", "Rejoiced always", "Demanded release"],
        2,
        "Philippians 4:4 — 'Rejoice in the Lord always.' He wrote that from jail!"
    ),
    (
        "You just got bad news. What do you say?",
        ["This ruins everything", "God is still good", "Why me?", "Nothing ever works out"],
        1,
        "Habakkuk 3:18 — 'Yet I will rejoice in the Lord… I will be joyful in God my Savior.'"
    ),
    (
        "What kind of joy does Jesus give?",
        ["Temporary", "Based on feelings", "Full and unshakable", "Earned joy"],
        2,
        "John 15:11 — 'That My joy may remain in you, and your joy may be full.'"
    ),
    (
        "How can you stir up joy in hard times?",
        ["Ignore the problem", "Listen to sad music", "Praise and speak promises", "Wait it out"],
        2,
        "Isaiah 61:3 — God gives a 'garment of praise for the spirit of heaviness.'"
    ),
    (
        "Joy is not a feeling — it’s a...",
        ["Reaction", "Spiritual weapon", "Reward", "Temporary escape"],
        1,
        "Joy fights back — it releases strength, hope, and victory in the middle of pressure."
    ),
    (
        "What happens when you choose joy instead of fear?",
        ["People think you're weird", "You stay in denial", "You overcome with faith", "Nothing"],
        2,
        "Faith rejoices before the breakthrough — joy is a sign you believe."
    ),
    (
        "What does joy in trials say to the enemy?",
        ["You’re not affected", "You're ignoring reality", "God will win this", "You’re giving up"],
        2,
        "Joy is defiant faith — it announces that God is bigger than the attack."
    ),
    (
        "What does it mean to 'rejoice always'?",
        ["Be fake", "Avoid pain", "Choose faith even in chaos", "Be out of touch"],
        2,
        "1 Thess. 5:16 — Joy is choosing to believe in God’s nature no matter what."
    ),
    (
        "How do you cultivate joy daily?",
        ["Meditate on problems", "Hope for better days", "Speak God’s promises and give thanks", "Fake a smile"],
        2,
        "Philippians 4:8 — Think on what is good. Gratitude and the Word fuel joy."
    )
]

let identityQuizQuestions = [
    (
        "When you feel unworthy, what truth should you declare?",
        ["Try to be better", "I’m not enough", "I am the righteousness of God in Christ", "Maybe next time"],
        2,
        "2 Corinthians 5:21 — You’re not righteous by performance, but by Jesus' finished work."
    ),
    (
        "What happened when you believed in Jesus?",
        ["You joined a church", "You got rules to follow", "You became a new creation", "You got religion"],
        2,
        "2 Corinthians 5:17 — 'If anyone is in Christ, he is a new creation… all things have become new.'"
    ),
    (
        "How does God see you right now?",
        ["Trying your best", "Still messed up", "Holy, blameless, and loved", "On probation"],
        2,
        "Colossians 1:22 — He sees you holy and blameless in His sight through Christ."
    ),
    (
        "What gives you authority as a believer?",
        ["Your good behavior", "Being a church member", "Faith in Jesus' name", "Time spent studying"],
        2,
        "Luke 10:19 — Jesus gave you authority to trample every lie and tactic of the enemy."
    ),
    (
        "What does it mean to be a child of God?",
        ["You must earn it", "You’re adopted with full rights", "You’re tolerated", "You belong if you behave"],
        1,
        "Romans 8:15 — You received the Spirit of adoption, by whom you cry out, 'Abba, Father.'"
    ),
    (
        "How should you see yourself daily?",
        ["A work in progress", "Trying not to sin", "Seated with Christ in heavenly places", "Still broken"],
        2,
        "Ephesians 2:6 — You’re already seated with Christ in victory and authority."
    ),
    (
        "What is your true spiritual position?",
        ["Trying to get close to God", "Under spiritual attack", "In Christ, above all things", "At the mercy of life"],
        2,
        "Colossians 3:3 — Your life is hidden with Christ in God. That’s your secure identity."
    ),
    (
        "How do you renew your identity mindset?",
        ["Positive thinking", "Hearing & speaking the Word", "Social media detox", "Trying harder"],
        1,
        "Romans 12:2 — You’re transformed by renewing your mind with God’s truth daily."
    ),
    (
        "If you’ve sinned, what’s your standing with God?",
        ["He’s disappointed", "You must work to earn back favor", "Confess & receive mercy instantly", "He ignores you"],
        2,
        "1 John 1:9 — Confess and be instantly cleansed. Your position in Christ doesn't change."
    ),
    (
        "You feel defeated. What truth lifts you up?",
        ["Try again tomorrow", "Maybe it's not God's will", "I’m more than a conqueror in Christ", "Everyone struggles"],
        2,
        "Romans 8:37 — You are more than a conqueror through Him who loves you."
    ),
    (
        "What’s your status in God's family?",
        ["Visitor", "Barely accepted", "Chosen, royal, and set apart", "Trying to fit in"],
        2,
        "1 Peter 2:9 — 'You are a chosen generation… royal priesthood… God’s special possession.'"
    ),
    (
        "Why can you speak with boldness before God?",
        ["You’ve been good lately", "You read your Bible", "You’re clothed in Christ's righteousness", "You’ve been consistent"],
        2,
        "Hebrews 4:16 — Come boldly to the throne of grace because of Jesus, not your performance."
    ),
    (
        "What’s your true spiritual identity?",
        ["Trying to be holy", "A sinner saved by grace", "A saint empowered by Christ", "A barely forgiven servant"],
        2,
        "Ephesians 1:4 — You were chosen to be holy and blameless in His sight before time began."
    ),
    (
        "What makes you valuable?",
        ["Your achievements", "What others think", "Christ’s blood and calling", "Your gifts"],
        2,
        "You were bought with a price (1 Cor. 6:20). Your value is set by Heaven."
    ),
    (
        "What does it mean to be 'in Christ'?",
        ["You’re trying to follow Jesus", "You’re part of a religion", "You’ve been placed into His victory", "You believe the right stuff"],
        2,
        "Being 'in Christ' means you now share in His identity, righteousness, and authority."
    )
]
