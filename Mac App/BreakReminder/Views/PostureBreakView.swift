import SwiftUI

struct PostureBreakView: View {
    let duration: TimeInterval
    
    @State private var timeRemaining: TimeInterval
    @State private var arrowOffset: CGFloat = 60
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    
    init(duration: TimeInterval) {
        self.duration = duration
        self._timeRemaining = State(initialValue: duration)
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 15) {
                // Posture Icon
                Image(systemName: "figure.stand")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                // Upward animating Arrow
                Image(systemName: "arrow.up")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .offset(y: arrowOffset)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.3, green: 0.8, blue: 0.5),
                                Color(red: 0.2, green: 0.65, blue: 0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .fill(Color(white: 0.1, opacity: 0.75))
                    .shadow(color: Color.black.opacity(0.5), radius: 30, y: 15)
            )
            .scaleEffect(scale)
            .opacity(opacity)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: true)) {
                arrowOffset = -20
            }
            
            startCountdown()
        }
    }
    
    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if timeRemaining > 0 {
                timeRemaining -= 1
                if timeRemaining == 0 {
                    withAnimation(.easeIn(duration: 0.3)) {
                        scale = 0.5
                        opacity = 0.0
                    }
                }
            } else {
                timer.invalidate()
            }
        }
    }
}
