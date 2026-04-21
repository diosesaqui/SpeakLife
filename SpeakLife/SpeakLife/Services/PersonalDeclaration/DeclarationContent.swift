//
//  DeclarationContent.swift
//  SpeakLife
//
//  Curated verse + declaration text per category.
//  Separated from matching logic (Single Responsibility).
//

import Foundation

enum DeclarationContent {

    static func verse(for category: DeclarationCategory) -> String {
        switch category {
        case .health:
            return "\"By his wounds we are healed.\""
        case .wealth:
            return "\"My God will supply every need of yours according to his riches in glory in Christ Jesus.\""
        case .anxiety:
            return "\"Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God. And the peace of God, which transcends all understanding, will guard your hearts and your minds.\""
        case .marriage:
            return "\"Two are better than one, because they have a good return for their labor. If either of them falls down, one can help the other up.\""
        case .parenting:
            return "\"Train up a child in the way he should go; even when he is old he will not depart from it.\""
        case .destiny:
            return "\"For I know the plans I have for you — plans to prosper you and not to harm you, plans to give you hope and a future.\""
        case .identity:
            return "\"See what great love the Father has lavished on us, that we should be called children of God! And that is what we are!\""
        case .rest:
            return "\"Come to me, all you who are weary and burdened, and I will give you rest.\""
        case .joy:
            return "\"Weeping may stay for the night, but rejoicing comes in the morning.\""
        case .favor:
            return "\"For the Lord God is a sun and shield; the Lord bestows favor and honor. No good thing does he withhold from those whose walk is blameless.\""
        case .grace:
            return "\"There is now no condemnation for those who are in Christ Jesus.\""
        case .godsprotection:
            return "\"No weapon formed against you shall prosper, and every tongue which rises against you in judgment you shall condemn.\""
        case .addiction:
            return "\"It is for freedom that Christ has set us free. Stand firm, then, and do not let yourselves be burdened again by a yoke of slavery.\""
        case .confidence:
            return "\"Let us approach the throne of grace with confidence, so that we may receive mercy and find grace to help us in our time of need.\""
        case .fear:
            return "\"For God has not given us a spirit of fear, but of power and of love and of a sound mind.\""
        case .wisdom:
            return "\"If any of you lacks wisdom, let him ask God, who gives generously to all without reproach, and it will be given him.\""
        case .love:
            return "\"He who finds a wife finds a good thing and obtains favor from the Lord.\""
        case .work:
            return "\"Whatever you do, work at it with all your heart, as working for the Lord, not for human masters. It is the Lord Christ you are serving.\""
        case .business:
            return "\"The blessing of the Lord makes rich, and he adds no sorrow with it.\""
        case .innerHealing:
            return "\"He heals the brokenhearted and binds up their wounds.\""
        case .spiritualGrowth:
            return "\"But grow in the grace and knowledge of our Lord and Savior Jesus Christ. To him be glory both now and forever.\""
        case .miracles:
            return "\"Everything is possible for one who believes.\""
        case .hardtimes:
            return "\"The sufferings of this present time are not worth comparing with the glory that is to be revealed to us.\""
        case .warfare:
            return "\"The Lord will fight for you; you need only to be still.\""
        case .friendship:
            return "\"God sets the lonely in families. He leads out the prisoners with singing.\""
        case .purity:
            return "\"Create in me a clean heart, O God, and renew a right spirit within me.\""
        case .hope:
            return "\"May the God of hope fill you with all joy and peace as you trust in him, so that you may overflow with hope by the power of the Holy Spirit.\""
        case .grief:
            return "\"Blessed are those who mourn, for they will be comforted.\""
        case .fertility:
            return "\"He settles the childless woman in her home as a happy mother of children. Praise the Lord.\""
        case .salvation:
            return "\"The Lord is not slow in keeping his promise... not wanting anyone to perish, but everyone to come to repentance.\""
        case .debt:
            return "\"You will lend to many nations but will borrow from none. The Lord will make you the head, not the tail.\""
        case .education:
            return "\"The Lord gives wisdom; from his mouth come knowledge and understanding.\""
        case .housing:
            return "\"My people will live in peaceful dwelling places, in secure homes, in undisturbed places of rest.\""
        case .divorce:
            return "\"The Lord is close to the brokenhearted and saves those who are crushed in spirit.\""
        case .wellness:
            return "\"Do you not know that your bodies are temples of the Holy Spirit, who is in you, whom you have received from God? You are not your own.\""
        case .mentalHealth:
            return "\"He restores my soul. He leads me in paths of righteousness for his name's sake.\""
        case .forgiveness:
            return "\"Bear with each other and forgive one another if any of you has a grievance against someone. Forgive as the Lord forgave you.\""
        case .newSeason:
            return "\"See, I am doing a new thing! Now it springs up; do you not perceive it? I am making a way in the wilderness and streams in the wasteland.\""
        case .singleParent:
            return "\"A father to the fatherless, a defender of widows, is God in his holy dwelling. God sets the lonely in families.\""
        case .anger:
            return "\"Whoever is slow to anger is better than the mighty, and he who rules his spirit than he who takes a city.\""
        default:
            return "\"Being confident of this, that he who began a good work in you will carry it on to completion until the day of Christ Jesus.\""
        }
    }

