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
    @State private var animateList = false
    
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
                                .font(.system(size: 16, weight: .medium))
                                .frame(width: 28, height: 28)
                                .background(Color(folder.color).opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            VStack(alignment: .leading) {
                                Text(folder.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            Text("\(folder.notes?.count ?? 0)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 6)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showFolderNotes(folder)
                            }
                        }
                        .contextMenu {
                            Button {
                                showDeleteFolderConfirmation(folder)
                            } label: {
                                Label("Delete Folder", systemImage: "trash")
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.folders.count)
                }
            }
            
            // Notes section
            Section(header: Text(viewModel.folders.isEmpty ? "" : "Notes")) {
                ForEach(notes, id: \.self) { note in
                    NoteRowView(note: note, viewModel: viewModel)
                        .tag(note)
                        .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .contextMenu {
                            Button(role: .destructive) {
                                if let index = notes.firstIndex(where: { $0 == note }) {
                                    withAnimation {
                                        onDelete(IndexSet(integer: index))
                                    }
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            if note.folder != nil {
                                Button {
                                    withAnimation {
                                        viewModel.removeNoteFromFolder(note)
                                    }
                                } label: {
                                    Label("Remove from Folder", systemImage: "folder.badge.minus")
                                }
                            } else {
                                // Add folder options for unorganized notes
                                Menu("Add to Folder") {
                                    ForEach(viewModel.folders, id: \.self) { folder in
                                        Button {
                                            withAnimation {
                                                viewModel.assignNote(note, toFolder: folder)
                                            }
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
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .scale(scale: 0.9).combined(with: .opacity)
                        ))
                }
                .onDelete { indexSet in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        onDelete(indexSet)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: notes.count)
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
                            withAnimation {
                                isOrganizing = true
                            }
                            errorMessage = nil
                            let (success, error) = await viewModel.organizeNotesWithAI()
                            
                            withAnimation {
                                isOrganizing = false
                            }
                            
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
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                        .pressAnimation()
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .transition(.slideUp)
        }
        .sheet(isPresented: $showCreateFolder) {
            CreateFolderView(viewModel: viewModel)
                .transition(.slideUp)
        }
        .overlay {
            if isOrganizing {
                FormatProgressView(message: "Organizing notes...")
                    .transition(.opacity)
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.deleteFolder(folder, deleteNotes: false)
                    }
                    folderToDelete = nil
                }
            }
            
            Button("Delete Folder and Notes", role: .destructive) {
                if let folder = folderToDelete {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.deleteFolder(folder, deleteNotes: true)
                    }
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
                    .transition(.slideUp)
            }
        }
        .onAppear {
            // When view appears, animate the list items sequentially
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                animateList = true
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