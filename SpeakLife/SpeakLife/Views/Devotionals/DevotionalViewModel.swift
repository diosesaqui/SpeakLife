//
//  DevotionalViewModel.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 5/10/23.
//

import SwiftUI

final class DevotionalViewModel: ObservableObject, Sendable {
    
    @AppStorage("devotionalDictionary") var devotionalDictionaryData = Data()
    
    @Published var devotionalText = ""
    @Published var devotionalDate = ""
    @Published var devotionalBooks = ""
    @Published var title = ""
    @Published var hasError = false
    var devotionalId: String {
        // Generate consistent ID based on date for tracking
        return "devotional_\(devotionalDate.replacingOccurrences(of: " ", with: "_"))"
    }
    let errorString = "Upgrade to the latest version for Today's Devotional."
    private let freeCount = 1
    @Published var lastFetchDate: String = ""
    
    var devotionals: [Devotional] = []
    
    @Published var devotionValue = 0
    
    var devotional: Devotional? {
        didSet {
            updateViewModel()
        }
    }
    
    var devotionalDictionary: [DateComponents: Bool] {
        get {
            let decoder = JSONDecoder()
            if let decoded = try? decoder.decode([DateComponents: Bool].self, from: devotionalDictionaryData) {
                return decoded
            } else {
                return [:]  // Return an empty dictionary as a default value
            }
        }
        
        set  {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
                DispatchQueue.main.async { [weak self] in
                    self?.devotionalDictionaryData = encoded
                }
            }
        }
    }
    
    var devotionalsLeft: Int {
        if !devotionalLimitReached {
            return freeCount - devotionalDictionary.count
        }
        return 0
    }
    
    var devotionalLimitReached: Bool {
        devotionalDictionary.count > 1
    }
    
    private func setDevotionalDictionary(date: Date = Date()) {

        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: date)
        
        // means we added the date user looked at devotional already
        if let _ = devotionalDictionary[components] {
            
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.devotionalDictionary[components] = true
            }
        }
        
    }
    
    private let service: DevotionalService
    
    init(service: DevotionalService = DevotionalServiceClient()) {
        self.service = service
    }
    
    private func updateViewModel() {
        guard let devotional = devotional else { return }
        DispatchQueue.main.async { [ weak self] in
            self?.devotionalText = devotional.devotionalText
            self?.devotionalDate = devotional.date.toSimpleDate()
            self?.devotionalBooks = devotional.books
            self?.title = devotional.title
        }
    }
    
    func fetchDevotional(remoteVersion: Int) async {
        
        if let devotional = await service.fetchTodayDevotional(remoteVersion: remoteVersion).first {
            DispatchQueue.main.async { [weak self] in
                self?.devotional = devotional
            }
            setDevotionalDictionary()
        }
        else {
            DispatchQueue.main.async { [weak self] in
                self?.hasError = true
            }
        }
        return
    }
    
    func fetchDevotionalFor(value: Int) async {
        guard devotionValue > -14 && devotionValue < 1 else {
            return
        }
        if self.devotionals.isEmpty {
            let devotionals = await service.fetchAllDevotionals(needsSync: false)
            self.devotionals = devotionals
        }
            let now = Date()
            let calendar = Calendar.current
        if let searchDate = calendar.date(byAdding: .day, value: value, to: now) {
        
            let searchComponents = calendar.dateComponents([.month, .day], from: searchDate)
        
            let month = searchComponents.month
            let day = searchComponents.day
        
        if let foundDevotional = devotionals.first(where: {
            let devotionalComponents = calendar.dateComponents([.month, .day], from: $0.date)
            let devotionalMonth = devotionalComponents.month
            let devotionalDay = devotionalComponents.day
            return (devotionalMonth, devotionalDay) == (month, day)}) {
            self.devotional = foundDevotional
            setDevotionalDictionary(date: searchDate)
        }
        }
    }
    
    func shouldFetchNewDevotional() -> Bool {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        return today != lastFetchDate
    }
}