    static func verseReference(for category: DeclarationCategory) -> String {
        switch category {
        case .health:         return "Isaiah 53:5"
        case .wealth:         return "Philippians 4:19"
        case .anxiety:        return "Philippians 4:6–7"
        case .marriage:       return "Ecclesiastes 4:9–10"
        case .parenting:      return "Proverbs 22:6"
        case .destiny:        return "Jeremiah 29:11"
        case .identity:       return "1 John 3:1"
        case .rest:           return "Matthew 11:28"
        case .joy:            return "Psalm 30:5"
        case .favor:          return "Psalm 84:11"
        case .grace:          return "Romans 8:1"
        case .godsprotection: return "Isaiah 54:17"
        case .addiction:      return "Galatians 5:1"
        case .confidence:     return "Hebrews 4:16"
        case .fear:           return "2 Timothy 1:7"
        case .wisdom:         return "James 1:5"
        case .love:           return "Proverbs 18:22"
        case .work:           return "Colossians 3:23–24"
        case .business:       return "Proverbs 10:22"
        case .innerHealing:   return "Psalm 147:3"
        case .spiritualGrowth: return "2 Peter 3:18"
        case .miracles:       return "Mark 9:23"
        case .hardtimes:      return "Romans 8:18"
        case .warfare:        return "Exodus 14:14"
        case .friendship:     return "Psalm 68:6"
        case .purity:         return "Psalm 51:10"
        case .hope:           return "Romans 15:13"
        case .grief:          return "Matthew 5:4"
        case .fertility:      return "Psalm 113:9"
        case .salvation:      return "2 Peter 3:9"
        case .debt:           return "Deuteronomy 28:12–13"
        case .education:      return "Proverbs 2:6"
        case .housing:        return "Isaiah 32:18"
        case .divorce:        return "Psalm 34:18"
        case .wellness:       return "1 Corinthians 6:19"
        case .mentalHealth:   return "Psalm 23:3"
        case .forgiveness:    return "Colossians 3:13"
        case .newSeason:      return "Isaiah 43:19"
        case .singleParent:   return "Psalm 68:5–6"
        case .anger:          return "Proverbs 16:32"
        default:              return "Philippians 1:6"
        }
    }

