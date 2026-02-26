import SwiftUI
import AppKit

class OverlayWindowController {
    private var windows: [NSWindow] = []
    private var onSkip: (() -> Void)?
    private var onDelay: ((Int) -> Void)?

    // MARK: - Pre-Break Warning
    
    func showWarning(type: BreakType, duration: TimeInterval, isInMeeting: Bool = false, onSkip: @escaping () -> Void, onDelay: @escaping (Int) -> Void) {
        self.onSkip = onSkip
        self.onDelay = onDelay
        dismissOverlay()

        guard let mainScreen = NSScreen.main else { return }
        
        // Create a small, floating unobtrusive window
        let width: CGFloat = 350
        let height: CGFloat = 100
        let frame = NSRect(
            x: mainScreen.frame.midX - (width / 2),
            y: mainScreen.frame.maxY - 140, // On Top
            width: width,
            height: height
        )
        
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Add visual effect backdrop for the warning card
        let visualEffect = NSVisualEffectView(frame: window.contentView!.bounds)
        visualEffect.material = .popover
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 16
        visualEffect.layer?.masksToBounds = true
        
        window.contentView?.addSubview(visualEffect)
        
        let skipAction: () -> Void = { [weak self] in
            self?.onSkip?()
        }
        let delayAction: (Int) -> Void = { [weak self] mins in
            self?.onDelay?(mins)
        }
        
        let hostingView = NSHostingView(
            rootView: AnyView(
                PreBreakWarningView(
                    type: type,
                    duration: duration,
                    onSkip: skipAction,
                    onDelay: delayAction
                )
            )
        )
        
        hostingView.frame = visualEffect.bounds
        hostingView.autoresizingMask = [.width, .height]
        visualEffect.addSubview(hostingView)
        
        window.alphaValue = 0
        windows.append(window)
        
        // Important: Use orderFront regardless of activation so we don't steal keyboard focus
        window.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.5
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1.0
        })
    }

    // MARK: - Main Break
    
    func showBreak(type: BreakType, duration: TimeInterval, settings: SettingsManager, isInMeeting: Bool = false, onComplete: @escaping () -> Void) {
        self.onSkip = onComplete
        dismissOverlay()

        for screen in NSScreen.screens {
            let window = createBreakWindow(for: screen, type: type, duration: duration, settings: settings, isInMeeting: isInMeeting)
            windows.append(window)
            window.alphaValue = 0

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.8
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().alphaValue = 1.0
            })
        }
    }

    func dismissOverlay() {
        let windowsToClose = windows
        windows = []

        for window in windowsToClose {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 0.0
            }, completionHandler: {
                window.orderOut(nil)
            })
        }
    }

    private func createBreakWindow(for screen: NSScreen, type: BreakType, duration: TimeInterval, settings: SettingsManager, isInMeeting: Bool) -> NSWindow {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        
        // Blink and Posture are non-blocking, LookAway/Walk are blocking
        if type == .blink || type == .posture {
            window.ignoresMouseEvents = true
        } else {
            window.ignoresMouseEvents = false
        }
        
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = false

        let skipAction: () -> Void = { [weak self] in
            self?.onSkip?()
        }

        let showSkip = settings.showSkipButton && !settings.strictMode

        // Add NSVisualEffectView backdrop for Walk/LookAway
        if type == .walk || type == .lookAway {
            let visualEffect = NSVisualEffectView(frame: window.contentView!.bounds)
            
            if isInMeeting && type == .lookAway {
                // Lighter blur during meetings for Look Away
                visualEffect.material = .hudWindow
                visualEffect.blendingMode = .withinWindow
            } else if type == .walk {
                // Heavy blur for Walk
                visualEffect.material = .fullScreenUI
                visualEffect.blendingMode = .behindWindow
            } else {
                // Default dark blur for Look Away
                visualEffect.material = .underPageBackground
                visualEffect.blendingMode = .behindWindow
            }
            
            visualEffect.state = .active
            visualEffect.autoresizingMask = [.width, .height]
            window.contentView?.addSubview(visualEffect)
        }

        let hostingView: NSHostingView<AnyView>
        switch type {
        case .blink:
            hostingView = NSHostingView(rootView: AnyView(BlinkBreakView(duration: duration)))
        case .posture:
            hostingView = NSHostingView(rootView: AnyView(PostureBreakView(duration: duration)))
        case .lookAway:
            hostingView = NSHostingView(rootView: AnyView(LookAwayBreakView(duration: duration, showSkip: showSkip, onSkip: skipAction)))
        case .walk:
            hostingView = NSHostingView(rootView: AnyView(WalkBreakView(duration: duration, showSkip: showSkip, onSkip: skipAction)))
        }

        hostingView.frame = window.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        
        // Add SwiftUI view on top of background
        if let contentView = window.contentView {
            if contentView.subviews.isEmpty {
                window.contentView = hostingView
            } else {
                contentView.addSubview(hostingView)
            }
        } else {
            window.contentView = hostingView
        }
        
        // Only steal focus for blocking breaks
        if type == .blink || type == .posture {
            window.orderFront(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
        }

        return window
    }
}
