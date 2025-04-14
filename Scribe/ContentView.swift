//
//  ContentView.swift
//  Scribe
//
//  Created by Ruben Reut on 14/04/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedNote: ScribeNote?
    @State private var searchText = ""
    
    // Use a standard Query to fetch all notes sorted by lastModified
    @Query(sort: \ScribeNote.lastModified, order: .reverse) private var allNotes: [ScribeNote]
    
    // Filter notes in-memory instead of using a predicate
    var filteredNotes: [ScribeNote] {
        if searchText.isEmpty {
            return allNotes
        } else {
            return allNotes.filter { note in
                note.title.localizedStandardContains(searchText) ||
                note.content.localizedStandardContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            VStack {
                NoteListView(notes: filteredNotes, selectedNote: $selectedNote)
                    .searchable(text: $searchText, prompt: "Search notes...")
                    .navigationTitle("Notes")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: createNewNote) {
                                Label("New Note", systemImage: "square.and.pencil")
                            }
                        }
                    }
            }
        } detail: {
            NoteEditorView(note: $selectedNote)
                .environment(\.modelContext, modelContext)
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    private func createNewNote() {
        let newNote = ScribeNote()
        modelContext.insert(newNote)
        selectedNote = newNote
    }
}

#Preview {
    let container = try! ModelContainer(for: ScribeNote.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    
    // Add sample data
    let note1 = ScribeNote(title: "Meeting Notes", content: "Discuss project timeline and milestones", createdAt: Date().addingTimeInterval(-86400), lastModified: Date().addingTimeInterval(-3600))
    let note2 = ScribeNote(title: "Shopping List", content: "Milk\nEggs\nBread", createdAt: Date().addingTimeInterval(-172800), lastModified: Date().addingTimeInterval(-7200))
    container.mainContext.insert(note1)
    container.mainContext.insert(note2)
    
    return ContentView()
        .modelContainer(container)
}
