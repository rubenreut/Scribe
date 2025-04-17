import SwiftUI
import SwiftData
import OSLog
import UIKit

/// View for editing a single note
struct NoteEditorView: View {
    @Binding var note: ScribeNote?
    let viewModel: NoteViewModel
    private let logger = Logger(subsystem: "com.rubenreut.Scribe", category: "NoteEditorView")
    
    @Environment(\.undoManager) private var undoManager
    
    var body: some View {
        Group {
            if let note = note {
                VStack(spacing: 0) {
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
                    
                    TextEditor(text: Binding(
                        get: { 
                            // Get plain text from the attributed string
                            return viewModel.attributedContent(for: note).string
                        },
                        set: { newValue in
                            // Create a simple attributed string from plain text
                            let attributedString = NSAttributedString(string: newValue)
                            viewModel.updateNoteContent(note, newContent: attributedString)
                        }
                    ))
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                    .padding()
                    .accessibilityIdentifier("note-content-field")
                    
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
                    
                    ToolbarItemGroup(placement: .primaryAction) {
                        if let undoManager = undoManager {
                            Button {
                                undoManager.undo()
                            } label: {
                                Label("Undo", systemImage: "arrow.uturn.backward")
                            }
                            .disabled(!undoManager.canUndo)
                            
                            Button {
                                undoManager.redo()
                            } label: {
                                Label("Redo", systemImage: "arrow.uturn.forward")
                            }
                            .disabled(!undoManager.canRedo)
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    label: {
                        Label("No Note Selected", systemImage: "square.and.pencil")
                    },
                    description: {
                        Text("Select a note from the list or create a new one.")
                    }
                )
            }
        }
        .task(id: note?.persistentModelID) {
            // No need to log routine view appearance
        }
    }
    
    // Using View extension for keyboard dismissal
}

#Preview {
    PreviewContainer { container in
        let modelContext = container.mainContext
        let viewModel = NoteViewModel(modelContext: modelContext)
        
        // Create sample note with attributed string
        let sampleNote = PreviewHelpers.createSampleNote(
            title: "Sample Note",
            content: "This is sample content",
            in: modelContext
        )
        
        return NoteEditorView(note: .constant(sampleNote), viewModel: viewModel)
    }
}
