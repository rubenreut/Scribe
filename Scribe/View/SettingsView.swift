import SwiftUI
import CloudKit

struct SettingsView: View {
    @AppStorage("aiProvider") private var aiProvider = "OpenAI"
    @State private var apiKey = ""
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isTesting = false
    @State private var testResponse = ""
    @State private var iCloudStatus: SyncStatus = .upToDate
    @State private var isCheckingiCloud = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("AI Provider")) {
                    Picker("Provider", selection: $aiProvider) {
                        Text("OpenAI").tag("OpenAI")
                        Text("Claude").tag("Claude")
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("API Key")) {
                    SecureField("Enter API Key", text: $apiKey)
                    
                    Button(action: saveAPIKey) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Save API Key")
                        }
                    }
                    .disabled(apiKey.isEmpty || isSaving)
                }
                
                Section(header: Text("Testing")) {
                    Button("Test API Connection") {
                        testAPIConnection()
                    }
                    .disabled(apiKey.isEmpty || isTesting || isSaving)
                    
                    if isTesting {
                        ProgressView("Testing connection...")
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    
                    if !testResponse.isEmpty {
                        Text(testResponse)
                            .font(.caption)
                            .foregroundColor(testResponse.contains("Success") ? .green : .red)
                    }
                }
                
                Section(header: Text("iCloud Sync")) {
                    HStack {
                        Text("iCloud Sync")
                        Spacer()
                        CloudSyncStatusView(status: getiCloudStatus())
                    }
                    
                    Text("Your notes will be synced across all your devices signed in with the same iCloud account.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Check iCloud Status") {
                        checkiCloudStatus()
                    }
                }
                
                Section(header: Text("About")) {
                    Text("AI features require an API key from your chosen provider.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Your notes are securely stored in iCloud and will be preserved even if you delete the app.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .onAppear {
                loadAPIKey()
                checkiCloudStatus()
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("API Key"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
    
    private func testAPIConnection() {
        guard !apiKey.isEmpty else { return }
        
        isTesting = true
        testResponse = ""
        
        Task {
            do {
                let aiService = AIService(apiKey: apiKey, provider: AIService.AIProvider(rawValue: aiProvider) ?? .openAI)
                
                // This tests the simple echo endpoint
                let testPrompt = "Echo this message to verify the API is working: SCRIBE_TEST_SUCCESS"
                let response = try await aiService.testConnection(prompt: testPrompt)
                
                await MainActor.run {
                    isTesting = false
                    if response.contains("SCRIBE_TEST_SUCCESS") {
                        testResponse = "✅ Success! API connection is working."
                    } else {
                        testResponse = "⚠️ API responded, but with unexpected content."
                    }
                }
            } catch let error as AIServiceError {
                await MainActor.run {
                    isTesting = false
                    switch error {
                    case .networkError:
                        testResponse = "❌ Network error. Check your internet connection."
                    case .apiError(let statusCode, let message):
                        testResponse = "❌ API error (\(statusCode)): \(message)"
                    case .invalidResponseFormat:
                        testResponse = "❌ Invalid response from API."
                    case .missingAPIKey:
                        testResponse = "❌ API key is missing."
                    }
                }
            } catch {
                await MainActor.run {
                    isTesting = false
                    testResponse = "❌ Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func loadAPIKey() {
        apiKey = KeychainHelper.getAPIKey() ?? ""
    }
    
    private func saveAPIKey() {
        isSaving = true
        
        Task {
            let success = KeychainHelper.saveAPIKey(apiKey)
            
            await MainActor.run {
                isSaving = false
                showAlert = true
                alertMessage = success ? "API key saved successfully" : "Failed to save API key"
            }
        }
    }
    
    // MARK: - iCloud Status
    
    /// Returns the current iCloud sync status
    private func getiCloudStatus() -> SyncStatus {
        return iCloudStatus
    }
    
    /// Checks the current iCloud account status
    private func checkiCloudStatus() {
        isCheckingiCloud = true
        iCloudStatus = .syncing
        
        Task {
            // Check if iCloud is available
            await checkCloudKitAvailability()
            isCheckingiCloud = false
        }
    }
    
    /// Checks if CloudKit is available for the current user
    private func checkCloudKitAvailability() async {
        do {
            // Check account status
            return await withCheckedContinuation { continuation in
                CKContainer.default().accountStatus { status, error in
                    Task { @MainActor in
                        switch status {
                        case .available:
                            self.iCloudStatus = .upToDate
                            
                        case .noAccount:
                            self.iCloudStatus = .error("No iCloud account found")
                            
                        case .restricted:
                            self.iCloudStatus = .error("iCloud access is restricted")
                            
                        case .couldNotDetermine:
                            if let error = error {
                                self.iCloudStatus = .error(error.localizedDescription)
                            } else {
                                self.iCloudStatus = .error("Could not determine iCloud status")
                            }
                            
                        @unknown default:
                            self.iCloudStatus = .error("Unknown iCloud status")
                        }
                        
                        continuation.resume()
                    }
                }
            }
        } catch {
            await MainActor.run {
                iCloudStatus = .error(error.localizedDescription)
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
