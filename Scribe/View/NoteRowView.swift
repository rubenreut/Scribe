import SwiftUI

/// A modern card-style note row view
struct NoteRowView: View {
    let note: ScribeNote
    let viewModel: NoteViewModel
    @State private var showFolderIndicator = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Note icon with color based on folder or default accent color
            ZStack {
                Circle()
                    .fill(note.folder != nil ? Color(note.folder!.color).opacity(0.15) : Color.accentColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                
                Image(systemName: note.folder != nil ? "doc.on.doc" : "doc.text")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(note.folder != nil ? Color(note.folder!.color) : .accentColor)
            }
            
            // Note content
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(note.title)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .animation(.easeInOut, value: note.title)
                    .accessibilityAddTraits(.isHeader)
                
                // Preview text
                if !note.title.isEmpty {
                    Text(String(viewModel.attributedContent(for: note).string.prefix(50))
                        .trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.top, 1)
                        .accessibilityLabel("Note preview: \(viewModel.attributedContent(for: note).string)")
                }
                
                // Creation date
                Text("Created \(note.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
                    .padding(.top, 1)
                    .accessibilityLabel("Created on \(note.createdAt.formatted())")
            }
            
            Spacer()
            
            // Folder badge (if in folder)
            if note.folder != nil {
                VStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 10, weight: .medium))
                        
                        Text(note.folder?.name ?? "")
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundColor(Color(note.folder!.color))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(note.folder!.color).opacity(0.12))
                    .clipShape(Capsule())
                    .opacity(showFolderIndicator ? 1.0 : 0.0)
                    .offset(y: showFolderIndicator ? 0 : 5)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.3).delay(0.1)) {
                            showFolderIndicator = true
                        }
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .animation(.default, value: note.title)
        .contentShape(Rectangle())
    }
}

#Preview {
    PreviewContainer { container in
        let context = container.mainContext
        let viewModel = NoteViewModel(modelContext: context)
        
        // Create a sample note
        let note = PreviewHelpers.createSampleNote(
            title: "Meeting Notes",
            content: "Important topics to discuss in the team meeting",
            in: context
        )
        
        return NoteRowView(note: note, viewModel: viewModel)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}