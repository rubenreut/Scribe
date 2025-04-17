import Foundation
import SwiftData
import SwiftUI
import UIKit
import CloudKit

/// Represents a folder for organizing notes
@Model(cloudSync: true)
final class ScribeFolder {
    var name: String = "Untitled Folder"
    var icon: String = "folder"
    var colorData: Data = {
        return (try? NSKeyedArchiver.archivedData(withRootObject: UIColor.systemBlue, requiringSecureCoding: true)) ?? Data()
    }()
    var createdAt: Date = Date()
    
    @Relationship var notes: [ScribeNote]?
    
    init(name: String, icon: String = "folder", color: UIColor = .systemBlue, createdAt: Date = Date()) {
        self.name = name
        self.icon = icon
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true) {
            self.colorData = data
        }
        self.createdAt = createdAt
        self.notes = []
    }
    
    var color: UIColor {
        get {
            (try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: colorData)) ?? .systemBlue
        }
    }
}

/// Represents a note in the Scribe application
@Model(cloudSync: true)
final class ScribeNote {
    var title: String = "New Note"
    var content: Data = Data()
    var createdAt: Date = Date()
    var lastModified: Date = Date()
    
    // Relationship to parent folder (optional)
    var folder: ScribeFolder?
    
    /// Creates a new note with optional parameters
    /// - Parameters:
    ///   - title: The title of the note
    ///   - content: The content as binary data (for attributed string)
    ///   - createdAt: The creation date (defaults to now)
    ///   - lastModified: The last modification date (defaults to now)
    init(title: String = "New Note", content: Data = Data(), createdAt: Date = Date(), lastModified: Date = Date()) {
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}

extension ScribeNote: Equatable {
    static func == (lhs: ScribeNote, rhs: ScribeNote) -> Bool {
        lhs.persistentModelID == rhs.persistentModelID
    }
}