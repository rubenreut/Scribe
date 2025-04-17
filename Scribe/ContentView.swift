import SwiftUI
import SwiftData
import OSLog

/// Main content view showing split navigation between note list and editor
struct ContentView: View {
    private let logger = Logger(subsystem: Constants.App.bundleID, category: "ContentView")
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: NoteViewModel
    
    init() {
        // Initialize with an empty container that will be replaced when Environment is available
        do {
            // Use in-memory only container for initial setup
            let schema = Schema([ScribeNote.self, ScribeFolder.self])
            let config = ModelConfiguration("PreviewConfig", schema: schema, isStoredInMemoryOnly: true, allowsSave: true)
            let container = try ModelContainer(for: schema, configurations: [config])
            _viewModel = State(initialValue: NoteViewModel(modelContext: ModelContext(container)))
        } catch {
            // This should not happen but provide a fallback
            logger.warning("Using temporary container for initialization: \(error.localizedDescription)")
            
            // Create an empty model context as fallback (will be replaced on appear)
            let schema = Schema([ScribeNote.self, ScribeFolder.self])
            let descriptor = ModelConfiguration("FallbackConfig", schema: schema, isStoredInMemoryOnly: true, allowsSave: true)
            do {
                let container = try ModelContainer(for: schema, configurations: [descriptor])
                _viewModel = State(initialValue: NoteViewModel(modelContext: ModelContext(container)))
            } catch {
                // Last resort fallback - should never happen but prevents crash if it does
                logger.error("Critical error creating fallback container: \(error)")
                do {
                    let emptyContainer = try ModelContainer(for: schema)
                    let emptyContext = ModelContext(emptyContainer)
                    _viewModel = State(initialValue: NoteViewModel(modelContext: emptyContext))
                } catch {
                    logger.critical("Fatal error initializing model container: \(error)")
                    fatalError("Unable to initialize model container: \(error)")
                }
            }
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
        .onReceive(NotificationCenter.default.publisher(for: AppNotification.createNewNote.name)) { _ in
            viewModel.createNewNote()
        }
    }
}

#Preview {
    @MainActor func createPreview() -> some View {
        // Create preview container with in-memory storage
        let schema = Schema([ScribeNote.self, ScribeFolder.self])
        let config = ModelConfiguration("PreviewConfig", schema: schema, isStoredInMemoryOnly: true, allowsSave: true)
        
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            
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
        } catch {
            // Show an error view if container creation fails
            do {
                // Create a simple fallback container
                let fallbackContainer = try ModelContainer(for: schema)
                return ContentView()
                    .modelContainer(fallbackContainer)
                    .overlay(
                        Text("Preview Error: \(error.localizedDescription)")
                            .foregroundColor(.red)
                            .padding()
                    )
            } catch {
                // Last resort error view with no container
                return Text("Preview Initialization Failed: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }
    
    return createPreview()
}
