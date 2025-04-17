import SwiftUI

/// AI formatting extension for RichTextNoteEditorView
extension RichTextNoteEditorView {
    /// AI formatting button for the toolbar
    var formatWithAIButton: some View {
        Button {
            if let note = selectedNote {
                formatWithAI(note: note)
            }
        } label: {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 34, height: 34)
                .background(Color.secondary.opacity(0.1))
                .clipShape(Circle())
        }
        .disabled(isFormatting || selectedNote == nil)
    }
    
    // Error handling is done in the main view
    
    /// Apply AI formatting to the current note
    func formatWithAI(note: ScribeNote) {
        guard !isFormatting else { return }
        
        isFormatting = true
        errorMessage = nil
        
        // Get current note content
        let currentContent = attributedText.string
        
        Task {
            let (success, error) = await viewModel.formatNoteWithAI(note)
            
            // Update UI on the main thread
            await MainActor.run {
                isFormatting = false
                
                if success {
                    // If successful, update the view with the new content
                    attributedText = viewModel.attributedContent(for: note)
                } else if let errorMsg = error {
                    // Show error message
                    errorMessage = errorMsg
                    showError = true
                }
            }
        }
    }
    
    /// Enhanced toolbar with AI formatting button
    var enhancedToolbar: some View {
        HStack(spacing: 16) {
            Spacer()
            
            // Format menu (typography)
            FormatMenu(formattingState: formattingState) { action in
                if let note = selectedNote {
                    handleFormatAction(action, for: note)
                }
            }
            
            // AI formatting button
            formatWithAIButton
            
            // Attachment menu (files, images)
            AttachmentMenu(
                showImagePicker: $showImagePicker,
                showDocumentPicker: $showDocumentPicker
            )
            
            // Share button
            ShareLink(item: selectedNote != nil ? noteContentForSharing() : "") {

                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            Color(UIColor.secondarySystemBackground)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: -1)
        )
    }
    
    /// Formatting progress overlay
    var formattingOverlay: some View {
        Group {
            if isFormatting {
                FormatProgressView(message: "Formatting note...")
            }
        }
        .alert("Formatting Error", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK") { showError = false }
        } message: { error in
            Text(error)
        }
    }
}