import SwiftUI

// MARK: - Eye Shape

struct EyeShape: Shape {
    var openAmount: CGFloat  // 0 = closed, 1 = fully open

    var animatableData: CGFloat {
        get { openAmount }
        set { openAmount = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let midY = rect.midY
        let eyeHeight = h * 0.4 * openAmount

        // Top lid
        path.move(to: CGPoint(x: 0, y: midY))
        path.addQuadCurve(
            to: CGPoint(x: w, y: midY),
            control: CGPoint(x: w / 2, y: midY - eyeHeight)
        )
        // Bottom lid
        path.addQuadCurve(
            to: CGPoint(x: 0, y: midY),
            control: CGPoint(x: w / 2, y: midY + eyeHeight)
        )

        return path
    }
}

// MARK: - Iris/Pupil

struct IrisView: View {
    var openAmount: CGFloat
    var size: CGFloat

    @State private var lookDirection: CGFloat = 0

    var body: some View {
        ZStack {
            // Iris
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.3, green: 0.6, blue: 0.4),
                            Color(red: 0.2, green: 0.4, blue: 0.3),
                            Color(red: 0.1, green: 0.25, blue: 0.2)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.25
                    )
                )
                .frame(width: size * 0.45, height: size * 0.45)

            // Pupil
            Circle()
                .fill(.black)
                .frame(width: size * 0.2, height: size * 0.2)

            // Light reflection
            Circle()
                .fill(.white.opacity(0.8))
                .frame(width: size * 0.08, height: size * 0.08)
                .offset(x: -size * 0.06, y: -size * 0.06)
        }
        .offset(x: lookDirection * size * 0.05)
        .opacity(openAmount > 0.3 ? 1 : 0)
        .scaleEffect(y: openAmount)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                lookDirection = 1
            }
        }
    }
}

// MARK: - Single Animated Eye

struct AnimatedEye: View {
    var size: CGFloat
    @Binding var isBlinking: Bool

    @State private var openAmount: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Eye white
            EyeShape(openAmount: openAmount)
                .fill(.white)
                .frame(width: size, height: size * 0.5)

            // Iris and pupil
            IrisView(openAmount: openAmount, size: size)

            // Eye outline
            EyeShape(openAmount: openAmount)
                .stroke(Color.white.opacity(0.6), lineWidth: 2)
                .frame(width: size, height: size * 0.5)
        }
        .onChange(of: isBlinking) { _, blinking in
            if blinking {
                performBlink()
            }
        }
    }

    private func performBlink() {
        withAnimation(.easeIn(duration: 0.12)) {
            openAmount = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.18)) {
                openAmount = 1.0
            }
        }
    }
}

// MARK: - Breathing Text

struct BreathingText: ViewModifier {
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    scale = 1.05
                }
            }
    }
}

// MARK: - Countdown Ring

struct CountdownRing: View {
    var progress: CGFloat  // 0 to 1
    var size: CGFloat
    var color: Color

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 4)
                .frame(width: size, height: size)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.5), color],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
        }
    }
}

// MARK: - Particle Effect

struct FloatingParticle: View {
    let delay: Double
    let size: CGFloat

    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 0
    @State private var xOffset: CGFloat = 0

    var body: some View {
        Circle()
            .fill(.white.opacity(opacity))
            .frame(width: size, height: size)
            .offset(x: xOffset, y: yOffset)
            .onAppear {
                let randomX = CGFloat.random(in: -30...30)
                withAnimation(.easeInOut(duration: Double.random(in: 3...6)).repeatForever(autoreverses: true).delay(delay)) {
                    yOffset = CGFloat.random(in: -150...(-50))
                    opacity = Double.random(in: 0.2...0.5)
                    xOffset = randomX
                }
            }
    }
}

// MARK: - Walking Figure

struct WalkingFigure: View {
    var size: CGFloat
    @State private var stepPhase: Bool = false
    @State private var bounce: CGFloat = 0

    var body: some View {
        Image(systemName: stepPhase ? "figure.walk" : "figure.stand")
            .font(.system(size: size))
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, .white.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .offset(y: bounce)
            .onAppear {
                // Walking step animation
                Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in
                    withAnimation(.easeInOut(duration: 0.6)) {
                        stepPhase.toggle()
                    }
                }
                // Subtle bounce
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    bounce = -4
                }
            }
    }
}

// MARK: - Gradient Background

struct AnimatedGradientBackground: View {
    let colors: [Color]
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

extension View {
    func breathing() -> some View {
        modifier(BreathingText())
    }
}
