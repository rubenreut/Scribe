import Foundation
import SwiftData
import SwiftUI
import OSLog
import CloudKit

/// Enumeration of iCloud sync states for UI display
enum SyncStatus {
    case upToDate
    case syncing
    case error(String)
}

/// ViewModel for handling note operations
@Observable @MainActor class NoteViewModel {
    let logger = Logger(subsystem: "com.rubenreut.Scribe", category: "NoteViewModel")
    let modelContext: ModelContext
    private var saveTask: Task<Void, Never>? = nil
    private var cloudSubscription: Task<Void, Never>? = nil
    
    var selectedNote: ScribeNote?
    var searchText: String = ""
    var notes: [ScribeNote] = []
    var folders: [ScribeFolder] = []
    var syncStatus: SyncStatus = .upToDate
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refreshNotes()
        refreshFolders()
        setupCloudKitSubscription()
    }
    
    deinit {
        Task { @MainActor in
            // Cancel any pending tasks
            saveTask?.cancel()
            cloudSubscription?.cancel()
            
            // Remove notification observers
            NotificationCenter.default.removeObserver(self)
        }
    }
    
    /// Creates a new note and selects it
    func createNewNote() {
        // Create the note first
        let newNote = ScribeNote()
        
        // Add an empty attributed string with default body styling
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: bodyFont,
            .foregroundColor: UIColor.label
        ]
        let emptyText = NSAttributedString(string: "", attributes: defaultAttributes)
        
        // Save the default styling
        do {
            newNote.content = try NSKeyedArchiver.archivedData(withRootObject: emptyText, requiringSecureCoding: true)
        } catch {
            logger.error("Failed to initialize note with default styling: \(error.localizedDescription)")
        }
        
        // Insert into context and save immediately
        modelContext.insert(newNote)
        
        do {
            // Save BEFORE refreshing notes or setting selected note
            try modelContext.save()
            
            // Now set as selected note
            selectedNote = newNote
            
            // Refresh notes last, after save is complete
            refreshNotes()
        } catch {
            logger.error("Failed to save new note: \(error.localizedDescription)")
        }
    }
    /// Saves any pending changes to the notes
    func saveChanges() {
        // Cancel any existing save task
        saveTask?.cancel()
        
        // Create a new task with a brief delay to batch rapid changes
        saveTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(Constants.Time.autosaveDelay))
                guard !Task.isCancelled else { return }
                
                try modelContext.save()
                // Changes saved successfully
            } catch {
                logger.error("Failed to save note: \(error.localizedDescription)")
            }
        }
    }
    
    /// Updates a note's title and marks it as modified
    func updateNoteTitle(_ note: ScribeNote, newTitle: String) {
        note.title = newTitle
        note.lastModified = Date()
        saveChanges()
    }
    
    /// Updates a note's content with NSAttributedString and marks it as modified
    func updateNoteContent(_ note: ScribeNote, newContent: NSAttributedString) {
        do {
            // Ensure secure coding for images in NSTextAttachments
            NSAttributedString.registerAttributedStringCoder(for: newContent)
            note.content = try NSKeyedArchiver.archivedData(withRootObject: newContent, requiringSecureCoding: true)
            note.lastModified = Date()
            saveChanges()
        } catch {
            logger.error("Archiving error: \(error.localizedDescription)")
        }
    }
    
    /// Retrieves the attributed content for a note
    func attributedContent(for note: ScribeNote) -> NSAttributedString {
        guard !note.content.isEmpty else {
            return NSAttributedString(string: "")
        }
        
        do {
            // Create a dedicated unarchiver instance for this operation
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: note.content)
            unarchiver.setClass(NSTextAttachment.self, forClassName: "NSTextAttachment")
            unarchiver.setClass(UIImage.self, forClassName: "UIImage")
            
            // Use the dedicated unarchiver instance
            let content = unarchiver.decodeObject(of: NSAttributedString.self, forKey: NSKeyedArchiveRootObjectKey)
            return content ?? NSAttributedString(string: "")
        } catch {
            logger.error("Unarchiving error: \(error.localizedDescription)")
            return NSAttributedString(string: "")
        }
    }
    
    /// Deletes the specified notes
    func deleteNotes(at indexSet: IndexSet) {
        for index in indexSet {
            let noteToDelete = notes[index]
            modelContext.delete(noteToDelete)
            
            // If the deleted note was selected, deselect it
            if selectedNote == noteToDelete {
                selectedNote = notes.indices.contains(index - 1) ? notes[index - 1] : nil
            }
        }
        
        // Save changes after deletion
        do {
            try modelContext.save()
            refreshNotes() // Refresh notes to update UI
        } catch {
            logger.error("Failed to save after deletion: \(error.localizedDescription)")
        }
        
        
        // Notes deleted successfully
    }
    
    /// Refreshes the notes array from the model context
    func refreshNotes() {
        do {
            let descriptor = FetchDescriptor<ScribeNote>(sortBy: [SortDescriptor(\.lastModified, order: .reverse)])
            notes = try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch notes: \(error.localizedDescription)")
            notes = []
        }
    }
    
    /// Refreshes the folders array from the model context
    func refreshFolders() {
        do {
            let descriptor = FetchDescriptor<ScribeFolder>(sortBy: [SortDescriptor(\.name)])
            folders = try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch folders: \(error.localizedDescription)")
            folders = []
        }
    }
    
    /// Returns filtered notes based on search text
    var filteredNotes: [ScribeNote] {
        if searchText.isEmpty {
            return notes
        } else {
            return notes.filter { note in
                let content = attributedContent(for: note).string
                return note.title.localizedStandardContains(searchText) ||
                      content.localizedStandardContains(searchText)
            }
        }
    }
    
    // MARK: - iCloud Sync
    
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
                
                // If account is available, refresh data
                if case .upToDate = syncStatus {
                    logger.info("Periodic cloud sync check - refreshing data")
                    refreshNotes()
                    refreshFolders()
                }
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
                    
                    continuation.resume()
                }
            }
        }
    }
}

// Extension to ensure NSAttributedString can be properly archived with attachments
extension NSAttributedString {
    static func registerAttributedStringCoder(for attributedString: NSAttributedString) {
        // Register NSTextAttachment for secure coding
        NSKeyedArchiver.setClassName("NSTextAttachment", for: NSTextAttachment.self)
        NSKeyedUnarchiver.setClass(NSTextAttachment.self, forClassName: "NSTextAttachment")
        
        // Register UIImage for secure coding
        NSKeyedArchiver.setClassName("UIImage", for: UIImage.self)
        NSKeyedUnarchiver.setClass(UIImage.self, forClassName: "UIImage")
    }
}
