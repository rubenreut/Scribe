import Foundation
import SwiftData
import SwiftUI

@Model
final class ScribeNote {
    var title: String
    var content: String
    var createdAt: Date
    var lastModified: Date
    
    init(title: String = "New Note", content: String = "", createdAt: Date = Date(), lastModified: Date = Date()) {
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.lastModified = lastModified
    }
}