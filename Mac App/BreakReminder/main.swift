import AppKit

// Pure AppKit entry point for menu bar app
let app = NSApplication.shared

// Create and STRONGLY retain the delegate (NSApp.delegate is weak!)
let delegate = AppDelegate()
app.delegate = delegate

// Must be accessory to show in menu bar without dock icon
app.setActivationPolicy(.accessory)

// Keep a strong reference alive for the lifetime of the app
withExtendedLifetime(delegate) {
    app.run()
}
