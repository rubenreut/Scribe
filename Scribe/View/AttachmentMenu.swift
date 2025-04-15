import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

/// A menu for attaching different types of content to notes
struct AttachmentMenu: View {
    @Binding var showImagePicker: Bool
    @Binding var showDocumentPicker: Bool
    
    var body: some View {
        Menu {
            Button(action: { showImagePicker = true }) {
                Label("Photo", systemImage: "photo")
            }
            
            Button(action: { showDocumentPicker = true }) {
                Label("Document", systemImage: "doc")
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
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Circle())
        }
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