import SwiftUI
import UIKit
import SwiftData
import OSLog

/// View for editing a note with rich text formatting capabilities
struct RichTextNoteEditorView: View {
    @Binding var selectedNote: ScribeNote? // Renamed from 'note' to 'selectedNote'
    let viewModel: NoteViewModel
    @State private var attributedText = NSAttributedString(string: "")
    @ObservedObject private var textViewHolder = RichTextViewHolder.shared
    @StateObject private var formattingState = FormattingState()
    @State private var showImagePicker = false
    
    // Add id to force view refreshes when selected note changes
    private var noteId: String {
        selectedNote?.persistentModelID.storeIdentifier ?? "no-note"
    }


    
    private let logger = Logger(subsystem: "com.rubenreut.Scribe", category: "RichTextNoteEditorView")
    
    var body: some View {
        Group {
            if let note = selectedNote {
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
                    }, formattingState: formattingState)
                    .padding(.horizontal, 8)
                    
                    // Formatting toolbar
                    RichTextToolbar(attributedText: $attributedText, textView: textViewHolder.textView, formattingState: formattingState)
                    
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
                    
                    // Add image insertion button to main toolbar
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { showImagePicker = true }) {
                            Image(systemName: "photo")
                                .foregroundColor(.accentColor)
                        }
                        .accessibilityLabel("Insert Image")
                    }
                }
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker { selectedImage in
                        if let coordinator = textViewHolder.textView?.delegate as? RichTextEditor.Coordinator {
                            coordinator.insertImage(selectedImage)
                        }
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
                            // Save selection position if any
                            let selectedRange = tv.selectedRange
                            
                            // Update the text content
                            tv.attributedText = attributedText
                            
                            // Restore selection if possible
                            if selectedRange.location <= attributedText.length {
                                tv.selectedRange = selectedRange
                            }
                            
                            // Trigger formatting state update
                            if attributedText.length > 0 {
                                let position = min(max(0, selectedRange.location), attributedText.length - 1)
                                let attributes = tv.textStorage.attributes(at: position, effectiveRange: nil)
                                
                                // Update formatting state
                                if let font = attributes[.font] as? UIFont {
                                    formattingState.isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                                    formattingState.isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
                                }
                                
                                formattingState.isUnderlined = attributes[.underlineStyle] != nil
                                
                                if let color = attributes[.foregroundColor] as? UIColor {
                                    formattingState.textColor = Color(color)
                                }
                            }
                        }
                    }
                }
                .onChange(of: selectedNote) { _, _ in
                    // Reset formatting state when switching notes
                    formattingState.isBold = false
                    formattingState.isItalic = false
                    formattingState.isUnderlined = false
                    formattingState.textColor = .primary
                    
                    // When selectedNote changes, update content if not nil
                    if let note = selectedNote {
                        attributedText = viewModel.attributedContent(for: note)
                    } else {
                        attributedText = NSAttributedString(string: "")
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
        
        return RichTextNoteEditorView(selectedNote: .constant(sampleNote), viewModel: viewModel)
            .modelContainer(container)
    }
    
    return createPreview()
}
