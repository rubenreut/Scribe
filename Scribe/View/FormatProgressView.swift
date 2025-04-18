import SwiftUI

struct FormatProgressView: View {
    let message: String
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background blur
            Rectangle()
                .fill(.ultraThinMaterial)
                .edgesIgnoringSafeArea(.all)
                .opacity(0.7)
                .transition(.opacity)
            
            // Progress card 
            VStack(spacing: 20) {
                // Custom animated loader
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.accentColor.opacity(0.2), Color.accentColor.opacity(0.5)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0.0, to: 0.75)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.accentColor, Color.blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(Angle(degrees: rotation))
                        .onAppear {
                            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                            
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1)) {
                                scale = 1.0
                                opacity = 1.0
                            }
                        }
                }
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Add some subtle animation to the message
                Text("Please wait...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .opacity(0.8)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.12), radius: 15, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .transition(.opacity)
    }
}

struct FormatProgressView_Previews: PreviewProvider {
    static var previews: some View {
        FormatProgressView(message: "Processing your note...")
    }
}
