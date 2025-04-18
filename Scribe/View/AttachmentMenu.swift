import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

/// A menu for attaching different types of content to notes
struct AttachmentMenu: View {
    @Binding var showImagePicker: Bool
    @Binding var showDocumentPicker: Bool
    @State private var isHovered = false
    @State private var isPressing = false
    
    var body: some View {
        Menu {
            Button(action: { 
                withAnimation {
                    showImagePicker = true 
                }
            }) {
                Label("Photo", systemImage: "photo")
                    .symbolEffect(.pulse, options: .speed(1.5), value: showImagePicker)
            }
            
            Button(action: { 
                withAnimation {
                    showDocumentPicker = true 
                }
            }) {
                Label("Document", systemImage: "doc")
                    .symbolEffect(.pulse, options: .speed(1.5), value: showDocumentPicker)
            }
            
            // Camera option - would require camera permission handling
            Button(action: { /* Camera handling would go here */ }) {
                Label("Camera", systemImage: "camera")
            }
            
            // Scan document option
            Button(action: { /* Document scanning would go here */ }) {
                Label("Scan Document", systemImage: "doc.viewfinder")
            }
        } label: {
            Image(systemName: "paperclip")
                .toolbarButtonStyle()
                .overlay(
                    Circle()
                        .trim(from: 0, to: isHovered ? 1 : 0)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
                        .padding(-4)
                        .animation(.easeInOut(duration: 0.3), value: isHovered)
                )
                .scaleEffect(isPressing ? 0.92 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressing)
                .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 10) {
                    // Action at end of gesture
                } onPressingChanged: { pressing in
                    isPressing = pressing
                }
                .onHover { hovering in
                    withAnimation {
                        isHovered = hovering
                    }
                }
        }
        .buttonStyle(PressButtonStyle())
    }
}

// Preview provider for design-time preview
struct AttachmentMenu_Previews: PreviewProvider {
    static var previews: some View {
        AttachmentMenu(
            showImagePicker: .constant(false),
            showDocumentPicker: .constant(false)
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}