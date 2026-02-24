import SwiftUI

struct WalkBreakView: View {
    let duration: TimeInterval
    let showSkip: Bool
    let onSkip: () -> Void

    @State private var timeRemaining: TimeInterval
    @State private var appeared = false
    @State private var messageIndex = 0

    private let messages = [
        "Time to stand & stretch! 🧘",
        "Move around a bit 🚶",
        "Stretch your arms & legs 💪",
        "Take a deep breath 🌬️",
        "Drink some water 💧"
    ]

    init(duration: TimeInterval, showSkip: Bool, onSkip: @escaping () -> Void) {
        self.duration = duration
        self.showSkip = showSkip
        self.onSkip = onSkip
        self._timeRemaining = State(initialValue: duration)
    }

    var progress: CGFloat {
        CGFloat(1.0 - (timeRemaining / duration))
    }

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            // Walking figure with progress ring
            ZStack {
                CountdownRing(
                    progress: progress,
                    size: 220,
                    color: Color(red: 0.9, green: 0.6, blue: 0.3)
                )

                WalkingFigure(size: 80)
            }
            .scaleEffect(appeared ? 1.0 : 0.3)
            .opacity(appeared ? 1.0 : 0)

            // Rotating motivational messages
            Text(messages[messageIndex])
                .font(.system(size: 32, weight: .light, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .breathing()
                .opacity(appeared ? 1.0 : 0)
                .id(messageIndex)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))

            // Time remaining
            HStack(spacing: 4) {
                let mins = Int(timeRemaining) / 60
                let secs = Int(timeRemaining) % 60

                if mins > 0 {
                    Text("\(mins)")
                        .font(.system(size: 48, weight: .thin, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                    Text("m")
                        .font(.system(size: 24, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.6))
                        .offset(y: 8)
                }

                Text(String(format: "%02d", secs))
                    .font(.system(size: 48, weight: .thin, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                Text("s")
                    .font(.system(size: 24, weight: .ultraLight))
                    .foregroundColor(.white.opacity(0.6))
                    .offset(y: 8)
            }
            .opacity(appeared ? 1.0 : 0)

            // Skip button
            if showSkip {
                Button(action: onSkip) {
                    Text("Skip Break")
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
        .background(Color.clear) // NSVisualEffectView handles background blur
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appeared = true
            }
            startCountdown()
            startMessageRotation()
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

    private func startMessageRotation() {
        Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                messageIndex = (messageIndex + 1) % messages.count
            }
        }
    }
}
