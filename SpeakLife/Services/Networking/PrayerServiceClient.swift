//
//  PrayerServiceClient.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 4/11/23.
//

import Foundation

protocol PrayerService {
    func fetchPrayers() async -> [Prayer]
}

final class PrayerServiceClient: PrayerService {
    
    func fetchPrayers() async -> [Prayer] {
        
        guard
            let url = Bundle.main.url(forResource: "prayers", withExtension: "json"),
            let data = try? Data(contentsOf: url) else {
            return []
        }
        
        do {
            let welcome = try JSONDecoder().decode(WelcomePrayers.self, from: data)
            return welcome.prayers
        } catch {
            print(error)
           return []
        }
    }
}
