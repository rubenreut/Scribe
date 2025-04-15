import SwiftUI
import UIKit
import SwiftData
import OSLog
import UniformTypeIdentifiers

/// View for editing a note with rich text formatting capabilities
struct RichTextNoteEditorView: View {
    @Binding var selectedNote: ScribeNote?
    let viewModel: NoteViewModel
    @State private var attributedText = NSAttributedString(string: "")
    @ObservedObject private var textViewHolder = RichTextViewHolder.shared
    @StateObject private var formattingState = FormattingState()
    
    // Sheet states for pickers
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var showColorPicker = false
    
    // Add id to force view refreshes when selected note changes
    private var noteId: String {
        selectedNote?.persistentModelID.storeIdentifier ?? "no-note"
    }
    
    private let logger = Logger(subsystem: "com.rubenreut.Scribe", category: "RichTextNoteEditorView")
    
    var body: some View {
        Group {
            if let note = selectedNote {
                VStack(spacing: 0) {
                    // Title field with iOS-style appearance
                    TextField("Title", text: Binding(
                        get: { note.title },
                        set: { newValue in
                            viewModel.updateNoteTitle(note, newTitle: newValue)
                        }
                    ))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding([.horizontal, .top])
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("note-title-field")
                    
                    HStack {
                        Text(note.lastModified, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Rich text editor
                    RichTextEditor(attributedText: $attributedText, onTextChange: { newText in
                        // Update the note's content directly with NSAttributedString
                        viewModel.updateNoteContent(note, newContent: newText)
                    }, formattingState: formattingState)
                    .padding(.horizontal, 4)
                    
                    // Modern iOS-style toolbar
                    HStack(spacing: 16) {
                        Spacer()
                        
                        // Format menu (typography)
                        FormatMenu(formattingState: formattingState) { action in
                            handleFormatAction(action, for: note)
                        }
                        
                        // Attachment menu (files, images)
                        AttachmentMenu(
                            showImagePicker: $showImagePicker,
                            showDocumentPicker: $showDocumentPicker
                        )
                        
                        // Share button
                        Button(action: {
                            // Handle sharing functionality
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(width: 34, height: 34)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(
                        Color(UIColor.secondarySystemBackground)
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: -1)
                    )
                }
                .toolbar {
                    // Keyboard toolbar
                    ToolbarItemGroup(placement: .keyboard) {
                        HStack {
                            // Bold/Italic/Underline quick access in keyboard toolbar
                            Button(action: { handleFormatAction(.bold, for: note) }) {
                                Image(systemName: "bold")
                                    .foregroundColor(formattingState.isBold ? .accentColor : .primary)
                            }
                            
                            Button(action: { handleFormatAction(.italic, for: note) }) {
                                Image(systemName: "italic")
                                    .foregroundColor(formattingState.isItalic ? .accentColor : .primary)
                            }
                            
                            Button(action: { handleFormatAction(.underline, for: note) }) {
                                Image(systemName: "underline")
                                    .foregroundColor(formattingState.isUnderlined ? .accentColor : .primary)
                            }
                            
                            Spacer()
                            
                            Button("Done") {
                                hideKeyboard()
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
                // Handle various sheet presentations
                .sheet(isPresented: $showImagePicker) {
                    ImagePicker { selectedImage in
                        if let coordinator = textViewHolder.textView?.delegate as? RichTextEditor.Coordinator {
                            coordinator.insertImage(selectedImage)
                        }
                    }
                }
                .sheet(isPresented: $showDocumentPicker) {
                    DocumentPicker { fileURL in
                        if let coordinator = textViewHolder.textView?.delegate as? RichTextEditor.Coordinator {
                            coordinator.insertDocumentLink(url: fileURL, filename: fileURL.lastPathComponent)
                        }
                    }
                }
                .sheet(isPresented: $showColorPicker) {
                    VStack {
                        Text("Text Color")
                            .font(.headline)
                            .padding()
                        
                        ColorPicker("Select Color", selection: $formattingState.textColor)
                            .labelsHidden()
                            .padding()
                        
                        Button("Apply") {
                            handleFormatAction(.textColor, for: note)
                            showColorPicker = false
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                    .presentationDetents([.height(200)])
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
    
    /// Handle formatting actions from the format menu
    private func handleFormatAction(_ action: FormatMenu.FormatAction, for note: ScribeNote) {
        // Find toolbar instance
        let toolbar = RichTextToolbar.shared
        
        switch action {
        case .bold:
            // For these direct actions, we can toggle state even if toolbar is missing
            formattingState.isBold.toggle()
            toolbar?.toggleBold()
            
        case .italic:
            formattingState.isItalic.toggle()
            toolbar?.toggleItalic()
            
        case .underline:
            formattingState.isUnderlined.toggle()
            toolbar?.toggleUnderline()
            
        case .heading(let style):
            toolbar?.applyHeading(style)
            
        case .textColor:
            // Show color picker if not already visible
            if !showColorPicker {
                showColorPicker = true
            } else {
                // Apply current color selection
                toolbar?.applyTextColor()
            }
            
        case .bulletList:
            toolbar?.applyBulletPoints()
            
        case .clearFormatting:
            // Reset state for UI consistency
            formattingState.isBold = false
            formattingState.isItalic = false
            formattingState.isUnderlined = false
            formattingState.textColor = .primary
            
            // Clear formatting in the editor
            toolbar?.clearFormatting()
        }
    }
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