    static func declaration(for category: DeclarationCategory) -> String {
        switch category {
        case .health:
            return "I declare that by the stripes of Jesus I am healed. My body is the temple of the Holy Spirit and healing is my covenant right. Every symptom must bow to the name of Jesus and I receive my healing now — spirit, soul, and body."

        case .wealth:
            return "I declare that God is my provider and I shall not lack any good thing. He is opening doors of favor, creating streams of income, and multiplying everything I put my hands to. I am debt-free and moving into overflow."

        case .anxiety:
            return "I declare that the peace of God that surpasses all understanding guards my heart and mind right now. I cast every worry, every fear, and every anxious thought at the feet of Jesus. I am not moved by what I see — I am anchored by what I know."

        case .marriage:
            return "I declare that my marriage is covered by the blood of Jesus. Unconditional love, deep friendship, and unbreakable covenant define this relationship. What God has joined together, no force on earth can tear apart. We are growing stronger every day."

        case .parenting:
            return "I declare that my children are taught by the Lord and great is their peace. They are covered, protected, and walking in the destiny God wrote for them before they were born. I am exactly the parent God chose for them and I will not fear for them."

        case .destiny:
            return "I declare that I will walk fully in the purpose God placed inside me before the foundation of the world. My gifts are awakened, my assignment is clear, and I will not leave this earth without fulfilling everything God has called me to do."

        case .identity:
            return "I declare that I know who I am — I am a child of God, fully loved and completely accepted. My worth is not tied to performance, approval, or the opinion of others. I am who God says I am and that truth is unshakeable."

        case .rest:
            return "I declare that the rest of God is mine. I will not carry what Jesus already bore. I release striving, I release control, and I receive the supernatural rest that only comes from trusting the One who holds all things together."

        case .joy:
            return "I declare that the joy of the Lord is my strength. Weeping may have lasted through the night, but my morning is coming. I choose joy not as a feeling but as a force — and it grows stronger in me every single day."

        case .favor:
            return "I declare that God's favor surrounds me like a shield. The right doors are opening, the right people are finding me, and I am being positioned by God in rooms I could not get into by my own strength. His blessing is on everything I touch."

        case .grace:
            return "I declare that I am completely free from condemnation. The blood of Jesus has settled my past, my failures, and my mistakes once and for all. I do not carry guilt — I carry grace, and grace is taking me further than I ever thought possible."

        case .godsprotection:
            return "I declare that I and everyone I love are fully covered by the protection of God Almighty. No weapon formed against us shall prosper. Angels surround us, the Lord fights our battles, and nothing the enemy sends will reach us."

        case .addiction:
            return "I declare that I am completely free because Christ has made me free. The power of sin and addiction is broken off my life by the blood of Jesus. I do not belong to what once held me — I belong to God, and whom the Son sets free is free indeed."

        case .confidence:
            return "I declare that I step boldly into every room, every conversation, and every calling God has placed before me. I do not shrink back. I do not apologize for being anointed. God did not give me timidity — He gave me power, love, and a sound mind."

        case .fear:
            return "I declare that fear has no authority over my life. God has given me a spirit of power, love, and a sound mind. I will not bow to what I feel. I will advance in faith, knowing that the God who is with me is greater than anything that stands against me."

        case .wisdom:
            return "I declare that I have the wisdom of God on the inside of me. Every decision I make is guided by the Holy Spirit. I will not be confused. I will not be deceived. Clarity and discernment are mine and I know what to do."

        case .love:
            return "I declare that God is writing a love story for my life. The right person — the one God has prepared for me — is coming. I will not settle, I will not rush, and I will not lose faith. God who is faithful in all things is faithful in this, and I trust His timing completely."

        case .work:
            return "I declare that God's hand is on my career. I am excellent at what I do because I do it for the Lord. The right opportunities are coming to me. My work is valued, my contributions are seen, and God is promoting me into everything He has prepared."

        case .business:
            return "I declare that my business is blessed because God is my business partner. He gives me creative ideas, divine connections, and strategies the world cannot teach. My doors of opportunity are opening, my clients are coming, my revenue is growing, and every product and service I offer carries the favor of God. I do not just build a business — I build a Kingdom assignment."

        case .innerHealing:
            return "I declare that God is healing every wound in my heart — every hurt, every trauma, every place that was broken. He is gentle with my pain and He will not leave any part of me unhealed. I am being restored from the inside out."

        case .spiritualGrowth:
            return "I declare that I am growing in the grace and knowledge of Jesus Christ every single day. My faith is not stagnant — it is alive, increasing, and bearing fruit. The Holy Spirit is my teacher and He is leading me deeper every time I seek God."

        case .miracles:
            return "I declare that I serve the God of the impossible. What looks impossible to man is completely possible with God. I refuse to accept the limits of what I can see. I am expecting a miracle and I believe that what He promised, He will perform."

        case .hardtimes:
            return "I declare that this season does not define my destiny. The suffering I face right now is not the end of my story — it is the setup for God's glory. I will not quit. I will not give up. God is working in ways I cannot yet see and my breakthrough is closer than it has ever been."

        case .warfare:
            return "I declare that the battle belongs to the Lord. I am not fighting for victory — I am fighting from victory. I put on the full armor of God and I stand firm. Every assignment of the enemy against my life, my family, and my future is cancelled in the name of Jesus."

        case .friendship:
            return "I declare that God is bringing the right people into my life — covenant friendships, divine connections, and community that was handpicked by Heaven. I am not alone. God sets the lonely in families and His plan for my relationships is good."

        case .purity:
            return "I declare that God is creating a clean heart in me and renewing a right spirit within me. I am not defined by where I have been. The Holy Spirit is at work in me and I walk in holiness not by willpower but by the grace of God that teaches me to say no to ungodliness."

        case .hope:
            return "I declare that hope is alive in me because the God of all hope lives in me. What was deferred, what was delayed, and what seemed lost is not gone — it is on its way. I will not lose hope. My expectation is in the Lord and He will not disappoint me."

        case .grief:
            return "I declare that God is close to me in this grief. He is not distant — He is the God who draws near to the brokenhearted. My pain is real and He sees every tear. I will not grieve without hope. The same God who conquered death walks through this loss with me, and His comfort will reach places no human comfort ever could. I am held."

        case .fertility:
            return "I declare that my body was designed by God and He has the final word over my womb. I choose to believe the report of the Lord over the report of any doctor or test. I am not defined by a diagnosis — I am defined by the God who opens wombs, who gave Sarah a child past the age of reason and blessed Hannah after years of tears. My miracle is coming, and I will not stop expecting it."

        case .salvation:
            return "I declare that my loved one is not lost — they are known by God, seen by God, and pursued by God. His Word never returns void, and every seed of faith ever planted in them is still alive. The same Spirit that raised Christ from the dead can raise their faith. The prodigal always has a father waiting at the end of the road. I will pray without ceasing and I will believe without wavering — they are coming home."

        case .debt:
            return "I declare that the chain of debt over my life is being broken. God is giving me wisdom, creative strategy, and supernatural favor in my finances. Every door that needs to open for my financial freedom is opening. I am moving from debt to lender, from barely surviving to walking in God's overflow. No financial mountain is too big for the God who multiplied five loaves to feed thousands. My turnaround is here."

        case .education:
            return "I declare that God's wisdom is in me and working through me. My mind is sharp, my understanding is clear, and I retain what I study with supernatural clarity. The God who gave Daniel and his friends ten times the wisdom of those around them has anointed me to excel. No exam, no obstacle, and no moment of doubt will stand between me and what God has called me to achieve. I am prepared, I am capable, and I will succeed."

        case .housing:
            return "I declare that God is securing a home for me and my family. He makes a way where there is no way. The right doors are opening, the right resources are arriving, and no setback is final. The God who provided manna in the wilderness, who sent ravens to feed Elijah, and who has never once let His children go without — He is providing for me right now in ways I cannot yet see. Stable, safe housing is mine."

        case .divorce:
            return "I declare that God is putting me back together. What this season broke in me — He is healing. My identity is not in my marital status; it is in Christ alone. I am not less loved, less worthy, or less called because of what happened. God is writing the next chapter of my life and it is filled with peace, purpose, and restoration. What was meant to destroy me has become a doorway. I am not starting over — I am starting forward."

        case .wellness:
            return "I declare that my body is the temple of the Holy Spirit and I honor it as such. God is giving me discipline, wisdom, and genuine desire to steward my health well. I break every cycle of defeat, shame, and starting over that has kept me stuck. His grace reaches this area of my life too — not just my soul. I am making real, sustainable progress and I will not give up on the body God gave me."

        case .mentalHealth:
            return "I declare that God is the restorer of my mind and my soul. I am not defined by a diagnosis — I am defined by whose I am. I receive every resource God provides for my healing — natural and supernatural — and I reject every ounce of shame attached to my struggle. The God who said He has not given me a spirit of fear but of power, love, and a sound mind is speaking that over me right now. I am not what I feel. I am not what I fight. I am His, I am held, and I am healing."

        case .forgiveness:
            return "I declare that I choose to forgive. Not because what happened was okay — it was not. But because bitterness is a prison I refuse to stay in any longer. I release this person and this wound into the hands of God. I will not let what they did rob me of one more day of my peace, my joy, or my future. God is my vindicator. He sees what happened. And He is turning what was meant to destroy me into something I cannot yet imagine. I am free."

        case .newSeason:
            return "I declare that God is doing a new thing in my life and I perceive it. What is behind me is behind me — fully. The old chapter is closed and a new one is open. God wastes nothing — not the pain, not the failure, not the time I thought was lost. Every experience was preparation for where I am going. I step into this new beginning with bold faith, not with fear, trusting the God who says He makes all things new. My best days are not behind me."

        case .singleParent:
            return "I declare that God is the co-parent I need. He covers what I cannot carry alone — the gaps, the exhaustion, the fear, and the provision. My children are not at a disadvantage — they are covered by the same God who parted the Red Sea and provided for widows with nothing but a jar of oil. I am enough because God is more than enough, and He is with us. My household is blessed, my children are protected, and we will not lack any good thing."

        case .anger:
            return "I declare that I have been given a spirit of power, love, and a sound mind — not a spirit of rage. The fruit of the Holy Spirit is growing in me, and that fruit includes self-control. God is healing the wound underneath this anger so I can respond to life instead of react to it. I will not be mastered by what rises up in me. I am slow to anger and mighty in spirit, and I walk in peace that does not make sense to those around me."

        default:
            return "I declare that God who started this good work in me will bring it to completion. What He promised, He will perform. I will not stop believing. Every delay has been a setup and my breakthrough is on its way."
        }
    }
}
