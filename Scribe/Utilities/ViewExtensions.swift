import SwiftUI
import UIKit

/// Extensions to SwiftUI View for common functionality
extension View {
    /// Hides the keyboard by resigning first responder
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}