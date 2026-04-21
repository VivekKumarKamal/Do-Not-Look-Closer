import Foundation
import AppKit
import AVFoundation
import CoreAudio
import CoreGraphics
import CoreMediaIO

/// Detects if the user is in a deep focus state (Active Meetings, Screen Recording)
/// Designed to be conservative — only pauses breaks when genuinely occupied.
class FocusDetector: ObservableObject {
    static let shared = FocusDetector()

    @Published var isFocusModeActive: Bool = false
    @Published var inMeeting: Bool = false
    @Published var isCameraActive: Bool = false
    @Published var isScreenRecording: Bool = false

    private var checkTimer: Timer?

    private let checkInterval: TimeInterval = 2.0
    private let meetingAppNameFragments = [
        "zoom", "microsoft teams", "teams", "skype", "facetime", "whatsapp",
        "slack", "discord", "webex", "google chrome", "safari", "firefox",
        "arc", "brave"
    ]
    private let meetingBundleFragments = [
        "zoom", "teams", "skype", "facetime", "whatsapp", "slack", "discord",
        "webex", "chrome", "safari", "firefox", "arc", "brave"
    ]
    private let meetingWindowKeywords = [
        "meeting", "call", "video call", "voice call", "huddle", "google meet",
        "meet -", "zoom meeting", "teams meeting", "webex", "facetime"
    ]
    private let recorderAppNameFragments = [
        "obs", "screenflow", "camtasia", "cleanshot", "quicktime player",
        "screenshot", "loom", "kap", "screen studio"
    ]
    private let recorderBundleFragments = [
        "obsproject", "screenflow", "camtasia", "cleanshot", "quicktimeplayer",
        "screencaptureui", "loom", "kap", "screenstudio"
    ]
    private let recorderWindowKeywords = [
        "recording", "screen recording", "stop recording", "record screen",
        "recording controls", "live streaming", "streaming"
    ]
    
    private var settings: SettingsManager {
        SettingsManager.shared
    }

    private init() {
        startMonitoring()
    }

    func startMonitoring() {
        guard checkTimer == nil else { return }

        let timer = Timer(timeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.runChecks()
        }
        checkTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        runChecks()
    }

    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    private func runChecks() {
        let runningApps = NSWorkspace.shared.runningApplications
        let visibleWindows = currentVisibleWindows()

        let micActive = checkMicrophoneUsage()
        let cameraActive = checkCameraUsage()
        let meetingActive = micActive || cameraActive || hasActiveMeetingWindow(
            runningApps: runningApps,
            visibleWindows: visibleWindows
        )
        let recordingActive = hasActiveScreenRecording(
            runningApps: runningApps,
            visibleWindows: visibleWindows
        )

        DispatchQueue.main.async {
            let previousState = self.isFocusModeActive
            self.inMeeting = meetingActive
            self.isCameraActive = cameraActive
            self.isScreenRecording = recordingActive

            var focusActive = false
            if self.settings.pauseForMeetings && meetingActive { focusActive = true }
            if self.settings.pauseForScreenRecording && recordingActive { focusActive = true }

            self.isFocusModeActive = focusActive

            if self.isFocusModeActive != previousState {
                if self.isFocusModeActive {
                    print("Focus: pausing breaks (mic=\(micActive) camera=\(cameraActive) meeting=\(meetingActive) rec=\(recordingActive))")
                } else {
                    print("Focus ended: resuming breaks")
                }
            }
        }
    }

    // MARK: - Mic Check

    private func checkMicrophoneUsage() -> Bool {
        return allAudioInputDevices().contains { isAudioDeviceRunning($0) }
    }

