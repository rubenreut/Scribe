import Foundation
import SwiftData
import SwiftUI

/// AI-related extensions to the NoteViewModel
extension NoteViewModel {
    // MARK: - Folder Management
    
    /// Creates a new folder
    /// - Parameters:
    ///   - name: The name for the new folder
    ///   - icon: The system icon name
    ///   - color: The folder color
    /// - Returns: The newly created folder
    func createFolder(name: String, icon: String = "folder", color: UIColor = .systemBlue) -> ScribeFolder {
        let newFolder = ScribeFolder(name: name, icon: icon, color: color)
        modelContext.insert(newFolder)
        saveChanges()
        refreshFolders()
        return newFolder
    }
    
    /// Assigns a note to a folder
    /// - Parameters:
    ///   - note: The note to assign
    ///   - folder: The destination folder
    func assignNote(_ note: ScribeNote, toFolder folder: ScribeFolder) {
        note.folder = folder
        note.lastModified = Date()
        folder.notes?.append(note)
        saveChanges()
        refreshFolders()
    }
    
    /// Removes a note from its folder
    /// - Parameter note: The note to remove from folder
    func removeNoteFromFolder(_ note: ScribeNote) {
        if let folder = note.folder, let index = folder.notes?.firstIndex(where: { $0 == note }) {
            folder.notes?.remove(at: index)
        }
        note.folder = nil
        note.lastModified = Date()
        saveChanges()
        refreshFolders()
    }
    
    /// Deletes a folder and optionally its notes
    /// - Parameters:
    ///   - folder: The folder to delete
    ///   - deleteNotes: Whether to delete the contained notes as well
    func deleteFolder(_ folder: ScribeFolder, deleteNotes: Bool = false) {
        // Get all notes in the folder
        if let folderNotes = folder.notes {
            // Either delete the notes or just remove them from the folder
            if deleteNotes {
                for note in folderNotes {
                    modelContext.delete(note)
                }
            } else {
                // Just unlink notes from the folder without deleting them
                for note in folderNotes {
                    note.folder = nil
                    note.lastModified = Date()
                }
            }
        }
        
        // Delete the folder itself
        modelContext.delete(folder)
        saveChanges()
        
        // Refresh notes list
        refreshNotes()
        refreshFolders()
        
        logger.info("Deleted folder: \(folder.name) (with notes: \(deleteNotes))")
    }
    
    /// Gets all notes that belong to a specific folder
    /// - Parameter folder: The folder to get notes for
    /// - Returns: Array of notes in the folder
    func notesInFolder(_ folder: ScribeFolder) -> [ScribeNote] {
        return notes.filter { $0.folder == folder }
    }
    
    // MARK: - AI Organization
    
    /// Organizes notes without folders using AI
    func organizeNotesWithAI() async -> (Bool, String?) {
        // Get API key from secure storage
        guard let apiKey = KeychainHelper.getAPIKey(), !apiKey.isEmpty else {
            logger.error("No API key found for AI organization")
            return (false, "Please set your API key in Settings")
        }
        
        // Get notes without folders
        let notesToOrganize = notes.filter { $0.folder == nil }
        guard !notesToOrganize.isEmpty else {
            logger.info("No notes to organize")
            return (false, "No unorganized notes found")
        }
        
        do {
            logger.info("Organizing \(notesToOrganize.count) notes with AI...")
            let aiService = AIService(apiKey: apiKey)
            
            // Attempt the API call
            let organizations = try await aiService.organizeNotes(notesToOrganize, existingFolders: folders)
            logger.info("Received organization suggestions: \(organizations.count)")
            
            // Validate we got results
            guard !organizations.isEmpty else {
                return (false, "AI didn't suggest any organization")
            }
            
            // Apply the organizations
            for organization in organizations {
                logger.debug("Organizing note: '\(organization.note.title)' → '\(organization.folderName)'")
                if organization.isNewFolder {
                    // Create new folder
                    let newFolder = ScribeFolder(name: organization.folderName)
                    modelContext.insert(newFolder)
                    organization.note.folder = newFolder
                    logger.debug("Created new folder: \(organization.folderName)")
                } else if let existingFolder = folders.first(where: { $0.name == organization.folderName }) {
                    // Use existing folder
                    organization.note.folder = existingFolder
                    logger.debug("Used existing folder: \(organization.folderName)")
                }
                organization.note.lastModified = Date()
            }
            
            // Save changes
            logger.debug("Saving changes to model context...")
            try modelContext.save()
            
            // Refresh notes and folders
            logger.debug("Refreshing notes and folders...")
            refreshNotes()
            refreshFolders()
            return (true, nil)
        } catch {
            let errorMessage = "AI organization failed: \(error.localizedDescription)"
            logger.error("\(errorMessage)")
            return (false, errorMessage)
        }
    }
    
