import Foundation
import SwiftData
import SwiftUI
import OSLog

/// ViewModel for handling note operations
@Observable @MainActor class NoteViewModel {
    private let logger = Logger(subsystem: "com.rubenreut.Scribe", category: "NoteViewModel")
    private let modelContext: ModelContext
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
        modelContext.insert(newNote)
        selectedNote = newNote
        
        // Refresh notes to ensure the new note appears in the list
        refreshNotes()
        
        do {
            try modelContext.save()
        } catch {
            logger.error("Failed to save new note: \(error.localizedDescription)")
        }
        
        logger.debug("Created new note")
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
                logger.debug("Successfully saved changes")
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
            note.content = try NSKeyedArchiver.archivedData(withRootObject: newContent, requiringSecureCoding: false)
            note.lastModified = Date()
            saveChanges()
        } catch {
            logger.error("Archiving error: \(error.localizedDescription)")
        }
    }
    
    /// Retrieves the attributed content for a note
    func attributedContent(for note: ScribeNote) -> NSAttributedString {
        guard !note.content.isEmpty,
              let content = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(note.content) as? NSAttributedString else {
            return NSAttributedString(string: "")
        }
        return content
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
        
        logger.debug("Deleted \(indexSet.count) notes")
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