import SwiftUI
import AppKit
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    let timerEngine = TimerEngine()
    let settings = SettingsManager()
    private var statusUpdateTimer: Timer?
    private var settingsWindow: NSWindow?
    
    // Sparkle auto-updater
    private var updaterController: SPUStandardUpdaterController!

    // CRITICAL: Prevent app from terminating when overlay windows close
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Sparkle auto-updater
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        // Initialize notification manager (overlay-based, no entitlement needed)
        NotificationManager.shared.setup()

        // Connect timer engine to settings
        timerEngine.settingsRef = settings

        // Setup menu bar status item on next run loop tick
        DispatchQueue.main.async { [self] in
            self.setupStatusItem()

            self.statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.updateStatusItemTitle()
            }

            print("✅ Don't look closer is running! Check your menu bar.")

            // Auto-test mode for debugging
            if CommandLine.arguments.contains("--test") {
                print("🧪 Auto-test mode: triggering blink break in 3 seconds...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                    print("🧪 Triggering test blink break NOW")
                    self?.timerEngine.triggerTestBreak(.blink)
                }
            }
        }
    }

    // MARK: - Status Bar Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "👁"

            if let image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Break Reminder") {
                button.image = image
                button.imagePosition = .imageLeading
                button.title = ""
            }

            button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        }

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Pause submenu
        let pauseMenu = NSMenu()

        // Resume — shown at top only when paused (tag 210)
        let resumeItem = NSMenuItem(title: "Resume", action: #selector(togglePause), keyEquivalent: "p")
        resumeItem.target = self
        resumeItem.tag = 210
        resumeItem.isHidden = true
        pauseMenu.addItem(resumeItem)             // index 0

        let resumeSep = NSMenuItem.separator()
        resumeSep.tag = 211
        resumeSep.isHidden = true
        pauseMenu.addItem(resumeSep)              // index 1

        let pause30 = NSMenuItem(title: "Pause for 30 Minutes", action: #selector(pauseFor30Mins), keyEquivalent: "")
        pause30.target = self
        pauseMenu.addItem(pause30)               // index 2

        let pause1h = NSMenuItem(title: "Pause for 1 Hour", action: #selector(pauseFor1Hour), keyEquivalent: "")
        pause1h.target = self
        pauseMenu.addItem(pause1h)               // index 3

        let pause5h = NSMenuItem(title: "Pause for 5 Hours", action: #selector(pauseFor5Hours), keyEquivalent: "")
        pause5h.target = self
        pauseMenu.addItem(pause5h)               // index 4

        pauseMenu.addItem(NSMenuItem.separator()) // index 5

        let pauseInfItem = NSMenuItem(title: "Pause ∞", action: #selector(togglePause), keyEquivalent: "")
        pauseInfItem.target = self
        pauseMenu.addItem(pauseInfItem)           // index 6

        let pauseItem = NSMenuItem(title: "Pause", action: nil, keyEquivalent: "")
        pauseItem.tag = 200
        pauseItem.submenu = pauseMenu
        menu.addItem(pauseItem)

        // Skip (only visible during break)
        let skipItem = NSMenuItem(title: "Skip Break", action: #selector(skipBreak), keyEquivalent: "s")
        skipItem.target = self
        skipItem.tag = 202
        skipItem.isHidden = true
        menu.addItem(skipItem)

        menu.addItem(NSMenuItem.separator())

        // Test breaks submenu
        let testMenu = NSMenu()
        
        let testBlink = NSMenuItem(title: "Blink (5s)", action: #selector(testBlinkBreak), keyEquivalent: "")
        testBlink.target = self
        
        let testPosture = NSMenuItem(title: "Posture (5s)", action: #selector(testPostureBreak), keyEquivalent: "")
        testPosture.target = self
        
        let testLookAway = NSMenuItem(title: "Look Away (20s)", action: #selector(testLookAwayBreak), keyEquivalent: "")
        testLookAway.target = self
        
        let testWalk = NSMenuItem(title: "Walk Break (\(Int(settings.walkDuration))s)", action: #selector(testWalkBreak), keyEquivalent: "")
        testWalk.target = self
        
        testMenu.addItem(testBlink)
        testMenu.addItem(testPosture)
        testMenu.addItem(testLookAway)
        testMenu.addItem(testWalk)

        let testItem = NSMenuItem(title: "Test Break", action: nil, keyEquivalent: "")
        testItem.submenu = testMenu
        menu.addItem(testItem)

        // Check for Updates
        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "u")
        updateItem.target = updaterController
        menu.addItem(updateItem)

        // Settings
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit Don't look closer", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.addItem(NSMenuItem.separator())

        // Status section (bottom)
        let blinkStatusItem = NSMenuItem(title: "👀 Blink in --:--", action: nil, keyEquivalent: "")
        blinkStatusItem.tag = 100
        blinkStatusItem.isEnabled = false
        menu.addItem(blinkStatusItem)

        let postureStatusItem = NSMenuItem(title: "🧘 Posture in --:--", action: nil, keyEquivalent: "")
        postureStatusItem.tag = 101
        postureStatusItem.isEnabled = false
        menu.addItem(postureStatusItem)

        let lookAwayStatusItem = NSMenuItem(title: "👁️ Look away in --:--", action: nil, keyEquivalent: "")
        lookAwayStatusItem.tag = 102
        lookAwayStatusItem.isEnabled = false
        menu.addItem(lookAwayStatusItem)

        let walkStatusItem = NSMenuItem(title: "🚶 Walk in --:--", action: nil, keyEquivalent: "")
        walkStatusItem.tag = 103
        walkStatusItem.isEnabled = false
        menu.addItem(walkStatusItem)

        // Focus status
        let meetingStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        meetingStatusItem.tag = 104
        meetingStatusItem.isEnabled = false
        meetingStatusItem.isHidden = true
        menu.addItem(meetingStatusItem)

        statusItem.menu = menu
    }

    // MARK: - Status Updates

    private func updateStatusItemTitle() {
        guard let button = statusItem?.button else { return }
        let menu = statusItem?.menu
        let settings = timerEngine.settingsRef

        // Always use the same eye icon — keep it simple
        button.title = " \(timerEngine.menuBarTitle)"

        switch timerEngine.state {
        case .running:
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Don't look closer")

            let fmt: (TimeInterval) -> String = { t in
                let m = Int(t) / 60; let s = Int(t) % 60
                return m > 0 ? "\(m)m \(s)s" : "\(s)s"
            }

            let blinkOn    = settings?.blinkEnabled    ?? true
            let postureOn  = settings?.postureEnabled  ?? true
            let lookAwayOn = settings?.lookAwayEnabled ?? true
            let walkOn     = settings?.walkEnabled     ?? true

            menu?.item(withTag: 100)?.title = blinkOn    ? "Blink in \(fmt(timerEngine.blinkTimeRemaining))"       : "Blink (disabled)"
            menu?.item(withTag: 101)?.title = postureOn  ? "Posture in \(fmt(timerEngine.postureTimeRemaining))"   : "Posture (disabled)"
            menu?.item(withTag: 102)?.title = lookAwayOn ? "Look away in \(fmt(timerEngine.lookAwayTimeRemaining))" : "Look Away (disabled)"
            menu?.item(withTag: 103)?.title = walkOn     ? "Walk in \(fmt(timerEngine.walkTimeRemaining))"          : "Walk (disabled)"

            menu?.item(withTag: 100)?.isHidden = false
            menu?.item(withTag: 101)?.isHidden = false
            menu?.item(withTag: 102)?.isHidden = false
            menu?.item(withTag: 103)?.isHidden = false

            // Pause submenu: hide Resume, show Pause ∞
            let pauseSubWhenRunning = menu?.item(withTag: 200)?.submenu
            pauseSubWhenRunning?.item(withTag: 210)?.isHidden = true   // Resume
            pauseSubWhenRunning?.item(withTag: 211)?.isHidden = true   // separator after Resume
            menu?.item(withTag: 200)?.title = "Pause"
            menu?.item(withTag: 200)?.isHidden = false
            menu?.item(withTag: 202)?.isHidden = true

            if FocusDetector.shared.isFocusModeActive {
                menu?.item(withTag: 104)?.title = "Focus Mode — breaks paused"
                menu?.item(withTag: 104)?.isHidden = false
            } else {
                menu?.item(withTag: 104)?.isHidden = true
            }

        case .paused:
            button.image = NSImage(systemSymbolName: "pause.circle", accessibilityDescription: "Paused")

            let pauseSub = menu?.item(withTag: 200)?.submenu
            // Show Resume at top of submenu
            pauseSub?.item(withTag: 210)?.isHidden = false
            pauseSub?.item(withTag: 211)?.isHidden = false

            if let until = timerEngine.pauseUntilDate {
                let remaining = max(0, until.timeIntervalSinceNow)
                let mins = Int(remaining) / 60
                let secs = Int(remaining) % 60
                let label = mins > 0 ? "Paused — \(mins)m \(secs)s left" : "Paused — resuming…"
                menu?.item(withTag: 100)?.title = label
                pauseSub?.item(withTag: 210)?.title = "Resume Now"
            } else {
                menu?.item(withTag: 100)?.title = "Timers paused"
                pauseSub?.item(withTag: 210)?.title = "Resume"
            }
            menu?.item(withTag: 200)?.title = "Resume"

            menu?.item(withTag: 101)?.isHidden = true
            menu?.item(withTag: 102)?.isHidden = true
            menu?.item(withTag: 103)?.isHidden = true
            menu?.item(withTag: 104)?.isHidden = true
            menu?.item(withTag: 202)?.isHidden = true

        case .preBreak(let type), .onBreak(let type):
            let secs = Int(timerEngine.breakTimeRemaining)
            if case .preBreak = timerEngine.state {
                button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Warning")
                menu?.item(withTag: 100)?.title = "Break starting in \(Int(timerEngine.preBreakTimeRemaining))s"
            } else {
                button.image = NSImage(systemSymbolName: "eye.fill", accessibilityDescription: "On Break")
                switch type {
                case .blink:
                    menu?.item(withTag: 100)?.title = "Blink — \(secs)s left"
                case .posture:
                    menu?.item(withTag: 100)?.title = "Posture — \(secs)s left"
                case .lookAway:
                    menu?.item(withTag: 100)?.title = "Look away — \(secs)s left"
                case .walk:
                    menu?.item(withTag: 100)?.title = "Walk — \(secs)s left"
                }
            }

            menu?.item(withTag: 101)?.isHidden = true
            menu?.item(withTag: 102)?.isHidden = true
            menu?.item(withTag: 103)?.isHidden = true
            menu?.item(withTag: 104)?.isHidden = true
            menu?.item(withTag: 200)?.isHidden = true
            menu?.item(withTag: 202)?.isHidden = false

        case .disabled:
            button.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Disabled")
            menu?.item(withTag: 100)?.title = "Disabled"
            menu?.item(withTag: 101)?.isHidden = true
            menu?.item(withTag: 102)?.isHidden = true
            menu?.item(withTag: 103)?.isHidden = true
            menu?.item(withTag: 104)?.isHidden = true
            menu?.item(withTag: 202)?.isHidden = true
        }
    }

    // MARK: - Actions

    @objc private func togglePause() {
        timerEngine.togglePause()
    }

    @objc private func pauseFor30Mins() {
        timerEngine.pauseFor(minutes: 30)
    }

    @objc private func pauseFor1Hour() {
        timerEngine.pauseFor(minutes: 60)
    }

    @objc private func pauseFor5Hours() {
        timerEngine.pauseFor(minutes: 300)
    }

    @objc private func skipBreak() {
        timerEngine.skipBreak()
    }

    @objc private func toggleEnabled() {
        timerEngine.toggle()
    }

    @objc private func testBlinkBreak() {
        print("🧪 Triggering test blink break")
        timerEngine.triggerTestBreak(.blink)
    }
    
    @objc private func testPostureBreak() {
        print("🧪 Triggering test posture break")
        timerEngine.triggerTestBreak(.posture)
    }

    @objc private func testLookAwayBreak() {
        print("🧪 Triggering test look away break")
        timerEngine.triggerTestBreak(.lookAway)
    }

    @objc private func testWalkBreak() {
        print("🧪 Triggering test walk break")
        timerEngine.triggerTestBreak(.walk)
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView(settings: settings, timerEngine: timerEngine)
            let hostingController = NSHostingController(rootView: settingsView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = "Don't look closer Settings"
            window.styleMask = [.titled, .closable]
            window.setContentSize(NSSize(width: 500, height: 500))
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

extension Notification.Name {
    static let snoozeBreak = Notification.Name("snoozeBreak")
}
