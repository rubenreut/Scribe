import Foundation
import SwiftData
import SwiftUI
import UIKit

/// Represents a folder for organizing notes
@Model
final class ScribeFolder {
    var name: String
    var icon: String
    var colorData: Data
    var createdAt: Date
    
    @Relationship var notes: [ScribeNote]?
    
    init(name: String, icon: String = "folder", color: UIColor = .systemBlue, createdAt: Date = Date()) {
        self.name = name
        self.icon = icon
        self.colorData = try! NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: true)
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
@Model
final class ScribeNote {
    var title: String
    var content: Data
    var createdAt: Date
    var lastModified: Date
    
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