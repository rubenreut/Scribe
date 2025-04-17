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
    PreviewContainer { container in
        let context = container.mainContext
        let viewModel = NoteViewModel(modelContext: context)
        
        // Create some sample notes
        for i in 1...5 {
            // Create the note
            let note = PreviewHelpers.createSampleNote(
                title: "Sample Note \(i)",
                content: "Content for note \(i)",
                in: context
            )
            
            // Make some notes part of folders
            if i % 2 == 0 {
                if let folder = viewModel.folders.first(where: { $0.name == "Sample Folder" }) {
                    note.folder = folder
                } else {
                    let folder = PreviewHelpers.createSampleFolder(
                        name: "Sample Folder",
                        noteCount: 0,
                        in: context
                    )
                    note.folder = folder
                }
            }
        }
        
        // Force refresh of view model data
        viewModel.refreshNotes()
        viewModel.refreshFolders()
        
        return NoteListView(
            notes: viewModel.notes,
            selectedNote: .constant(viewModel.notes.first),
            onDelete: { _ in },
            viewModel: viewModel
        )
    }
}