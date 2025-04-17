import SwiftUI

/// View that displays the current iCloud sync status
struct CloudSyncStatusView: View {
    let status: SyncStatus
    @State private var isRotating = false
    
    var body: some View {
        HStack(spacing: 6) {
            statusIcon
                .font(.system(size: 16))
                .symbolEffect(.pulse, options: .repeating, value: status == .syncing)
                .rotationEffect(isRotating && status == .syncing ? .degrees(360) : .degrees(0))
                .animation(
                    status == .syncing ? 
                        Animation.linear(duration: 2.0).repeatForever(autoreverses: false) : 
                        .default, 
                    value: isRotating
                )
            
            if case .syncing = status {
                Text("Syncing")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray6).opacity(status == .upToDate ? 0 : 0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(statusColor.opacity(0.4), lineWidth: 1)
        )
        .onAppear {
            if status == .syncing {
                isRotating = true
            }
        }
        .onChange(of: status) { newValue in
            isRotating = newValue == .syncing
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
    
    /// Icon for the current sync status
    private var statusIcon: some View {
        switch status {
        case .upToDate:
            return Image(systemName: "checkmark.icloud")
                .foregroundColor(statusColor)
        case .syncing:
            return Image(systemName: "arrow.clockwise.icloud")
                .foregroundColor(statusColor)
        case .error:
            return Image(systemName: "exclamationmark.icloud")
                .foregroundColor(statusColor)
        }
    }
    
    /// Color based on sync status
    private var statusColor: Color {
        switch status {
        case .upToDate:
            return .green
        case .syncing:
            return .blue
        case .error:
            return .red
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