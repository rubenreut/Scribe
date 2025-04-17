import Foundation
import OSLog
import SwiftData
import CloudKit

/// Enumeration of iCloud sync states for UI display
enum SyncStatus: Equatable {
    case upToDate
    case syncing
    case error(String)
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.upToDate, .upToDate):
            return true
        case (.syncing, .syncing):
            return true
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

/// Manager for handling iCloud synchronization
@MainActor class SyncManager {
    let logger = Logger(subsystem: Constants.App.bundleID, category: "SyncManager")
    private let modelContext: ModelContext
    private var cloudSubscription: Task<Void, Never>? = nil
    
    var syncStatus: SyncStatus = .upToDate
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        setupCloudKitSubscription()
    }
    
    deinit {
        // Cancel any pending tasks
        cloudSubscription?.cancel()
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
    }
    
    /// Sets up subscription to CloudKit notifications to monitor sync status
    private func setupCloudKitSubscription() {
        // Cancel any existing subscription
        cloudSubscription?.cancel()
        
        // Start a new background task to monitor CloudKit notifications
        cloudSubscription = Task { 
            // Subscribe to various CloudKit notification types
            let center = NotificationCenter.default
            
            // Add observers for CloudKit account status
            center.addObserver(
                forName: NSNotification.Name.CKAccountChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleCloudKitAccountChange()
            }
            
            // Set up periodic refresh to ensure sync
            await periodicCloudSyncCheck()
        }
    }
    
    /// Periodically checks and refreshes data to ensure sync
    private func periodicCloudSyncCheck() async {
        while !Task.isCancelled {
            do {
                // Check iCloud status every 30 seconds
                try await Task.sleep(for: .seconds(30))
                
                // Skip if already syncing
                if case .syncing = syncStatus { continue }
                
                // Check account status
                await handleCloudKitAccountChangeAsync()
                
                // Sync complete notification - can be used by view models
                NotificationCenter.default.post(name: Notification.Name.syncStatusDidChange, object: self.syncStatus)
            } catch {
                // Task cancelled or other error
                break
            }
        }
    }
    
    /// Handles changes to the CloudKit account
    private func handleCloudKitAccountChange() {
        // Check iCloud account status
        CKContainer.default().accountStatus { [weak self] status, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                switch status {
                case .available:
                    self.logger.info("iCloud account is available")
                    self.syncStatus = .upToDate
                    
                case .restricted:
                    self.logger.warning("iCloud account is restricted")
                    self.syncStatus = .error("iCloud access is restricted")
                    
                case .noAccount:
                    self.logger.warning("No iCloud account is signed in")
                    self.syncStatus = .error("No iCloud account is available")
                    
                case .couldNotDetermine:
                    if let error = error {
                        self.logger.error("Could not determine iCloud account status: \(error.localizedDescription)")
                        self.syncStatus = .error("Could not connect to iCloud")
                    }
                    
                @unknown default:
                    self.logger.warning("Unknown iCloud account status")
                    self.syncStatus = .error("Unknown iCloud status")
                }
                
                // Notify about status change
                NotificationCenter.default.post(name: Notification.Name.syncStatusDidChange, object: self.syncStatus)
            }
        }
    }
    
    /// Async version of handleCloudKitAccountChange that can be awaited
    private func handleCloudKitAccountChangeAsync() async {
        return await withCheckedContinuation { continuation in
            CKContainer.default().accountStatus { [weak self] status, error in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                Task { @MainActor in
                    switch status {
                    case .available:
                        self.logger.info("iCloud account is available")
                        self.syncStatus = .upToDate
                        
                    case .restricted:
                        self.logger.warning("iCloud account is restricted")
                        self.syncStatus = .error("iCloud access is restricted")
                        
                    case .noAccount:
                        self.logger.warning("No iCloud account is signed in")
                        self.syncStatus = .error("No iCloud account is available")
                        
                    case .couldNotDetermine:
                        if let error = error {
                            self.logger.error("Could not determine iCloud account status: \(error.localizedDescription)")
                            self.syncStatus = .error("Could not connect to iCloud")
                        }
                        
                    @unknown default:
                        self.logger.warning("Unknown iCloud account status")
                        self.syncStatus = .error("Unknown iCloud status")
                    }
                    
                    // Notify about status change
                    NotificationCenter.default.post(name: Notification.Name.syncStatusDidChange, object: self.syncStatus)
                    
                    continuation.resume()
                }
            }
        }
    }
}

// Removed duplicate declaration - see Constants.swift for notification names
