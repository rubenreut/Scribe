//
//  ContentView.swift
//  Scribe
//
//  Created by Ruben Reut on 14/04/2025.
//

import SwiftUI
import SwiftData
import Foundation
import UIKit

/// Main content view showing split navigation between note list and editor
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: NoteViewModel
    @AppStorage("useRichText") private var useRichText: Bool = true
    
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
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            useRichText.toggle()
                        } label: {
                            Label(
                                useRichText ? "Plain Text" : "Rich Text", 
                                systemImage: useRichText ? "doc.plaintext" : "textformat"
                            )
                        }
                        .accessibilityLabel("Toggle Rich Text Editing")
                    }
                }
            }
        } detail: {
            // Conditionally show either rich text or plain text editor
            ZStack {
                if useRichText {
                    RichTextNoteEditorView(note: $viewModel.selectedNote, viewModel: viewModel)
                        .transition(.opacity)
                } else {
                    NoteEditorView(note: $viewModel.selectedNote, viewModel: viewModel)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: useRichText)
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            // Replace the temporary context with the real one
            viewModel = NoteViewModel(modelContext: modelContext)
            
            // Refresh notes on appear to ensure we have the latest data
            viewModel.refreshNotes()
            
            // Set up a timer to periodically refresh notes
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                viewModel.refreshNotes()
            }
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
