import SwiftUI
import SwiftData

struct CreateFolderView: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: NoteViewModel
    
    @State private var folderName = ""
    @State private var selectedColor = UIColor.systemBlue
    @State private var selectedIcon = "folder"
    
    private let availableIcons = [
        "folder", "folder.fill", "doc.on.doc", "tray", "archivebox",
        "book.closed", "magazine", "note.text", "doc.text", "briefcase",
        "star", "tag", "bookmark", "paperclip"
    ]
    
    private let availableColors: [UIColor] = [
        .systemBlue, .systemRed, .systemGreen, .systemPurple, .systemOrange,
        .systemTeal, .systemPink, .systemIndigo, .systemYellow, .systemGray
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Folder Name", text: $folderName)
                        .autocapitalization(.words)
                }
                
                Section(header: Text("Icon")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(selectedIcon == icon ? Color(selectedColor) : .gray)
                                .padding(8)
                                .background(
                                    selectedIcon == icon ?
                                    Color(selectedColor).opacity(0.2) :
                                    Color.clear
                                )
                                .clipShape(Circle())
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(header: Text("Color")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
                        ForEach(0..<availableColors.count, id: \.self) { index in
                            let color = availableColors[index]
                            Circle()
                                .fill(Color(color))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: selectedColor == color ? 2 : 0)
                                )
                                .padding(4)
                                .background(
                                    Circle()
                                        .fill(selectedColor == color ? Color(color).opacity(0.3) : Color.clear)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Folder")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Create") {
                    createFolder()
                    dismiss()
                }
                .disabled(folderName.isEmpty)
            )
        }
    }
    
    private func createFolder() {
        guard !folderName.isEmpty else { return }
        
        // Create the folder using ViewModel
        let folder = viewModel.createFolder(
            name: folderName, 
            icon: selectedIcon, 
            color: selectedColor
        )
        
        // A real implementation would now select this folder or show its contents
    }
}

#Preview {
    PreviewContainer { container in
        let context = container.mainContext
        let viewModel = NoteViewModel(modelContext: context)
        
        return CreateFolderView(viewModel: viewModel)
    }
}
