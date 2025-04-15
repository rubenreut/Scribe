import Foundation
import SwiftData
import SwiftUI
import OSLog

/// ViewModel for handling note operations
@Observable @MainActor class NoteViewModel {
    let logger = Logger(subsystem: "com.rubenreut.Scribe", category: "NoteViewModel")
    let modelContext: ModelContext
    private var saveTask: Task<Void, Never>? = nil
    
    var selectedNote: ScribeNote?
    var searchText: String = ""
    var notes: [ScribeNote] = []
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refreshNotes()
    }
    
    /// Creates a new note and selects it
    func createNewNote() {
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
        
        modelContext.insert(newNote)
        selectedNote = newNote
        
        // Refresh notes to ensure the new note appears in the list
        refreshNotes()
        
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save new note: \(error.localizedDescription)")
        }
        
        // Note created successfully
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
            // Register necessary classes for secure coding
            NSKeyedUnarchiver.setClass(NSTextAttachment.self, forClassName: "NSTextAttachment")
            NSKeyedUnarchiver.setClass(UIImage.self, forClassName: "UIImage")
            
            let content = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(note.content) as? NSAttributedString
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
                selectedNote = nil
            }
        }
        
        // Save changes after deletion
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save after deletion: \(error.localizedDescription)")
        }
        
        // Refresh notes to update the UI
        refreshNotes()
        
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
