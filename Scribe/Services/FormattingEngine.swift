import SwiftUI
import UIKit

/// A formatting state class to hold the current styling state
class FormattingState: ObservableObject {
    @Published var isBold: Bool = false
    @Published var isItalic: Bool = false
    @Published var isUnderlined: Bool = false
    @Published var textColor: Color = .primary
}

/// Engine for handling rich text formatting operations
class FormattingEngine {
    // Reference to the text view and attributed text
    private var textView: UITextView?
    private var attributedText: NSAttributedString
    
    // Formatting state to track current styling
    private var formattingState: FormattingState
    
    init(textView: UITextView?, attributedText: NSAttributedString, formattingState: FormattingState) {
        self.textView = textView
        self.attributedText = attributedText
        self.formattingState = formattingState
    }
    
    // Set the text view reference (used when the UITextView is created/updated)
    func setTextView(_ textView: UITextView) {
        self.textView = textView
    }
    
    // Update the attributed text reference
    func setAttributedText(_ attributedText: NSAttributedString) {
        self.attributedText = attributedText
    }
    
    // MARK: - Formatting Methods
    
    /// Apply bold formatting
    func toggleBold() -> NSAttributedString? {
        formattingState.isBold.toggle()
        
        guard let textView = textView else { return nil }

        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Scenario: User has selected text
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            
            // Store the original selection to restore it later
            let originalSelection = textView.selectedRange
            
            // Using a more efficient approach with fewer iterations
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
            textView.attributedText = mutableAttrText
            
            // Ensure selection is within bounds
            if NSLocationInRange(originalSelection.location, NSRange(location: 0, length: mutableAttrText.length)) {
                textView.selectedRange = originalSelection
            } else {
                textView.selectedRange = NSRange(location: mutableAttrText.length, length: 0)
            }
            
            return mutableAttrText
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
            
            return nil // No text selected, so no changes to the attributed string
        }
    }
    
    /// Apply italic formatting
    func toggleItalic() -> NSAttributedString? {
        formattingState.isItalic.toggle()
        
        guard let textView = textView else { return nil }

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
            
            textView.attributedText = mutableAttrText
            textView.selectedRange = selectedRange
            
            return mutableAttrText
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
            
            return nil // No text selected, so no changes to the attributed string
        }
    }
    
    /// Apply underline formatting
    func toggleUnderline() -> NSAttributedString? {
        formattingState.isUnderlined.toggle()
        
        guard let textView = textView else { return nil }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Scenario: User has selected text
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            
            if formattingState.isUnderlined {
                mutableAttrText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
            } else {
                mutableAttrText.removeAttribute(.underlineStyle, range: selectedRange)
            }
            
            textView.attributedText = mutableAttrText
            textView.selectedRange = selectedRange
            
            return mutableAttrText
        } else {
            // Scenario: No selection; set typing attributes for future input
            var currentAttributes = textView.typingAttributes
            
            if formattingState.isUnderlined {
                currentAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            } else {
                currentAttributes.removeValue(forKey: .underlineStyle)
            }
            
            textView.typingAttributes = currentAttributes
            
            return nil // No text selected, so no changes to the attributed string
        }
    }
    
    /// Apply text color
    func applyTextColor() -> NSAttributedString? {
        guard let textView = textView else { return nil }
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
            textView.attributedText = mutableAttrText
            textView.selectedRange = selectedRange
            
            return mutableAttrText
        } else {
            // Scenario: No selection; set typing attributes for future input
            var currentAttributes = textView.typingAttributes
            currentAttributes[.foregroundColor] = uiColor
            textView.typingAttributes = currentAttributes
            
            return nil // No text selected, so no changes to the attributed string
        }
    }
    
    /// Apply heading format
    func applyHeading(_ style: Font.TextStyle) -> NSAttributedString? {
        guard let textView = textView else { return nil }
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
            
            textView.attributedText = mutableAttrText
            textView.selectedRange = selectedRange
            
            return mutableAttrText
        } else {
            // Scenario: No selection; set typing attributes for future input
            var currentAttributes = textView.typingAttributes
            currentAttributes[.font] = newFont
            textView.typingAttributes = currentAttributes
            
            // Update toolbar state for this font size/style
            formattingState.isBold = fontWeight == .bold
            
            return nil // No text selected, so no changes to the attributed string
        }
    }
    
    /// Apply bullet points more efficiently using paragraph style
    func applyBulletPoints() -> NSAttributedString? {
        guard let textView = textView else { return nil }
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
            
            textView.attributedText = mutableAttrText
            
            // Set cursor position at the end of the modified text
            let newCursorPosition = paragraphRange.location + bulletedText.count
            textView.selectedRange = NSRange(location: newCursorPosition, length: 0)
            
            return mutableAttrText
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
            textView.attributedText = mutableAttrText
            textView.selectedRange = NSRange(location: currentPosition + bulletText.count, length: 0)
            
            return mutableAttrText
        }
    }
    
    /// Clear all formatting
    func clearFormatting() -> NSAttributedString? {
        guard let textView = textView else { return nil }
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
            
            textView.attributedText = mutableAttrText
            textView.selectedRange = NSRange(location: selectedRange.location, length: plainText.count)
            
            // Reset toolbar state
            formattingState.isBold = false
            formattingState.isItalic = false
            formattingState.isUnderlined = false
            formattingState.textColor = .primary
            
            return mutableAttrText
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
            formattingState.textColor = .primary
            
            return nil // No text selected, so no changes to the attributed string
        }
    }
    
    /// Insert image at current cursor position
    func insertImage(_ image: UIImage) -> NSAttributedString? {
        guard let textView = textView else { return nil }
        
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
        
        return mutableAttrString
    }
    
    /// Insert document link at current cursor position
    func insertDocumentLink(url: URL, filename: String) -> NSAttributedString? {
        guard let textView = textView else { return nil }
        
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
        
        return mutableAttrString
    }
    
    // MARK: - Cursor Position Formatting State
    
    /// Update formatting state based on cursor position attributes
    func updateFormattingState(for textView: UITextView) {
        let cursorPosition = textView.selectedRange.location
        let selectionLength = textView.selectedRange.length
        
        // If we have a selection, check the attributes of the first character
        if selectionLength > 0 && textView.attributedText.length > cursorPosition {
            updateFormattingFromAttributes(
                textView.textStorage.attributes(at: cursorPosition, effectiveRange: nil)
            )
        }
        // If we have just a cursor and it's not at the start, check character to the left
        else if selectionLength == 0 && cursorPosition > 0 && textView.attributedText.length >= cursorPosition {
            updateFormattingFromAttributes(
                textView.textStorage.attributes(at: cursorPosition - 1, effectiveRange: nil)
            )
        }
        // If at beginning of text, check typing attributes for future input
        else {
            updateFormattingFromAttributes(textView.typingAttributes)
        }
    }
    
    /// Reset formatting state to defaults
    func resetFormattingState() {
        formattingState.isBold = false
        formattingState.isItalic = false
        formattingState.isUnderlined = false
        formattingState.textColor = .primary
    }
    
    // MARK: - Private Helpers
    
    /// Update formatting state from attributes dictionary
    private func updateFormattingFromAttributes(_ attributes: [NSAttributedString.Key: Any]) {
        // Check for font traits
        if let font = attributes[.font] as? UIFont {
            formattingState.isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
            formattingState.isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
        } else {
            // Default state if no font
            formattingState.isBold = false
            formattingState.isItalic = false
        }
        
        // Check for underline
        formattingState.isUnderlined = attributes[.underlineStyle] != nil
        
        // Update text color if present
        if let color = attributes[.foregroundColor] as? UIColor {
            formattingState.textColor = Color(color)
        } else {
            formattingState.textColor = .primary
        }
    }
}
