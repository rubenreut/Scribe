//
//  ScribeApp.swift
//  Scribe
//
//  Created by Ruben Reut on 14/04/2025.
//

import SwiftUI

@main
struct ScribeApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
