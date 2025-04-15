import SwiftUI
import UIKit
import SwiftData
import OSLog

/// View for editing a note with rich text formatting capabilities
struct RichTextNoteEditorView: View {
    @Binding var note: ScribeNote?
    let viewModel: NoteViewModel
    @State private var attributedText = NSAttributedString(string: "")
    @ObservedObject private var textViewHolder = RichTextViewHolder.shared
    
    // Add id to force view refreshes when selected note changes
    private var noteId: String {
        note?.persistentModelID.storeIdentifier ?? "no-note"
    }


    
    private let logger = Logger(subsystem: "com.rubenreut.Scribe", category: "RichTextNoteEditorView")
    
    var body: some View {
        Group {
            if let note = note {
                VStack(spacing: 0) {
                    // Title field
                    TextField("Title", text: Binding(
                        get: { note.title },
                        set: { newValue in
                            viewModel.updateNoteTitle(note, newTitle: newValue)
                        }
                    ))
                    .font(.largeTitle)
                    .padding([.horizontal, .top])
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("note-title-field")
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Rich text editor
                    RichTextEditor(attributedText: $attributedText, onTextChange: { newText in
                        // Update the note's content directly with NSAttributedString
                        viewModel.updateNoteContent(note, newContent: newText)
                    })
                    .padding(.horizontal, 8)
                    
                    // Formatting toolbar
                    RichTextToolbar(attributedText: $attributedText, textView: textViewHolder.textView)
                    
                    // Last edited timestamp
                    HStack {
                        Spacer()
                        Text("Last edited: \(note.lastModified, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .accessibilityLabel("Last edited \(note.lastModified.formatted())")
                    }
                    .padding(.bottom, 4)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        
                        Button("Done") {
                            hideKeyboard()
                        }
                        .accessibilityIdentifier("keyboard-done-button")
                    }
                }
                // Use id to force full view rebuild when note changes
                .id(noteId)
                .onAppear {
                    // Load the attributed string directly from the note
                    attributedText = viewModel.attributedContent(for: note)
                    
                    // Ensure textView updates properly with correct styling
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let tv = textViewHolder.textView {
                            tv.attributedText = attributedText
                        }
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("No Note Selected", systemImage: "square.and.pencil")
                } description: {
                    Text("Select a note from the list or create a new one.")
                }
            }
        }
    }
    
    // Using View extension for keyboard dismissal
}

// Observable class to hold the text view reference
class RichTextViewHolder: ObservableObject {
    static let shared = RichTextViewHolder()
    @Published var textView: UITextView?
    
    private init() {}
}

#Preview {
    @MainActor func createPreview() -> some View {
        let container = try! ModelContainer(for: ScribeNote.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let modelContext = container.mainContext
        let viewModel = NoteViewModel(modelContext: modelContext)
        
        // Create an attributed string
        let attributedString = NSAttributedString(string: "This is sample content")
        
        // Create sample note with archived attributed string
        let sampleNote = ScribeNote(title: "Rich Text Sample")
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: attributedString, requiringSecureCoding: true) {
            sampleNote.content = data
        }
        modelContext.insert(sampleNote)
        
        return RichTextNoteEditorView(note: .constant(sampleNote), viewModel: viewModel)
            .modelContainer(container)
    }
    
    return createPreview()
}
