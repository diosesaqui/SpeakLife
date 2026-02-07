//
//  APIClient.swift
//  Dios Es Aqui
//
//  Created by Riccardo Washington on 1/1/22.
//

import Foundation
import Combine
import SwiftUI
import FirebaseStorage
import FirebaseRemoteConfigInternal

final class LocalAPIClient: APIService {
    // Singleton instance to prevent duplicate fetches
    static let shared = LocalAPIClient()
    
    // Static cache and loading state shared across all instances
    private static var cachedDeclarations: [Declaration]?
    private static var isLoadingDeclarations = false
    private static var pendingDeclarationCallbacks: [([Declaration], APIError?, Bool) -> Void] = []
    private static let loadingQueue = DispatchQueue(label: "com.speaklife.declarations.loading")
    
    @AppStorage("declarationsFileName") private var declarationsFileName = "declarationsv7.json"
    @AppStorage("declarationCountFile") var declarationCountFile = 0
    @AppStorage("declarationCountBE") var declarationCountBE = 0
    @AppStorage("firstInstallDate") var firstInstallDate: Date?
    @AppStorage("lastRemoteFetchDate") var lastRemoteFetchDate: Date?
    
    @AppStorage("remoteVersion") var remoteVersion = 0
    @AppStorage("localVersion") var localVersion = 0
    @AppStorage("audioLocalVersion") var audioLocalVersion = 0
    
    private var remoteConfig = RemoteConfig.remoteConfig()
    
    // Public init allowed but uses static cache
    init() {
    }
    
    func declarations(completion: @escaping([Declaration], APIError?, Bool) -> Void) {
        if firstInstallDate == nil {
            firstInstallDate = Date()
        }
        
        // Update declarations file name from remote config if available
        updateDeclarationsFileName()
        
        var shouldLoad = false
        
        LocalAPIClient.loadingQueue.sync {
            // Check if we have cached declarations
            if let cached = LocalAPIClient.cachedDeclarations {
                completion(cached, nil, false)
                return
            }
            
            // Check if already loading
            if LocalAPIClient.isLoadingDeclarations {
                LocalAPIClient.pendingDeclarationCallbacks.append(completion)
                return
            }
            
            // We're the first - set flag and prepare to load
            LocalAPIClient.isLoadingDeclarations = true
            LocalAPIClient.pendingDeclarationCallbacks.append(completion)
            shouldLoad = true
        }
        
        // Only load if we're the first request
        guard shouldLoad else { return }
        
        
        self.loadFromBackEnd() { declarations, error, needsSync in
            LocalAPIClient.loadingQueue.sync {
                // Cache the declarations
                LocalAPIClient.cachedDeclarations = declarations
                
                // Call all pending callbacks
                let callbacks = LocalAPIClient.pendingDeclarationCallbacks
                LocalAPIClient.pendingDeclarationCallbacks = []
                LocalAPIClient.isLoadingDeclarations = false
                
                
                for callback in callbacks {
                    callback(declarations, nil, needsSync)
                }
            }
        }
    }
    
    private func loadFromDisk(completion: @escaping([Declaration], APIError?) -> Void) {
        let documentDirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentDirURL.appendingPathComponent("declarations").appendingPathExtension("txt")
        
        
        guard let data = try? Data(contentsOf: fileURL),
              let declarations = try? JSONDecoder().decode([Declaration].self, from: data) else {
            completion([], APIError.failedRequest)
            return
        }
        declarationCountFile = declarations.count
        completion(declarations, nil)
        return
    }
    
    private func loadFile(file: String, completion: @escaping([Declaration], APIError?) -> Void) {
        let documentDirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentDirURL.appendingPathComponent(file).appendingPathExtension("txt")
        
        
        guard let data = try? Data(contentsOf: fileURL),
              let declarations = try? JSONDecoder().decode([Declaration].self, from: data) else {
            completion([], APIError.failedRequest)
            return
        }
        declarationCountFile = declarations.count
        completion(declarations, nil)
        return
    }
    
    private func loadAudioFromDisk(completion: @escaping([AudioDeclaration], APIError?) -> Void) {
        let documentDirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentDirURL.appendingPathComponent("audioDeclarations").appendingPathExtension("txt")
        
        guard let data = try? Data(contentsOf: fileURL),
              let declarations = try? JSONDecoder().decode([AudioDeclaration].self, from: data) else {
            print("Failed to load audio")
            completion([], APIError.failedRequest)
            return
        }
        completion(declarations, nil)
        return
    }
    
    func save(declarations: [Declaration], completion: @escaping(Bool) -> Void) {
        
        guard
            let DocumentDirURL = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true),
            let data = try? JSONEncoder().encode(declarations)
        else {
            completion(false)
           return
        }
        
