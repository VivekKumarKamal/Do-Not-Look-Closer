import Foundation
import SwiftUI
import ServiceManagement

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // Interval Settings (in minutes)
    @AppStorage("blinkInterval") var blinkInterval: Double = 10
    @AppStorage("postureInterval") var postureInterval: Double = 30
    @AppStorage("lookAwayInterval") var lookAwayInterval: Double = 60
    @AppStorage("walkInterval") var walkInterval: Double = 120

    // Duration Settings (in seconds)
    @AppStorage("blinkDuration") var blinkDuration: Double = 5
    @AppStorage("postureDuration") var postureDuration: Double = 5
    @AppStorage("lookAwayDuration") var lookAwayDuration: Double = 20
    @AppStorage("walkDuration") var walkDuration: Double = 300 // 5 minutes default

    // Global Settings
    @AppStorage("soundEnabled") var soundEnabled: Bool = true
    @AppStorage("isEnabled") var isEnabled: Bool = true
    @AppStorage("showSkipButton") var showSkipButton: Bool = true
    @AppStorage("strictMode") var strictMode: Bool = false
    
    // Focus Mode / Auto-Pause Settings
    @AppStorage("pauseForMeetings") var pauseForMeetings: Bool = true
    @AppStorage("pauseForScreenRecording") var pauseForScreenRecording: Bool = true
    @AppStorage("pauseForFullscreen") var pauseForFullscreen: Bool = true
    @AppStorage("pauseForVideo") var pauseForVideo: Bool = true
    @AppStorage("pauseForDeepFocus") var pauseForDeepFocus: Bool = true

    var launchAtLogin: Bool {
        get {
            SMAppService.mainApp.status == .enabled
        }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                objectWillChange.send()
            } catch {
                print("Launch at login error: \(error)")
            }
        }
    }

    // Computed intervals in seconds for the timer engine
    var blinkIntervalSeconds: TimeInterval { blinkInterval * 60 }
    var postureIntervalSeconds: TimeInterval { postureInterval * 60 }
    var lookAwayIntervalSeconds: TimeInterval { lookAwayInterval * 60 }
    var walkIntervalSeconds: TimeInterval { walkInterval * 60 }
}
