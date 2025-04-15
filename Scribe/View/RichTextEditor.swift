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
        textView.attributedText = attributedText
        textView.backgroundColor = backgroundColor
        textView.tintColor = tintColor
        textView.font = .preferredFont(forTextStyle: .body)
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.isUserInteractionEnabled = true
        textView.autocapitalizationType = .sentences
        textView.autocorrectionType = .default
        textView.allowsEditingTextAttributes = true
        textView.dataDetectorTypes = [.link]
        textView.isSelectable = true
        
        // Important: Set this in the coordinator
        context.coordinator.textView = textView
        
        // Store reference in the shared holder immediately
        DispatchQueue.main.async {
            RichTextViewHolder.shared.textView = textView
        }
        
        // Ensure proper formatting is preserved by reapplying
        textView.attributedText = attributedText
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.attributedText.string != attributedText.string {
            // Save cursor position
            let selectedRange = textView.selectedRange
            
            // Only update if content actually changed
            textView.attributedText = attributedText
            
            // Restore cursor position with thorough bounds checking
            if NSLocationInRange(selectedRange.location, NSRange(location: 0, length: attributedText.length)) {
                textView.selectedRange = selectedRange
            } else {
                // If cursor was outside valid range, place at end of text
                textView.selectedRange = NSRange(location: attributedText.length, length: 0)
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
            parent.attributedText = textView.attributedText
            parent.onTextChange(textView.attributedText)
        }
        
        // Add this to ensure styling is preserved when view appears/reappears
        func textViewDidEndEditing(_ textView: UITextView) {
            // Save the final attributed text when editing ends
            parent.attributedText = textView.attributedText
            parent.onTextChange(textView.attributedText)
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
        
        // Update toolbar state based on cursor position
        func textViewDidChangeSelection(_ textView: UITextView) {
            self.textView = textView
            
            let cursorPosition = textView.selectedRange.location
            let selectionLength = textView.selectedRange.length
            
            // Update the shared text view holder
            DispatchQueue.main.async {
                RichTextViewHolder.shared.textView = textView
            }
            
            // If we have a selection, check the attributes of the first character in the selection
            if selectionLength > 0 && textView.attributedText.length > 0 {
                let attributes = textView.textStorage.attributes(at: cursorPosition, effectiveRange: nil)
                
                // Check for font traits
                if let font = attributes[.font] as? UIFont {
                    parent.formattingState.isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                    parent.formattingState.isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
                }
                
                // Check for underline
                parent.formattingState.isUnderlined = attributes[.underlineStyle] != nil
                
                // Update text color if present
                if let color = attributes[.foregroundColor] as? UIColor {
                    parent.formattingState.textColor = Color(color)
                }
            } 
            // If we have just a cursor (no selection) and it's not at the start, check character to the left
            else if selectionLength == 0 && cursorPosition > 0 && textView.attributedText.length > 0 {
                // Get attributes at the cursor position (right before it, as cursor is between characters)
                let attributes = textView.textStorage.attributes(at: cursorPosition - 1, effectiveRange: nil)
                
                // Check for font traits
                if let font = attributes[.font] as? UIFont {
                    parent.formattingState.isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                    parent.formattingState.isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
                }
                
                // Check for underline
                parent.formattingState.isUnderlined = attributes[.underlineStyle] != nil
                
                // Update text color if present
                if let color = attributes[.foregroundColor] as? UIColor {
                    parent.formattingState.textColor = Color(color)
                }
            } 
            // If at beginning of text or empty text, check typing attributes for future input
            else {
                if let font = textView.typingAttributes[.font] as? UIFont {
                    parent.formattingState.isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                    parent.formattingState.isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
                } else {
                    parent.formattingState.isBold = false
                    parent.formattingState.isItalic = false
                }
                
                parent.formattingState.isUnderlined = textView.typingAttributes[.underlineStyle] != nil
                
                if let color = textView.typingAttributes[.foregroundColor] as? UIColor {
                    parent.formattingState.textColor = Color(color)
                } else {
                    parent.formattingState.textColor = .primary
                }
            }
        }
    }
}

/// A toolbar for rich text editing actions
struct RichTextToolbar: View {
    @Binding var attributedText: NSAttributedString
    let textView: UITextView?  // Reference to the active UITextView
    
    // Shared formatting state
    @ObservedObject var formattingState: FormattingState
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Text Style Group
                Group {
                    // Bold button
                    Button(action: toggleBold) {
                        Image(systemName: "bold")
                            .padding(6)
                            .background(formattingState.isBold ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(6)
                    }
                    .accessibilityLabel("Bold")
                    
                    // Italic button
                    Button(action: toggleItalic) {
                        Image(systemName: "italic")
                            .padding(6)
                            .background(formattingState.isItalic ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(6)
                    }
                    .accessibilityLabel("Italic")
                    
                    // Underline button
                    Button(action: toggleUnderline) {
                        Image(systemName: "underline")
                            .padding(6)
                            .background(formattingState.isUnderlined ? Color.accentColor.opacity(0.2) : Color.clear)
                            .cornerRadius(6)
                    }
                    .accessibilityLabel("Underline")
                }
                
                Divider()
                    .frame(height: 20)
                
                // Color picker - more compact
                Button(action: { showColorPickerVisible.toggle() }) {
                    Image(systemName: "paintpalette")
                        .padding(6)
                        .foregroundColor(formattingState.textColor)
                }
                .accessibilityLabel("Text Color")
                
                Divider()
                    .frame(height: 20)
                
                // Paragraph Style Group
                Group {
                    // Heading 1
                    Button(action: { applyHeading(.title) }) {
                        Image(systemName: "textformat.size")
                            .padding(6)
                    }
                    .accessibilityLabel("Heading 1")
                    
                    // Heading 2
                    Button(action: { applyHeading(.headline) }) {
                        Image(systemName: "textformat.size.smaller")
                            .padding(6)
                    }
                    .accessibilityLabel("Heading 2")
                    
                    // Body text
                    Button(action: { applyHeading(.body) }) {
                        Image(systemName: "text.justify")
                            .padding(6)
                    }
                    .accessibilityLabel("Body text")
                }
                
                Divider()
                    .frame(height: 20)
                
                // List and bullets
                Button(action: applyBulletPoints) {
                    Image(systemName: "list.bullet")
                        .padding(6)
                }
                .accessibilityLabel("Bullet list")
                
                // Clear formatting
                Button(action: clearFormatting) {
                    Image(systemName: "eraser")
                        .padding(6)
                }
                .accessibilityLabel("Clear formatting")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(height: 48)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 4)
        .sheet(isPresented: $showColorPickerVisible) {
            ColorPicker("Text Color", selection: $formattingState.textColor)
                .padding()
                .onChange(of: formattingState.textColor) { _ in
                    applyTextColor()
                }
                .presentationDetents([.height(200)])
        }
    }
    
    // State for color picker sheet
    @State private var showColorPickerVisible = false
    
    // Apply bold formatting
    private func toggleBold() {
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
    private func toggleItalic() {
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
    private func toggleUnderline() {
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
    private func applyTextColor() {
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
    private func applyHeading(_ style: Font.TextStyle) {
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
    private func applyBulletPoints() {
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
    private func clearFormatting() {
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