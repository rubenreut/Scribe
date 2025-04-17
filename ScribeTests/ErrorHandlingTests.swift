import XCTest
@testable import Scribe

final class ErrorHandlingTests: XCTestCase {
    
    func testAppErrorDescriptions() {
        // Test error descriptions for all error types
        let dataError = AppError.dataError(description: "Data error")
        XCTAssertEqual(dataError.errorDescription, "Data Error: Data error")
        
        let networkError = AppError.networkError(description: "Network error")
        XCTAssertEqual(networkError.errorDescription, "Network Error: Network error")
        
        let syncError = AppError.syncError(description: "Sync error")
        XCTAssertEqual(syncError.errorDescription, "Sync Error: Sync error")
        
        let aiError = AppError.aiError(description: "AI error")
        XCTAssertEqual(aiError.errorDescription, "AI Error: AI error")
        
        let validationError = AppError.validationError(description: "Validation error")
        XCTAssertEqual(validationError.errorDescription, "Validation Error: Validation error")
        
        let permissionError = AppError.permissionError(description: "Permission error")
        XCTAssertEqual(permissionError.errorDescription, "Permission Error: Permission error")
        
        let unexpectedError = AppError.unexpected(description: "Unexpected error")
        XCTAssertEqual(unexpectedError.errorDescription, "Unexpected Error: Unexpected error")
    }
    
    func testAppErrorRecoverySuggestions() {
        // Test recovery suggestions for all error types
        XCTAssertNotNil(AppError.dataError(description: "").recoverySuggestion)
        XCTAssertNotNil(AppError.networkError(description: "").recoverySuggestion)
        XCTAssertNotNil(AppError.syncError(description: "").recoverySuggestion)
        XCTAssertNotNil(AppError.aiError(description: "").recoverySuggestion)
        XCTAssertNotNil(AppError.validationError(description: "").recoverySuggestion)
        XCTAssertNotNil(AppError.permissionError(description: "").recoverySuggestion)
        XCTAssertNotNil(AppError.unexpected(description: "").recoverySuggestion)
    }
    
    func testUnderlyingErrors() {
        // Create a sample underlying error
        let underlyingError = NSError(domain: "test", code: 123, userInfo: nil)
        
        // Test that underlying errors are properly stored and retrieved
        let dataError = AppError.dataError(description: "Data error", underlyingError: underlyingError)
        XCTAssertEqual(dataError.underlyingError as NSError?, underlyingError)
        
        let networkError = AppError.networkError(description: "Network error", underlyingError: underlyingError)
        XCTAssertEqual(networkError.underlyingError as NSError?, underlyingError)
        
        let syncError = AppError.syncError(description: "Sync error", underlyingError: underlyingError)
        XCTAssertEqual(syncError.underlyingError as NSError?, underlyingError)
        
        let aiError = AppError.aiError(description: "AI error", underlyingError: underlyingError)
        XCTAssertEqual(aiError.underlyingError as NSError?, underlyingError)
        
        let unexpectedError = AppError.unexpected(description: "Unexpected error", underlyingError: underlyingError)
        XCTAssertEqual(unexpectedError.underlyingError as NSError?, underlyingError)
        
        // Errors without underlying errors should return nil
        let validationError = AppError.validationError(description: "Validation error")
        XCTAssertNil(validationError.underlyingError)
        
        let permissionError = AppError.permissionError(description: "Permission error")
        XCTAssertNil(permissionError.underlyingError)
    }
    
    func testTryOperation() {
        // Test successful operation
        let successResult = ErrorHandler.tryOperation(
            { return "success" },
            errorTransform: { error in AppError.unexpected(description: "Failed", underlyingError: error) }
        )
        XCTAssertEqual(successResult, "success")
        
        // Test failing operation
        let failingResult = ErrorHandler.tryOperation(
            {
                struct TestError: Error {}
                throw TestError()
            },
            errorTransform: { error in AppError.unexpected(description: "Failed", underlyingError: error) }
        )
        XCTAssertNil(failingResult)
    }
    
    func testTryAsync() async {
        // Test successful async operation
        let successResult = await ErrorHandler.tryAsync(
            { return "async success" },
            errorTransform: { error in AppError.unexpected(description: "Failed", underlyingError: error) }
        )
        XCTAssertEqual(successResult, "async success")
        
        // Test failing async operation
        let failingResult = await ErrorHandler.tryAsync(
            {
                struct TestError: Error {}
                throw TestError()
            },
            errorTransform: { error in AppError.unexpected(description: "Failed", underlyingError: error) }
        )
        XCTAssertNil(failingResult)
    }
}