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
                        ForEach(folderNotes, id: \.self) { note in
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
                let binding = Binding<ScribeNote?>(
                    get: { note },
                    set: { _ in }
                )
                RichTextNoteEditorView(selectedNote: binding, viewModel: viewModel)
            }
        }
    }
    
    // Computed property for notes in this folder
    private var folderNotes: [ScribeNote] {
        viewModel.notesInFolder(folder)
    }
    
    // Refresh function to update the view when notes change
    private func refreshNotes() {
        
        viewModel.refreshNotes()
    }
}

// No need for a custom Identifiable implementation since we're using \.self for identification

#Preview {
    PreviewContainer { container in
        let context = container.mainContext
        let viewModel = NoteViewModel(modelContext: context)
        
        // Create a sample folder with notes
        let folder = PreviewHelpers.createSampleFolder(
            name: "Sample Folder",
            noteCount: 3,
            in: context
        )
        
        // Force a refresh of view model data
        viewModel.refreshNotes()
        viewModel.refreshFolders()
        
        return FolderNotesView(folder: folder, viewModel: viewModel)
    }
}