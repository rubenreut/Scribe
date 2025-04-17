# Scribe Refactoring & Optimization Plan

This document provides a step-by-step guide for refactoring, cleaning up, and optimizing the Scribe codebase.

## Table of Contents
1. [Completed Refactorings](#completed-refactorings)
2. [Pending Refactorings](#pending-refactorings)
3. [Code Cleanup Tasks](#code-cleanup-tasks)
4. [Performance Optimizations](#performance-optimizations)
5. [Next Steps](#next-steps)

## 1. Completed Refactorings

### Major Architectural Improvements

#### FormattingEngine Extraction ✅
- Created a standalone `FormattingEngine` class in `/Services/FormattingEngine.swift` 
- Extracted all rich text formatting methods from `RichTextEditor` and `RichTextToolbar`
- Methods now have a consistent API that returns a modified `NSAttributedString` when text is selected
- Simplified the `RichTextEditor` and `RichTextNoteEditorView` implementations
- Improved code organization by keeping formatting logic in one place

#### iCloud Sync Manager ✅
- Created a dedicated `SyncManager` class in `/Services/SyncManager.swift`
- Moved all iCloud sync code from `NoteViewModel` to the new class
- Added a notification system to propagate sync status changes
- Clarified responsibilities: `SyncManager` handles iCloud operations, `NoteViewModel` handles note operations
- Reduced size and complexity of `NoteViewModel`

#### AIService Refactoring ✅
- Broke up long methods in `AIService` into smaller, more focused helpers
- Extracted JSON parsing logic into reusable helpers
- Added better error handling and logging
- Improved code readability with clear separation of API, parsing, and helper methods

#### Error Handling Framework ✅
- Created a comprehensive error handling system with `AppError` and `ErrorHandler`
- Added domain-specific error types with localized descriptions and recovery suggestions
- Implemented utilities for error transformation and safe execution of operations
- Added support for underlying errors and structured error logging
- Added testing for error handling components

### Code Quality Improvements

#### Preview Helpers ✅
- Created standardized `PreviewHelpers` for SwiftUI previews
- Implemented `PreviewContainer` wrapper for declarative preview creation
- Added reusable sample data generation functions
- Removed force-unwraps and improved error handling in previews
- Made preview code consistent across all views

#### Improved Logging ✅
- Replaced all debug print statements with proper logging via `OSLog`
- Used appropriate log levels for different message types (debug, info, error)
- Centralized app identifier in Constants for consistent logging

#### Enhanced Constants Usage ✅
- Improved type-safety for notification names with `AppNotification` enum
- Created `Constants.App` namespace for app-wide identifiers
- Made notification names more consistent with backward compatibility

#### Fixed Sharing Functionality ✅
- Replaced stub share button with proper `ShareLink` SwiftUI component
- Added helper function for formatting note content for sharing
- Fixed missing UI implementation for share functionality

#### Unit Tests ✅
- Added `FormattingEngineTests` to verify formatting functionality
- Added `SyncManagerTests` to verify sync notifications
- Added `ErrorHandlingTests` to verify error handling system
- Structured tests to cover main components of new functionality

#### Fixed Compilation Issues ✅
- Created a separate `RichTextViewHolder` class file to fix scope issues
- Changed `noteContentForSharing()` from private to internal to fix access from extensions
- Fixed binding issue in `FolderNotesView` sheet presentation
- Ensured all components properly communicate with each other

## 2. Pending Refactorings

### High Priority

#### ContentView Simplification
- Extract the split navigation view setup into a smaller component
- Move preview data creation to separate extension or helper
- Reduce redundant code in fallback container creation

#### NoteViewModel Split
- Further separate note management from folder management
- Create a dedicated FolderViewModel or move folder operations to a service class

### Medium Priority

#### ViewExtensions Expansion
- Create more helper view modifiers for common styling patterns
- Add extensions for previews to simplify preview creation

#### RichTextNoteEditorView Refactoring
- Extract toolbar buttons into smaller, reusable components
- Create dedicated formatters for different text operations

## 3. Code Cleanup Tasks

- [ ] Delete unused imports across the application
- [ ] Remove or replace commented code in views
- [ ] Replace hardcoded strings with constants
- [ ] Standardize document picker and image picker implementation
- [ ] Make consistent use of access modifiers (private, fileprivate, etc.)
- [ ] Update variable names to be more descriptive and consistent

## 4. Performance Optimizations

- [ ] Add Combine debouncing for text input in RichTextEditor
- [ ] Optimize SwiftData fetch operations in NoteViewModel
- [ ] Improve image attachment handling and resizing
- [ ] Add caching for frequently accessed notes and content
- [ ] Implement lazy loading for note content in lists

## 5. Next Steps

### Short Term
1. Complete pending code cleanup tasks
2. Implement the high priority refactorings
3. Add unit tests for the new service classes

### Long Term
1. Consider migrating to a more robust state management solution
2. Implement full Combine integration for reactive streams
3. Add comprehensive performance profiling
4. Implement offline-first sync strategy

## Benefits of Completed Refactorings

1. **Improved Code Organization**
   - Clear separation of concerns
   - Easier to understand component responsibilities
   - More maintainable code structure

2. **Reduced Class Sizes**
   - Smaller, more focused classes
   - Easier to test individual components
   - Better alignment with SOLID principles

3. **Enhanced Maintainability**
   - Isolated formatting logic makes it easier to modify or extend
   - Sync operations are contained in a dedicated class
   - API interactions are more clearly structured

4. **Better Code Reuse**
   - `FormattingEngine` can be used across different text editing views
   - `SyncManager` provides a clean API for iCloud operations
   - Shared helper methods reduce code duplication