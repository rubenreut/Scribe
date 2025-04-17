import Foundation

/// Application-wide constants
enum Constants {
    /// Time constants
    enum Time {
        /// Autosave delay in milliseconds
        static let autosaveDelay: UInt64 = 500
    }
    
    /// API Constants
    enum API {
        /// OpenAI API endpoint for chat completions
        static let openAIBaseURL = "https://api.openai.com/v1/chat/completions"
        /// Keychain identifier for storing the API key
        static let keychainAPIKeyIdentifier = "ScribeAIServiceAPIKey"
    }
    
    /// Application identifiers
    enum App {
        /// App bundle identifier used for logging subsystem
        static let bundleID = "com.rubenreut.Scribe"
    }
}

/// App notification names with proper type safety
enum AppNotification: String {
    /// Notification posted when a new note should be created
    case createNewNote = "CreateNewNote"
    
    /// The corresponding Notification.Name
    var name: Notification.Name {
        return Notification.Name(self.rawValue)
    }
}

/// Extension on Notification.Name for backward compatibility
extension Notification.Name {
    static let syncStatusDidChange = Notification.Name("com.rubenreut.Scribe.syncStatusDidChange")
    
    // Migrate other notification names here
    static let createNewNote = AppNotification.createNewNote.name
}