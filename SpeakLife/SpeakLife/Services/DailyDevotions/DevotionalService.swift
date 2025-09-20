//
//  DevotionalService.swift
//  SpeakLife
//
//  Created by Riccardo Washington on 5/10/23.
//

import Foundation
import FirebaseStorage
import SwiftUI

protocol DevotionalService {
    func fetchTodayDevotional(remoteVersion: Int) async -> [Devotional]
    func fetchAllDevotionals(needsSync: Bool) async -> [Devotional]
    var devotionals: [Devotional] { get }
}

final class DevotionalServiceClient: DevotionalService {

    // MARK: - Properties
    private(set) var devotionals: [Devotional] = []
    @AppStorage("devotionalRemoteVersion") private var currentVersion = 0

    // MARK: - Public Methods
    func fetchTodayDevotional(remoteVersion: Int) async -> [Devotional] {
        let needsSync = currentVersion < remoteVersion
        if needsSync {
            if let data = await fetchData(needsSync: needsSync) {
                do {
                    let decodedDevotionals = try decodeDevotionals(from: data)
                    self.currentVersion = remoteVersion
                    self.devotionals = decodedDevotionals
                    
                    if needsSync {
                        saveDevotionalsToFile { _ in }
                    }
                    
                    return findTodayDevotional(from: decodedDevotionals)
                } catch {
                    print("Decoding error: \(error)")
                }
            }
        } else {
            do {
                let localDevotionals = try await loadDevotionalsFromFile()
                return findTodayDevotional(from: localDevotionals)
            } catch {
                print("Local load error: \(error)")
            }
        }
        return []
    }

    func fetchAllDevotionals(needsSync: Bool) async -> [Devotional] {
        guard let data = await fetchData(needsSync: needsSync) else { return [] }

        do {
            let decodedDevotionals = try decodeDevotionals(from: data)
            if needsSync {
                saveDevotionalsToFile { _ in }
            }
            return decodedDevotionals
        } catch {
            print("Decoding error: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Private Helpers
    private func fetchData(needsSync: Bool) async -> Data? {
        if needsSync {
            do {
                return try await downloadDevotionals()
            } catch {
                print("Remote fetch failed, falling back to bundle")
            }
        }

        return Bundle.main.url(forResource: "devotionals", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
    }

    private func decodeDevotionals(from data: Data) throws -> [Devotional] {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd-MM"

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(formatter)

        let container = try decoder.decode(WelcomeDevotional.self, from: data)
        return container.devotionals
    }

    private func findTodayDevotional(from devotionals: [Devotional]) -> [Devotional] {
        let today = Calendar.current.dateComponents([.month, .day], from: Date())
        return devotionals.filter {
            let components = Calendar.current.dateComponents([.month, .day], from: $0.date)
            return components.month == today.month && components.day == today.day
        }
    }

    private func saveDevotionalsToFile(completion: @escaping (Bool) -> Void) {
        guard
            let documentDir = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true),
            let data = try? JSONEncoder().encode(devotionals)
        else {
            completion(false)
            return
        }

        do {
            let fileURL = documentDir.appendingPathComponent("remoteDevotionals.json")
            try data.write(to: fileURL, options: .atomic)
            completion(true)
        } catch {
            print("File save error: \(error)")
            completion(false)
        }
    }

    private func loadDevotionalsFromFile() async throws -> [Devotional] {
        return try await withCheckedThrowingContinuation { continuation in
            loadDevotionalsFromFile { result in
                switch result {
                case .success(let devotionals):
                    continuation.resume(returning: devotionals)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func loadDevotionalsFromFile(completion: @escaping (Result<[Devotional], Error>) -> Void) {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("remoteDevotionals.json")

        do {
            let data = try Data(contentsOf: fileURL)
            let devotionals = try JSONDecoder().decode([Devotional].self, from: data)
            completion(.success(devotionals))
        } catch {
            completion(.failure(error))
        }
    }

    private func downloadDevotionals() async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            let storage = Storage.storage()
            let ref = storage.reference(withPath: "devotionals.json")

            ref.getData(maxSize: 1 * 1024 * 1024) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: NSError(domain: "DownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data and no error returned"]))
                }
            }
        }
    }
}
