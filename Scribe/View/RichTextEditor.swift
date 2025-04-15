import SwiftUI
import UIKit
import Combine

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
        context.coordinator.textView = textView
        
        // Store reference in the shared holder
        DispatchQueue.main.async {
            RichTextViewHolder.shared.textView = textView
        }
        
        return textView
    }
    
    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.attributedText != attributedText {
            // Only update if the text has changed to avoid cursor jumping
            textView.attributedText = attributedText
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
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            let currentFont = mutableAttrText.attribute(.font, at: selectedRange.location, effectiveRange: nil) as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
            
            let newFont: UIFont
            if isBold {
                newFont = UIFont.boldSystemFont(ofSize: currentFont.pointSize)
            } else {
                newFont = UIFont.systemFont(ofSize: currentFont.pointSize)
            }
            
            mutableAttrText.addAttribute(.font, value: newFont, range: selectedRange)
            attributedText = mutableAttrText
            textView.attributedText = mutableAttrText
            textView.selectedRange = selectedRange
        }
    }
    
    // Apply italic formatting
    private func toggleItalic() {
        isItalic.toggle()
        
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            let currentFont = mutableAttrText.attribute(.font, at: selectedRange.location, effectiveRange: nil) as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
            
            let newFont: UIFont
            if isItalic {
                newFont = UIFont.italicSystemFont(ofSize: currentFont.pointSize)
            } else {
                newFont = UIFont.systemFont(ofSize: currentFont.pointSize)
            }
            
            mutableAttrText.addAttribute(.font, value: newFont, range: selectedRange)
            attributedText = mutableAttrText
            textView.attributedText = mutableAttrText
            textView.selectedRange = selectedRange
        }
    }
    
    // Apply underline formatting
    private func toggleUnderline() {
        isUnderlined.toggle()
        
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            
            if isUnderlined {
                mutableAttrText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
            } else {
                mutableAttrText.removeAttribute(.underlineStyle, range: selectedRange)
            }
            
            attributedText = mutableAttrText
            textView.attributedText = mutableAttrText
            textView.selectedRange = selectedRange
        }
    }
    
    // Apply text color
    private func applyTextColor() {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            let uiColor = UIColor(textColor)
            
            mutableAttrText.addAttribute(.foregroundColor, value: uiColor, range: selectedRange)
            attributedText = mutableAttrText
            textView.attributedText = mutableAttrText
            textView.selectedRange = selectedRange
        }
    }
    
    // Apply heading format
    private func applyHeading(_ style: Font.TextStyle) {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            
            let fontSize: CGFloat
            switch style {
            case .title: fontSize = 24
            case .headline: fontSize = 18
            default: fontSize = 16
            }
            
            let newFont = UIFont.systemFont(ofSize: fontSize, weight: style == .body ? .regular : .bold)
            
            mutableAttrText.addAttribute(.font, value: newFont, range: selectedRange)
            attributedText = mutableAttrText
            textView.attributedText = mutableAttrText
            textView.selectedRange = selectedRange
        }
    }
    
    // Apply bullet points
    private func applyBulletPoints() {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            let fullText = mutableAttrText.string
            let selectedText = fullText.substring(with: Range(selectedRange, in: fullText)!)
            
            // Split by new lines and add bullets
            let lines = selectedText.split(separator: "\n")
            var bulletedText = ""
            
            for line in lines {
                if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    bulletedText += "• " + line + "\n"
                } else {
                    bulletedText += line + "\n"
                }
            }
            
            // If there's a trailing newline in selectedText, remove it from bulletedText
            if selectedText.hasSuffix("\n") && bulletedText.hasSuffix("\n\n") {
                bulletedText.removeLast()
            }
            
            let bulletedAttrString = NSAttributedString(string: bulletedText)
            mutableAttrText.replaceCharacters(in: selectedRange, with: bulletedAttrString)
            
            attributedText = mutableAttrText
            textView.attributedText = mutableAttrText
            textView.selectedRange = NSRange(location: selectedRange.location, length: bulletedText.count)
        }
    }
    
    // Clear all formatting
    private func clearFormatting() {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            let mutableAttrText = NSMutableAttributedString(attributedString: attributedText)
            let plainText = mutableAttrText.string.substring(with: Range(selectedRange, in: mutableAttrText.string)!)
            let plainAttrString = NSAttributedString(string: plainText)
            
            mutableAttrText.replaceCharacters(in: selectedRange, with: plainAttrString)
            
            attributedText = mutableAttrText
            textView.attributedText = mutableAttrText
            textView.selectedRange = NSRange(location: selectedRange.location, length: plainText.count)
        }
    }
}

/// Utility for creating default attributed strings
struct AttributedStringHelper {
    /// Creates a new attributed string with default attributes
    static func createDefaultString(_ text: String = "") -> NSAttributedString {
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body)
        ]
        return NSAttributedString(string: text, attributes: defaultAttributes)
    }
}
