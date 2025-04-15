import Foundation
import SwiftData
import SwiftUI

/// Represents a note in the Scribe application
@Model
final class ScribeNote {
    var title: String
    var content: Data
    var createdAt: Date
    var lastModified: Date
    
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