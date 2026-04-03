#!/usr/bin/env python3
"""
Patch May devotionals with full 7-paragraph rewrites.
Every entry follows the structure from devotionals-writing-guide.md.
"""
import json

DEVOTIONALS_PATH = "SpeakLife/SpeakLife/Preview Content/AffirmationData/devotionals.json"

# New devotional texts — keyed by date, following 7-paragraph structure:
# P1 Hook (God's Heart), P2 Character Unpacked, P3 Real Life,
# P4 Personal Implications, P5 Trust Grounding, P6 Bring It Home, P7 Prayer
NEW_TEXTS = {

"01-05": (
"God went public for you long before you went public for Him — and that kind of loyalty changes everything.\n\n"
"Jesus is your advocate before the Father, not because you've earned that standing, but because He purchased it. "
"His faithfulness to you didn't begin the day you decided to follow. It was sealed on a cross, for someone who hadn't believed yet. "
"That's who He is — a God who speaks your name in heaven even when you go silent about His on earth.\n\n"
"But this verse carries a holy weight. There will come moments when confessing His name costs you something real — "
"a friendship, a promotion, approval from people you genuinely care about. That pressure is not a reason to retreat. "
"It's the moment your faith moves from theory into truth.\n\n"
"You were not saved in secret so you could stay hidden. Your rescue has a voice. The courage you show in one honest conversation "
"can become the thread that unravels someone else's darkness. Your life was never meant to be only about you.\n\n"
"You can trust Him with the cost of standing because He already paid the highest one. No one has ever lost more for faithfulness "
"than Jesus — and He did it willingly, for you. That is the track record you are trusting when you open your mouth.\n\n"
"Standing for Jesus is not a performance for His approval. You already have it. It is a response — love answering love, "
"courage answering courage, loyalty returned to the One who was loyal first.\n\n"
"Jesus, I am not ashamed of the name that rescued me. You stood for me at the cross before I ever stood for You. "
"I choose boldness — not to earn Your love, but because I already have it. Let my life declare who You are. Amen. \U0001f49c"
),

"02-05": (
"God's love is fierce enough to cut — and that fierceness is not cruelty, it is the deepest kindness you will ever encounter.\n\n"
"When Jesus said He came not to bring peace but a sword, He was not describing violence. He was describing truth. "
"This is who He is: a Savior too honest and too committed to your freedom to offer you a peace built on pretense. "
"The sword He carries severs lies from your identity, chains from your soul, and comfort from the things that were slowly killing you.\n\n"
"Following Jesus rearranges things. Your priorities shift. Some relationships feel the tension. Certain old patterns no longer fit. "
"Not because you've become difficult — but because light and darkness cannot share the same space without something giving way.\n\n"
"This means you don't have to apologize for the way your faith has cost you something. The division isn't your failure. "
"It's the evidence that you've chosen something real over something easy. "
"That's not a small thing. That's the beginning of a life that actually means something.\n\n"
"You can trust Him through the cost because He walked through the ultimate cost first. "
"He was rejected, betrayed, and crucified for refusing to water down who He was. He paid that price knowing it was worth it — "
"because you were worth it. His peace on the other side of the sword is real, and it outlasts every storm.\n\n"
"The sword that divides is the same sword that heals. Truth doesn't come to ruin your life. It comes to free you from every lie "
"that has kept you small, stuck, and afraid.\n\n"
"Jesus, I embrace truth even when it costs me comfort. Cut away every compromise in me. "
"I don't want a peace I've manufactured — I want the peace only You can give. I choose You, whatever the cost. Amen. \U0001f49c"
),

"03-05": (
"God's Kingdom cannot be suppressed — and when it moves, even the most powerful people in the room take notice.\n\n"
"When Herod heard about Jesus, he was perplexed and disturbed. Not mildly curious — shaken. He had power, position, and a kingdom of his own, "
"and none of it insulated him from the unsettling reality of what Jesus was doing. "
"This is who God is: a King whose authority makes every counterfeit throne feel unstable the moment He walks in.\n\n"
"Herod couldn't ignore Jesus. Not because Jesus forced His way in, but because the presence of truth always exposes what's false. "
"No amount of title, wealth, or influence can mute what the Spirit of God is doing in a room — or in a life.\n\n"
"That same Spirit now lives in you. When you walk in that reality — not striving, not performing, just abiding — "
"you carry something that disrupts darkness before you ever open your mouth. "
"People will take notice. Some will be drawn in. Others will be unsettled. Both responses are the evidence that God is at work.\n\n"
"You can trust that God's Kingdom keeps advancing because it already has — through Roman occupation, through Herod's paranoia, "
"through every attempt to silence the name of Jesus. History is on His side. Nothing has stopped Him yet.\n\n"
"You don't need a throne. You need His Spirit. And you already have that. Let your life carry what Herod couldn't ignore — "
"the undeniable presence of a living God.\n\n"
"Jesus, let Your presence in me shake what is false and confirm what is real. "
"I don't need a title — I have Your Spirit. Use my life to disrupt darkness and draw people to You. Amen. \U0001f49c"
),

"04-05": (
"God is not content to be one option among many — He asks a question that forces your hand and opens your heart.\n\n"
"Jesus had just asked the disciples what others were saying about Him. But then He made it personal: "
"Who do you say that I am? Not the crowd's answer. Yours. "
"This is who He is — a God who refuses to let you stay at a comfortable intellectual distance. "
"He steps close and waits for your honest response.\n\n"
"Peter didn't recite theology. He spoke from revelation: You are the Christ. "
"That answer wasn't just correct — it was transforming. Something shifted the moment Peter named what he truly believed. "
"Because what you believe about Jesus determines everything about how you live.\n\n"
"The question still stands today. Not what did your church say, or what does your culture assume. "
"What do you believe — when life is hard, when prayers seem unanswered, when faith feels expensive? "
"Who do you say He is in that moment? That is where your real confession lives.\n\n"
"You can trust Him with your honest answer because He can handle it. He already knows what's in your heart. "
"He's not waiting to grade you — He's waiting to meet you exactly where you are and lead you deeper. "
"Peter's answer wasn't perfect theology. It was honest surrender. That's what moved heaven.\n\n"
"Your confession of who Jesus is doesn't just define your belief — it shapes the ground you stand on. "
"Build on the Rock, and nothing can move you.\n\n"
"Jesus, You are the Christ — not just in doctrine but in my life. You are my Savior, my foundation, my King. "
"I don't just admire You from a distance. I trust You with everything. Amen. \U0001f49c"
),

"05-05": (
"God notices when you come back — and what He does in that moment goes far beyond what you came back for.\n\n"
"Ten lepers were healed. All ten experienced a genuine miracle. But only one turned around. "
"Only one fell at Jesus' feet. Only one recognized that the healing wasn't the end of the story — it was an invitation to know the Healer. "
"This is who Jesus is: a God whose goodness is always pointing you toward something deeper than the blessing itself.\n\n"
"Nine walked away satisfied. One walked back transformed. "
"The difference wasn't in what they received — it was in what they did with it. "
"Gratitude is not just good manners. It is the posture that keeps you close to the source of everything you've been given.\n\n"
"Think about what God has already done in your life. The moments He showed up. The prayers He answered. The times He kept you. "
"It's easy to receive the miracle and move on to the next need. But something sacred happens when you stop, return, and say thank You. "
"It repositions your heart toward the Giver, not just the gift.\n\n"
"You can trust that He notices because Scripture records this moment with such care. "
"Jesus asked where the others were. He sees who returns. He honors the heart that runs back. "
"Gratitude is never wasted on a God who gave everything to reach you.\n\n"
"Don't let answered prayers turn into forgotten praises. The one who came back received more than healing — he received wholeness. "
"That's what a thankful heart always unlocks.\n\n"
"Jesus, I want to be the one who comes back every time. You have healed me, kept me, and carried me more than I can count. "
"I will not stay silent. My life is a thank-You on repeat, and my heart runs back to You. Amen. \U0001f49c"
),

"06-05": (
"God doesn't just want to fix what's broken on the outside — He wants to make you whole from the inside out.\n\n"
"Ten lepers were healed that day, but only one was made whole. "
"When the Samaritan returned to worship, Jesus spoke over him: Your faith has made you well. "
"That word reaches further than physical restoration. It means complete — body, mind, spirit, and soul. "
"This is who Jesus is: a Healer who never stops at the surface.\n\n"
"The other nine received the same healing. But this one received something more because he came back to the Source. "
"He didn't stop at the gift — he pressed through to the Giver. And in that act of return, Jesus poured out what only relationship can release.\n\n"
"This is a picture of how God works in your life. He meets your need, but His heart is always after more for you. "
"He heals the wound, but He longs to heal the wound beneath the wound — the fear, the shame, the disconnection. "
"Wholeness is not just the absence of pain. It's the fullness of His presence.\n\n"
"You don't have to earn greater wholeness by doing more. You receive it by drawing closer. "
"The one who came back didn't bring an offering. He brought himself. "
"That was enough. That was everything. That is always what Jesus is after.\n\n"
"Faith that stops at answered prayer misses what faith is really for. "
"Real faith keeps running back to Jesus — not because you need another miracle, but because you know who He is.\n\n"
"Jesus, I don't just want a touch — I want transformation. Thank You for every healing, every answered prayer. "
"But more than Your gifts, I want You. I choose to live close to You, in faith and in awe, made whole. Amen. \U0001f49c"
),

"07-05": (
"God's process is never random — every step He takes you through is intentional, purposeful, and leading somewhere good.\n\n"
"Jesus could have healed this blind man on the spot, in front of everyone. Instead, He took the man by the hand "
"and led him away from the village — away from the crowd, away from familiar ground, into what must have felt like the unknown. "
"This is who He is: a God who isn't in a hurry and never wastes a single step of the journey He walks with you.\n\n"
"The healing didn't come instantly. First blurry. Then clear. Jesus asked, Do you see anything? "
"The miracle came in stages. Not because Jesus was limited — but because the man needed to be built, not just fixed. "
"Faith grows in the process, not just in the result.\n\n"
"You may be in a season that feels slow. The answer hasn't come. The healing hasn't been complete. "
"The path forward isn't obvious. That doesn't mean you're forgotten. "
"It means Jesus has taken you by the hand and is walking you through a process that is forming you for what's coming.\n\n"
"You can trust His timing because He has never wasted a step. Every season Jesus walked with people, "
"He did what was exactly right at exactly the right moment — not what was fastest, but what was best. "
"His record holds. He is the same toward you today.\n\n"
"If Jesus is holding your hand, you are exactly where you need to be. The process is not the problem — it is the preparation.\n\n"
"Jesus, even when I don't understand the steps, I trust the One leading me. "
"Hold my hand through every stage. I believe my breakthrough is coming, and I will walk with You until I see it fully. Amen. \U0001f49c"
),

"08-05": (
"God is watching what you do with what you have right now — and He is not unimpressed by small.\n\n"
"Jesus didn't say faithful in much receives much. He said faithful in least is faithful in much. "
"The character you carry in the small moments is the same character that will show up when the stakes are higher. "
"This is who God is: a Father who sees the hidden faithfulness others overlook and treats it as the most important credential you could carry.\n\n"
"David tended sheep before he faced Goliath. Joseph managed a prison before he governed a nation. "
"Jesus spent thirty hidden years before three public ones that changed eternity. "
"The pattern is not accidental — God uses the small to prepare you for the large, and He doesn't skip the preparation.\n\n"
"This means that what you're doing right now matters more than it may look. "
"The job no one sees. The responsibility no one applauds. The daily faithfulness when nothing seems to be happening. "
"That is not a waiting room. That is a classroom. And God is your teacher.\n\n"
"You can trust that your faithfulness is not invisible. Hebrews 6:10 says God is not unjust to forget your work. "
"Every act of quiet obedience is recorded. Every time you chose diligence over shortcuts, integrity over convenience — He saw it. "
"And He does not forget what He sees.\n\n"
"Your hidden season is not wasted. It is where character is built, and character is what makes expanded opportunity mean something.\n\n"
"Jesus, teach me to be faithful with exactly what You've placed in my hands today. "
"I trust that You see my quiet obedience, and I believe You are preparing me for more. Help me honor every assignment. Amen. \U0001f49c"
),

"09-05": (
"God doesn't measure your worth by your output — He sees your exhaustion, and His first response is an invitation to rest.\n\n"
"The disciples had been pouring themselves out — teaching, healing, traveling. Crowds pressed in so constantly they didn't have time to eat. "
"And into that depletion, Jesus spoke not another assignment but a tender command: Come away. Rest. "
"This is who He is: a God who cares as much about your restoration as He does about your work.\n\n"
"Rest is not the reward for finishing everything on your list. It is a Kingdom value. "
"It is a declaration that says you trust God enough to stop. That His purposes don't collapse when you put something down. "
"That you are more than what you produce.\n\n"
"Our culture tells you that slowing down is falling behind. Jesus tells you it's the only way to stay fruitful. "
"You cannot pour from empty. You cannot carry others when you are collapsing under your own weight. "
"The stillness He invites you into is not laziness — it is wisdom.\n\n"
"You are not failing God by resting. You are trusting Him. And that trust is exactly the posture He blesses. "
"Psalm 23 says He makes you lie down — sometimes He will bring the rest even when you won't choose it. "
"Better to accept the invitation than to wait for the collapse.\n\n"
"In the quiet, He restores. In the stillness, He speaks. In the pause, He prepares you for what's coming. "
"Rest is not time lost — it is time with the One who is your strength.\n\n"
"Jesus, I hear Your invitation and I accept it. I lay down the striving and choose to sit with You. "
"Restore my soul. Renew my strength. Remind me that it is Your power, not my effort, that makes the difference. Amen. \U0001f49c"
),

"10-05": (
"God doesn't just calm storms from a distance — He shows up in the middle of one and invites you to walk toward Him through it.\n\n"
"The disciples were terrified, wind roaring, waves crashing, hearts shaking. And Jesus walked toward them on the water. "
"His first words were not instructions — they were identity: It is I. Don't be afraid. "
"This is who He is: a God who comes to you in the worst moments, not when they're over.\n\n"
"Peter's response is one of the boldest in all of Scripture. Not, rescue us. Not, make it stop. "
"Lord, if it is You, command me to come to You on the water. "
"He didn't want comfort from a safe distance. He wanted to participate in the miracle. "
"Faith like this doesn't just receive — it reaches.\n\n"
"The storm was real. The wind was fierce. Peter knew the risk. But his eyes were on Jesus, "
"and that was enough to make him take the step that changed him forever. "
"You were made for this kind of faith — not the kind that waits until conditions are perfect, but the kind that steps out because Jesus called.\n\n"
"What is Jesus calling you toward that feels impossible? Where has fear kept you in the boat "
"when He's been standing on the water asking you to come? "
"The miracle is not in the safety of the boat. The miracle is on the water with Him.\n\n"
"You can trust His call because He has never let a person who stepped out in genuine faith drown. "
"Even when Peter sank, Jesus reached out immediately. That hand is always there.\n\n"
"Jesus, I hear You say, Come. I don't want to stay safe when You are calling me deeper. "
"Give me courage to step out of what's comfortable and meet You in the impossible. My eyes are on You. Amen. \U0001f49c"
),

"11-05": (
"God's purpose for your life is bigger than any platform the world could offer you — and He will not let you be forced into the wrong one.\n\n"
"The crowd wanted to make Jesus king by force. He had just fed five thousand with almost nothing, "
"and the people were ready to crown Him on the spot. But Jesus withdrew to the mountain alone. "
"He refused the throne the crowd was building because it wasn't the throne He came for. "
"This is who He is: a God so certain of His calling that no amount of applause can push Him off mission.\n\n"
"Their version of kingship meant political power and earthly rescue. His calling was the cross — something deeper, costlier, and infinitely more freeing. "
"He could have taken what they offered. He chose what the Father assigned instead.\n\n"
"The world will offer you platforms. People will project onto you what they need you to be. "
"Opportunities will appear that feel big but aren't yours. The crowd's applause can be louder than God's voice if you let it. "
"But you were not designed to be shaped by other people's expectations.\n\n"
"You can trust God to define your assignment because He's the only one who knows what you were actually built for. "
"Not every open door is your door. Not every opportunity is your calling. Knowing the difference requires staying close to the One who made you.\n\n"
"Walk in the identity heaven gave you, not the role the crowd is casting. "
"Real significance looks less like applause and more like obedience.\n\n"
"Jesus, I want to follow Your example. Help me stay focused on what You've assigned — not what others expect. "
"Let Your voice be louder than any crowd. I want to live for Your purpose alone. Amen. \U0001f49c"
),

"12-05": (
"God speaks one word and the impossible becomes your next step — the only question is whether you'll move when He says so.\n\n"
"The wind was still roaring. The waves were still high. Nothing about the situation had changed. "
"And Jesus simply said, Come. That one word was enough for Peter to climb out of the boat and walk on the water. "
"This is who God is: a God whose word carries more weight than every natural law that says it can't be done.\n\n"
"Peter didn't walk on water because he was unusually brave. He walked on water because he moved on a word from Jesus. "
"Faith isn't about your personal confidence level — it's about whose voice you're responding to. "
"When God speaks, the water holds. Not because you're ready, but because He said so.\n\n"
"Many people are waiting in the boat — waiting for the storm to calm, waiting for more clarity, waiting until it feels safe. "
"But the miracle was never inside the boat. The impossible moment you've been praying for is waiting on the other side of obedience. "
"The water only holds when you actually step out.\n\n"
"You may not feel qualified. The conditions may look all wrong. But if Jesus is calling you forward, "
"you are more prepared than you think. His command is the authorization. His voice is the platform.\n\n"
"You can trust His word because it has never failed. Not once. Every person who ever stepped out in obedience to God's voice "
"found that He was already there before they arrived.\n\n"
"Jesus, when You say Come, I will come. I refuse to let fear keep me in the boat when You are calling me out. "
"I step out on Your word, with my eyes locked on You. Amen. \U0001f49c"
),

"13-05": (
"God's power doesn't decrease when the storm intensifies — your focus is the only thing that determines whether you sink or walk.\n\n"
"Peter was doing the impossible. Feet on water, wind in his face, heart pounding — and it was working. "
"Then he looked at the wind. He felt the waves. And what had been miracle became fear, and what had been victory became sinking. "
"This is the truth Jesus reveals here: the storm didn't stop Peter. His shifted gaze did.\n\n"
"Fear is not the enemy of faith — distraction is. The moment Peter's eyes moved from Jesus to the waves, "
"he lost what he already had. And the waves didn't get bigger. Jesus didn't move. Only Peter's focus changed.\n\n"
"You have experienced this. You stepped out in faith, and for a moment it was working. Then the noise got louder. "
"The obstacle looked bigger. Someone said something. The numbers didn't add up. And suddenly you're not walking — you're sinking. "
"Not because God left. Because your eyes drifted.\n\n"
"This is not condemnation — it's an invitation. Jesus didn't let Peter drown. He reached out immediately. "
"He still catches you in the sink. But His desire is for you to keep walking, eyes locked, unbroken.\n\n"
"You can trust that Jesus is closer than the storm. Not after it. Not above it. "
"Right there in it with you, close enough to catch you the instant you cry out.\n\n"
"When the waves roar, fix your gaze. Not on what's raging, but on the One who rules over all of it. "
"That refocused gaze is an act of worship.\n\n"
"Jesus, I bring You my drifting eyes and my sinking moments. Teach me to fix my gaze on You — especially when the storm gets loud. "
"I trust You completely. I will not let the wind steal what faith has built. Amen. \U0001f49c"
),

"14-05": (
"God's miracles are not just displays of power — they are invitations to go deeper, and a hardened heart can miss them both.\n\n"
"The disciples had just watched Jesus feed five thousand people with almost nothing. Then He walked on water and stilled a storm. "
"And yet Mark writes something startling: their heart was hardened. "
"Not because they doubted — because they saw the miracle but didn't let it reshape their understanding. "
"This is what hardness of heart looks like: amazed in the moment, unchanged in the soul.\n\n"
"A hardened heart isn't always cold rebellion. Sometimes it's a heart that has stopped receiving what God is showing. "
"We witness His faithfulness and say wow — then go back to fear and striving as if nothing happened. "
"We collect answered prayers without letting them build our faith for the next storm.\n\n"
"God's miracles are messages. Every breakthrough carries a word: trust Me more. Every answered prayer says, I know what I'm doing. "
"Every display of power is an invitation to go somewhere deeper in your relationship with Him.\n\n"
"What has God done in your life that you've moved past too quickly? What miracle are you still holding at arm's length, "
"impressed by it but not changed by it? Bring it back. Let the weight of His faithfulness land in your heart.\n\n"
"You can trust Him in the next storm because of what He did in the last one. "
"He is the same God. His track record does not change. Let it soften you.\n\n"
"A heart that stays soft before God is a heart that walks in increasing confidence, because every miracle builds on the last.\n\n"
"Jesus, soften my heart. I don't want to just collect miracles — I want to be changed by them. "
"Let every time You move in my life deepen my trust and reshape my faith. I receive what You are showing me. Amen. \U0001f49c"
),

"15-05": (
"God doesn't hide when He shows up — but it takes eyes tuned to His presence to recognize Him and run.\n\n"
"The moment Jesus stepped off the boat, the people recognized Him. They didn't debate or wait for confirmation. "
"They knew — and immediately they ran through the surrounding region, bringing every sick person they could find to where He was. "
"This is who God is: a healer whose presence creates urgency in people who recognize what's standing in front of them.\n\n"
"This kind of recognition is a gift, and it can be lost. "
"When we become too familiar with the idea of Jesus without staying close to the Person of Jesus, "
"our spiritual senses grow dull. We stop expecting. We lose the sense of awe. We stop running.\n\n"
"But when you are close to Him — when His Word is in your heart and His Spirit is moving in your awareness — "
"you notice when He shows up. In a conversation. In a moment of unexpected peace. In a Scripture that lands like a letter. "
"In the stillness that follows a storm. You recognize Him, and recognition ignites response.\n\n"
"You get to bring your needs to a God who is not hard to find. The people in this passage didn't have to persuade Jesus — "
"they just had to recognize Him and move. That same access is yours right now. He is here. He has not moved away from you.\n\n"
"You can trust that He is reachable because He has made Himself so. "
"The same Jesus who stood on that shore still stands ready to meet you exactly where you are.\n\n"
"Don't let familiarity steal your awe. Stay awake. Stay expectant. He is close — and when you recognize Him, everything can change.\n\n"
"Jesus, open my eyes to recognize You in every moment of my day. Keep my heart awake to Your presence. "
"I come to You now — with my needs, my people, my hope. You are here, and that changes everything. Amen. \U0001f49c"
),

"16-05": (
"God sees past your requests straight to your heart — and what He finds there determines what He can actually give you.\n\n"
"The crowd had chased Jesus across the lake. They found Him, they pressed in — and He told them the truth. "
"You're not looking for Me because of the signs. You're looking for Me because you ate the bread and were filled. "
"He saw exactly what was driving them. Not hunger for truth. Hunger for bread. "
"This is who He is: a God too honest and too loving to give you only what you're asking for when He knows you need something so much greater.\n\n"
"This isn't condemnation — it's a mirror. How often do we come to God primarily when we need something? "
"When the situation is desperate, when the provision has run out, when the storm has arrived? "
"He meets us there. But His heart is always drawing us toward something deeper than the answer to our immediate need.\n\n"
"He wants you to know Him — not just use Him. To seek His face, not just His hand. "
"Blessing is real, but relationship is the prize. Provision matters, but presence is everything.\n\n"
"You can check your own heart right now: what are you actually coming to God for today? "
"If the answer is only the need, He's not offended. He meets you there. But He's inviting you to want more than the miracle. "
"He's inviting you to want Him.\n\n"
"You can trust that He is worth seeking for Himself because everyone who has ever genuinely pursued God — not just His gifts — "
"has found that He is more than enough. He doesn't disappoint the ones who come for Him.\n\n"
"Jesus, purify my seeking. I don't want to come to You only when I need something. I want to know You. "
"You are my greatest treasure, my deepest pursuit. Be my first hunger, not my last resort. Amen. \U0001f49c"
),

"17-05": (
"God is not offering you one more thing to fill your days — He is offering you Himself, the only thing that truly satisfies.\n\n"
"Lord, give us this bread always. The crowd heard Jesus speak about bread from heaven that gives life to the world, "
"and their response was eager, leaning in, hungry. But they still didn't fully understand. "
"They were thinking about full stomachs and ongoing supply. Jesus was offering something their deepest hunger had never yet tasted. "
"This is who He is: a God whose provision is not a resource to manage but a Person to know.\n\n"
"We do the same thing. We hear about eternal life, the peace that surpasses understanding, the joy unspeakable — "
"and we want those things. But sometimes we want them the way we want better circumstances: "
"something to improve our situation while we stay in control. Jesus offers more than improvement. He offers Himself.\n\n"
"The Bread of Life does not just fill you for the morning. It sustains you at 3 AM when fear grips you. "
"It nourishes you when every earthly comfort has been stripped away. "
"It satisfies the part of you that nothing else has ever been able to reach.\n\n"
"You were made for this. The hunger you feel — the one that success, relationships, and achievement keep failing to fill — "
"was designed by God to lead you to God. It is not a flaw. It is a compass.\n\n"
"You can trust that Jesus satisfies because He is the only One who was designed for the deepest part of you. "
"Everything else was made for this world. He was made for eternity — and He put eternity in your heart.\n\n"
"Jesus, I want the bread that never runs out — I want You. Fill what nothing else can reach. "
"Be my source, my sustenance, my deepest satisfaction. I hunger for You above everything else. Amen. \U0001f49c"
),

"18-05": (
"God's economy runs on faith, not effort — and the moment you understand that, the striving loses its grip.\n\n"
"What shall we do, to work the works of God? It's the most human question in the Bible. "
"They heard something powerful and immediately asked: how do I perform this? What's the formula? What's the requirement? "
"And Jesus answered in a way that still surprises people: This is the work of God — that you believe in Him whom He sent. "
"This is who God is: a Father whose first requirement is not your performance but your trust.\n\n"
"The crowd was ready to do something. They were wired for works — for religious effort, for spiritual achievement, "
"for proving themselves worthy. But Jesus redirected the whole conversation to the inside. "
"Not what you do. What you believe. Not how you perform. Who you trust.\n\n"
"Most of us are carrying a version of the crowd's question. We work harder to feel more worthy. "
"We serve more to feel more accepted. We perform more hoping God will finally be impressed. "
"But you cannot out-work your way into what grace is already offering freely.\n\n"
"This doesn't mean works don't matter. But they flow from belief, not toward it. "
"You don't serve to earn — you serve because you're already loved. That changes everything about how you show up.\n\n"
"You can trust that belief is enough because Jesus said so — and He did not say it to people who had it all together. "
"He said it to a crowd still figuring out who He was. Your faith doesn't have to be perfect. It just has to be real.\n\n"
"Rest in what He has already done. Let the works flow from a loved heart, not a striving one.\n\n"
"Jesus, I lay down the performance and choose to believe. I am not trying to earn Your love — I'm responding to it. "
"Let everything I do flow from that place of grace. Amen. \U0001f49c"
),

"19-05": (
"God is drawing you toward Jesus right now — not through pressure, not through guilt, but through the quiet work of His voice in your heart.\n\n"
"Jesus said it plainly: Everyone who has heard and learned from the Father comes to Me. "
"This means the move toward Jesus was never entirely your own idea. "
"The Father was already working in you — drawing, wooing, opening, softening — before you ever consciously reached. "
"This is who God is: a Father who pursues the hearts of people long before they know they're being pursued.\n\n"
"Learning from the Father is not a performance task. It is not mastering theology or accumulating spiritual knowledge. "
"It is the posture of a heart that stays open — that says, speak to me, change me, shape me, lead me. "
"Revelation is the fruit of that posture. He teaches the humble. He fills the surrendered.\n\n"
"This means your spiritual growth is not primarily about your effort — it's about your receptivity. "
"The question isn't how hard are you working at faith. The question is how open are you to being taught. "
"Are you making space to hear? Are you slowing down enough to learn?\n\n"
"You can trust God's voice because He does not mislead. His Spirit leads into truth — always. "
"Every person who has genuinely leaned in to hear the Father has been led closer to Jesus. "
"Not to religion, not to rules — to a Person who is the answer to every question the heart carries.\n\n"
"Quiet the noise today. Not because you have to earn an audience, but because the Father is already speaking and you don't want to miss it.\n\n"
"Jesus, I open my heart to what the Father is teaching me. Draw me close. Speak clearly. "
"I want to be someone who listens, who learns, who comes to You every single time. Amen. \U0001f49c"
),

"20-05": (
"God's words are not information — they are the breath of heaven itself, and every time you receive them, something dead comes alive.\n\n"
"Jesus didn't come to offer better advice or an upgraded moral code. He came to speak life. "
"In John 6:63 He draws the line clearly: the flesh profits nothing, but the words He speaks are spirit and life. "
"Not helpful. Not inspiring. Life. This is who He is — a God whose language is the same substance that made the universe, "
"and it still carries the same creative power every time it reaches your heart.\n\n"
"That means when you read Scripture, you are not just reading ancient text. You are receiving living words from a living God. "
"Words that are able to heal what medicine cannot reach. Words that can reorder a chaotic mind. "
"Words that reach the dead places in your soul and call them back to life.\n\n"
"The flesh gets tired. Self-effort runs dry. Religious routine eventually empties out. "
"But the Spirit breathes fresh strength into you when you position yourself to receive what He's speaking. "
"That's why His Word isn't a discipline to endure — it's a lifeline to reach for every morning.\n\n"
"Are you feeding on His voice? Or surviving on your own reasoning, the world's noise, and secondhand inspiration? "
"There's a difference between knowing about God's Word and living inside it — letting it soak deep enough to change you.\n\n"
"You can trust that His words carry life because they have already proven it — in every life that has ever opened up to receive them.\n\n"
"Come hungry. Come open. Let His words go deep and do what only His Spirit can do.\n\n"
"Jesus, speak life into every part of me. I open myself to Your Word — not as a duty, but as a desperate need. "
"Fill me with spirit and life. Let what You say reshape everything. Amen. \U0001f49c"
),

"21-05": (
"God is not watching your hands — He is watching your heart, and He sees things there that no ritual can reach or clean.\n\n"
"The Pharisees had noticed: some disciples eating with unwashed hands. Their system said that made them defiled. "
"But Jesus wasn't bothered by the hands. He was looking at the hearts in the room — "
"the religious pride, the judgment dressed as holiness, the distance from God hidden behind performance. "
"This is who He is: a God who goes deeper than every standard we've set for looking spiritual.\n\n"
"The Pharisees had a detailed system. They had rules for washing, rules for eating, rules for appearances. "
"And they used those rules to measure others while their own hearts were far from the God they claimed to serve. "
"External compliance became a substitute for real connection. It always does, eventually.\n\n"
"This is the danger of religion without relationship. You can do all the right things, say all the right words, "
"show up in all the right places — and still be far from God in the place He actually lives: your interior world.\n\n"
"God is not after your record. He is after your heart. Not performance — intimacy. "
"Not clean hands — a surrendered life. He wants the inside, not because the outside doesn't matter, "
"but because when the inside is truly His, the outside follows naturally.\n\n"
"You can trust this because Jesus Himself modeled it. He was fully God, fully righteous — "
"and He didn't spend His time polishing appearances. He spent it in connection with the Father and genuine love toward people.\n\n"
"Let Jesus into the real places today — not the version you're performing, but the truth underneath it.\n\n"
"Jesus, search me deeper than my habits. I don't want to just look clean — I want to be genuinely Yours. "
"Purify my heart. Make my motives right. Draw me into the intimacy that religion alone can never give. Amen. \U0001f49c"
),

"22-05": (
"God doesn't want your performance — He wants your heart, and He can tell the difference between the two in an instant.\n\n"
"Jesus quoted Isaiah with laser precision: This people honors Me with their lips, but their heart is far from Me. "
"The Pharisees had mastered the vocabulary of worship. They knew the right words, the right posture, the right occasions. "
"But their hearts were distant — polished on the outside, cold on the inside. "
"This is who God is: a Father who is not fooled by the right language when the love behind it has gone cold.\n\n"
"Real worship costs something. It is not a performance you put on — it is a reality you live from. "
"When your heart is genuinely close to God, the words that come out of your mouth carry a different weight. "
"They aren't produced. They overflow.\n\n"
"Be honest: is there a gap right now between what you say about God and what you actually feel toward Him? "
"Not to shame yourself — just to locate yourself. Because the gap is not permanent, and God is not far.\n\n"
"God is not looking for theological precision from people with distant hearts. He is looking for honest nearness. "
"A rough, real, reaching-out-from-where-I-actually-am kind of worship is worth more than polished words without presence.\n\n"
"You can trust that He welcomes honest proximity because He said so — Draw near to God, and He will draw near to you. "
"That promise doesn't require you to feel ready. It requires you to move.\n\n"
"Let your words and your heart say the same thing today. Even if all you can say is, God, I want to want You — say it. "
"That is worship He honors.\n\n"
"Jesus, I don't want lip service — I want real nearness. Expose anything in me that's just performance. "
"Fill my heart with genuine love for You, and let my worship flow from the inside out. Amen. \U0001f49c"
),

"23-05": (
"God's Word is powerful enough to transform everything — but it only works in the life that actually lets it.\n\n"
"Jesus confronted something subtle and dangerous: making the Word of God of no effect through human tradition. "
"Not outright rejecting Scripture — just slowly surrounding it with so many layers of opinion, habit, and preference "
"that it can no longer cut, challenge, or change. "
"This is the warning: you can carry your Bible everywhere and still let the traditions around it silence what it says.\n\n"
"We all do this in some form. We read the parts that comfort us and quietly avoid the parts that confront us. "
"We hold onto interpretations our culture handed us without ever asking if they're actually what God said. "
"We let what's familiar become more authoritative than what's true.\n\n"
"But the Word of God is alive. It is sharper than any two-edged sword, Hebrews says. "
"It pierces even to the division of soul and spirit. It discerns the thoughts and intentions of the heart. "
"That's not language for a book you read casually — it's language for a force that changes you.\n\n"
"To let it work, you have to let it lead. Not read it to confirm what you already believe, "
"but open it ready to be changed, challenged, and redirected.\n\n"
"You can trust the Word because it has never failed anyone who fully submitted to it. "
"Every life built on Scripture has a foundation that holds. Every life that built on substitutes has eventually found them hollow.\n\n"
"Honor what God has spoken. Build on it. Stand on it. Let it be the loudest voice in the room.\n\n"
"Jesus, I never want to make Your Word powerless in my life. Strip away everything I've elevated above Your truth. "
"Teach me to receive what You say — all of it — and to build my life on what You've spoken. Amen. \U0001f49c"
),

"24-05": (
"God is not concerned with your exterior — He is doing deep, irreversible work in the place where your real life actually lives.\n\n"
"Jesus flipped the entire religious system with one statement: It's not what goes into a person that defiles them — "
"it's what comes out. The Pharisees were obsessed with external purity. Jesus went straight to the source. "
"He is always more interested in your heart than your reputation, your interior than your image, your reality than your performance.\n\n"
"What comes out of us reveals what's actually in us. Not the polished version we present on Sunday. "
"The words we say when we're tired. The thoughts we entertain when no one's watching. "
"The reactions we have when life doesn't go our way. That's where our real condition shows up.\n\n"
"This isn't to condemn you — it's to invite you into the deeper work God wants to do. "
"Because Jesus didn't diagnose the heart problem just to leave you without a solution. "
"He IS the solution. He is the one who exchanges old hearts for new ones. He transforms the source, not just the symptoms.\n\n"
"You don't have to manage your way to holiness. You don't have to white-knuckle your way to better behavior. "
"You come to Him honestly, let Him in to the real places, and trust Him to do what only He can do.\n\n"
"You can trust this process because He said He makes all things new. Not improves — new. "
"That's not behavior modification. That's the miracle of a transformed heart.\n\n"
"What you bring to the surface, He can heal. What you hide, stays. Bring it all into the light.\n\n"
"Jesus, search me and know me. I don't want to hide behind appearances. "
"Purify what's in me so that what flows out of me reflects Your love and truth. Make me clean from the inside. Amen. \U0001f49c"
),

"25-05": (
"God sees every hidden corner of your heart — and He chose to love you anyway, before you fixed a single thing.\n\n"
"Jesus named it directly: from within, out of the heart of men, proceed evil thoughts. "
"He didn't soften it. He didn't leave room for us to blame outside circumstances or external influences. "
"The root of what defiles us, He said, is not out there — it's in here. "
"This is the honesty of a God who loves you too much to pretend the problem doesn't exist.\n\n"
"But He named it without condemning you. He exposed the issue the way a surgeon marks the site of surgery — "
"not to shame you, but to heal you. He already knew what was in the human heart before He came. "
"He saw it all, and He came anyway. He went to the cross anyway. He chose you anyway.\n\n"
"The real danger isn't what's in your heart — it's letting it stay there unchallenged. "
"Sin doesn't announce itself. It starts as a thought, a whisper, an entertained idea. "
"Left unaddressed, it becomes the pattern that shapes behavior, corrodes relationships, and creates distance from God.\n\n"
"You don't fight this with willpower. You fight it with proximity to Jesus. "
"When you stay close to Him, the hidden things surface in the light of His presence — and that is where transformation happens. "
"He doesn't clean what you don't bring to Him. Bring it all.\n\n"
"You can trust Him with the ugly parts because He already carried them to the cross. "
"Nothing you bring before Him is a surprise. Everything you bring to Him can be healed.\n\n"
"You are not your worst hidden thought. You are the one Jesus died to free from it.\n\n"
"Jesus, I bring every hidden place into Your light. I don't want to manage what only You can heal. "
"Cleanse me, renew me, and fill me with Your Spirit. Change me from the inside out. Amen. \U0001f49c"
),

"26-05": (
"God's grace has no borders — and the faith that refuses to be discouraged will always find a way through to breakthrough.\n\n"
"A Gentile woman — an outsider by every religious standard of the day — came to Jesus desperate for her daughter's freedom. "
"What happened next would test anyone's resolve. He called her a dog, essentially saying the blessing wasn't for her. "
"But Jesus wasn't being cruel — He was drawing out what He already saw in her: a faith that would not flinch. "
"This is who He is: a God who sometimes tests the persistence of faith before He releases the power of breakthrough.\n\n"
"She could have walked away offended. Most people would have. Instead, she leaned further in. "
"Yes, Lord — yet even the little dogs under the table eat from the children's crumbs. "
"That answer was breathtaking. It said, I know my place, and I don't care. I just need You to move.\n\n"
"Jesus called her faith great. Not because she had the right credentials. Not because she was in the right category. "
"Because she refused to let rejection be the last word. That is what great faith looks like.\n\n"
"You are not too far outside, too broken, or too late for God to move in your situation. "
"The grace of Jesus has always crossed the lines that religion drew. "
"His healing has always reached the people who were told they didn't qualify.\n\n"
"You can trust that He responds to persistent faith because He proved it here. "
"She didn't have the right background. She had the right posture — desperate and unwilling to give up.\n\n"
"Don't let silence become your stopping point. Press through. Keep asking. Keep believing. The breakthrough is coming.\n\n"
"Jesus, even when the answer feels delayed, I will not stop coming. I believe Your grace reaches me. "
"I will keep pressing, keep trusting, and keep expecting — until breakthrough comes. Amen. \U0001f49c"
),

"27-05": (
"God doesn't owe you a sign — and yet He has already given you more evidence of His love than you could spend a lifetime processing.\n\n"
"The Pharisees came demanding proof. They had witnessed miracles, heard teachings no one had ever spoken, "
"watched blind eyes open and the dead return to life. And still they wanted more. "
"Mark tells us Jesus sighed deeply in His spirit. Not frustration — grief. "
"This is who He is: a God whose heart breaks when the people He loves can't see what's right in front of them.\n\n"
"Their request for a sign wasn't hunger — it was resistance. They weren't asking because they wanted to believe. "
"They were testing, looking for an angle, keeping their options open. "
"And Jesus refused to perform for a heart that wasn't actually seeking.\n\n"
"Faith is not the result of enough evidence. Evidence never produced faith in the Pharisees — and it won't do it in us either. "
"Faith is a response to presence. You recognize something real, you respond, you trust. "
"It begins not with proof but with surrender.\n\n"
"Here is what you already have: the Word of God, the Spirit of God, the testimony of history, "
"and the record of a God who has never once broken a promise. That's not nothing. "
"That's more than enough to trust Him with your life.\n\n"
"You can trust Him without the sign because He has already proven who He is — at the cross, in the resurrection, "
"and in every moment He has carried you that you didn't notice until you looked back.\n\n"
"Don't wait for more proof. Look closer at what's already there.\n\n"
"Jesus, I don't want to grieve Your Spirit by demanding what I've already been given. "
"Open my eyes to what You're already doing. I trust You — not because I see it all clearly, but because You are faithful. Amen. \U0001f49c"
),

"28-05": (
"God has already given you more than enough to believe — but a closed heart will walk past a miracle without recognizing it.\n\n"
"The Pharisees and Sadducees arrived together — two groups who rarely agreed on anything — united in one goal: "
"to test Jesus, to trap Him, to demand He prove Himself on their terms. "
"They had seen everything. Every miracle. Every impossible moment. "
"And still they stood there asking for a sign. "
"This is the warning in this passage: you can have access to God's power and still miss God's presence.\n\n"
"Jesus saw through it immediately. He knew the difference between seeking and testing. "
"Between hunger and hardness. Between someone reaching for truth and someone building a case against it. "
"You can't manufacture faith on demand for people who have already decided not to believe.\n\n"
"The real danger here isn't unbelief — it's the subtler version: saying you want to see God move "
"while actually protecting yourself from the risk of trusting Him. "
"We do it too. We ask God to prove Himself while ignoring the peace He's already given, "
"the door He's already opened, the word He's already spoken.\n\n"
"Recognition requires openness. When your heart is open to God, even small moments feel significant. "
"When it's closed, even heaven's loudest signs can feel ordinary.\n\n"
"You can trust that God is moving right now because He is always working. "
"He doesn't go silent. He doesn't withdraw. He keeps showing up — in the ordinary moments you walk past.\n\n"
"Open your eyes. Soften your posture. He's not hiding. He's already here.\n\n"
"Jesus, I don't want to be found looking for signs while ignoring Your presence. "
"Open my heart to recognize You in every moment. I trust You — not because I demanded proof, but because You are faithful. Amen. \U0001f49c"
),

"29-05": (
"God is in the boat with you — and that fact is more powerful than anything the storm can do.\n\n"
"The disciples were doing exactly what Jesus told them to do, going exactly where He sent them. "
"And a violent storm hit anyway. That matters. Obedience does not guarantee calm waters. "
"Sometimes it leads you straight into the storm. But here is what else the story shows: "
"Jesus was with them. Asleep in the stern — at rest, at peace, undisturbed. "
"His rest was not absence. It was authority. This is who He is: a God whose peace in the storm is proof of His power over it.\n\n"
"The disciples panicked. They cried out, Lord, save us — we are perishing. "
"And in that cry is something deeply human: the fear that the storm means God has forgotten you. "
"That His silence is distance. That if He cared, He wouldn't let you feel this.\n\n"
"But He was there the whole time. Not standing by passively — abiding with them in the boat. "
"And when they cried out, He answered. Not before. Because the cry itself was part of the story.\n\n"
"Your storm right now is not evidence that God is gone. It may be evidence that He trusts you enough "
"to walk through something that will reshape your faith from the inside.\n\n"
"You can trust that He is with you because He said so: I will never leave you or forsake you. "
"Not a conditional promise. Not a fair-weather commitment. Never.\n\n"
"Let your cry lead you to confidence. He is in your boat. He has not moved. And the storm will not have the final word.\n\n"
"Jesus, even when the waves are high and my faith feels small, I choose to trust You. "
"You are in my boat. You are still Lord over this storm. I will not be moved by what I see. Amen. \U0001f49c"
),

"30-05": (
"God doesn't ask you to carry the cross alone — He walks with you through it and calls what looks like loss the path to real life.\n\n"
"Jesus didn't soften this. Deny yourself. Take up your cross daily. Follow Me. "
"He wasn't offering a comfortable religion — He was issuing an invitation to the only kind of life that actually means something. "
"This is who He is: a God who loves you enough to call you past comfort and into something that costs you — "
"because He knows what waits on the other side of surrender.\n\n"
"The cross wasn't a symbol then. It was an instrument of death. When Jesus said take it up, everyone in that crowd knew exactly what He meant. "
"Lay down your life. Not just once — daily. Every morning, your ego gets the same invitation: you're not in charge today.\n\n"
"But here is what following Jesus makes clear: you don't lose your life by surrendering it. "
"You lose the false version that was keeping you small. The life you lay down at His feet "
"is the life that was keeping you from the one He designed for you.\n\n"
"This isn't about adding hardship to your days. It's about releasing the control you were never meant to carry. "
"Every time you choose His way over your own — patience over reaction, forgiveness over bitterness, obedience over convenience — "
"you are picking up the cross. And every time you do, you are becoming who you were made to be.\n\n"
"You can trust Him with your surrender because He surrendered everything first. He carried the cross you deserved. "
"He rose to prove that what looks like an ending is actually a beginning.\n\n"
"Lay it down. He's already been where you're going, and He's waiting on the other side.\n\n"
"Jesus, I pick up my cross today — not with dread, but with trust. I surrender my plans, my control, my comfort. "
"I follow You because You are worth everything, and I believe the life You give is better than the one I'm holding onto. Amen. \U0001f49c"
),

"31-05": (
"God will not ask you to give up something precious unless He intends to reveal something greater — "
"and the altar is not the end of the story.\n\n"
"Abraham built the altar. He arranged the wood. He bound his son — the miracle, the promise, the child he had waited decades for — "
"and placed him on top. And he did it without hesitation. "
"Not because he understood, but because he knew who was asking. "
"This is who God is: a Father whose requests always come from a heart that has better plans than the ones we're surrendering.\n\n"
"This wasn't a test of Abraham's strength. It was a test of his trust. "
"Would he hold the promise more tightly than he held the Promiser? "
"Would the gift become the god? The answer Abraham gave that day shaped a covenant that has echoed through history.\n\n"
"You will face your own altar moments. They won't look the same — but they will feel the same. "
"A dream you've built your identity around. A relationship that feels irreplaceable. A plan you've been certain was from God. "
"And then He quietly asks: do you trust Me more than you trust this?\n\n"
"The altar is not a place of loss. It is the place where what is temporal gets exchanged for what is eternal. "
"Where what you cannot keep gets released to the One who can give back what no one else could.\n\n"
"You can trust Him at the altar because He provided the ram. He didn't let Abraham leave empty. "
"Jehovah Jireh — the Lord will provide — was spoken for the first time on that mountain, and it has been true ever since.\n\n"
"What you lay down in faith, God will not waste. What you surrender in trust, He returns in transformation.\n\n"
"Jesus, I trust You with everything I hold dear. You are my provider, my keeper, my enough. "
"I lay it all on the altar, believing that what I surrender in faith, You will multiply in grace. Amen. \U0001f49c"
),

}

