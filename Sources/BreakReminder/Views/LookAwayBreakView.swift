import SwiftUI

struct LookAwayBreakView: View {
    let duration: TimeInterval
    let showSkip: Bool
    let onSkip: () -> Void

    @State private var timeRemaining: TimeInterval
    @State private var appeared = false

    init(duration: TimeInterval, showSkip: Bool, onSkip: @escaping () -> Void) {
        self.duration = duration
        self.showSkip = showSkip
        self.onSkip = onSkip
        self._timeRemaining = State(initialValue: duration)
    }

    var progress: CGFloat {
        CGFloat(timeRemaining / duration)
    }

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Message
            Text("Look away from the screen")
                .font(.system(size: 42, weight: .light, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .breathing()
                .scaleEffect(appeared ? 1.0 : 0.8)
                .opacity(appeared ? 1.0 : 0)

            Text("20-20-20 Rule: Focus on something 20 feet away")
                .font(.system(size: 24, weight: .ultraLight, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .scaleEffect(appeared ? 1.0 : 0.8)
                .opacity(appeared ? 1.0 : 0)

            // Countdown
            ZStack {
                CountdownRing(
                    progress: progress,
                    size: 100,
                    color: Color(red: 0.4, green: 0.7, blue: 1.0)
                )

                Text("\(Int(timeRemaining))")
                    .font(.system(size: 34, weight: .thin, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.top, 20)
            .scaleEffect(appeared ? 1.0 : 0.5)
            .opacity(appeared ? 1.0 : 0)

            // Skip button
            if showSkip {
                Button(action: onSkip) {
                    Text("Skip")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.1))
                                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 20)
                .opacity(appeared ? 1.0 : 0)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Background effects are handled by NSVisualEffectView in the Window Controller
        .background(Color.clear) 
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
            startCountdown()
        }
    }

    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                timer.invalidate()
            }
        }
    }
}
