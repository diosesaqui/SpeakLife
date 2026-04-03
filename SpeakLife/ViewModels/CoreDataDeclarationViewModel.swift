//
//  CoreDataDeclarationViewModel.swift
//  SpeakLife
//
//  ViewModel using Core Data repositories for Create Your Own entries
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class CoreDataDeclarationViewModel: ObservableObject {
    
    @Published var journalEntries: [JournalEntry] = []
    @Published var affirmationEntries: [AffirmationEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let journalRepository: any JournalRepositoryProtocol
    private let affirmationRepository: any AffirmationRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(journalRepository: any JournalRepositoryProtocol = JournalRepository(),
         affirmationRepository: any AffirmationRepositoryProtocol = AffirmationRepository()) {
        self.journalRepository = journalRepository
        self.affirmationRepository = affirmationRepository
        
        setupObservers()
        loadEntries()
    }
    
    // MARK: - Setup
    private func setupObservers() {
        journalRepository.observeAll()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.journalEntries = entries
            }
            .store(in: &cancellables)
        
        affirmationRepository.observeAll()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.affirmationEntries = entries
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Loading
    private func loadEntries() {
        Task {
            isLoading = true
            errorMessage = nil
            
            do {
                let journals = try await journalRepository.fetch(predicate: nil)
                let affirmations = try await affirmationRepository.fetch(predicate: nil)
                
                await MainActor.run {
                    self.journalEntries = journals
                    self.affirmationEntries = affirmations
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - Journal Operations
    func createJournalEntry(text: String, category: String = "myOwn") {
        Task {
            do {
                let context = PersistenceController.shared.container.viewContext
                let entry = JournalEntry(context: context)
                entry.text = text
                entry.category = category
                entry.isFavorite = false
                
                try await journalRepository.create(entry)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func updateJournalEntry(_ entry: JournalEntry, text: String) {
        Task {
            do {
                entry.text = text
                try await journalRepository.update(entry)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func deleteJournalEntry(_ entry: JournalEntry) {
        Task {
            do {
                try await journalRepository.delete(entry)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func toggleJournalFavorite(_ entry: JournalEntry) {
        Task {
            do {
                try await journalRepository.toggleFavorite(entry)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Affirmation Operations
    func createAffirmationEntry(text: String, category: String = "myOwn") {
        Task {
            do {
                let context = PersistenceController.shared.container.viewContext
                let entry = AffirmationEntry(context: context)
                entry.text = text
                entry.category = category
                entry.isFavorite = false
                
                try await affirmationRepository.create(entry)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func updateAffirmationEntry(_ entry: AffirmationEntry, text: String) {
        Task {
            do {
                entry.text = text
                try await affirmationRepository.update(entry)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func deleteAffirmationEntry(_ entry: AffirmationEntry) {
        Task {
            do {
                try await affirmationRepository.delete(entry)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func toggleAffirmationFavorite(_ entry: AffirmationEntry) {
        Task {
            do {
                try await affirmationRepository.toggleFavorite(entry)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // MARK: - Search
    func searchJournalEntries(text: String) async -> [JournalEntry] {
        do {
            return try await journalRepository.search(text: text)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return []
        }
    }
    
    func searchAffirmationEntries(text: String) async -> [AffirmationEntry] {
        do {
            return try await affirmationRepository.search(text: text)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return []
        }
    }
    
    // MARK: - Favorites
    func getFavoriteJournalEntries() async -> [JournalEntry] {
        do {
            return try await journalRepository.fetchFavorites()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return []
        }
    }
    
    func getFavoriteAffirmationEntries() async -> [AffirmationEntry] {
        do {
            return try await affirmationRepository.fetchFavorites()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            return []
        }
    }
    
    // MARK: - Convenience Methods
    func getEntriesForContentType(_ contentType: ContentType) -> [Any] {
        switch contentType {
        case .journal:
            return journalEntries
        case .affirmation:
            return affirmationEntries
        }
    }
    
    func createEntry(text: String, contentType: ContentType) {
        switch contentType {
        case .journal:
            createJournalEntry(text: text)
        case .affirmation:
            createAffirmationEntry(text: text)
        }
    }
    
    func deleteEntry(_ entry: Any) {
        if let journalEntry = entry as? JournalEntry {
            deleteJournalEntry(journalEntry)
        } else if let affirmationEntry = entry as? AffirmationEntry {
            deleteAffirmationEntry(affirmationEntry)
        }
    }
    
    func updateEntry(_ entry: Any, text: String) {
        if let journalEntry = entry as? JournalEntry {
            updateJournalEntry(journalEntry, text: text)
        } else if let affirmationEntry = entry as? AffirmationEntry {
            updateAffirmationEntry(affirmationEntry, text: text)
        }
    }
}