# Load JSON
with open(DEVOTIONALS_PATH, "r", encoding="utf-8") as f:
    data = json.load(f)

devotionals = data["devotionals"]

updated = 0
skipped = 0
issues = []

for entry in devotionals:
    date = entry.get("date", "")
    if not date.endswith("-05"):
        continue
    if date in NEW_TEXTS:
        entry["devotionalText"] = NEW_TEXTS[date]
        updated += 1
    else:
        skipped += 1
        issues.append(f"No new text for {date}")

data["devotionals"] = devotionals

with open(DEVOTIONALS_PATH, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)

print(f"Updated: {updated}, Skipped: {skipped}")
if issues:
    print("Issues:", issues)

# Validate
with open(DEVOTIONALS_PATH, "r", encoding="utf-8") as f:
    check = json.load(f)

may_entries = [e for e in check["devotionals"] if e.get("date","").endswith("-05")]
print(f"\nValidation — {len(may_entries)} May entries:")
all_ok = True
for e in sorted(may_entries, key=lambda x: x["date"]):
    dt = e.get("devotionalText","")
    n = len(dt)
    status = "OK" if 1400 <= n <= 1600 else ("SHORT" if n < 1400 else "LONG")
    if status != "OK":
        all_ok = False
    print(f"  {e['date']} | {n} chars | {status} | {e['title'][:40]}")

print(f"\nAll in range: {all_ok}")
