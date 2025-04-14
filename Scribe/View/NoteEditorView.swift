import SwiftUI
import SwiftData

struct NoteEditorView: View {
    @Binding var note: ScribeNote?
    @Environment(\.modelContext) private var modelContext
    @State private var lastSaveTime = Date()
    
    // Timer for autosave
    @State private var timer: Timer?
    
    var body: some View {
        Group {
            if let note = note {
                VStack(spacing: 0) {
                    TextField("Title", text: Binding(
                        get: { note.title },
                        set: { newValue in
                            note.title = newValue
                            note.lastModified = Date()
                            scheduleAutosave()
                        }
                    ))
                    .font(.largeTitle)
                    .padding([.horizontal, .top])
                    .textFieldStyle(.plain)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    TextEditor(text: Binding(
                        get: { note.content },
                        set: { newValue in
                            note.content = newValue
                            note.lastModified = Date()
                            scheduleAutosave()
                        }
                    ))
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                    .padding()
                    
                    HStack {
                        Spacer()
                        Text("Last edited: \(note.lastModified, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 4)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        
                        Button("Done") {
                            hideKeyboard()
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    label: {
                        Label("No Note Selected", systemImage: "square.and.pencil")
                    },
                    description: {
                        Text("Select a note from the list or create a new one.")
                    }
                )
            }
        }
        .onDisappear {
            timer?.invalidate()
            saveChanges()
        }
    }
    
    private func scheduleAutosave() {
        // Cancel existing timer
        timer?.invalidate()
        
        // Create a new timer that will save after 0.5 seconds of inactivity
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            saveChanges()
        }
    }
    
    private func saveChanges() {
        do {
            try modelContext.save()
            lastSaveTime = Date()
        } catch {
            print("Failed to save note: \(error.localizedDescription)")
        }
    }

    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    let container = try! ModelContainer(for: ScribeNote.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    
    // Add sample data
    let note = ScribeNote(title: "Meeting Notes", content: "Discuss project timeline and milestones")
    container.mainContext.insert(note)
    
    return NoteEditorView(note: .constant(note))
        .modelContainer(container)
}