        do  {
            let fileURL = DocumentDirURL.appendingPathComponent("declarations").appendingPathExtension("txt")
            try data.write(to: fileURL, options: .atomic)
            completion(true)
            return
        } catch {
            print(error)
            completion(false)
            return
        }
    }
    
    func save(audioDeclarations: [AudioDeclaration], completion: @escaping(Bool) -> Void) {
        
        guard
            let DocumentDirURL = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true),
            let data = try? JSONEncoder().encode(audioDeclarations)
        else {
            completion(false)
            return
        }
        
        do  {
            let fileURL = DocumentDirURL.appendingPathComponent("audioDeclarations").appendingPathExtension("txt")
            try data.write(to: fileURL, options: .atomic)
            completion(true)
            return
        } catch {
            print(error)
            completion(false)
            return
        }
    }
    
    func storeFetchDate() {
        let currentDate = Date()
        UserDefaults.standard.set(currentDate, forKey: "lastFetchDate")
    }
    
    func hasBeenThirtyDaysSinceLastFetch() -> Bool {
        // Retrieve the last fetch date; if none exists, assume the fetch is needed.
        guard let lastFetchDate = UserDefaults.standard.object(forKey: "lastFetchDate") as? Date else {
            return true
        }

        // Compute the date 30 days ago from today.
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!

        // Return true if the last fetch was on or before 30 days ago.
        return lastFetchDate <= thirtyDaysAgo && (firstInstallDate ?? Date()) >= thirtyDaysAgo
    }
    
    
    private func fetchDeclarationData(tryLocal: Bool, completion: @escaping(Data?) -> Void?) {
        
        //TODO: fix remote download
        if !tryLocal {
            downloadDeclarations { data, error in
                completion(data)
            }
        } else {
            // Use lazy loading to prevent memory crashes
            LazyJSONLoader.shared.loadDeclarations(fileName: declarationsFileName) { declarations in
                do {
                    let data = try JSONEncoder().encode(declarations)
                    completion(data)
                } catch {
                    print("❌ Failed to encode declarations: \(error)")
                    completion(nil)
                }
            }
        }
    }
    
    private func loadFromBackEnd(completion: @escaping([Declaration], APIError?, Bool) -> Void) {
        let now = Date()
        let twentyFourHoursAgo = now.addingTimeInterval(-86400)

        let shouldFetchFromRemote: Bool
        
        // Check if this is a fresh install
        let isFreshInstall = lastRemoteFetchDate == nil && firstInstallDate != nil
        

        if isFreshInstall {
            // Always fetch remote on fresh install
            shouldFetchFromRemote = true
        } else if localVersion < remoteVersion {
            if let lastFetchDate = lastRemoteFetchDate {
                shouldFetchFromRemote = lastFetchDate <= twentyFourHoursAgo
            } else {
                shouldFetchFromRemote = true // no fetch has happened yet
            }
        } else {
            shouldFetchFromRemote = false
        }

        if shouldFetchFromRemote {
            fetchDeclarationData(tryLocal: false) { [weak self] data in
                self?.lastRemoteFetchDate = Date()
                if let data = data {
                    let declarations = self?.decodeDeclarationsSafely(from: data)
                    if let declarations = declarations, !declarations.isEmpty {
                        self?.localVersion = self?.remoteVersion ?? 2
                        completion(declarations, nil, true)
                    } else {
                        self?.fallbackToLocal(completion: completion)
                    }
                } else {
                    self?.fallbackToLocal(completion: completion)
                }
            }
        } else {
            fallbackToLocal(completion: completion)
        }
    }
    

    
    private func fallbackToLocal(completion: @escaping([Declaration], APIError?, Bool) -> Void) {
        // Use lazy loading for fallback to prevent memory crashes
        LazyJSONLoader.shared.loadDeclarations(fileName: declarationsFileName) { declarations in
            // Apply same memory limits as remote loading
            let maxDeclarations = 5000
            let limitedDeclarations = declarations.count > maxDeclarations ? 
                Array(declarations.prefix(maxDeclarations)) : declarations
                
            if !limitedDeclarations.isEmpty {
                completion(limitedDeclarations, nil, false)
            } else {
                completion([], APIError.failedDecode, false)
            }
        }
    }
    
    private func updateDeclarationsFileName() {
        // Fetch the declarations file name from remote config
        let configFileName = remoteConfig["declarationsFileName"].stringValue
        if !configFileName.isEmpty && configFileName != declarationsFileName {
            print("Updating declarations file name from \(declarationsFileName) to \(configFileName)")
            declarationsFileName = configFileName
        }
    }
    
    private func decodeDeclarationsSafely(from data: Data) -> [Declaration]? {
        do {
            // First try to decode the full structure
            let welcome = try JSONDecoder().decode(Welcome.self, from: data)
            let declarations = Set(welcome.declarations)
            return Array(declarations)
        } catch {
            // If that fails, try partial decoding
            
            do {
                // Parse JSON as dictionary to extract individual declarations
                guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let declarationsArray = jsonObject["declarations"] as? [[String: Any]] else {
                    return nil
                }
                
                var successfulDeclarations: [Declaration] = []
                var failedCount = 0
                
                // Try to decode each declaration individually
                for (index, declarationDict) in declarationsArray.enumerated() {
                    do {
                        let declarationData = try JSONSerialization.data(withJSONObject: declarationDict)
                        let declaration = try JSONDecoder().decode(Declaration.self, from: declarationData)
                        successfulDeclarations.append(declaration)
                    } catch {
                        failedCount += 1
                        // Log which declaration failed and why
                        let category = declarationDict["category"] as? String ?? "unknown"
                    }
                }
                
                
                // Return unique declarations
                let uniqueDeclarations = Set(successfulDeclarations)
                return Array(uniqueDeclarations)
                
            } catch {
                return nil
            }
        }
    }
    
    func audio(version: Int, completion: @escaping(WelcomeAudio?, [AudioDeclaration]?) -> Void) {
        
        // Check if fresh install or need update  
        let shouldFetchRemote = audioLocalVersion < version || audioLocalVersion == 0
        
        if shouldFetchRemote {
            downloadAudioDeclarations() { [weak self] data, error in
                if let error = error {
                    // Fall back to local audioDevotionals.json file
                    self?.loadLocalAudioDevotionals { localAudios in
                        if !localAudios.isEmpty {
                            completion(nil, localAudios)
                        } else {
                            completion(nil, speaklifeFiles)
                        }
                    }
                    return
                }
                
                if let data = data {
                    do {
                        let welcome = try JSONDecoder().decode(WelcomeAudio.self, from: data)
                        let audios = Array(welcome.audios)
                        
                        self?.audioLocalVersion = version
                        self?.save(audioDeclarations: audios) { success in
                        }
                        completion(welcome, nil)
                        return
                    } catch {
                        completion(nil, speaklifeFiles)
                    }
                } else {
                    completion(nil, speaklifeFiles)
                }
            }
        } else {
            loadAudioFromDisk { audios, error in
                if let error = error {
                    completion(nil, speaklifeFiles)
                    return
                }
                    
                if !audios.isEmpty {
                    completion(nil, audios)
                } else {
                    completion(nil, speaklifeFiles)
                }
            }
        }
    }
    
    // Load audio from local bundle audioDevotionals.json
    private func loadLocalAudioDevotionals(completion: @escaping([AudioDeclaration]) -> Void) {
        
        guard let url = Bundle.main.url(forResource: "audioDevotionals", withExtension: "json") else {
            completion([])
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            
            let welcome = try JSONDecoder().decode(WelcomeAudio.self, from: data)
            let audios = Array(welcome.audios)
            
            // Save to disk for next time
            self.save(audioDeclarations: audios) { success in
            }
            
            completion(audios)
        } catch {
            completion([])
        }
    }
    
    func downloadDeclarations(completion: @escaping((Data?, Error?) -> Void))  {
        let storage = Storage.storage()
        let jsonRef = storage.reference(withPath: declarationsFileName)

        // Download the file into memory with a maximum allowed size of 2MB (4 * 1024 * 1024 bytes)
        jsonRef.getData(maxSize: 4 * 1024 * 1024) { data, error in
            if let error = error {
                completion(nil, error)
                print("Error downloading JSON file: \(error)")
            } else if let jsonData = data {
                //self?.storeFetchDate()
                completion(jsonData, nil)
            }
        }
    }
    
    func downloadAudioDeclarations(completion: @escaping((Data?, Error?) -> Void))  {
        let storage = Storage.storage()
        let jsonRef = storage.reference(withPath: "audioDevotionals.json")

        // Download the file into memory with a maximum allowed size of 1MB (2 * 1024 * 1024 bytes)
        jsonRef.getData(maxSize: 2 * 1024 * 1024) { data, error in
            if let error = error {
                completion(nil, error)
                print("Error downloading JSON file: \(error)")
            } else if let jsonData = data {
                //self?.storeFetchDate()
                completion(jsonData, nil)
            }
        }
    }
    
    // MARK: - Notifications
    
    func declarationCategories(completion: @escaping(Set<DeclarationCategory>, APIError?) -> Void) {
        loadSelectedCategoriesFromDisk { categories, error in
            if let error = error {
                completion([], error)
                return
            }
            
            completion(categories, nil)
            return
        }
    }
    
    func save(selectedCategories: Set<DeclarationCategory>, completion: @escaping(Bool) -> Void) {
        guard
            let DocumentDirURL = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true),
            let data = try? JSONEncoder().encode(selectedCategories)
        else {
            completion(false)
            return
        }
        
        do  {
            let fileURL = DocumentDirURL.appendingPathComponent("notificationcategories").appendingPathExtension("txt")
            try data.write(to: fileURL, options: .atomic)
            completion(true)
            return
        } catch {
            print(error)
            completion(false)
            return
        }
    }
    
    private func loadSelectedCategoriesFromDisk(completion: @escaping(Set<DeclarationCategory>, APIError?) -> Void) {
        let documentDirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentDirURL.appendingPathComponent("notificationcategories").appendingPathExtension("txt")
        
        
        guard let data = try? Data(contentsOf: fileURL),
              let declarationsCategories = try? JSONDecoder().decode(Set<DeclarationCategory>.self, from: data) else {
            completion([], APIError.failedRequest)
            return
        }
        completion(declarationsCategories, nil)
        return
    }
}
