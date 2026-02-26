import SwiftUI

struct PreBreakWarningView: View {
    let type: BreakType
    let duration: TimeInterval
    let onSkip: () -> Void
    let onDelay: (Int) -> Void
    
    @State private var timeRemaining: TimeInterval
    
    init(type: BreakType, duration: TimeInterval, onSkip: @escaping () -> Void, onDelay: @escaping (Int) -> Void) {
        self.type = type
        self.duration = duration
        self.onSkip = onSkip
        self.onDelay = onDelay
        self._timeRemaining = State(initialValue: duration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Text(iconString)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(titleText)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Countdown Ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 3)
                        .frame(width: 32, height: 32)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(timeRemaining / duration))
                        .stroke(iconColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 32, height: 32)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: timeRemaining)
                    
                    Text("\(Int(timeRemaining))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
            }
            
            // Action buttons for look away and walk
            if type == .lookAway || type == .walk {
                HStack(spacing: 6) {
                    // Delay buttons
                    ForEach([1, 2, 5], id: \.self) { mins in
                        Button(action: { onDelay(mins) }) {
                            Text("+\(mins)m")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    // Skip
                    Button(action: onSkip) {
                        Text("Skip")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startCountdown()
        }
    }
    
    private var iconString: String {
        switch type {
        case .lookAway: return "👀"
        case .walk: return "🚶"
        default: return "⏱️"
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .lookAway: return .blue
        case .walk: return .orange
        default: return .gray
        }
    }
    
    private var titleText: String {
        switch type {
        case .lookAway: return "Look Away Break"
        case .walk: return "Walk Break"
        default: return "Break Reminder"
        }
    }
    
    private var subtitleText: String {
        switch type {
        case .lookAway: return "Starting in a few seconds..."
        case .walk: return "Time to stretch your legs."
        default: return ""
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
