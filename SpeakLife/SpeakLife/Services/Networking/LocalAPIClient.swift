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

final class LocalAPIClient: APIService {
    
    @AppStorage("declarationCountFile") var declarationCountFile = 0
    @AppStorage("declarationCountBE") var declarationCountBE = 0
    @AppStorage("firstInstallDate") var firstInstallDate: Date?
    @AppStorage("lastRemoteFetchDate") var lastRemoteFetchDate: Date?
    
    @AppStorage("remoteVersion") var remoteVersion = 0
    @AppStorage("localVersion") var localVersion = 0
    @AppStorage("audioLocalVersion") var audioLocalVersion = 0
    
    func declarations(completion: @escaping([Declaration], APIError?, Bool) -> Void) {
        if firstInstallDate == nil {
            firstInstallDate = Date()
        }
        self.loadFromBackEnd() { [weak self] declarations, error, needsSync in
            var favorites: [Declaration] = []
            var myOwn: [Declaration] = []
            
            self?.loadFromDisk() { declarations, error in
                favorites = declarations.filter { $0.isFavorite == true }
                myOwn = declarations.filter {
                    $0.category == .myOwn
                }
            }
            
            
            var updatedDeclarations: [Declaration] = declarations
            
            for fav in favorites  {
                updatedDeclarations.removeAll { $0.id == fav.id }
            }
            updatedDeclarations.append(contentsOf: favorites)
            updatedDeclarations.append(contentsOf: myOwn)
           // self?.declarationCountFile = updatedDeclarations.count
            completion(updatedDeclarations,  nil, needsSync)
            return
            
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
            print("failed to load audio RWRW")
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
            guard
                let url = Bundle.main.url(forResource: "declarationsv7", withExtension: "json") else {
                print("cant find file rwrw")
                return
            }
                guard let data = try? Data(contentsOf: url) else {
                    print("cant make data rwrw")
                completion(nil)
                return
            }
            completion(data)
        }
    }
    
    private func loadFromBackEnd(completion: @escaping([Declaration], APIError?, Bool) -> Void) {
        let now = Date()
        let twentyFourHoursAgo = now.addingTimeInterval(-86400)

        let shouldFetchFromRemote: Bool

        if localVersion < remoteVersion {
            if let lastFetchDate = lastRemoteFetchDate {
                shouldFetchFromRemote = lastFetchDate <= twentyFourHoursAgo
            } else {
                shouldFetchFromRemote = true // no fetch has happened yet
            }
        } else {
            shouldFetchFromRemote = false
        }

        if shouldFetchFromRemote {
            print("Fetching from remote...")
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

    private func fallbackToLocal(completion: @escaping ([Declaration], APIError?, Bool) -> Void) {
        fetchDeclarationData(tryLocal: true) { [weak self] data in
            if let data = data {
                let declarations = self?.decodeDeclarationsSafely(from: data)
                if let declarations = declarations, !declarations.isEmpty {
                    completion(declarations, nil, false)
                } else {
                    print("Failed to decode any declarations from local data")
                    completion([], APIError.failedDecode, false)
                }
            } else {
                completion([], APIError.failedDecode, false)
            }
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
            print("Standard decoding failed, attempting partial decoding: \(error)")
            
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
                        print("Failed to decode declaration at index \(index) with category '\(category)': \(error)")
                    }
                }
                
                print("Successfully decoded \(successfulDeclarations.count) declarations, failed \(failedCount)")
                
                // Return unique declarations
                let uniqueDeclarations = Set(successfulDeclarations)
                return Array(uniqueDeclarations)
                
            } catch {
                print("Partial decoding also failed: \(error)")
                return nil
            }
        }
    }
//    func downloadUpdates(completion: @escaping((Bool, Error?) -> Void))  {
//        let storage = Storage.storage()
//        let jsonRef = storage.reference(withPath: "updates.json")
//
//        // Download the file into memory with a maximum allowed size of 1MB (1 * 1024 * 1024 bytes)
//        jsonRef.getData(maxSize: 1 * 1024 * 1024) { [weak self] data, error in
//            if let error = error {
//                completion(false, error)
//                print("Error downloading JSON file: \(error)")
//            } else if let jsonData = data {
//                guard let self = self else { completion(false, nil)
//                    return
//                }
//                let version = try? JSONDecoder().decode(Updates.self, from: jsonData)
//                self.remoteVersion = version?.currentDeclarationVersion ?? 0
//                completion(self.remoteVersion > self.localVersion, nil)
//                print("JSON download successful, data length: \(jsonData.count)")
//            }
//        }
//    }
    func audio(version: Int, completion: @escaping(WelcomeAudio?, [AudioDeclaration]?) -> Void) {
        print(version, "rwrw")
        if audioLocalVersion < version {
            downloadAudioDeclarations() { data, error in
                if let _ = error {
                    completion(nil, speaklifeFiles)
                }
                if let data = data {
                    do {
                        let welcome = try JSONDecoder().decode(WelcomeAudio.self, from: data)
                        let audios = Array(welcome.audios)
                        self.audioLocalVersion = version
                        self.save(audioDeclarations: audios) { success in
                        }
                        completion(welcome, nil)
                        return
                    } catch {
                        print(error, error.localizedDescription, "RWRW")
                        completion(nil, speaklifeFiles)
                    }
                }
            }
        } else {
            loadAudioFromDisk { audios, error in
                if let error = error {
                    completion(nil, speaklifeFiles)
                }
                    
                    if !audios.isEmpty {
                        print("this got hit RWRW")
                        completion(nil, audios)
                    }
                }
        }
    }
    
    func downloadDeclarations(completion: @escaping((Data?, Error?) -> Void))  {
        let storage = Storage.storage()
        let jsonRef = storage.reference(withPath: "declarationsv7.json")

        // Download the file into memory with a maximum allowed size of 2MB (4 * 1024 * 1024 bytes)
        jsonRef.getData(maxSize: 4 * 1024 * 1024) { data, error in
            if let error = error {
                completion(nil, error)
                print("Error downloading JSON file: \(error)")
            } else if let jsonData = data {
                //self?.storeFetchDate()
                completion(jsonData, nil)
                print("JSON download successful, data length: \(jsonData.count) decl rwrw")
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
                print("JSON download successful, data length: \(jsonData.count) audio rwrw")
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
