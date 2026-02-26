import Foundation
import SwiftUI
import Combine

enum TimerState: Equatable {
    case running
    case paused
    case preBreak(BreakType) // Countdown before lookAway or walk
    case onBreak(BreakType)
    case disabled
}

class TimerEngine: ObservableObject {
    @Published var blinkTimeRemaining: TimeInterval = 0
    @Published var postureTimeRemaining: TimeInterval = 0
    @Published var lookAwayTimeRemaining: TimeInterval = 0
    @Published var walkTimeRemaining: TimeInterval = 0
    
    @Published var breakTimeRemaining: TimeInterval = 0
    @Published var preBreakTimeRemaining: TimeInterval = 0
    
    @Published var state: TimerState = .disabled
    @Published var currentBreakType: BreakType? = nil

    private var timer: Timer?
    private var overlayController = OverlayWindowController()
    private var cancellables = Set<AnyCancellable>()
    private let focusDetector = FocusDetector.shared

    // Set by AppDelegate after init
    var settingsRef: SettingsManager? {
        didSet {
            guard settingsRef != nil else { return }
            resetTimers()
            startTimer()
        }
    }

    private var settings: SettingsManager {
        settingsRef ?? SettingsManager()
    }

    var menuBarTitle: String {
        switch state {
        case .running:
            let nextBreak = min(blinkTimeRemaining, postureTimeRemaining, lookAwayTimeRemaining, walkTimeRemaining)
            let mins = Int(nextBreak) / 60
            let secs = Int(nextBreak) % 60
            if mins > 0 {
                return "\(mins)m"
            } else {
                return "\(secs)s"
            }
        case .paused:
            return "Paused"
        case .preBreak(_):
            return "\(Int(preBreakTimeRemaining))s"
        case .onBreak(_):
            let secs = Int(breakTimeRemaining)
            if secs >= 60 {
                return "\(secs / 60)m \(secs % 60)s"
            } else {
                return "\(secs)s"
            }
        case .disabled:
            return "Off"
        }
    }

    init() {
        NotificationCenter.default.publisher(for: .snoozeBreak)
            .sink { [weak self] _ in
                self?.snooze()
            }
            .store(in: &cancellables)
    }

    func resetTimers() {
        blinkTimeRemaining = settings.blinkIntervalSeconds
        postureTimeRemaining = settings.postureIntervalSeconds
        lookAwayTimeRemaining = settings.lookAwayIntervalSeconds
        walkTimeRemaining = settings.walkIntervalSeconds
    }

    func startTimer() {
        timer?.invalidate()
        if !settings.isEnabled {
            state = .disabled
            return
        }
        state = .running
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard state == .running else { return }

        // Decrement all running timers. If Auto-pause is active, we freeze EVERYTHING.
        if !focusDetector.isFocusModeActive {
            blinkTimeRemaining -= 1
            postureTimeRemaining -= 1
            lookAwayTimeRemaining -= 1
            walkTimeRemaining -= 1
        }

        // Check for triggers starting from highest priority (walk) to lowest (blink)
        var triggeredBreakType: BreakType? = nil
        
        if walkTimeRemaining <= 0 {
            triggeredBreakType = .walk
        } else if lookAwayTimeRemaining <= 0 {
            triggeredBreakType = .lookAway
        } else if postureTimeRemaining <= 0 {
            triggeredBreakType = .posture
        } else if blinkTimeRemaining <= 0 {
            triggeredBreakType = .blink
        }

        // Handle triggered breaks
        if let breakType = triggeredBreakType {
            if blinkTimeRemaining <= 0 { blinkTimeRemaining = settings.blinkIntervalSeconds }
            if postureTimeRemaining <= 0 { postureTimeRemaining = settings.postureIntervalSeconds }
            if lookAwayTimeRemaining <= 0 { lookAwayTimeRemaining = settings.lookAwayIntervalSeconds }
            
            if breakType == .walk || breakType == .lookAway {
                startPreBreak(breakType)
            } else {
                startBreak(breakType)
            }
        }
    }

