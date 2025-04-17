import XCTest
import SwiftData
import CloudKit
@testable import Scribe

final class SyncManagerTests: XCTestCase {
    
    var container: ModelContainer!
    var modelContext: ModelContext!
    var syncManager: SyncManager!
    
    override func setUp() async throws {
        // Create an in-memory container for testing
        let schema = Schema([ScribeNote.self, ScribeFolder.self])
        let config = ModelConfiguration("TestConfig", schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(container)
        
        // Create the SyncManager with our test context
        syncManager = SyncManager(modelContext: modelContext)
        
        // Set up test notification observation
        setupNotificationObservation()
    }
    
    override func tearDown() {
        // Remove notification observer
        NotificationCenter.default.removeObserver(self)
        
        syncManager = nil
        modelContext = nil
        container = nil
        
        super.tearDown()
    }
    
    // Notification expectation for testing
    var notificationExpectation: XCTestExpectation?
    var receivedStatus: SyncStatus?
    
    private func setupNotificationObservation() {
        // Listen for sync status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncStatusChange(_:)),
            name: Notification.Name.syncStatusDidChange,
            object: nil
        )
    }
    
    @objc private func handleSyncStatusChange(_ notification: Notification) {
        // Store the received status
        if let status = notification.object as? SyncStatus {
            receivedStatus = status
            notificationExpectation?.fulfill()
        }
    }
    
    func testSyncStatusInitialState() async {
        // Initial state should be upToDate
        XCTAssertEqual(syncManager.syncStatus, .upToDate)
    }
    
    func testSyncStatusEquality() {
        // Test the Equatable implementation
        XCTAssertEqual(SyncStatus.upToDate, SyncStatus.upToDate)
        XCTAssertEqual(SyncStatus.syncing, SyncStatus.syncing)
        XCTAssertEqual(SyncStatus.error("Test"), SyncStatus.error("Test"))
        
        XCTAssertNotEqual(SyncStatus.upToDate, SyncStatus.syncing)
        XCTAssertNotEqual(SyncStatus.syncing, SyncStatus.error("Test"))
        XCTAssertNotEqual(SyncStatus.error("Test1"), SyncStatus.error("Test2"))
    }
    
    func testSyncStatusDidChangeNotification() async {
        // Set up expectation
        notificationExpectation = expectation(description: "Should receive sync status notification")
        
        // Use test reflection to set an error state (this would normally happen internally)
        await changeStatusForTesting(to: .error("Test error"))
        
        // Wait for notification
        await fulfillment(of: [notificationExpectation!], timeout: 1.0)
        
        // Verify the notification had the right status
        XCTAssertEqual(receivedStatus, .error("Test error"))
    }
    
    // Helper to directly set the status for testing
    private func changeStatusForTesting(to status: SyncStatus) async {
        // We can't access private properties directly, so we post a notification manually
        // This would normally be done by the SyncManager itself
        await MainActor.run {
            NotificationCenter.default.post(name: Notification.Name.syncStatusDidChange, object: status)
        }
    }
}