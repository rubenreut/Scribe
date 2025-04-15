import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct DocumentPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var completion: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Allow all document types
        let supportedTypes: [UTType] = [.pdf, .plainText, .image, .audio, .movie, .spreadsheet, .presentation]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing the security-scoped resource
            let gotAccess = url.startAccessingSecurityScopedResource()
            
            if gotAccess {
                parent.completion(url)
                // Make sure you release the security-scoped resource when finished
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}