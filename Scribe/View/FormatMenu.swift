import SwiftUI

/// A modern formatting menu for the rich text editor
struct FormatMenu: View {
    @ObservedObject var formattingState: FormattingState
    let onFormat: (FormatAction) -> Void
    
    // Available formatting actions
    enum FormatAction {
        case bold
        case italic
        case underline
        case heading(Font.TextStyle)
        case textColor
        case bulletList
        case clearFormatting
    }
    
    var body: some View {
        Menu {
            // Text style section
            Section {
                Button(action: { onFormat(.bold) }) {
                    Label("Bold", systemImage: "bold")
                }
                .foregroundColor(formattingState.isBold ? .accentColor : nil)
                
                Button(action: { onFormat(.italic) }) {
                    Label("Italic", systemImage: "italic")
                }
                .foregroundColor(formattingState.isItalic ? .accentColor : nil)
                
                Button(action: { onFormat(.underline) }) {
                    Label("Underline", systemImage: "underline")
                }
                .foregroundColor(formattingState.isUnderlined ? .accentColor : nil)
            }
            
            // Headings section
            Section {
                Button(action: { onFormat(.heading(.title)) }) {
                    Label("Heading", systemImage: "textformat.size.larger")
                }
                
                Button(action: { onFormat(.heading(.headline)) }) {
                    Label("Subheading", systemImage: "textformat.size")
                }
                
                Button(action: { onFormat(.heading(.body)) }) {
                    Label("Body Text", systemImage: "text.justify")
                }
            }
            
            // Other formatting section
            Section {
                Button(action: { onFormat(.textColor) }) {
                    Label("Text Color", systemImage: "paintpalette")
                }
                
                Button(action: { onFormat(.bulletList) }) {
                    Label("Bullet List", systemImage: "list.bullet")
                }
                
                Button(action: { onFormat(.clearFormatting) }) {
                    Label("Clear Formatting", systemImage: "eraser")
                }
            }
        } label: {
            Image(systemName: "textformat")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Circle())
        }
    }
}

// Preview provider for design-time preview
struct FormatMenu_Previews: PreviewProvider {
    static var previews: some View {
        FormatMenu(
            formattingState: FormattingState(),
            onFormat: { _ in }
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}