    private func startPreBreak(_ type: BreakType) {
        timer?.invalidate()
        currentBreakType = type
        state = .preBreak(type)
        preBreakTimeRemaining = 5 // 5 seconds warning
        
        if settings.soundEnabled {
            NSSound(named: "Glass")?.play()
        }
        
        let inMeeting = focusDetector.inMeeting
        overlayController.showWarning(type: type, duration: preBreakTimeRemaining, isInMeeting: inMeeting) { [weak self] in
            self?.endBreak(wasSkipped: true)
        } onDelay: { [weak self] mins in
            self?.delayBreak(minutes: mins)
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.preBreakTimeRemaining -= 1
            if self.preBreakTimeRemaining <= 0 {
                self.startBreak(type)
            }
        }
    }

    private func startBreak(_ type: BreakType) {
        timer?.invalidate()
        currentBreakType = type
        state = .onBreak(type)

        let duration: TimeInterval
        switch type {
        case .blink: duration = settings.blinkDuration
        case .posture: duration = settings.postureDuration
        case .lookAway: duration = settings.lookAwayDuration
        case .walk: duration = settings.walkDuration
        }
        
        breakTimeRemaining = duration

        if settings.soundEnabled && (type == .blink || type == .posture) {
            NSSound(named: "Glass")?.play()
        }

        let inMeeting = focusDetector.inMeeting
        overlayController.showBreak(
            type: type,
            duration: duration,
            settings: settings,
            isInMeeting: inMeeting
        ) { [weak self] in
            self?.endBreak(wasSkipped: true)
        }


        // Break countdown timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.breakTimeRemaining -= 1
            if self.breakTimeRemaining <= 0 {
                self.endBreak(wasSkipped: false)
            }
        }
    }

    func endBreak(wasSkipped: Bool = false) {
        timer?.invalidate()
        overlayController.dismissOverlay()
        currentBreakType = nil
        let previousState = state
        state = .running

        // Play end sound
        if settings.soundEnabled && !wasSkipped {
            NSSound(named: "Purr")?.play()
        }

        // Reset the timer that just finished, leave others running
        if case .onBreak(let type) = previousState {
            resetTimer(for: type)
        } else if case .preBreak(let type) = previousState {
            resetTimer(for: type)
        }

        startTimer()
    }
    
    private func resetTimer(for type: BreakType) {
        switch type {
        case .blink:
            blinkTimeRemaining = settings.blinkIntervalSeconds
        case .posture:
            postureTimeRemaining = settings.postureIntervalSeconds
        case .lookAway:
            lookAwayTimeRemaining = settings.lookAwayIntervalSeconds
        case .walk:
            walkTimeRemaining = settings.walkIntervalSeconds
        }
    }

    func skipBreak() {
        endBreak(wasSkipped: true)
    }

    func togglePause() {
        switch state {
        case .running:
            timer?.invalidate()
            state = .paused
        case .paused:
            startTimer()
        default:
            break
        }
    }

    func snooze() {
        if case .onBreak(let type) = state {
            endBreak(wasSkipped: true)
            // Push it back by 5 minutes, or less if interval is smaller
            switch type {
            case .blink: blinkTimeRemaining = min(settings.blinkIntervalSeconds, 60)
            case .posture: postureTimeRemaining = min(settings.postureIntervalSeconds, 5 * 60)
            case .lookAway: lookAwayTimeRemaining = min(settings.lookAwayIntervalSeconds, 5 * 60)
            case .walk: walkTimeRemaining = min(settings.walkIntervalSeconds, 10 * 60)
            }
        }
    }

    func delayBreak(minutes: Int) {
        guard case .preBreak(let type) = state else { return }
        
        timer?.invalidate()
        overlayController.dismissOverlay()
        currentBreakType = nil
        state = .running
        
        // Push the break back by the requested minutes
        let delaySeconds = TimeInterval(minutes * 60)
        switch type {
        case .blink: blinkTimeRemaining = delaySeconds
        case .posture: postureTimeRemaining = delaySeconds
        case .lookAway: lookAwayTimeRemaining = delaySeconds
        case .walk: walkTimeRemaining = delaySeconds
        }
        
        startTimer()
    }

    func toggle() {
        settings.isEnabled.toggle()
        if settings.isEnabled {
            resetTimers()
            startTimer()
        } else {
            timer?.invalidate()
            state = .disabled
        }
    }

    func triggerTestBreak(_ type: BreakType) {
        timer?.invalidate()
        // For testing, go straight to break or warning based on type
        if type == .walk || type == .lookAway {
            startPreBreak(type)
        } else {
            startBreak(type)
        }
    }
}
