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
    let title: String//DeclarationCategory
    let items: [Prayer]
    var isExpanded: Bool = false
}

final class PrayerViewModel: ObservableObject {
    
    @Published var sectionData: [SectionData] = []
    
    @Published var hasError = false
    
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
    
    func fetchPrayers() async {
        guard prayers.isEmpty else { return }
       // let prayers = await service.fetchPrayers()
       // self.prayers = prayers
    }
    
    private func buildSectionData()  {
//        guard !prayers.isEmpty else {
//            DispatchQueue.main.async { [weak self] in
//                self?.hasError = true
//            }
//            return
//        }
    
//        for category in DeclarationCategory.allCases {
//            let prayers = prayers.filter { $0.category == category }
//            DispatchQueue.main.async { [weak self] in
//                if !prayers.isEmpty {
//                    self?.sectionData.append(SectionData(title: category.categoryTitle, items: prayers))
//                }
//            }
//        }
        DispatchQueue.main.async { [weak self] in
            self?.sectionData.insert(SectionData(title: "God's Protection", items: [Prayer(prayerText: psalm91NLT, category: .godsprotection, isPremium: false)]), at: 0)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.sectionData.insert(SectionData(title: "Salvation Prayer", items: [Prayer(prayerText: salvationPrayer, category: .godsprotection, isPremium: false)]), at: 0)
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
