//
//  PrayerViewModel.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 4/10/23.
//

import Combine
import SwiftUI


struct SectionData: Identifiable {
    let id = UUID()
    let title: String
    let items: [Prayer]
    var isExpanded: Bool = false
}

final class PrayerViewModel: ObservableObject {
    
    @Published var sectionData: [SectionData] = []
    
    private var prayers: [Prayer] = [] {
        didSet {
            buildSectionData()
        }
    }
    
    private let service: PrayerService
    
    init(service: PrayerService = PrayerServiceClient()) {
        self.service = service
        buildSectionData()
    }
    
    
    private func buildSectionData() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.sectionData = [
                SectionData(title: "Salvation Prayer", items: [Prayer(prayerText: salvationPrayer, category: .godsprotection, isPremium: false)]),
                SectionData(title: "God's Protection", items: [Prayer(prayerText: psalm91NLT, category: .godsprotection, isPremium: false)]),
                SectionData(title: "Healing", items: [Prayer(prayerText: healingPrayer, category: .health, isPremium: false)]),
                SectionData(title: "Comfort", items: [Prayer(prayerText: comfortPrayer, category: .rest, isPremium: false)]),
                SectionData(title: "Strength in Hope", items: [Prayer(prayerText: strengthInHopePrayer, category: .hope, isPremium: false)]),
                SectionData(title: "Peace Over Anxiety", items: [Prayer(prayerText: peaceOverAnxietyPrayer, category: .anxiety, isPremium: false)]),
                SectionData(title: "Overcoming Fear", items: [Prayer(prayerText: overcomingFearPrayer, category: .fear, isPremium: false)]),
                SectionData(title: "God's Faithfulness", items: [Prayer(prayerText: godsFaithfulnessPrayer, category: .gratitude, isPremium: false)]),
                SectionData(title: "Strength in Battle", items: [Prayer(prayerText: strengthInBattlePrayer, category: .warfare, isPremium: false)]),
                SectionData(title: "Wisdom", items: [Prayer(prayerText: wisdomPrayer, category: .wisdom, isPremium: false)]),
                SectionData(title: "God's Help", items: [Prayer(prayerText: godsHelpPrayer, category: .godsprotection, isPremium: false)]),
                SectionData(title: "God Is For Me", items: [Prayer(prayerText: godIsForMePrayer, category: .identity, isPremium: false)])
            ]
        }
    }
}
let salvationPrayer = """

Lord Jesus,

I turn from my sins — past, present, and future.

Come into my heart. Be my Lord and my Savior.

Thank You for dying for me, forgiving me, and welcoming me into Your Kingdom,

where I will live with You forever. Amen!



You are now born again ✝️🎊🥳
"""
let psalm91NLT = """
Psalm 91

 I live under the protection of the Most High, and I find rest in the shadow of the Almighty.
    
    This I declare about you Lord: You alone are my refuge, my place of safety; You are my God, and I trust in You.
    
    You rescue me from every trap and protect me from all deadly diseases.
    
    You cover me with Your feathers and shelter me with your wings, Your faithful promises are my armor and protection.
    
    I am not afraid of the terrors of the night, nor the arrow that flies in the day.
    
    I do not dread the disease that stalks in darkness, nor the sudden death that strikes at noon.
    
    A thousand fall at my side, and ten thousand are dying around me, these evils will not touch me.
    
    I will keep my eyes open, and see how the wicked are punished.
    
    I have made the Lord my refuge; the Most High my shelter.
    
    No evil will conquer me; no plague will come near my home.
    
    For You have ordered Your angels to protect me wherever I go.
    
    They lift me up with their hands, I won’t even hurt my foot on a stone.
    
    I will trample upon lions and cobras; I will crush fierce lions and serpents under my feet!
    
    The Lord will rescue me because I love him. You will protect me because I trust in Your name.
    
    When I call on You, You will answer; You will be with me in trouble. You will rescue and honor me.
    
    You will reward me with a long life and give me your salvation.'

"""
let healingPrayer = """
Isaiah 53:5

He was pierced for my rebellion. He was crushed for my sins.

The punishment that brought me peace fell on Him.

By His wounds I am healed.

I refuse the report of sickness, for my Savior carried it to the cross.

Health belongs to me. Wholeness belongs to me. I am bought, and I am made new.

This body answers to the finished work of Jesus, and the finished work says I am free.
"""
let comfortPrayer = """
Psalm 23

The Lord is my Shepherd. I have everything I need.

He lets me rest in green meadows. He leads me beside peaceful streams.

He renews my strength. He guides me along right paths, and He does it for the honor of His name.

Even when I walk through the darkest valley, I am not afraid, for He is close beside me.

His rod and His staff protect and comfort me.

He prepares a feast for me in the presence of my enemies. He fills my cup until it overflows.

Goodness and unfailing love pursue me all the days of my life.

I will dwell in the house of the Lord forever.
"""
let strengthInHopePrayer = """
Isaiah 40:31

I put my hope in the Lord, and He renews my strength.

I soar on wings like eagles. I run and do not grow weary. I walk and do not faint.

My God never tires. My God never grows weak.

When I am exhausted, He pours fresh power into me.

I rise above every storm because my hope is anchored in Him.

What drains the strong only lifts me higher, for I wait on the Lord.
"""
let peaceOverAnxietyPrayer = """
Philippians 4:6-7

I refuse to be anxious about anything.

In every situation, by prayer and thanksgiving, I bring my requests to God.

I hand Him the worry and I take His peace in its place.

The peace of God, which surpasses all understanding, guards my heart and my mind in Christ Jesus.

This peace is not fragile. It stands watch over me like a soldier at the gate.

My mind is settled. My heart is steady. I rest in Him.
"""
let overcomingFearPrayer = """
Isaiah 41:10

I will not fear, for God is with me.

I will not be discouraged, for He is my God.

He strengthens me. He helps me. He holds me up with His victorious right hand.

Every enemy that rages against me comes to nothing.

I stand firm because the One who upholds me cannot be moved.

Fear has no home in me. The Lord is on my side, and that is enough.
"""
let godsFaithfulnessPrayer = """
Lamentations 3:22-23

The faithful love of the Lord never ends. His mercies never cease.

Great is His faithfulness. His mercies begin fresh each morning.

I wake to a new supply of grace that did not run out in the night.

The Lord is my inheritance, therefore I will hope in Him.

He has never failed me, and He will not start now.

My whole life rests on the One who keeps every promise He has spoken.
"""
let strengthInBattlePrayer = """
Ephesians 6:10-18

I am strong in the Lord and in His mighty power.

I put on the full armor of God so I can stand against every scheme of the enemy.

My fight is not against flesh and blood, but against the powers of darkness, and my God has already won.

The belt of truth is around my waist. The breastplate of righteousness guards my heart.

My feet are ready with the gospel of peace.

I lift the shield of faith and quench every flaming arrow aimed at me.

I wear the helmet of salvation and wield the sword of the Spirit, the Word of God.

I stand my ground, and after the battle I am still standing.
"""
let wisdomPrayer = """
Proverbs 3:5-6

I trust in the Lord with all my heart.

I do not lean on my own understanding.

In all my ways I acknowledge Him, and He makes my paths straight.

When I do not know the next step, He directs it.

His wisdom guides my decisions. His voice corrects my course.

I walk in clarity, not confusion, because the Lord is leading me.
"""
let godsHelpPrayer = """
Psalm 121

I lift my eyes to the hills. Where does my help come from?

My help comes from the Lord, who made heaven and earth.

He will not let my foot slip. The One who watches over me never sleeps.

The Lord watches over me. He is the shade at my right hand.

The sun will not harm me by day, nor the moon by night.

The Lord keeps me from all harm. He watches over my life.

He watches over my coming and going, both now and forever.
"""
let godIsForMePrayer = """
Romans 8:31-39

If God is for me, who can stand against me?

He did not spare His own Son but gave Him up for me. He will freely give me all things.

No charge can stick to me, for God Himself has declared me righteous.

Christ died, was raised, and now stands praying for me.

Nothing can separate me from the love of God.

Not trouble, not hardship, not danger, not death itself.

In all these things I am more than a conqueror through Him who loved me.

I am held by a love that nothing in heaven or earth can break.
"""
