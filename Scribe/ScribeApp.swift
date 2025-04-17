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
import CloudKit

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
            // Set up the schema and configuration for CloudKit
            let schema = Schema([ScribeNote.self, ScribeFolder.self])
            let configuration = ModelConfiguration(
                schema: schema,
                url: URL(filePath: NSPersistentContainer.defaultDirectoryURL().path(percentEncoded: false))
                    .appending(path: "Scribe.store"),
                cloudKitContainerIdentifier: "iCloud.com.rubenreut.Scribe"
            )
            
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

