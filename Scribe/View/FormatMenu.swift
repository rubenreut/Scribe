import SwiftUI

/// A modern formatting menu for the rich text editor
struct FormatMenu: View {
    @ObservedObject var formattingState: FormattingState
    let onFormat: (FormatAction) -> Void
    @State private var isPressing = false
    
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
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onFormat(.bold)
                    }
                }) {
                    Label("Bold", systemImage: "bold")
                        .symbolEffect(.bounce, options: .speed(1.5), value: formattingState.isBold)
                }
                .foregroundColor(formattingState.isBold ? .accentColor : nil)
                
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onFormat(.italic)
                    }
                }) {
                    Label("Italic", systemImage: "italic")
                        .symbolEffect(.bounce, options: .speed(1.5), value: formattingState.isItalic)
                }
                .foregroundColor(formattingState.isItalic ? .accentColor : nil)
                
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onFormat(.underline)
                    }
                }) {
                    Label("Underline", systemImage: "underline")
                        .symbolEffect(.bounce, options: .speed(1.5), value: formattingState.isUnderlined)
                }
                .foregroundColor(formattingState.isUnderlined ? .accentColor : nil)
            }
            
            // Headings section
            Section {
                Button(action: { 
                    withAnimation {
                        onFormat(.heading(.title))
                    }
                }) {
                    Label("Heading", systemImage: "textformat.size.larger")
                }
                
                Button(action: { 
                    withAnimation {
                        onFormat(.heading(.headline))
                    }
                }) {
                    Label("Subheading", systemImage: "textformat.size")
                }
                
                Button(action: { 
                    withAnimation {
                        onFormat(.heading(.body))
                    }
                }) {
                    Label("Body Text", systemImage: "text.justify")
                }
            }
            
            // Other formatting section
            Section {
                Button(action: { 
                    withAnimation {
                        onFormat(.textColor)
                    }
                }) {
                    Label("Text Color", systemImage: "paintpalette")
                }
                
                Button(action: { 
                    withAnimation {
                        onFormat(.bulletList)
                    }
                }) {
                    Label("Bullet List", systemImage: "list.bullet")
                }
                
                Button(action: { 
                    withAnimation {
                        onFormat(.clearFormatting)
                    }
                }) {
                    Label("Clear Formatting", systemImage: "eraser")
                }
            }
        } label: {
            Image(systemName: "textformat")
                .toolbarButtonStyle()
                .overlay(
                    Circle()
                        .stroke(formattingState.isBold || formattingState.isItalic || formattingState.isUnderlined ? 
                                Color.accentColor.opacity(0.3) : Color.clear, 
                                lineWidth: 2)
                        .padding(-4)
                )
                .scaleEffect(isPressing ? 0.92 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressing)
                .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 10) {
                    // Action at the end of gesture
                } onPressingChanged: { pressing in
                    isPressing = pressing
                }
        }
        .buttonStyle(PressButtonStyle())
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