    private func allAudioInputDevices() -> [AudioDeviceID] {
        let deviceID = AudioObjectID(kAudioObjectSystemObject)
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &propertyAddress) else {
            return []
        }

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize) == noErr else {
            return []
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        guard deviceCount > 0 else {
            return []
        }

        var devices = [AudioDeviceID](repeating: 0, count: deviceCount)
        let status = devices.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return OSStatus(kAudioHardwareUnspecifiedError)
            }

            return AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, baseAddress)
        }

        guard status == noErr else {
            return []
        }

        return devices.filter { hasInputStreams($0) }
    }

    private func hasInputStreams(_ deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &propertyAddress) else {
            return false
        }

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize) == noErr else {
            return false
        }

        return dataSize >= MemoryLayout<AudioStreamID>.size
    }

    private func isAudioDeviceRunning(_ deviceID: AudioDeviceID) -> Bool {
        let scopes = [kAudioDevicePropertyScopeInput, kAudioObjectPropertyScopeGlobal]

        for scope in scopes {
            var isRunning: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            var runningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: scope,
                mElement: kAudioObjectPropertyElementMain
            )

            guard AudioObjectHasProperty(deviceID, &runningAddress) else {
                continue
            }

            let runningStatus = AudioObjectGetPropertyData(deviceID, &runningAddress, 0, nil, &runningSize, &isRunning)
            if runningStatus == noErr {
                return isRunning != 0
            }
        }

        return false
    }

    // MARK: - Camera Check

    private func checkCameraUsage() -> Bool {
        let cameraUIDs = cameraDeviceUIDs()
        guard !cameraUIDs.isEmpty else {
            return false
        }

        return allCMIOInputDevices().contains { deviceID in
            guard let uid = cmioDeviceUID(deviceID), cameraUIDs.contains(uid) else {
                return false
            }

            return isCMIODeviceRunning(deviceID)
        }
    }

    private func cameraDeviceUIDs() -> Set<String> {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .continuityCamera, .deskViewCamera, .external],
            mediaType: .video,
            position: .unspecified
        )

        return Set(discoverySession.devices.map(\.uniqueID))
    }

    private func allCMIOInputDevices() -> [CMIODeviceID] {
        var propertyAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )

        guard CMIOObjectHasProperty(CMIOObjectID(kCMIOObjectSystemObject), &propertyAddress) else {
            return []
        }

        var dataSize: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &propertyAddress, 0, nil, &dataSize) == noErr else {
            return []
        }

        let deviceCount = Int(dataSize) / MemoryLayout<CMIODeviceID>.size
        guard deviceCount > 0 else {
            return []
        }

        var devices = [CMIODeviceID](repeating: 0, count: deviceCount)
        var dataUsed: UInt32 = 0
        let status = devices.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return OSStatus(-1)
            }

            return CMIOObjectGetPropertyData(
                CMIOObjectID(kCMIOObjectSystemObject),
                &propertyAddress,
                0,
                nil,
                dataSize,
                &dataUsed,
                baseAddress
            )
        }

        guard status == noErr else {
            return []
        }

        let usedDeviceCount = Int(dataUsed) / MemoryLayout<CMIODeviceID>.size
        return Array(devices.prefix(usedDeviceCount)).filter { hasCMIOInputStreams($0) }
    }

    private func hasCMIOInputStreams(_ deviceID: CMIODeviceID) -> Bool {
        var propertyAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyStreams),
            mScope: CMIOObjectPropertyScope(kCMIODevicePropertyScopeInput),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )

        guard CMIOObjectHasProperty(deviceID, &propertyAddress) else {
            return false
        }

        var dataSize: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize) == noErr else {
            return false
        }

        return dataSize >= MemoryLayout<CMIOStreamID>.size
    }

    private func cmioDeviceUID(_ deviceID: CMIODeviceID) -> String? {
        var propertyAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceUID),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )

        guard CMIOObjectHasProperty(deviceID, &propertyAddress) else {
            return nil
        }

        var unmanagedUID: Unmanaged<CFString>?
        var dataUsed: UInt32 = 0
        let dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = CMIOObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            dataSize,
            &dataUsed,
            &unmanagedUID
        )

        guard status == noErr, let unmanagedUID else {
            return nil
        }

        return unmanagedUID.takeUnretainedValue() as String
    }

    private func isCMIODeviceRunning(_ deviceID: CMIODeviceID) -> Bool {
        var propertyAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )

        guard CMIOObjectHasProperty(deviceID, &propertyAddress) else {
            return false
        }

        var isRunning: UInt32 = 0
        var dataUsed: UInt32 = 0
        let status = CMIOObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &dataUsed,
            &isRunning
        )

        return status == noErr && isRunning != 0
    }

    // MARK: - App and Window Checks

    private struct VisibleWindow {
        let ownerPID: pid_t
        let ownerName: String
        let title: String
        let layer: Int

        var searchableText: String {
            "\(ownerName) \(title)"
        }
    }

    private func currentVisibleWindows() -> [VisibleWindow] {
        guard let windowInfoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        return windowInfoList.compactMap { info in
            let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            guard alpha > 0 else {
                return nil
            }

            let ownerName = info[kCGWindowOwnerName as String] as? String ?? ""
            let title = info[kCGWindowName as String] as? String ?? ""
            guard !ownerName.isEmpty || !title.isEmpty else {
                return nil
            }

            let ownerPID = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0
            return VisibleWindow(ownerPID: ownerPID, ownerName: ownerName, title: title, layer: layer)
        }
    }

    private func hasActiveMeetingWindow(
        runningApps: [NSRunningApplication],
        visibleWindows: [VisibleWindow]
    ) -> Bool {
        let meetingPIDs = Set(runningApps.filter(isKnownMeetingApp).map(\.processIdentifier))

        return visibleWindows.contains { window in
            guard window.layer == 0 else {
                return false
            }

            let fromMeetingApp = meetingPIDs.contains(window.ownerPID)
                || containsAny(window.ownerName, fragments: meetingAppNameFragments)
            guard fromMeetingApp else {
                return false
            }

            return containsAny(window.searchableText, fragments: meetingWindowKeywords)
        }
    }

    private func hasActiveScreenRecording(
        runningApps: [NSRunningApplication],
        visibleWindows: [VisibleWindow]
    ) -> Bool {
        let recorderPIDs = Set(runningApps.filter(isKnownRecorderApp).map(\.processIdentifier))

        let hasRecordingWindow = visibleWindows.contains { window in
            let fromRecorderApp = recorderPIDs.contains(window.ownerPID)
                || containsAny(window.ownerName, fragments: recorderAppNameFragments)
            guard fromRecorderApp else {
                return false
            }

            return containsAny(window.searchableText, fragments: recorderWindowKeywords)
        }

        if hasRecordingWindow {
            return true
        }

        return runningApps.contains { app in
            guard isKnownRecorderApp(app) else {
                return false
            }

            let appText = "\(app.localizedName ?? "") \(app.bundleIdentifier ?? "")"
            let isSystemCaptureUI = containsAny(appText, fragments: ["screenshot", "screencaptureui"])
            return isSystemCaptureUI && app.isActive
        }
    }

    private func isKnownMeetingApp(_ app: NSRunningApplication) -> Bool {
        let appText = "\(app.localizedName ?? "") \(app.bundleIdentifier ?? "")"
        return containsAny(appText, fragments: meetingAppNameFragments)
            || containsAny(appText, fragments: meetingBundleFragments)
    }

    private func isKnownRecorderApp(_ app: NSRunningApplication) -> Bool {
        let appText = "\(app.localizedName ?? "") \(app.bundleIdentifier ?? "")"
        return containsAny(appText, fragments: recorderAppNameFragments)
            || containsAny(appText, fragments: recorderBundleFragments)
    }

    private func containsAny(_ value: String, fragments: [String]) -> Bool {
        let normalizedValue = value.lowercased()
        return fragments.contains { normalizedValue.contains($0) }
    }
}
