//
//  ScribeApp.swift
//  Scribe
//
//  Created by Ruben Reut on 14/04/2025.
//

import SwiftUI
import SwiftData

@main
struct ScribeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: ScribeNote.self)
    }
}

