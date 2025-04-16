import SwiftUI
import SwiftData

struct FolderNotesView: View {
    let folder: ScribeFolder
    let viewModel: NoteViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedNote: ScribeNote? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                if folderNotes.isEmpty {
                    ContentUnavailableView {
                        Label("No Notes", systemImage: "doc.text")
                    } description: {
                        Text("This folder doesn't contain any notes yet.")
                    }
                } else {
                    List(selection: $selectedNote) {
                        ForEach(folderNotes, id: \.persistentModelID) { note in
                            NoteRowView(note: note, viewModel: viewModel)
                                .tag(note)
                                .contextMenu {
                                    Button {
                                        viewModel.removeNoteFromFolder(note)
                                        // Refresh view to update list
                                        refreshNotes()
                                    } label: {
                                        Label("Remove from Folder", systemImage: "folder.badge.minus")
                                    }
                                }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle(folder.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedNote) { note in
                RichTextNoteEditorView(selectedNote: .constant(note), viewModel: viewModel)
            }
        }
    }
    
    // Computed property for notes in this folder
    private var folderNotes: [ScribeNote] {
        viewModel.notesInFolder(folder)
    }
    
    // Refresh function to update the view when notes change
    private func refreshNotes() {
        // Force view refresh
        viewModel.refreshNotes()
    }
}

// We don't need a custom Identifiable implementation 
// since we're using persistentModelID directly in ForEach

#Preview {
    @MainActor func createPreview() -> some View {
        // Use the SwiftData preview container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: ScribeNote.self, ScribeFolder.self, configurations: config)
        let modelContext = container.mainContext
        let viewModel = NoteViewModel(modelContext: modelContext)
        
        // Create a folder and some notes
        let folder = ScribeFolder(name: "Sample Folder")
        modelContext.insert(folder)
        
        // Create notes with archived attributed strings
        let attributedString = NSAttributedString(string: "This is sample content")
        
        for i in 1...3 {
            let note = ScribeNote(title: "Sample Note \(i)")
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: attributedString, requiringSecureCoding: true) {
                note.content = data
            }
            note.folder = folder
            modelContext.insert(note)
        }
        
        return FolderNotesView(folder: folder, viewModel: viewModel)
            .modelContainer(container)
    }
    
    return createPreview()
}