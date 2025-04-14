import SwiftUI
import SwiftData

struct NoteListView: View {
    var notes: [ScribeNote]
    @Binding var selectedNote: ScribeNote?
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        List(selection: $selectedNote) {
            ForEach(notes) { note in
                NoteRowView(note: note)
                    .tag(note)
            }
            .onDelete(perform: deleteNotes)
        }
        .listStyle(.sidebar)
        .navigationTitle("Notes")
        .scrollContentBackground(.visible)
    }
    
    private func deleteNotes(_ indexSet: IndexSet) {
        for index in indexSet {
            let noteToDelete = notes[index]
            modelContext.delete(noteToDelete)
            
            // If the deleted note was selected, deselect it
            if selectedNote == noteToDelete {
                selectedNote = nil
            }
        }
    }
}

struct NoteRowView: View {
    let note: ScribeNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(note.lastModified, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(note.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

