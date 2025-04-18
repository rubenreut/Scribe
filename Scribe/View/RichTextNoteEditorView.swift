import SwiftUI
import UIKit
import SwiftData
import OSLog
import UniformTypeIdentifiers

/// View for editing a note with rich text formatting capabilities
struct RichTextNoteEditorView: View {
    @Binding var selectedNote: ScribeNote?
    let viewModel: NoteViewModel
    @State var attributedText = NSAttributedString(string: "")
    @ObservedObject var textViewHolder = RichTextViewHolder.shared
    @StateObject var formattingState = FormattingState()
    @State var isFormatting = false
    @State var errorMessage: String? = nil
    @State var showError = false
    
    // Sheet states for pickers
    @State var showImagePicker = false
    @State var showDocumentPicker = false
    @State private var showColorPicker = false
    
    // Add id to force view refreshes when selected note changes
    private var noteId: String {
        selectedNote?.persistentModelID.storeIdentifier ?? "no-note"
    }
    
    private let logger = Logger(subsystem: Constants.App.bundleID, category: "RichTextNoteEditorView")
    
    /// Prepare note content for sharing
    func noteContentForSharing() -> String {
        guard let note = selectedNote else { return "" }
        return note.title.isEmpty ? attributedText.string : "\(note.title)\n\n\(attributedText.string)"
    }
    
    // Formatting engine for handling format operations
    private var formattingEngine: FormattingEngine? {
        if let textView = textViewHolder.textView {
            return FormattingEngine(
                textView: textView,
                attributedText: attributedText,
                formattingState: formattingState
            )
        }
        return nil
    }
    
    var body: some View {
        Group {
            if let note = selectedNote {
                VStack(spacing: 0) {
                    // Title field with iOS-style appearance
                    TextField("Title", text: Binding(
                        get: { note.title },
                        set: { newValue in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.updateNoteTitle(note, newTitle: newValue)
                            }
                        }
                    ))
                    .font(.system(.largeTitle, design: .rounded))
                    .fontWeight(.bold)
                    .padding([.horizontal, .top])
                    .padding(.top, 6)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("note-title-field")
                    .onChange(of: note.title) { oldValue, newValue in
                        if oldValue.isEmpty && !newValue.isEmpty {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                // Title appearance animation
                            }
                        }
                    }
                    
                    HStack {
                        Text("Created \(note.createdAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Color.secondary.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                    .padding(.top, 2)
                    
                    Divider()
                        .padding(.horizontal)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.accentColor.opacity(0.1), Color.clear, Color.clear]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    // Rich text editor
                    ZStack(alignment: .bottomTrailing) {
                        // Text editor
                        RichTextEditor(attributedText: $attributedText, onTextChange: { newText in
                            // Update the note's content directly with NSAttributedString
                            viewModel.updateNoteContent(note, newContent: newText)
                        }, formattingState: formattingState)
                        .padding(.horizontal, 4)
                        
                        // Also include hidden toolbar for API connections
                        RichTextToolbar(attributedText: $attributedText, textView: textViewHolder.textView, formattingState: formattingState)
                            .frame(width: 0, height: 0)
                            .opacity(0)
                            .accessibilityHidden(true)
                    }
                    
                    // Modern iOS-style toolbar with AI formatting
                    enhancedToolbar
                }
                .overlay {
                    formattingOverlay
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
                .onAppear { [self] in
                    // Load the attributed string directly from the note only if needed
                    let currentText = self.attributedText.string
                    let noteContent = viewModel.attributedContent(for: note)
                    
                    // Only update if content differs to prevent unnecessary redraws
                    if currentText != noteContent.string {
                        self.attributedText = noteContent
                    }
                    
                    // Don't modify text view directly here - let SwiftUI handle it
                    // Just reset formatting state based on the content
                    if self.attributedText.length > 0 {
                        // Apply a conservative check of attributes at position 0
                        let attributes = self.attributedText.attributes(at: 0, effectiveRange: nil)
                        
                        // Reset format state to reflect actual content
                        if let font = attributes[.font] as? UIFont {
                            self.formattingState.isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                            self.formattingState.isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
                        } else {
                            self.formattingState.isBold = false
                            self.formattingState.isItalic = false
                        }
                        
                        self.formattingState.isUnderlined = attributes[.underlineStyle] != nil
                        
                        if let color = attributes[.foregroundColor] as? UIColor {
                            self.formattingState.textColor = Color(color)
                        } else {
                            self.formattingState.textColor = .primary
                        }
                    } else {
                        // Reset to defaults if empty
                        self.formattingState.isBold = false
                        self.formattingState.isItalic = false
                        self.formattingState.isUnderlined = false
                        self.formattingState.textColor = .primary
                    }
                }
                .onChange(of: selectedNote) { [self] _, _ in
                    // Reset formatting state when switching notes
                    self.formattingState.isBold = false
                    self.formattingState.isItalic = false
                    self.formattingState.isUnderlined = false
                    self.formattingState.textColor = .primary
                    
                    // When selectedNote changes, update content if not nil
                    if let note = selectedNote {
                        self.attributedText = viewModel.attributedContent(for: note)
                    } else {
                        self.attributedText = NSAttributedString(string: "")
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
    
    /// Handle formatting actions from the format menu
    func handleFormatAction(_ action: FormatMenu.FormatAction, for note: ScribeNote) {
        // Use the formatting engine to perform the requested action
        var newText: NSAttributedString? = nil
        
        switch action {
        case .bold:
            newText = formattingEngine?.toggleBold()
        case .italic:
            newText = formattingEngine?.toggleItalic()
        case .underline:
            newText = formattingEngine?.toggleUnderline()
        case .heading(let style):
            newText = formattingEngine?.applyHeading(style)
        case .textColor:
            if !showColorPicker {
                showColorPicker = true
                return
            } else {
                newText = formattingEngine?.applyTextColor()
            }
        case .bulletList:
            newText = formattingEngine?.applyBulletPoints()
        case .clearFormatting:
            newText = formattingEngine?.clearFormatting()
        }
        
        // If text was modified, update the note
        if let updatedText = newText {
            // Update the view's attribute text binding
            attributedText = updatedText
            
            // Update the note in the view model
            viewModel.updateNoteContent(note, newContent: updatedText)
        }
    }
}