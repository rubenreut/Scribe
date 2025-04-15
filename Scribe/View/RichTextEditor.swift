import SwiftUI
import UIKit

/// A SwiftUI wrapper around UITextView for rich text editing
struct RichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var onTextChange: (NSAttributedString) -> Void
    
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
        RichTextViewHolder.shared.textView = textView
        
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
            
            // Restore cursor position
            if selectedRange.location < attributedText.length {
                textView.selectedRange = selectedRange
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
        
        // Update toolbar state based on cursor position
        func textViewDidChangeSelection(_ textView: UITextView) {
            self.textView = textView
            
            let cursorPosition = textView.selectedRange.location
            
            // If we have text and a valid cursor position
            if cursorPosition > 0 && textView.attributedText.length > 0 {
                // Get attributes at the cursor position (actually right before it, as cursor is between characters)
                let attributes = textView.textStorage.attributes(at: max(0, cursorPosition - 1), effectiveRange: nil)
                
                // Check for font traits
                if let font = attributes[.font] as? UIFont {
                    parent.isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                    parent.isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
                }
                
                // Check for underline
                parent.isUnderlined = attributes[.underlineStyle] != nil
                
                // Update text color if present
                if let color = attributes[.foregroundColor] as? UIColor {
                    parent.textColor = Color(color)
                }
            } else if textView.selectedRange.length == 0 {
                // If at beginning of text or empty text, check typing attributes
                if let font = textView.typingAttributes[.font] as? UIFont {
                    parent.isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
                    parent.isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
                } else {
                    parent.isBold = false
                    parent.isItalic = false
                }
                
                parent.isUnderlined = textView.typingAttributes[.underlineStyle] != nil
            }
        }
    }
}

/// A toolbar for rich text editing actions
struct RichTextToolbar: View {
    @Binding var attributedText: NSAttributedString
    let textView: UITextView?  // Reference to the active UITextView
    
    // Active formatting state
    @State private var isBold = false
    @State private var isItalic = false
    @State private var isUnderlined = false
    
    @State private var showColorPicker = false
    @State private var textColor: Color = .primary
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Bold button
                Button(action: toggleBold) {
                    Image(systemName: "bold")
                        .padding(8)
                        .background(isBold ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                }
                .accessibilityLabel("Bold")
                
                // Italic button
                Button(action: toggleItalic) {
                    Image(systemName: "italic")
                        .padding(8)
                        .background(isItalic ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                }
                .accessibilityLabel("Italic")
                
                // Underline button
                Button(action: toggleUnderline) {
                    Image(systemName: "underline")
                        .padding(8)
                        .background(isUnderlined ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                }
                .accessibilityLabel("Underline")
                
                Divider()
                    .frame(height: 20)
                
                // Color picker
                Button(action: { showColorPicker.toggle() }) {
                    Image(systemName: "paintpalette")
                        .padding(8)
                        .foregroundColor(textColor)
                }
                .accessibilityLabel("Text Color")
                
                Divider()
                    .frame(height: 20)
                
                // Heading buttons
                Button(action: { applyHeading(.title) }) {
                    Text("H1")
                        .fontWeight(.bold)
                        .padding(8)
                }
                .accessibilityLabel("Heading 1")
                
                Button(action: { applyHeading(.headline) }) {
                    Text("H2")
                        .fontWeight(.bold)
                        .padding(8)
                }
                .accessibilityLabel("Heading 2")
                
                Button(action: { applyHeading(.body) }) {
                    Text("Body")
                        .padding(8)
                }
                .accessibilityLabel("Body text")
                
                Divider()
                    .frame(height: 20)
                
                // List and bullet points
                Button(action: applyBulletPoints) {
                    Image(systemName: "list.bullet")
                        .padding(8)
                }
                .accessibilityLabel("Bullet list")
                
                // Clear formatting
                Button(action: clearFormatting) {
                    Image(systemName: "eraser")
                        .padding(8)
                }
                .accessibilityLabel("Clear formatting")
            }
            .padding(.horizontal)
        }
        .frame(height: 56)
        .background(Color(UIColor.secondarySystemBackground))
        .sheet(isPresented: $showColorPicker) {
            ColorPicker("Text Color", selection: $textColor)
                .padding()
                .onChange(of: textColor) { _ in
                    applyTextColor()
                }
                .presentationDetents([.height(200)])
        }
    }
    
    // Apply bold formatting
    private func toggleBold() {
        isBold.toggle()
        
        guard let textView = textView else { return }

        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Scenario: User has selected text
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            
            mutableAttrText.enumerateAttribute(.font, in: selectedRange) { value, range, _ in
                let currentFont = value as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
                var traits = currentFont.fontDescriptor.symbolicTraits
                
                if isBold {
                    traits.insert(.traitBold)
                } else {
                    traits.remove(.traitBold)
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

            if isBold {
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
        isItalic.toggle()
        
        guard let textView = textView else { return }

        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Scenario: User has selected text
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            
            mutableAttrText.enumerateAttribute(.font, in: selectedRange) { value, range, _ in
                let currentFont = value as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
                var traits = currentFont.fontDescriptor.symbolicTraits
                
                if isItalic {
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

            if isItalic {
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
        isUnderlined.toggle()
        
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Scenario: User has selected text
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            
            if isUnderlined {
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
            
            if isUnderlined {
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
        let uiColor = UIColor(textColor)
        
        if selectedRange.length > 0 {
            // Scenario: User has selected text
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            
            mutableAttrText.addAttribute(.foregroundColor, value: uiColor, range: selectedRange)
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
            isBold = fontWeight == .bold
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
            isBold = false
            isItalic = false
            isUnderlined = false
            textColor = Color.primary
        } else {
            // Reset typing attributes for future input
            let defaultFont = UIFont.preferredFont(forTextStyle: .body)
            let defaultAttributes: [NSAttributedString.Key: Any] = [
                .font: defaultFont,
                .foregroundColor: UIColor.label
            ]
            textView.typingAttributes = defaultAttributes
            
            // Reset toolbar state
            isBold = false
            isItalic = false
            isUnderlined = false
            textColor = Color.primary
        }
    }
}

