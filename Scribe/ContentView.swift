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
        // This will be properly initialized when the @Environment is available
        do {
            let container = try ModelContainer(for: ScribeNote.self)
            _viewModel = State(initialValue: NoteViewModel(modelContext: ModelContext(container)))
        } catch {
            fatalError("Failed to create model container: \(error.localizedDescription)")
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
                    
                    // Rich text toggle button removed - always using rich text editor
                }
            }
        } detail: {
            // Only show the rich text editor
            RichTextNoteEditorView(note: $viewModel.selectedNote, viewModel: viewModel)
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
        let container = try! ModelContainer(for: ScribeNote.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        
        return ContentView()
            .modelContainer(container)
    }
    
    return createPreview()
}
