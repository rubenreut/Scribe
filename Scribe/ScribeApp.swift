//
//  ScribeApp.swift
//  Scribe
//
//  Created by Ruben Reut on 14/04/2025.
//

import SwiftUI
import SwiftData
import OSLog
import Foundation

/// Main application entry point
@main
struct ScribeApp: App {
    private let logger = Logger(subsystem: "com.rubenreut.Scribe", category: "Application")
    
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
                    NotificationCenter.default.post(name: Constants.NotificationNames.createNewNote, object: nil)
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
        let schema = Schema([ScribeNote.self, ScribeFolder.self])
        
        // Configure for iCloud sync
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.rubenreut.Scribe")
        )
        
        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            logger.info("Successfully created model container with iCloud sync")
            return container
        } catch {
            logger.error("Failed to create model container with iCloud sync: \(error.localizedDescription)")
            
            // Fallback to local-only storage
            logger.warning("Falling back to local-only storage")
            do {
                let localConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return try ModelContainer(for: schema, configurations: [localConfiguration])
            } catch {
                logger.critical("Failed to create local model container: \(error.localizedDescription)")
                fatalError("Unable to create any model container")
            }
        }
    }
}

