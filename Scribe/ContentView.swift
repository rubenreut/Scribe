import SwiftUI
import SwiftData
import OSLog

/// Main content view showing split navigation between note list and editor
struct ContentView: View {
    private let logger = Logger(subsystem: Constants.App.bundleID, category: "ContentView")
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: NoteViewModel
    @State private var showNewNoteAnimation = false
    @State private var isSplitViewCompact = false
    
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
        NavigationSplitView(columnVisibility: .constant(.automatic)) {
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
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                showNewNoteAnimation = true
                                viewModel.createNewNote()
                            }
                            
                            // Reset animation state after delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                showNewNoteAnimation = false
                            }
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 38, height: 38)
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .accessibilityLabel("Create a new note")
                            }
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                                    .scaleEffect(showNewNoteAnimation ? 1.4 : 1.0)
                                    .opacity(showNewNoteAnimation ? 0 : 1)
                            )
                            .pressAnimation()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        CloudSyncStatusView(status: viewModel.syncStatus)
                    }
                }
                
                // Show iCloud status at the bottom of the list
                if case .error(let message) = viewModel.syncStatus {
                    VStack {
                        HStack {
                            Image(systemName: "exclamationmark.icloud")
                                .foregroundColor(.red)
                                .font(.caption)
                            
                            Text("iCloud Sync Error")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                        
                        Text(message)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        } detail: {
            // Only show the rich text editor
            RichTextNoteEditorView(selectedNote: $viewModel.selectedNote, viewModel: viewModel)
                .transition(.opacity)
                .id(viewModel.selectedNote?.persistentModelID.storeIdentifier ?? "no-note") // Force view refresh when note changes
        }
        .navigationSplitViewStyle(.balanced)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.selectedNote?.persistentModelID.storeIdentifier)
        .onAppear {
            // Replace the temporary context with the real one
            viewModel = NoteViewModel(modelContext: modelContext)
            
            // Refresh notes on appear to ensure we have the latest data
            viewModel.refreshNotes()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppNotification.createNewNote.name)) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                viewModel.createNewNote()
            }
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
