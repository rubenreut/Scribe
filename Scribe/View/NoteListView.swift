import SwiftUI
import SwiftData

/// List view showing all notes
struct NoteListView: View {
    var notes: [ScribeNote]
    @Binding var selectedNote: ScribeNote?
    var onDelete: (IndexSet) -> Void
    let viewModel: NoteViewModel
    
    @State private var showSettings = false
    @State private var showCreateFolder = false
    @State private var isOrganizing = false
    @State private var errorMessage: String? = nil
    @State private var showError = false
    
    // Folder management states
    @State private var selectedFolder: ScribeFolder? = nil
    @State private var showingFolderNotes = false
    @State private var folderToDelete: ScribeFolder? = nil
    @State private var showDeleteConfirmation = false
    @State private var deleteNotesWithFolder = false
    
    var body: some View {
        List(selection: $selectedNote) {
            // Folders section (if any)
            if !viewModel.folders.isEmpty {
                Section("Folders") {
                    ForEach(viewModel.folders, id: \.self) { folder in
                        HStack {
                            Image(systemName: folder.icon)
                                .foregroundColor(Color(folder.color))
                            Text(folder.name)
                            Spacer()
                            Text("\(folder.notes?.count ?? 0)")
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showFolderNotes(folder)
                        }
                        .contextMenu {
                            Button {
                                showDeleteFolderConfirmation(folder)
                            } label: {
                                Label("Delete Folder", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            
            // Notes section
            Section(header: Text(viewModel.folders.isEmpty ? "" : "Notes")) {
                ForEach(notes, id: \.self) { note in
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
                            
                            if note.folder != nil {
                                Button {
                                    viewModel.removeNoteFromFolder(note)
                                } label: {
                                    Label("Remove from Folder", systemImage: "folder.badge.minus")
                                }
                            } else {
                                // Add folder options for unorganized notes
                                Menu("Add to Folder") {
                                    ForEach(viewModel.folders, id: \.self) { folder in
                                        Button {
                                            viewModel.assignNote(note, toFolder: folder)
                                        } label: {
                                            Label(folder.name, systemImage: folder.icon)
                                        }
                                    }
                                    
                                    Button {
                                        showCreateFolder = true
                                    } label: {
                                        Label("New Folder...", systemImage: "folder.badge.plus")
                                    }
                                }
                            }
                        }
                }
                .onDelete(perform: onDelete)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Notes")
        .scrollContentBackground(.visible)
        .accessibilityLabel("Notes list")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        Task {
                            isOrganizing = true
                            errorMessage = nil
                            let (success, error) = await viewModel.organizeNotesWithAI()
                            isOrganizing = false
                            
                            if !success, let errorMsg = error {
                                errorMessage = errorMsg
                                showError = true
                            }
                        }
                    } label: {
                        Label("Organize with AI", systemImage: "folder.badge.gearshape")
                    }
                    
                    Button {
                        showCreateFolder = true
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                    
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            
            ToolbarItem(placement: .navigationBarLeading) {
                // Button removed as requested
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showCreateFolder) {
            CreateFolderView(viewModel: viewModel)
        }
        .overlay {
            if isOrganizing {
                FormatProgressView(message: "Organizing notes...")
            }
        }
        .alert("Organization Error", isPresented: $showError, presenting: errorMessage) { _ in
            Button("OK") { showError = false }
        } message: { error in
            Text(error)
        }
        .alert("Delete Folder", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                folderToDelete = nil
            }
            
            Button("Delete Only Folder", role: .destructive) {
                if let folder = folderToDelete {
                    viewModel.deleteFolder(folder, deleteNotes: false)
                    folderToDelete = nil
                }
            }
            
            Button("Delete Folder and Notes", role: .destructive) {
                if let folder = folderToDelete {
                    viewModel.deleteFolder(folder, deleteNotes: true)
                    folderToDelete = nil
                }
            }
        } message: {
            Text("Do you want to delete the folder '\(folderToDelete?.name ?? "")' and its notes, or just the folder?")
        }
        .sheet(isPresented: $showingFolderNotes, onDismiss: {
            selectedFolder = nil
        }) {
            if let folder = selectedFolder {
                FolderNotesView(folder: folder, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Folder Actions

extension NoteListView {
    /// Shows the notes that are in a specific folder
    private func showFolderNotes(_ folder: ScribeFolder) {
        selectedFolder = folder
        showingFolderNotes = true
    }
    
    /// Shows the confirmation dialog for deleting a folder
    private func showDeleteFolderConfirmation(_ folder: ScribeFolder) {
        folderToDelete = folder
        showDeleteConfirmation = true
    }
}

struct NoteRowView: View {
    let note: ScribeNote
    let viewModel: NoteViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                
                if note.folder != nil {
                    Spacer()
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
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
        let container = try! ModelContainer(for: ScribeNote.self, ScribeFolder.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let modelContext = container.mainContext
        let viewModel = NoteViewModel(modelContext: modelContext)
        
        // Create an attributed string
        let attributedString = NSAttributedString(string: "This is sample content")
        
        // Create sample note with archived attributed string
        let sampleNote = ScribeNote(title: "Sample Note")
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: attributedString, requiringSecureCoding: true) {
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