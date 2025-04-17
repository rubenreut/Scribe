import XCTest
import SwiftUI
@testable import Scribe

final class FormattingEngineTests: XCTestCase {
    
    var formattingState: FormattingState!
    var formattingEngine: FormattingEngine!
    var textView: UITextView!
    
    override func setUp() {
        super.setUp()
        
        // Create the formatting state
        formattingState = FormattingState()
        
        // Create a test UITextView
        textView = UITextView()
        textView.text = "Test content"
        
        // Create test attributed string
        let attributedString = NSAttributedString(string: "Test content")
        
        // Initialize the formatting engine
        formattingEngine = FormattingEngine(
            textView: textView,
            attributedText: attributedString,
            formattingState: formattingState
        )
    }
    
    override func tearDown() {
        formattingState = nil
        textView = nil
        formattingEngine = nil
        super.tearDown()
    }
    
    func testToggleBold() {
        // Select all text
        textView.selectedRange = NSRange(location: 0, length: textView.text.count)
        
        // Initial state should be not bold
        XCTAssertFalse(formattingState.isBold)
        
        // Toggle bold
        let result = formattingEngine.toggleBold()
        
        // State should now be bold
        XCTAssertTrue(formattingState.isBold)
        XCTAssertNotNil(result, "Should return a new attributed string when text is selected")
        
        // Toggle bold again
        let secondResult = formattingEngine.toggleBold()
        
        // State should be back to not bold
        XCTAssertFalse(formattingState.isBold)
        XCTAssertNotNil(secondResult, "Should return a new attributed string when text is selected")
    }
    
    func testToggleItalic() {
        // Select all text
        textView.selectedRange = NSRange(location: 0, length: textView.text.count)
        
        // Initial state should be not italic
        XCTAssertFalse(formattingState.isItalic)
        
        // Toggle italic
        let result = formattingEngine.toggleItalic()
        
        // State should now be italic
        XCTAssertTrue(formattingState.isItalic)
        XCTAssertNotNil(result, "Should return a new attributed string when text is selected")
    }
    
    func testToggleUnderline() {
        // Select all text
        textView.selectedRange = NSRange(location: 0, length: textView.text.count)
        
        // Initial state should be not underlined
        XCTAssertFalse(formattingState.isUnderlined)
        
        // Toggle underline
        let result = formattingEngine.toggleUnderline()
        
        // State should now be underlined
        XCTAssertTrue(formattingState.isUnderlined)
        XCTAssertNotNil(result, "Should return a new attributed string when text is selected")
    }
    
    func testClearFormatting() {
        // Set up initial formatting
        textView.selectedRange = NSRange(location: 0, length: textView.text.count)
        
        // Apply bold
        _ = formattingEngine.toggleBold()
        XCTAssertTrue(formattingState.isBold)
        
        // Apply italic
        _ = formattingEngine.toggleItalic()
        XCTAssertTrue(formattingState.isItalic)
        
        // Clear formatting
        let result = formattingEngine.clearFormatting()
        
        // All formatting states should be reset
        XCTAssertFalse(formattingState.isBold)
        XCTAssertFalse(formattingState.isItalic)
        XCTAssertFalse(formattingState.isUnderlined)
        XCTAssertNotNil(result, "Should return a new attributed string when text is selected")
    }
    
    func testNoTextSelected() {
        // No text selected (empty selection)
        textView.selectedRange = NSRange(location: 0, length: 0)
        
        // Toggle bold with no selection should still update state
        let result = formattingEngine.toggleBold()
        
        // State should change
        XCTAssertTrue(formattingState.isBold)
        // But no attributed string should be returned
        XCTAssertNil(result, "Should not return a new attributed string when no text is selected")
    }
}