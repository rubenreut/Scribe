import Foundation
import OSLog

/// Domain-specific error types for the app
enum AppError: Error {
    /// Data-related errors
    case dataError(description: String, underlyingError: Error? = nil)
    
    /// Network-related errors
    case networkError(description: String, underlyingError: Error? = nil)
    
    /// iCloud sync errors
    case syncError(description: String, underlyingError: Error? = nil)
    
    /// AI-related errors
    case aiError(description: String, underlyingError: Error? = nil)
    
    /// User input errors
    case validationError(description: String)
    
    /// Permission-related errors
    case permissionError(description: String)
    
    /// Unexpected errors
    case unexpected(description: String, underlyingError: Error? = nil)
}

extension AppError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .dataError(let description, _):
            return "Data Error: \(description)"
        case .networkError(let description, _):
            return "Network Error: \(description)"
        case .syncError(let description, _):
            return "Sync Error: \(description)"
        case .aiError(let description, _):
            return "AI Error: \(description)"
        case .validationError(let description):
            return "Validation Error: \(description)"
        case .permissionError(let description):
            return "Permission Error: \(description)"
        case .unexpected(let description, _):
            return "Unexpected Error: \(description)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .dataError:
            return "Try restarting the app or check if you have enough storage space."
        case .networkError:
            return "Check your internet connection and try again."
        case .syncError:
            return "Make sure you're signed in to iCloud and have a stable internet connection."
        case .aiError:
            return "Check your API key in Settings and try again."
        case .validationError:
            return "Please correct the input and try again."
        case .permissionError:
            return "Please grant the necessary permissions in Settings."
        case .unexpected:
            return "Please restart the app and try again."
        }
    }
    
    var underlyingError: Error? {
        switch self {
        case .dataError(_, let error),
             .networkError(_, let error),
             .syncError(_, let error),
             .aiError(_, let error),
             .unexpected(_, let error):
            return error
        default:
            return nil
        }
    }
}

/// Error handling utilities
class ErrorHandler {
    private static let logger = Logger(subsystem: Constants.App.bundleID, category: "ErrorHandler")
    
    /// Logs an error with appropriate severity
    /// - Parameters:
    ///   - error: The error to log
    ///   - file: Source file where the error occurred
    ///   - function: Function where the error occurred
    ///   - line: Line number where the error occurred
    static func logError(
        _ error: Error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileURL = URL(fileURLWithPath: file)
        let fileName = fileURL.lastPathComponent
        let location = "\(fileName):\(line) - \(function)"
        
        if let appError = error as? AppError {
            // Log domain-specific errors with appropriate level
            switch appError {
            case .validationError:
                // User input errors are just info level
                logger.info("[\(location)] \(appError.localizedDescription)")
            case .networkError, .syncError:
                // Network/sync errors are a common occurrence, log as warning
                logger.warning("[\(location)] \(appError.localizedDescription)")
                if let underlyingError = appError.underlyingError {
                    logger.debug("Underlying error: \(underlyingError)")
                }
            default:
                // Other app errors are logged as errors
                logger.error("[\(location)] \(appError.localizedDescription)")
                if let underlyingError = appError.underlyingError {
                    logger.error("Underlying error: \(underlyingError)")
                }
            }
        } else {
            // Unknown/system errors are always logged as errors
            logger.error("[\(location)] Unexpected error: \(error.localizedDescription)")
        }
    }
    
    /// Wraps a throwing operation with error handling
    /// - Parameters:
    ///   - operation: The operation to perform that might throw
    ///   - errorTransform: A closure that transforms the caught error into an AppError
    ///   - file: Source file where the operation is called
    ///   - function: Function where the operation is called
    ///   - line: Line number where the operation is called
    /// - Returns: The result of the operation or nil if an error occurred
    static func tryOperation<T>(
        _ operation: () throws -> T,
        errorTransform: (Error) -> AppError,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) -> T? {
        do {
            return try operation()
        } catch {
            let appError = errorTransform(error)
            logError(appError, file: file, function: function, line: line)
            return nil
        }
    }
    
    /// Handles errors in async operations
    /// - Parameters:
    ///   - operation: The async operation to perform that might throw
    ///   - errorTransform: A closure that transforms the caught error into an AppError
    ///   - file: Source file where the operation is called
    ///   - function: Function where the operation is called
    ///   - line: Line number where the operation is called
    /// - Returns: The result of the operation or nil if an error occurred
    static func tryAsync<T>(
        _ operation: () async throws -> T,
        errorTransform: @escaping (Error) -> AppError,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async -> T? {
        do {
            return try await operation()
        } catch {
            let appError = errorTransform(error)
            logError(appError, file: file, function: function, line: line)
            return nil
        }
    }
}