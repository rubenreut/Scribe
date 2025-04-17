import SwiftUI
import SwiftData
import OSLog
import Foundation
import CloudKit

/// Main application entry point
@main
struct ScribeApp: App {
    private let logger = Logger(subsystem: Constants.App.bundleID, category: "Application")
    
    init() {
        configureLogger()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // No need to log every view appearance
        }
        .modelContainer(createModelContainer())
        .commands {
            // Add app-specific commands
            CommandGroup(after: .newItem) {
                Button("New Note") {
                    NotificationCenter.default.post(name: AppNotification.createNewNote.name, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
    
    /// Configures application-wide logging
    private func configureLogger() {
        #if DEBUG
        // More verbose in debug builds
        // Debug logging enabled
        #endif
    }
    
    /// Creates and configures the SwiftData model container with iCloud sync
    private func createModelContainer() -> ModelContainer {
        do {
            // Set up the schema and configuration for CloudKit
            let schema = Schema([ScribeNote.self, ScribeFolder.self])
            guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw AppError.dataError(description: "Could not access Application Support directory")
            }
            let storeURL = baseURL.appending(path: "Scribe.store")
                
            // Use only the supported parameters for ModelConfiguration
            let configuration = ModelConfiguration(
                "Scribe", // Configuration name as first parameter
                schema: schema,
                url: storeURL,
                allowsSave: true
            )
            
            // Configure CloudKit in entitlements instead
            
            // Create the container with the configuration
            let container = try ModelContainer(for: schema, configurations: [configuration])
            logger.info("Successfully created model container with iCloud sync")
            return container
        } catch {
            logger.critical("Failed to create model container: \(error.localizedDescription)")
            fatalError("Unable to create model container: \(error.localizedDescription)")
        }
    }
}

