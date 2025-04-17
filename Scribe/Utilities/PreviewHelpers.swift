import SwiftUI
import SwiftData
import Foundation

/// Helper utilities for SwiftUI previews
enum PreviewHelpers {
    /// Creates a model container for previews with in-memory storage
    /// - Parameters:
    ///   - modelTypes: The models to include in the schema
    ///   - configurationName: Optional name for the configuration
    /// - Returns: A ModelContainer or throws an error
    static func createPreviewContainer(
        _ modelTypes: [any PersistentModel.Type],
        configurationName: String = "PreviewConfig"
    ) throws -> ModelContainer {
        let schema = Schema(modelTypes)
        let config = ModelConfiguration(
            configurationName,
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
    
    /// Creates a sample note with the given title and content
    /// - Parameters:
    ///   - title: The note title
    ///   - content: The note content as plain text
    ///   - context: The ModelContext to insert the note into
    /// - Returns: The created note
    static func createSampleNote(
        title: String = "Sample Note",
        content: String = "This is sample content for the preview",
        in context: ModelContext
    ) -> ScribeNote {
        let note = ScribeNote(title: title)
        
        // Create a basic attributed string
        let sampleText = NSAttributedString(string: content)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: sampleText, requiringSecureCoding: true) {
            note.content = data
        }
        
        context.insert(note)
        return note
    }
    
    /// Creates a sample folder with optional notes inside
    /// - Parameters:
    ///   - name: The folder name
    ///   - noteCount: Number of notes to create in the folder
    ///   - context: The ModelContext to insert into
    /// - Returns: The created folder
    static func createSampleFolder(
        name: String = "Sample Folder",
        noteCount: Int = 2,
        in context: ModelContext
    ) -> ScribeFolder {
        let folder = ScribeFolder(name: name)
        context.insert(folder)
        
        // Create some notes in the folder if requested
        if noteCount > 0 {
            for i in 1...noteCount {
                let note = createSampleNote(
                    title: "Note \(i) in \(name)",
                    content: "Content for note \(i) in folder \(name)",
                    in: context
                )
                note.folder = folder
            }
        }
        
        return folder
    }
    
    /// Creates an attributed string with test content
    /// - Parameter text: The plain text to convert
    /// - Returns: An NSAttributedString with default formatting
    static func createAttributedString(_ text: String) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label
        ]
        return NSAttributedString(string: text, attributes: attributes)
    }
}

/// A wrapper to make preview creation more declarative
struct PreviewContainer<Content: View>: View {
    private let content: (ModelContainer) -> Content
    private let modelTypes: [any PersistentModel.Type]
    @State private var container: ModelContainer?
    @State private var error: Error?
    
    /// Creates a preview with the given model types
    /// - Parameters:
    ///   - modelTypes: The model types to include
    ///   - content: A closure that takes a ModelContainer and returns content
    init(modelTypes: [any PersistentModel.Type], @ViewBuilder content: @escaping (ModelContainer) -> Content) {
        self.modelTypes = modelTypes
        self.content = content
    }
    
    var body: some View {
        Group {
            if let container = container {
                content(container)
                    .modelContainer(container)
            } else if let error = error {
                ContentUnavailableView {
                    Label("Preview Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error.localizedDescription)
                }
            } else {
                ProgressView("Preparing preview...")
            }
        }
        .task {
            if container == nil && error == nil {
                do {
                    let container = try PreviewHelpers.createPreviewContainer(modelTypes)
                    self.container = container
                } catch {
                    self.error = error
                }
            }
        }
    }
}

/// Convenience initializers for preview container
extension PreviewContainer {
    /// Creates a preview with ScribeNote and ScribeFolder models
    init(@ViewBuilder content: @escaping (ModelContainer) -> Content) {
        self.init(modelTypes: [ScribeNote.self, ScribeFolder.self], content: content)
    }
}