    // MARK: - AI Formatting
    
    /// Formats the content of a note using AI
    /// - Parameter note: The note to format
    /// - Returns: Tuple with success flag and optional error message
    func formatNoteWithAI(_ note: ScribeNote) async -> (Bool, String?) {
        // Get API key from secure storage
        guard let apiKey = KeychainHelper.getAPIKey(), !apiKey.isEmpty else {
            logger.error("No API key found for AI formatting")
            return (false, "Please set your API key in Settings")
        }
        
        // Get current note content
        let currentContent = attributedContent(for: note).string
        guard !currentContent.isEmpty else {
            logger.error("Note content is empty, cannot format")
            return (false, "Note content is empty")
        }
        
        do {
            logger.info("Formatting note with AI: \(note.title)")
            let aiService = AIService(apiKey: apiKey)
            let formattedContent = try await aiService.formatNoteContent(currentContent)
            logger.info("Received formatting instructions: \(formattedContent.instructions.count)")
            
            // Verify we got formatting instructions
            guard !formattedContent.instructions.isEmpty else {
                return (false, "AI didn't return any formatting")
            }
            
            // Apply the formatting
            logger.debug("Applying formatting to note...")
            let formattedAttributedText = applyFormatting(formattedContent)
            updateNoteContent(note, newContent: formattedAttributedText)
            return (true, nil)
        } catch {
            let errorMessage = "AI formatting failed: \(error.localizedDescription)"
            logger.error("\(errorMessage)")
            return (false, errorMessage)
        }
    }
    
    /// Applies formatting instructions to create a formatted NSAttributedString
    /// - Parameter formattedContent: The formatting instructions
    /// - Returns: The formatted attributed string
    private func applyFormatting(_ formattedContent: FormattedContent) -> NSAttributedString {
        // Create a new attributed string with formatting
        let mutableAttrText = NSMutableAttributedString()
        
        for instruction in formattedContent.instructions {
            switch instruction {
            case .heading(let text, let level):
                // Add heading with appropriate size and weight
                let fontSize: CGFloat = level == 1 ? 24 : (level == 2 ? 20 : 18)
                let font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.label
                ]
                let headingAttr = NSAttributedString(string: text + "\n", attributes: attrs)
                mutableAttrText.append(headingAttr)
                
            case .paragraph(let text):
                // Add paragraph with body font
                let bodyFont = UIFont.preferredFont(forTextStyle: .body)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: bodyFont,
                    .foregroundColor: UIColor.label
                ]
                let paragraphAttr = NSAttributedString(string: text + "\n\n", attributes: attrs)
                mutableAttrText.append(paragraphAttr)
                
            case .bulletList(let items):
                // Add bullet list
                let bodyFont = UIFont.preferredFont(forTextStyle: .body)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.headIndent = 15
                paragraphStyle.firstLineHeadIndent = 0
                paragraphStyle.paragraphSpacing = 4
                
                for item in items {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: bodyFont,
                        .foregroundColor: UIColor.label,
                        .paragraphStyle: paragraphStyle
                    ]
                    let bulletItem = "• " + item + "\n"
                    let bulletAttr = NSAttributedString(string: bulletItem, attributes: attrs)
                    mutableAttrText.append(bulletAttr)
                }
                mutableAttrText.append(NSAttributedString(string: "\n"))
            }
        }
        
        return mutableAttrText
    }
}