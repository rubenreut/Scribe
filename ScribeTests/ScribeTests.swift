//
//  ScribeTests.swift
//  ScribeTests
//
//  Created by Ruben Reut on 14/04/2025.
//

import Testing
import SwiftData
@testable import Scribe

struct ScribeTests {
    @Test func testCreateNote() async throws {
        // Create test environment
        let (_, viewModel) = try TestHelpers.createTestEnvironment()
        
        // Initial note count should be 0
        #expect(viewModel.notes.count == 0, "Should start with no notes")
        
        // Create a new note
        viewModel.createNewNote()
        
        // Verify note was created and selected
        #expect(viewModel.notes.count == 1, "Should have one note after creation")
        #expect(viewModel.selectedNote != nil, "A note should be selected")
        #expect(viewModel.selectedNote?.title == "New Note", "Default title should be set")
        #expect(viewModel.selectedNote?.content == "", "Content should start empty")
    }
    
    @Test func testUpdateNoteContent() async throws {
        // Create test environment
        let (_, viewModel) = try TestHelpers.createTestEnvironment()
        
        // Create a note
        viewModel.createNewNote()
        let note = viewModel.selectedNote!
        
        // Update content
        let newContent = "Test content"
        viewModel.updateNoteContent(note, newContent: newContent)
        
        // Verify content was updated
        #expect(note.content == newContent, "Content should be updated")
    }
    
    @Test func testDeleteNote() async throws {
        // Create test environment
        let (_, viewModel) = try TestHelpers.createTestEnvironment()
        
        // Create a note
        viewModel.createNewNote()
        
        // Verify we have a note
        #expect(viewModel.notes.count == 1, "Should have one note")
        
        // Delete the note
        viewModel.deleteNotes(at: IndexSet(integer: 0))
        
        // Verify note was deleted
        #expect(viewModel.notes.count == 0, "Should have no notes after deletion")
        #expect(viewModel.selectedNote == nil, "No note should be selected after deletion")
    }
    
    @Test func testFilterNotes() async throws {
        // Create test environment with sample data
        let (_, viewModel) = try TestHelpers.createTestEnvironment(withSampleData: true)
        
        // Test with no filter
        #expect(viewModel.filteredNotes.count == 2, "Should show all notes with no filter")
        
        // Test with filter matching title
        viewModel.searchText = "Shopping"
        #expect(viewModel.filteredNotes.count == 1, "Should filter by title")
        #expect(viewModel.filteredNotes.first?.title == "Shopping")
        
        // Test with filter matching content
        viewModel.searchText = "milk"
        #expect(viewModel.filteredNotes.count == 1, "Should filter by content")
        #expect(viewModel.filteredNotes.first?.content == "Buy milk")
        
        // Test with no matches
        viewModel.searchText = "nonexistent"
        #expect(viewModel.filteredNotes.count == 0, "Should return empty array for no matches")
    }
}
