import Foundation
import SwiftData
@testable import Scribe

/// Provides test helpers for creating test environments
struct TestHelpers {
    /// Creates an in-memory test container and viewmodel with optional sample data
    /// - Parameter withSampleData: Whether to add sample data to the container
    /// - Returns: A tuple containing the container and viewmodel
    @MainActor
    static func createTestEnvironment(withSampleData: Bool = false) throws -> (container: ModelContainer, viewModel: NoteViewModel) {
        let container = try ModelContainer(
            for: ScribeNote.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        
        let viewModel = NoteViewModel(modelContext: container.mainContext)
        
        if withSampleData {
            let note1 = ScribeNote(title: "Shopping", content: "Buy milk")
            let note2 = ScribeNote(title: "Work", content: "Finish project")
            let note3 = ScribeNote(title: "Ideas", content: "New app concept")
            
            container.mainContext.insert(note1)
            container.mainContext.insert(note2)
            container.mainContext.insert(note3)
            
            viewModel.refreshNotes()
        }
        
        return (container, viewModel)
    }
}