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
        do {
            // Create a container with cloud sync - pass models as separate arguments, not as an array
            let container = try ModelContainer(for: ScribeNote.self, ScribeFolder.self)
            logger.info("Successfully created model container with iCloud sync")
            return container
        } catch {
            logger.critical("Failed to create model container: \(error.localizedDescription)")
            fatalError("Unable to create model container: \(error.localizedDescription)")
        }
    }
}

