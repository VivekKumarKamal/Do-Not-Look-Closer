import Foundation
import AppKit
import CoreAudio
import AVFoundation

/// Detects if the user is in a deep focus state (Active Meetings, Screen Recording)
/// Designed to be conservative — only pauses breaks when genuinely occupied.
class FocusDetector: ObservableObject {
    static let shared = FocusDetector()

    @Published var isFocusModeActive: Bool = false
    @Published var inMeeting: Bool = false
    @Published var isScreenRecording: Bool = false

    private var checkTimer: Timer?
    
    private var settings: SettingsManager {
        SettingsManager.shared
    }

    private init() {
        startMonitoring()
    }

    func startMonitoring() {
        checkTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.runChecks()
        }
        // Delay the first check to let the app settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.runChecks()
        }
    }

    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    private func runChecks() {
        let previousState = isFocusModeActive

        // 1. Meeting detection: ONLY when mic is actively in use
        //    Just having Slack/Zoom open doesn't count — the mic must be hot.
        let micActive = checkMicrophoneUsage()
        inMeeting = micActive

        // 2. Screen recording: check for known recording apps that are actively recording
        let runningApps = NSWorkspace.shared.runningApplications
        let recorderApps = ["OBS", "ScreenFlow", "Camtasia", "CleanShot X"]
        isScreenRecording = runningApps.contains { app in
            guard let name = app.localizedName else { return false }
            return recorderApps.contains { name.contains($0) }
        }

        // Aggregate — only check settings that user has enabled
        var focusActive = false
        if settings.pauseForMeetings && inMeeting { focusActive = true }
        if settings.pauseForScreenRecording && isScreenRecording { focusActive = true }

        DispatchQueue.main.async {
            self.isFocusModeActive = focusActive

            if self.isFocusModeActive != previousState {
                if self.isFocusModeActive {
                    print("🛑 Focus: pausing breaks (mic=\(micActive) rec=\(self.isScreenRecording))")
                } else {
                    print("✅ Focus ended: resuming breaks")
                }
            }
        }
    }

    // MARK: - Mic Check

    private func checkMicrophoneUsage() -> Bool {
        let deviceID = AudioObjectID(kAudioObjectSystemObject)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var defaultInputDevice = AudioDeviceID()

        let status = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &defaultInputDevice)

        if status == noErr && defaultInputDevice != kAudioObjectUnknown {
            var isRunning: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            var runningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            let runningStatus = AudioObjectGetPropertyData(defaultInputDevice, &runningAddress, 0, nil, &runningSize, &isRunning)
            if runningStatus == noErr {
                return isRunning != 0
            }
        }
        return false
    }
}
