import SwiftUI
import UIKit

/// Observable class to hold the text view reference
class RichTextViewHolder: ObservableObject {
    static let shared = RichTextViewHolder()
    @Published var textView: UITextView?
    
    private init() {}
}