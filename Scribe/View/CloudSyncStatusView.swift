import SwiftUI

/// View that displays the current iCloud sync status
struct CloudSyncStatusView: View {
    let status: SyncStatus
    
    var body: some View {
        HStack(spacing: 4) {
            statusIcon
                .font(.caption)
            
            if case .syncing = status {
                Text("Syncing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(status == .upToDate ? nil : Color(.systemGray6))
        .cornerRadius(4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    /// Icon for the current sync status
    private var statusIcon: some View {
        switch status {
        case .upToDate:
            return Image(systemName: "checkmark.icloud")
                .foregroundColor(.green)
        case .syncing:
            return Image(systemName: "arrow.clockwise.icloud")
                .foregroundColor(.blue)
        case .error:
            return Image(systemName: "exclamationmark.icloud")
                .foregroundColor(.red)
        }
    }
    
    /// Accessibility label for the current sync status
    private var accessibilityLabel: String {
        switch status {
        case .upToDate:
            return "iCloud sync is up to date"
        case .syncing:
            return "iCloud sync in progress"
        case .error(let message):
            return "iCloud sync error: \(message)"
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CloudSyncStatusView(status: .upToDate)
        CloudSyncStatusView(status: .syncing)
        CloudSyncStatusView(status: .error("No iCloud account found"))
    }
    .padding()
}