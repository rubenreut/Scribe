import SwiftUI
import UIKit

/// Extensions to SwiftUI View for common functionality
extension View {
    /// Hides the keyboard by resigning first responder
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    /// Apply a modern card style to a view
    func cardStyle() -> some View {
        self
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
    
    /// Apply a consistent button style for toolbar buttons
    func toolbarButtonStyle() -> some View {
        self
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 38, height: 38)
            .background(Color.secondary.opacity(0.12))
            .clipShape(Circle())
            .contentShape(Circle())
            .scaleEffect(1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: 1.0) 
    }
    
    /// Add a scale animation when pressing a button
    func pressAnimation() -> some View {
        self.buttonStyle(PressButtonStyle())
    }
    
    /// Add a slide transition when a view appears
    func slideTransition() -> some View {
        self.transition(AnyTransition.opacity.combined(with: .move(edge: .bottom)))
    }
}

/// Custom button style with press animation
struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Extension to provide custom transition animations
extension AnyTransition {
    static var slideUp: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }
    
    static var scaleUp: AnyTransition {
        AnyTransition.asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity)
        )
    }
}