import Foundation

/// Application-wide constants
enum Constants {
    /// Notification names used throughout the app
    enum NotificationNames {
        /// Notification posted when a new note should be created
        static let createNewNote = Notification.Name("CreateNewNote")
    }
    
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
}