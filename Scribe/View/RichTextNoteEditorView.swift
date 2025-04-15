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
    
    // Using View extension for keyboard dismissal
    
    /// Handle formatting actions from the format menu
    func handleFormatAction(_ action: FormatMenu.FormatAction, for note: ScribeNote) {
        // Get the text view and coordinator directly
        guard let textView = textViewHolder.textView,
              let coordinator = textView.delegate as? RichTextEditor.Coordinator else {
            return
        }
        
        // Create a mutable copy of the current text
        let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
        let selectedRange = textView.selectedRange
        
        switch action {
        case .bold:
            self.formattingState.isBold.toggle()
            
            // Handle selection vs insertion point differently
            if selectedRange.length > 0 {
                // Apply to selected text
                mutableAttrText.enumerateAttribute(.font, in: selectedRange) { [self] value, range, _ in
                    let currentFont = value as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
                    var traits = currentFont.fontDescriptor.symbolicTraits
                    
                    if self.formattingState.isBold {
                        traits.insert(.traitBold)
                    } else {
                        traits.remove(.traitBold)
                    }
                    
                    if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                        let newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                        mutableAttrText.addAttribute(.font, value: newFont, range: range)
                    }
                }
                
                // Update text view
                textView.attributedText = mutableAttrText
                attributedText = mutableAttrText
                textView.selectedRange = selectedRange
                viewModel.updateNoteContent(note, newContent: mutableAttrText)
            } else {
                // Update typing attributes for future text
                var currentAttributes = textView.typingAttributes
                let currentFont = currentAttributes[.font] as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
                var traits = currentFont.fontDescriptor.symbolicTraits
                
                if self.formattingState.isBold {
                    traits.insert(.traitBold)
                } else {
                    traits.remove(.traitBold)
                }
                
                if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                    let newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                    currentAttributes[.font] = newFont
                    textView.typingAttributes = currentAttributes
                }
            }
            
        case .italic:
            self.formattingState.isItalic.toggle()
            
            // Similar implementation to bold but for italic
            if selectedRange.length > 0 {
                mutableAttrText.enumerateAttribute(.font, in: selectedRange) { [self] value, range, _ in
                    let currentFont = value as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
                    var traits = currentFont.fontDescriptor.symbolicTraits
                    
                    if self.formattingState.isItalic {
                        traits.insert(.traitItalic)
                    } else {
                        traits.remove(.traitItalic)
                    }
                    
                    if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                        let newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                        mutableAttrText.addAttribute(.font, value: newFont, range: range)
                    }
                }
                
                textView.attributedText = mutableAttrText
                attributedText = mutableAttrText
                textView.selectedRange = selectedRange
                viewModel.updateNoteContent(note, newContent: mutableAttrText)
            } else {
                var currentAttributes = textView.typingAttributes
                let currentFont = currentAttributes[.font] as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
                var traits = currentFont.fontDescriptor.symbolicTraits
                
                if self.formattingState.isItalic {
                    traits.insert(.traitItalic)
                } else {
                    traits.remove(.traitItalic)
                }
                
                if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                    let newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                    currentAttributes[.font] = newFont
                    textView.typingAttributes = currentAttributes
                }
            }
            
        case .underline:
            self.formattingState.isUnderlined.toggle()
            
            if selectedRange.length > 0 {
                if self.formattingState.isUnderlined {
                    mutableAttrText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
                } else {
                    mutableAttrText.removeAttribute(.underlineStyle, range: selectedRange)
                }
                
                textView.attributedText = mutableAttrText
                attributedText = mutableAttrText
                textView.selectedRange = selectedRange
                viewModel.updateNoteContent(note, newContent: mutableAttrText)
            } else {
                var currentAttributes = textView.typingAttributes
                
                if self.formattingState.isUnderlined {
                    currentAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                } else {
                    currentAttributes.removeValue(forKey: .underlineStyle)
                }
                
                textView.typingAttributes = currentAttributes
            }
            
        case .heading(let style):
            // Determine font size based on heading style
            let fontSize: CGFloat
            switch style {
            case .title: fontSize = 24
            case .headline: fontSize = 18
            default: fontSize = 16
            }
            
            let fontWeight = style == .body ? UIFont.Weight.regular : UIFont.Weight.bold
            let newFont = UIFont.systemFont(ofSize: fontSize, weight: fontWeight)
            
            if selectedRange.length > 0 {
                mutableAttrText.addAttribute(.font, value: newFont, range: selectedRange)
                textView.attributedText = mutableAttrText
                attributedText = mutableAttrText
                textView.selectedRange = selectedRange
                viewModel.updateNoteContent(note, newContent: mutableAttrText)
            } else {
                var currentAttributes = textView.typingAttributes
                currentAttributes[.font] = newFont
                textView.typingAttributes = currentAttributes
                
                // Update toolbar state for this font size/style
                self.formattingState.isBold = fontWeight == .bold
            }
            
        case .textColor:
            // Show color picker if not already visible
            if !self.showColorPicker {
                self.showColorPicker = true
            } else {
                // Apply color to selection or typing attributes
                let uiColor = UIColor(self.formattingState.textColor)
                
                if selectedRange.length > 0 {
                    mutableAttrText.addAttribute(.foregroundColor, value: uiColor, range: selectedRange)
                    textView.attributedText = mutableAttrText
                    attributedText = mutableAttrText
                    textView.selectedRange = selectedRange
                    viewModel.updateNoteContent(note, newContent: mutableAttrText)
                } else {
                    var currentAttributes = textView.typingAttributes
                    currentAttributes[.foregroundColor] = uiColor
                    textView.typingAttributes = currentAttributes
                }
            }
            
        case .bulletList:
            // Direct implementation of bullet points function
            if selectedRange.length > 0 {
                // Process selected text paragraphs for bullets
                let fullText = mutableAttrText.string
                let nsString = fullText as NSString
                let paragraphRange = nsString.paragraphRange(for: selectedRange)
                
                // Prepare paragraph style
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.headIndent = 15
                paragraphStyle.firstLineHeadIndent = 0
                
                // Process paragraphs
                let selectedText = nsString.substring(with: paragraphRange)
                let paragraphs = selectedText.components(separatedBy: "\n")
                var bulletedText = ""
                
                for (index, paragraph) in paragraphs.enumerated() {
                    let trimmedParagraph = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedParagraph.isEmpty {
                        let bulletedParagraph = "• " + paragraph
                        bulletedText += bulletedParagraph
                        if index < paragraphs.count - 1 || selectedText.hasSuffix("\n") {
                            bulletedText += "\n"
                        }
                    } else if index < paragraphs.count - 1 {
                        bulletedText += "\n"
                    }
                }
                
                // Create attributed string with bullets
                let bulletedAttrString = NSMutableAttributedString(string: bulletedText)
                bulletedAttrString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: bulletedText.count))
                
                // Replace the original text
                mutableAttrText.replaceCharacters(in: paragraphRange, with: bulletedAttrString)
                textView.attributedText = mutableAttrText
                attributedText = mutableAttrText
                
                // Position cursor at end of bulleted text
                let newPosition = paragraphRange.location + bulletedText.count
                textView.selectedRange = NSRange(location: newPosition, length: 0)
                
                viewModel.updateNoteContent(note, newContent: mutableAttrText)
            } else {
                // Insert bullet at cursor position
                let bulletText = "• "
                let bulletAttrString = NSAttributedString(string: bulletText)
                
                mutableAttrText.insert(bulletAttrString, at: selectedRange.location)
                textView.attributedText = mutableAttrText
                attributedText = mutableAttrText
                textView.selectedRange = NSRange(location: selectedRange.location + bulletText.count, length: 0)
                
                viewModel.updateNoteContent(note, newContent: mutableAttrText)
            }
            
        case .clearFormatting:
            // Reset formatting state
            self.formattingState.isBold = false
            self.formattingState.isItalic = false
            self.formattingState.isUnderlined = false
            self.formattingState.textColor = .primary
            
            if selectedRange.length > 0 {
                // Clear formatting on selected text
                let plainText = mutableAttrText.string.substring(with: Range(selectedRange, in: mutableAttrText.string)!)
                
                // Default attributes
                let defaultFont = UIFont.preferredFont(forTextStyle: .body)
                let defaultAttributes: [NSAttributedString.Key: Any] = [
                    .font: defaultFont,
                    .foregroundColor: UIColor.label
                ]
                
                let plainAttrString = NSAttributedString(string: plainText, attributes: defaultAttributes)
                mutableAttrText.replaceCharacters(in: selectedRange, with: plainAttrString)
                
                textView.attributedText = mutableAttrText
                attributedText = mutableAttrText
                textView.selectedRange = NSRange(location: selectedRange.location, length: plainText.count)
                
                viewModel.updateNoteContent(note, newContent: mutableAttrText)
            } else {
                // Reset typing attributes
                let defaultFont = UIFont.preferredFont(forTextStyle: .body)
                let defaultAttributes: [NSAttributedString.Key: Any] = [
                    .font: defaultFont,
                    .foregroundColor: UIColor.label
                ]
                textView.typingAttributes = defaultAttributes
            }
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
