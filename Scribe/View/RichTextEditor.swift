import SwiftUI
import UIKit

/// A SwiftUI wrapper around UITextView for rich text editing
struct RichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var onTextChange: (NSAttributedString) -> Void
    
    // Formatting state (shared with toolbar)
    @ObservedObject var formattingState: FormattingState
    
    // Configuration options
    var backgroundColor: UIColor = .systemBackground
    var tintColor: UIColor = .label
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = backgroundColor
        textView.tintColor = tintColor
        
        // Use body text as default styling
        let bodyFont = UIFont.preferredFont(forTextStyle: .body)
        textView.font = bodyFont
        
        // Set default typing attributes for consistent formatting
        textView.typingAttributes = [
            .font: bodyFont,
            .foregroundColor: UIColor.label
        ]
        
        // Configure text view behavior
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.isUserInteractionEnabled = true
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.allowsEditingTextAttributes = true
        textView.dataDetectorTypes = [.link]
        textView.isSelectable = true
        
        // Improve performance by setting these properties
        textView.layoutManager.allowsNonContiguousLayout = false
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        // Ensure content text is applied before setting references
        if attributedText.length > 0 {
            textView.attributedText = attributedText
        } else {
            // If there's no text, create an empty attributed string with body formatting
            textView.attributedText = NSAttributedString(
                string: "",
                attributes: [.font: bodyFont, .foregroundColor: UIColor.label]
            )
        }
        
        // Important: Set this in the coordinator
        context.coordinator.textView = textView
        
        // Initialize formatting engine and store in coordinator
        context.coordinator.formattingEngine = FormattingEngine(
            textView: textView,
            attributedText: attributedText,
            formattingState: formattingState
        )
        
        // Store reference in the shared holder immediately
        DispatchQueue.main.async {
            RichTextViewHolder.shared.textView = textView
        }
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update if the text has actually changed to prevent unnecessary refreshes
        let textViewString = textView.attributedText.string
        let newString = attributedText.string
        
        if textViewString != newString || textView.attributedText.length != attributedText.length {
            // Save cursor position and selection state
            let selectedRange = textView.selectedRange
            let isFirstResponder = textView.isFirstResponder
            
            // Disable delegate temporarily to prevent unwanted calls
            let oldDelegate = textView.delegate
            textView.delegate = nil
            
            // Update the text
            textView.attributedText = attributedText
            
            // Update formatted text reference in the formatting engine
            context.coordinator.formattingEngine?.setAttributedText(attributedText)
            
            // Re-enable delegate
            textView.delegate = oldDelegate
            
            // Restore cursor position with thorough bounds checking
            if NSLocationInRange(selectedRange.location, NSRange(location: 0, length: attributedText.length)) {
                textView.selectedRange = selectedRange
            } else if attributedText.length > 0 {
                // If cursor was outside valid range, place at end of text
                textView.selectedRange = NSRange(location: min(selectedRange.location, attributedText.length), length: 0)
            } else {
                textView.selectedRange = NSRange(location: 0, length: 0)
            }
            
            // Make sure first responder state is preserved
            if isFirstResponder && !textView.isFirstResponder {
                textView.becomeFirstResponder()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        var textView: UITextView?
        var formattingEngine: FormattingEngine?
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            self.textView = textView
            
            // Update formatting engine reference with the new text view
            formattingEngine?.setTextView(textView)
            
            // Create non-mutable copy of the text to avoid reference issues
            let textCopy = NSAttributedString(attributedString: textView.attributedText)
            
            // Optimize for large content changes
            let shouldDelayUpdate = textView.text.count > 1000
                                
            // For smaller content, update immediately
            if !shouldDelayUpdate {
                self.parent.attributedText = textCopy
                self.parent.onTextChange(textCopy)
            } else {
                // For larger content, batch updates with slight delay to prevent lag
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.parent.attributedText = textCopy
                    self.parent.onTextChange(textCopy)
                }
            }
        }
        
        // Add this to ensure styling is preserved when view appears/reappears
        func textViewDidEndEditing(_ textView: UITextView) {
            // Save the final attributed text when editing ends
            let textCopy = NSAttributedString(attributedString: textView.attributedText)
            self.parent.attributedText = textCopy
            self.parent.onTextChange(textCopy)
        }
        
        // Method to insert images into the rich text
        func insertImage(_ image: UIImage) {
            // Use formatting engine to handle image insertion
            if let newText = formattingEngine?.insertImage(image) {
                parent.attributedText = newText
                parent.onTextChange(newText)
            }
        }
        
        // Method to insert a document reference/link
        func insertDocumentLink(url: URL, filename: String) {
            // Use formatting engine to handle document link insertion
            if let newText = formattingEngine?.insertDocumentLink(url: url, filename: filename) {
                parent.attributedText = newText
                parent.onTextChange(newText)
            }
        }
        
        // Update toolbar state based on cursor position
        func textViewDidChangeSelection(_ textView: UITextView) {
            self.textView = textView
            
            // Throttle updates to formatting state to prevent lag
            // Only update if selection is stable
            let currentSelection = textView.selectedRange
            let shouldUpdateFormatting = currentSelection.location != 0 || currentSelection.length > 0
            
            // Update the shared text view holder outside the main state update
            // to prevent performance issues
            RichTextViewHolder.shared.textView = textView
            
            // Don't update formatting state if text is empty
            if textView.text.isEmpty {
                formattingEngine?.resetFormattingState()
                return
            }
            
            // We only want to update if we have a valid position that makes sense to check
            if shouldUpdateFormatting {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, 
                          let textView = self.textView,
                          textView.selectedRange == currentSelection else { return }
                    
                    // Use formatting engine to update state
                    self.formattingEngine?.updateFormattingState(for: textView)
                }
            }
        }
    }
}

