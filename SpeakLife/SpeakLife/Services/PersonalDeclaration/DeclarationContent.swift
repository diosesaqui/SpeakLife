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
        case .health:         return "\"I am the Lord who heals you.\""
        case .wealth:         return "\"My God will supply every need of yours according to his riches in glory.\""
        case .anxiety:        return "\"Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.\""
        case .marriage:       return "\"What God has joined together, let no one separate.\""
        case .parenting:      return "\"Train up a child in the way he should go; even when he is old he will not depart from it.\""
        case .destiny:        return "\"For I know the plans I have for you — plans to prosper you and not to harm you, plans to give you hope and a future.\""
        case .identity:       return "\"You are a chosen people, a royal priesthood, a holy nation, God's special possession.\""
        case .rest:           return "\"You will keep in perfect peace those whose minds are steadfast, because they trust in you.\""
        case .joy:            return "\"The joy of the Lord is your strength.\""
        case .favor:          return "\"For surely, O Lord, you bless the righteous; you surround them with your favor as with a shield.\""
        case .grace:          return "\"There is now no condemnation for those who are in Christ Jesus.\""
        case .godsprotection: return "\"The Lord will fight for you; you need only to be still.\""
        case .addiction:      return "\"I can do all things through Christ who strengthens me.\""
        case .confidence:     return "\"I can do all things through Christ who strengthens me.\""
        case .fear:           return "\"For God has not given us a spirit of fear, but of power and of love and of a sound mind.\""
        case .wisdom:         return "\"If any of you lacks wisdom, let him ask God, who gives generously to all without reproach.\""
        case .love:           return "\"For God so loved the world that he gave his only Son.\""
        default:              return "\"Being confident of this, that he who began a good work in you will carry it on to completion.\""
        }
    }

    static func verseReference(for category: DeclarationCategory) -> String {
        switch category {
        case .health:         return "Exodus 15:26"
        case .wealth:         return "Philippians 4:19"
        case .anxiety:        return "Philippians 4:6"
        case .marriage:       return "Matthew 19:6"
        case .parenting:      return "Proverbs 22:6"
        case .destiny:        return "Jeremiah 29:11"
        case .identity:       return "1 Peter 2:9"
        case .rest:           return "Isaiah 26:3"
        case .joy:            return "Nehemiah 8:10"
        case .favor:          return "Psalm 5:12"
        case .grace:          return "Romans 8:1"
        case .godsprotection: return "Exodus 14:14"
        case .addiction:      return "Philippians 4:13"
        case .confidence:     return "Philippians 4:13"
        case .fear:           return "2 Timothy 1:7"
        case .wisdom:         return "James 1:5"
        case .love:           return "John 3:16"
        default:              return "Philippians 1:6"
        }
    }

    static func declaration(for category: DeclarationCategory) -> String {
        switch category {
        case .health:
            return "I declare that I am healed by the stripes of Jesus. My body is the temple of the Holy Spirit and every cell aligns with God's perfect design. Healing is mine — I receive it now and every day until I see it fully manifest."
        case .wealth:
            return "I declare that God is my provider and my source. Every need is met. Every door He ordained is open. I walk in overflow, not lack, and I will see His provision manifest in my life."
        case .anxiety:
            return "I declare that the peace that surpasses all understanding guards my heart and mind. Fear has no place in me. I cast every care on the Lord and I trust that He holds every detail of my life."
        case .marriage:
            return "I declare that my marriage is covered by the blood of Jesus. What God has joined, no force can break. Love, patience, and covenant define this relationship and we grow stronger every day."
        case .parenting:
            return "I declare that my children are taught by the Lord and great is their peace. Every child in my home is covered, called, and walking in their God-given destiny. I am the parent God chose for them."
        case .destiny:
            return "I declare that I will walk fully in the purpose God wrote for me before the foundation of the world. Every gift is awakened. Every assignment is clear. I will not leave this earth without fulfilling my calling."
        case .identity:
            return "I declare that I know who I am. I am chosen, loved, and called. My identity is not in what I have done or what others say — it is rooted in who God says I am, and that does not change."
        case .rest:
            return "I declare that God's perfect peace rules my mind today and every day. I am not moved by what I see. I am anchored in the truth of His Word and I rest in the finished work of Jesus."
        case .joy:
            return "I declare that the joy of the Lord is my strength. No season, no loss, no circumstance can steal what God has placed inside me. I choose joy and it grows stronger in me every single day."
        case .favor:
            return "I declare that God's favor surrounds me like a shield. Doors open for me that no man can shut. I am seen, promoted, and positioned by the Lord in every room I walk into."
        case .grace:
            return "I declare that I am free from condemnation. My past does not define me — the blood of Jesus does. I walk in grace today and every day, fully forgiven and fully restored."
        case .godsprotection:
            return "I declare that I and everyone I love are covered by the protection of God Almighty. No weapon formed against us shall prosper. Angels surround us and the Lord fights every battle."
        case .addiction:
            return "I declare that I am free. The chains are broken and I walk in the liberty that Christ purchased for me. I am not defined by what once held me — I am defined by who holds me now."
        case .confidence:
            return "I declare that I step boldly into every room, every conversation, every calling. God did not give me a spirit of timidity. I am equipped, anointed, and more than capable of what God has placed before me."
        case .fear:
            return "I declare that fear has no authority over my life. God has given me power, love, and a sound mind. I will not shrink back. I will not be moved. I advance in faith, not fear."
        case .wisdom:
            return "I declare that God's wisdom lives in me. I make decisions with clarity and confidence. Every door I walk through, the Spirit of wisdom leads the way and I will not be confused."
        case .love:
            return "I declare that I am fully loved by God — not based on my performance but based on His nature. His love is unconditional, unending, and unchanging. I receive that love today and it flows through me to others."
        default:
            return "I declare that God who started this work in me will bring it to completion. What He promised, He will perform. I will not stop believing. My breakthrough is on its way."
        }
    }
}
