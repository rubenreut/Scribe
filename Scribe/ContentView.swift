//
//  ContentView.swift
//  Scribe
//
//  Created by Ruben Reut on 14/04/2025.
//

import SwiftUI
import SwiftData
import Foundation

/// Main content view showing split navigation between note list and editor
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: NoteViewModel
    // Always use rich text - remove toggle functionality
    private let useRichText: Bool = true
    
    init() {
        // Initialize with an empty container that will be replaced when Environment is available
        do {
            // Use in-memory only container for initial setup
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: ScribeNote.self, ScribeFolder.self, configurations: config)
            _viewModel = State(initialValue: NoteViewModel(modelContext: ModelContext(container)))
        } catch {
            // This should not happen but provide a fallback
            print("Warning: Using temporary container for initialization: \(error.localizedDescription)")
            
            // Create an empty model context if everything fails (will be replaced on appear)
            let descriptor = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: ScribeNote.self, ScribeFolder.self, configurations: descriptor)
            _viewModel = State(initialValue: NoteViewModel(modelContext: ModelContext(container)))
        }
    }
    
    var body: some View {
        NavigationSplitView {
            VStack {
                NoteListView(
                    notes: viewModel.filteredNotes,
                    selectedNote: $viewModel.selectedNote,
                    onDelete: viewModel.deleteNotes,
                    viewModel: viewModel
                )
                .searchable(text: $viewModel.searchText, prompt: "Search notes...")
                .navigationTitle("Notes")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: viewModel.createNewNote) {
                            Label("New Note", systemImage: "square.and.pencil")
                                .accessibilityLabel("Create a new note")
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        CloudSyncStatusView(status: viewModel.syncStatus)
                    }
                    
                    // Rich text toggle button removed - always using rich text editor
                }
                
                // Show iCloud status at the bottom of the list
                if case .error(let message) = viewModel.syncStatus {
                    VStack {
                        Text("iCloud Sync Error")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text(message)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                }
            }
        } detail: {
            // Only show the rich text editor
            RichTextNoteEditorView(selectedNote: $viewModel.selectedNote, viewModel: viewModel)
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            // Replace the temporary context with the real one
            viewModel = NoteViewModel(modelContext: modelContext)
            
            // Refresh notes on appear to ensure we have the latest data
            viewModel.refreshNotes()
        }
        .onReceive(NotificationCenter.default.publisher(for: Constants.NotificationNames.createNewNote)) { _ in
            viewModel.createNewNote()
        }
    }
}

#Preview {
    @MainActor func createPreview() -> some View {
        let container = try! ModelContainer(for: ScribeNote.self, ScribeFolder.self, 
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        
        // Add a sample note for the preview
        let context = ModelContext(container)
        let sampleNote = ScribeNote(title: "Sample Note")
        
        // Create a basic attributed string
        let sampleText = NSAttributedString(string: "This is sample content for the preview")
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: sampleText, requiringSecureCoding: true) {
            sampleNote.content = data
        }
        
        context.insert(sampleNote)
        
        return ContentView()
            .modelContainer(container)
    }
    
    return createPreview()
}
