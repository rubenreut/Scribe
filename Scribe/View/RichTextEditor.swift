import SwiftUI
import UIKit

/// A formatting state class to hold the current styling state
class FormattingState: ObservableObject {
    @Published var isBold: Bool = false
    @Published var isItalic: Bool = false
    @Published var isUnderlined: Bool = false
    @Published var textColor: Color = .primary
}

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
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            self.textView = textView
            
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
            guard let textView = self.textView else { return }
            
            // Create the NSTextAttachment
            let attachment = NSTextAttachment()
            attachment.image = image
            
            // Adjust attachment bounds (resize if necessary)
            let maxWidth = textView.frame.size.width - 20
            let imageRatio = image.size.height / image.size.width
            let attachmentWidth = min(maxWidth, image.size.width)
            let attachmentHeight = attachmentWidth * imageRatio
            attachment.bounds = CGRect(x: 0, y: 0, width: attachmentWidth, height: attachmentHeight)

            // Create attributed string from attachment
            let attrStringWithImage = NSAttributedString(attachment: attachment)

            // Insert at the current cursor location
            let mutableAttrString = NSMutableAttributedString(attributedString: textView.attributedText)
            let selectedRange = textView.selectedRange
            mutableAttrString.insert(attrStringWithImage, at: selectedRange.location)

            // Update textView
            textView.attributedText = mutableAttrString
            
            // Move cursor after the inserted image
            textView.selectedRange = NSRange(location: selectedRange.location + 1, length: 0)
            
            // Notify parent SwiftUI view about changes
            parent.attributedText = textView.attributedText
            parent.onTextChange(textView.attributedText)
        }
        
        // Method to insert a document reference/link
        func insertDocumentLink(url: URL, filename: String) {
            guard let textView = self.textView else { return }
            
            // Create a link text with the file name
            let linkText = " 📎 \(filename) "
            
            // Create an attributed string with a link
            let linkAttributes: [NSAttributedString.Key: Any] = [
                .link: url,
                .foregroundColor: UIColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .backgroundColor: UIColor.systemGray6
            ]
            
            let linkString = NSAttributedString(string: linkText, attributes: linkAttributes)
            
            // Insert at the current cursor location
            let mutableAttrString = NSMutableAttributedString(attributedString: textView.attributedText)
            let selectedRange = textView.selectedRange
            mutableAttrString.insert(linkString, at: selectedRange.location)
            
            // Update textView
            textView.attributedText = mutableAttrString
            
            // Move cursor after the inserted link
            textView.selectedRange = NSRange(location: selectedRange.location + linkText.count, length: 0)
            
            // Notify parent SwiftUI view about changes
            parent.attributedText = textView.attributedText
            parent.onTextChange(textView.attributedText)
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
                self.resetFormattingState()
                return
            }
            
            // We only want to update if we have a valid position that makes sense to check
            if shouldUpdateFormatting {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, 
                          let textView = self.textView,
                          textView.selectedRange == currentSelection else { return }
                    
                    self.updateFormattingState(for: textView)
                }
            }
        }
        
        // Helper to update formatting state without duplicating code
        private func updateFormattingState(for textView: UITextView) {
            let cursorPosition = textView.selectedRange.location
            let selectionLength = textView.selectedRange.length
            
            // If we have a selection, check the attributes of the first character
            if selectionLength > 0 && textView.attributedText.length > cursorPosition {
                self.updateFormattingFromAttributes(
                    textView.textStorage.attributes(at: cursorPosition, effectiveRange: nil)
                )
            }
            // If we have just a cursor and it's not at the start, check character to the left
            else if selectionLength == 0 && cursorPosition > 0 && textView.attributedText.length >= cursorPosition {
                self.updateFormattingFromAttributes(
                    textView.textStorage.attributes(at: cursorPosition - 1, effectiveRange: nil)
                )
            }
            // If at beginning of text, check typing attributes for future input
            else {
                self.updateFormattingFromAttributes(textView.typingAttributes)
            }
        }
        
        // Helper to update the format state from attributes dictionary
        private func updateFormattingFromAttributes(_ attributes: [NSAttributedString.Key: Any]) {
            // Check for font traits
            if let font = attributes[.font] as? UIFont {
                self.parent.formattingState.isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                self.parent.formattingState.isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
            } else {
                // Default state if no font
                self.parent.formattingState.isBold = false
                self.parent.formattingState.isItalic = false
            }
            
            // Check for underline
            self.parent.formattingState.isUnderlined = attributes[.underlineStyle] != nil
            
            // Update text color if present
            if let color = attributes[.foregroundColor] as? UIColor {
                self.parent.formattingState.textColor = Color(color)
            } else {
                self.parent.formattingState.textColor = .primary
            }
        }
        
        // Reset formatting state to defaults
        private func resetFormattingState() {
            self.parent.formattingState.isBold = false
            self.parent.formattingState.isItalic = false
            self.parent.formattingState.isUnderlined = false
            self.parent.formattingState.textColor = .primary
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
    
    // Apply bold formatting
    func toggleBold() {
        formattingState.isBold.toggle()
        
        guard let textView = textView else { return }

        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Scenario: User has selected text
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            
            // Store the original selection to restore it later
            let originalSelection = textView.selectedRange
            
            // Using a more efficient approach with fewer iterations
            let fullRange = NSRange(location: 0, length: mutableAttrText.length)
            mutableAttrText.enumerateAttribute(.font, in: selectedRange, options: []) { value, range, _ in
                let currentFont = value as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
                var traits = currentFont.fontDescriptor.symbolicTraits
                
                // Update traits based on formatting state
                if formattingState.isBold {
                    traits.insert(.traitBold)
                } else {
                    traits.remove(.traitBold)
                }
                
                // Create new font with updated traits
                if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                    let newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                    
                    // Collect other existing attributes at this range to preserve them
                    var combinedAttributes: [NSAttributedString.Key: Any] = [.font: newFont]
                    
                    // Add other existing attributes
                    mutableAttrText.attributes(at: range.location, effectiveRange: nil).forEach { key, value in
                        if key != .font {
                            combinedAttributes[key] = value
                        }
                    }
                    
                    // Apply all attributes at once
                    mutableAttrText.addAttributes(combinedAttributes, range: range)
                }
            }
            
            // Update the text and restore selection
            attributedText = mutableAttrText
            textView.attributedText = mutableAttrText
            
            // Ensure selection is within bounds
            if NSLocationInRange(originalSelection.location, NSRange(location: 0, length: mutableAttrText.length)) {
                textView.selectedRange = originalSelection
            } else {
                textView.selectedRange = NSRange(location: mutableAttrText.length, length: 0)
            }
        } else {
            // Scenario: No selection; set typing attributes for future input
            var currentAttributes = textView.typingAttributes
            let currentFont = currentAttributes[.font] as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
            var traits = currentFont.fontDescriptor.symbolicTraits

            if formattingState.isBold {
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
    }
    
    // Apply italic formatting
    func toggleItalic() {
        formattingState.isItalic.toggle()
        
        guard let textView = textView else { return }

        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Scenario: User has selected text
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            
            mutableAttrText.enumerateAttribute(.font, in: selectedRange) { value, range, _ in
                let currentFont = value as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
                var traits = currentFont.fontDescriptor.symbolicTraits
                
                if formattingState.isItalic {
                    traits.insert(.traitItalic)
                } else {
                    traits.remove(.traitItalic)
                }
                
                if let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
                    let newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)
                    mutableAttrText.addAttribute(.font, value: newFont, range: range)
                }
            }
            
            attributedText = mutableAttrText
            textView.attributedText = mutableAttrText
            textView.selectedRange = selectedRange
        } else {
            // Scenario: No selection; set typing attributes for future input
            var currentAttributes = textView.typingAttributes
            let currentFont = currentAttributes[.font] as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
            var traits = currentFont.fontDescriptor.symbolicTraits

            if formattingState.isItalic {
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
    }
    
    // Apply underline formatting
    func toggleUnderline() {
        formattingState.isUnderlined.toggle()
        
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Scenario: User has selected text
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            
            if formattingState.isUnderlined {
                mutableAttrText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
            } else {
                mutableAttrText.removeAttribute(.underlineStyle, range: selectedRange)
            }
            
            attributedText = mutableAttrText
            textView.attributedText = mutableAttrText
            textView.selectedRange = selectedRange
        } else {
            // Scenario: No selection; set typing attributes for future input
            var currentAttributes = textView.typingAttributes
            
            if formattingState.isUnderlined {
                currentAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            } else {
                currentAttributes.removeValue(forKey: .underlineStyle)
            }
            
            textView.typingAttributes = currentAttributes
        }
    }
    
    // Apply text color
    func applyTextColor() {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        let uiColor = UIColor(formattingState.textColor)
        
        if selectedRange.length > 0 {
            // Scenario: User has selected text
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            
            // More efficient to add all attributes at once if possible
            var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: uiColor]
            
            // Include font attributes if they exist at this position
            if let existingFont = mutableAttrText.attribute(.font, at: selectedRange.location, effectiveRange: nil) as? UIFont {
                attributes[.font] = existingFont
            }
            
            mutableAttrText.addAttributes(attributes, range: selectedRange)
            attributedText = mutableAttrText
            textView.attributedText = mutableAttrText
            textView.selectedRange = selectedRange
        } else {
            // Scenario: No selection; set typing attributes for future input
            var currentAttributes = textView.typingAttributes
            currentAttributes[.foregroundColor] = uiColor
            textView.typingAttributes = currentAttributes
        }
    }
    
    // Apply heading format
    func applyHeading(_ style: Font.TextStyle) {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
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
            // Scenario: User has selected text
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            
            // Preserve bold/italic traits if present
            mutableAttrText.enumerateAttribute(.font, in: selectedRange) { value, range, _ in
                if let currentFont = value as? UIFont {
                    var traits = currentFont.fontDescriptor.symbolicTraits
                    if let descriptor = newFont.fontDescriptor.withSymbolicTraits(traits) {
                        let styledFont = UIFont(descriptor: descriptor, size: fontSize)
                        mutableAttrText.addAttribute(.font, value: styledFont, range: range)
                    } else {
                        mutableAttrText.addAttribute(.font, value: newFont, range: range)
                    }
                } else {
                    mutableAttrText.addAttribute(.font, value: newFont, range: range)
                }
            }
            
            attributedText = mutableAttrText
            textView.attributedText = mutableAttrText
            textView.selectedRange = selectedRange
        } else {
            // Scenario: No selection; set typing attributes for future input
            var currentAttributes = textView.typingAttributes
            currentAttributes[.font] = newFont
            textView.typingAttributes = currentAttributes
            
            // Update toolbar state for this font size/style
            formattingState.isBold = fontWeight == .bold
        }
    }
    
    // Apply bullet points more efficiently using paragraph style
    func applyBulletPoints() {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Processing selected text
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            let fullText = mutableAttrText.string
            
            // Get the paragraph ranges from the selection
            let nsString = fullText as NSString
            let paragraphRange = nsString.paragraphRange(for: selectedRange)
            
            // Create paragraph style with indentation
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 15
            paragraphStyle.firstLineHeadIndent = 0
            paragraphStyle.paragraphSpacing = 4
            
            // Split the selected text into paragraphs and process each one
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
            
            // Apply the formatted text with attributes while preserving existing attributes
            let bulletedAttrString = NSMutableAttributedString(string: bulletedText)
            
            // Apply paragraph style to the entire text
            bulletedAttrString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: bulletedText.count))
            
            // Copy other attributes from original text
            let originalAttrs = mutableAttrText.attributes(at: paragraphRange.location, effectiveRange: nil)
            for (key, value) in originalAttrs {
                if key != .paragraphStyle {
                    bulletedAttrString.addAttribute(key, value: value, range: NSRange(location: 0, length: bulletedText.count))
                }
            }
            
            mutableAttrText.replaceCharacters(in: paragraphRange, with: bulletedAttrString)
            
            attributedText = mutableAttrText
            textView.attributedText = mutableAttrText
            
            // Set cursor position at the end of the modified text
            let newCursorPosition = paragraphRange.location + bulletedText.count
            textView.selectedRange = NSRange(location: newCursorPosition, length: 0)
        } else {
            // Cursor only - modify current line
            let text = textView.text as NSString
            let currentPosition = selectedRange.location
            let lineRange = text.lineRange(for: NSRange(location: currentPosition, length: 0))
            
            // Create paragraph style with indentation
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 15
            paragraphStyle.firstLineHeadIndent = 0
            paragraphStyle.paragraphSpacing = 4
            
            // Prepare for typing a bullet point
            var currentAttributes = textView.typingAttributes
            currentAttributes[.paragraphStyle] = paragraphStyle
            textView.typingAttributes = currentAttributes
            
            // Insert bullet at current position
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            let bulletText = "• "
            let bulletAttrs = textView.typingAttributes
            let bulletAttrString = NSAttributedString(string: bulletText, attributes: bulletAttrs)
            
            mutableAttrText.insert(bulletAttrString, at: currentPosition)
            attributedText = mutableAttrText
            textView.attributedText = mutableAttrText
            textView.selectedRange = NSRange(location: currentPosition + bulletText.count, length: 0)
        }
    }
    
    // Clear all formatting
    func clearFormatting() {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Clear formatting on selected text
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            let plainText = mutableAttrText.string.substring(with: Range(selectedRange, in: mutableAttrText.string)!)
            
            // Create an attributed string with default attributes only
            let defaultFont = UIFont.preferredFont(forTextStyle: .body)
            let defaultAttributes: [NSAttributedString.Key: Any] = [
                .font: defaultFont,
                .foregroundColor: UIColor.label
            ]
            let plainAttrString = NSAttributedString(string: plainText, attributes: defaultAttributes)
            
            mutableAttrText.replaceCharacters(in: selectedRange, with: plainAttrString)
            
            attributedText = mutableAttrText
            textView.attributedText = mutableAttrText
            textView.selectedRange = NSRange(location: selectedRange.location, length: plainText.count)
            
            // Reset toolbar state
            formattingState.isBold = false
            formattingState.isItalic = false
            formattingState.isUnderlined = false
            formattingState.textColor = Color.primary
        } else {
            // Reset typing attributes for future input
            let defaultFont = UIFont.preferredFont(forTextStyle: .body)
            let defaultAttributes: [NSAttributedString.Key: Any] = [
                .font: defaultFont,
                .foregroundColor: UIColor.label
            ]
            textView.typingAttributes = defaultAttributes
            
            // Reset toolbar state
            formattingState.isBold = false
            formattingState.isItalic = false
            formattingState.isUnderlined = false
            formattingState.textColor = Color.primary
        }
    }
}