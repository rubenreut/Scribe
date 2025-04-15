import SwiftUI
import SwiftData

/// List view showing all notes
struct NoteListView: View {
    var notes: [ScribeNote]
    @Binding var selectedNote: ScribeNote?
    var onDelete: (IndexSet) -> Void
    let viewModel: NoteViewModel
    
    var body: some View {
        List(selection: $selectedNote) {
            ForEach(notes) { note in
                NoteRowView(note: note, viewModel: viewModel)
                    .tag(note)
                    .contextMenu {
                        Button(role: .destructive) {
                            if let index = notes.firstIndex(where: { $0 == note }) {
                                onDelete(IndexSet(integer: index))
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .onDelete(perform: onDelete)
        }
        .listStyle(.sidebar)
        .navigationTitle("Notes")
        .scrollContentBackground(.visible)
        .accessibilityLabel("Notes list")
    }
}

/// Individual row in the notes list
struct NoteRowView: View {
    let note: ScribeNote
    let viewModel: NoteViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title)
                .font(.headline)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            
            Text(note.lastModified, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityLabel("Last edited \(note.lastModified.formatted())")
            
            Text(viewModel.attributedContent(for: note).string)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .accessibilityLabel("Note preview: \(viewModel.attributedContent(for: note).string)")
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    @MainActor func createPreview() -> some View {
        let container = try! ModelContainer(for: ScribeNote.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let modelContext = container.mainContext
        let viewModel = NoteViewModel(modelContext: modelContext)
        
        // Create an attributed string
        let attributedString = NSAttributedString(string: "This is sample content")
        
        // Create sample note with archived attributed string
        let sampleNote = ScribeNote(title: "Sample Note")
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: attributedString, requiringSecureCoding: false) {
            sampleNote.content = data
        }
        modelContext.insert(sampleNote)
        
        return NoteListView(
            notes: [sampleNote],
            selectedNote: .constant(sampleNote),
            onDelete: { _ in },
            viewModel: viewModel
        )
        .modelContainer(container)
    }
    
    return createPreview()
}

