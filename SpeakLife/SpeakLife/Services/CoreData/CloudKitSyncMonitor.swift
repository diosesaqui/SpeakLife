//
//  CloudKitSyncMonitor.swift
//  SpeakLife
//
//  CloudKit Sync Status Monitor for UI indicators
//

import Foundation
import CoreData
import CloudKit
import Combine

enum CloudKitSyncStatus {
    case unknown
    case syncing
    case synced
    case error(String)
    case accountUnavailable
    case importing // New state for initial import
}

final class CloudKitSyncMonitor: ObservableObject {
    
    @Published var syncStatus: CloudKitSyncStatus = .unknown
    @Published var lastSyncDate: Date?
    @Published var isExporting: Bool = false
    @Published var isImporting: Bool = false
    
    private let container: NSPersistentCloudKitContainer
    private var cancellables = Set<AnyCancellable>()
    
    init(container: NSPersistentCloudKitContainer = PersistenceController.shared.container) {
        self.container = container
        setupMonitoring()
        checkInitialStatus()
    }
    
    private func setupMonitoring() {
        // Monitor CloudKit events
        NotificationCenter.default.publisher(for: NSNotification.Name("NSPersistentCloudKitContainerEventChangedNotification"))
            .compactMap { $0.userInfo?["event"] as? NSPersistentCloudKitContainer.Event }
            .sink { [weak self] event in
                self?.handleCloudKitEvent(event)
            }
            .store(in: &cancellables)
        
        // Monitor remote changes
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .sink { [weak self] _ in
                print("RWRW: Remote change detected - updating sync status")
                self?.updateSyncStatus()
            }
            .store(in: &cancellables)
        
        // Monitor import started
        NotificationCenter.default.publisher(for: NSNotification.Name("CloudKitImportStarted"))
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.syncStatus = .importing
                }
            }
            .store(in: &cancellables)
        
        // Monitor import completed
        NotificationCenter.default.publisher(for: NSNotification.Name("CloudKitImportCompleted"))
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.syncStatus = .synced
                    self?.lastSyncDate = Date()
                }
            }
            .store(in: &cancellables)
        
        // Monitor import failed
        NotificationCenter.default.publisher(for: NSNotification.Name("CloudKitImportFailed"))
            .sink { [weak self] notification in
                DispatchQueue.main.async {
                    let reason = notification.userInfo?["reason"] as? String ?? "Unknown error"
                    self?.syncStatus = .error(reason)
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkInitialStatus() {
        let cloudKitContainer = CKContainer(identifier: "iCloud.com.franchiz.speaklife")
        
        cloudKitContainer.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("RWRW: Sync Monitor - Account status error: \(error.localizedDescription)")
                    self?.syncStatus = .error(error.localizedDescription)
                } else {
                    switch status {
                    case .available:
                        print("RWRW: Sync Monitor - CloudKit account available")
                        self?.syncStatus = .synced
                    case .noAccount:
                        print("RWRW: Sync Monitor - No iCloud account")
                        self?.syncStatus = .accountUnavailable
                    case .restricted, .couldNotDetermine, .temporarilyUnavailable:
                        print("RWRW: Sync Monitor - CloudKit unavailable: \(status)")
                        self?.syncStatus = .accountUnavailable
                    @unknown default:
                        self?.syncStatus = .unknown
                    }
                }
            }
        }
    }
    
    private func handleCloudKitEvent(_ event: NSPersistentCloudKitContainer.Event) {
        DispatchQueue.main.async { [weak self] in
            print("RWRW: Sync Monitor - CloudKit event: \(event.type)")
            
            switch event.type {
            case .setup:
                if event.endDate == nil {
                    self?.syncStatus = .syncing
                } else if event.error != nil {
                    self?.syncStatus = .error(event.error?.localizedDescription ?? "Setup failed")
                } else {
                    self?.syncStatus = .synced
                }
                
            case .import:
                self?.isImporting = event.endDate == nil
                if event.endDate == nil {
                    self?.syncStatus = .syncing
                } else if event.error != nil {
                    self?.syncStatus = .error(event.error?.localizedDescription ?? "Import failed")
                } else {
                    self?.syncStatus = .synced
                    self?.lastSyncDate = event.endDate
                    print("RWRW: Sync Monitor - Import completed successfully")
                }
                
            case .export:
                self?.isExporting = event.endDate == nil
                if event.endDate == nil {
                    self?.syncStatus = .syncing
                } else if event.error != nil {
                    self?.syncStatus = .error(event.error?.localizedDescription ?? "Export failed")
                } else {
                    self?.syncStatus = .synced
                    self?.lastSyncDate = event.endDate
                    print("RWRW: Sync Monitor - Export completed successfully")
                }
                
            @unknown default:
                break
            }
        }
    }
    
    private func updateSyncStatus() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // If we're not actively syncing, mark as synced
            if !self.isImporting && !self.isExporting {
                switch self.syncStatus {
                case .syncing:
                    self.syncStatus = .synced
                    self.lastSyncDate = Date()
                default:
                    break
                }
            }
        }
    }
    
    // MARK: - Public Methods
    func requestSync() {
        DispatchQueue.main.async { [weak self] in
            print("RWRW: Sync Monitor - Manual sync requested")
            self?.syncStatus = .syncing
        }
        
        // Use the optimized sync request
        PersistenceController.shared.requestImmediateSync()
    }
    
    var statusDescription: String {
        switch syncStatus {
        case .unknown:
            return "Checking sync status..."
        case .syncing:
            return "Syncing with iCloud..."
        case .synced:
            if let lastSync = lastSyncDate {
                return "Synced \(timeAgoString(from: lastSync))"
            }
            return "Synced with iCloud"
        case .error(let message):
            return "Sync error: \(message)"
        case .accountUnavailable:
            return "iCloud unavailable"
        case .importing:
            return "Importing your data..."
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}