/// A toolbar for rich text editing actions
struct RichTextToolbar: View {
    // Singleton instance for external access
    static var shared: RichTextToolbar?
    
    @Binding var attributedText: NSAttributedString
    let textView: UITextView?  // Reference to the active UITextView
    
    // Shared formatting state
    @ObservedObject var formattingState: FormattingState
    
    init(attributedText: Binding<NSAttributedString>, textView: UITextView?, formattingState: FormattingState) {
        self._attributedText = attributedText
        self.textView = textView
        self.formattingState = formattingState
        
        // Set shared instance
        Self.shared = self
    }
    
    var body: some View {
        // We're not displaying the traditional toolbar in the new UI design
        // But we need to keep the toolbar structure for the formatting methods
        Color.clear.frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .id(1000) // Add a tag that can be found for direct method access
            .sheet(isPresented: $showColorPickerVisible) {
                ColorPicker("Text Color", selection: $formattingState.textColor)
                    .padding()
                    .onChange(of: formattingState.textColor) { [self] _ in
                        self.applyTextColor()
                    }
                    .presentationDetents([.height(200)])
            }
    }
    
    // State for color picker sheet
    @State private var showColorPickerVisible = false
    
    // Create an instance of the formatting engine to handle formatting operations
    private var formattingEngine: FormattingEngine? {
        if let textView = textView {
            return FormattingEngine(
                textView: textView,
                attributedText: attributedText,
                formattingState: formattingState
            )
        }
        return nil
    }
    
    // Formatting methods using the formattingEngine
    
    // Apply bold formatting
    func toggleBold() {
        if let newText = formattingEngine?.toggleBold() {
            attributedText = newText
        }
    }
    
    // Apply italic formatting
    func toggleItalic() {
        if let newText = formattingEngine?.toggleItalic() {
            attributedText = newText
        }
    }
    
    // Apply underline formatting
    func toggleUnderline() {
        if let newText = formattingEngine?.toggleUnderline() {
            attributedText = newText
        }
    }
    
    // Apply text color
    func applyTextColor() {
        if let newText = formattingEngine?.applyTextColor() {
            attributedText = newText
        }
    }
    
    // Apply heading format
    func applyHeading(_ style: Font.TextStyle) {
        if let newText = formattingEngine?.applyHeading(style) {
            attributedText = newText
        }
    }
    
    // Apply bullet points
    func applyBulletPoints() {
        if let newText = formattingEngine?.applyBulletPoints() {
            attributedText = newText
        }
    }
    
    // Clear all formatting
    func clearFormatting() {
        if let newText = formattingEngine?.clearFormatting() {
            attributedText = newText
        }
    }
}