import SwiftUI

struct BlinkBreakView: View {
    let duration: TimeInterval
    
    @State private var timeRemaining: TimeInterval
    @State private var isBlinking = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    @State private var blinkTimer: Timer?
    
    init(duration: TimeInterval) {
        self.duration = duration
        self._timeRemaining = State(initialValue: duration)
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 30) {
                AnimatedEye(size: 80, isBlinking: $isBlinking)
                AnimatedEye(size: 80, isBlinking: $isBlinking)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.85, blue: 0.55),
                                Color(red: 1.0, green: 0.75, blue: 0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.orange.opacity(0.4), radius: 30, y: 10)
            )
            .scaleEffect(scale)
            .opacity(opacity)
            
            Text("Blink your eyes ✨")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 16)
                .opacity(opacity)
                .shadow(color: .black.opacity(0.5), radius: 4)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
                scale = 1.0
                opacity = 1.0
            }
            
            startBlinkTimer()
            startCountdown()
        }
        .onDisappear {
            blinkTimer?.invalidate()
        }
    }
    
    private func startBlinkTimer() {
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
            isBlinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isBlinking = false
            }
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
