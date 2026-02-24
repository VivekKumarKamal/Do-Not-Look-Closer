import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var timerEngine: TimerEngine
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab(settings: settings, timerEngine: timerEngine)
                .tabItem { Label("General", systemImage: "gear") }
                .tag(0)

            BreakSettingsTab(settings: settings)
                .tabItem { Label("Breaks", systemImage: "timer") }
                .tag(1)
                
            FocusModeTab(settings: settings)
                .tabItem { Label("Auto-Pause", systemImage: "moon.stars") }
                .tag(2)

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(3)
        }
        .frame(width: 500, height: 420)
    }
}

// MARK: - General Tab
struct GeneralSettingsTab: View {
    @ObservedObject var settings: SettingsManager
    @ObservedObject var timerEngine: TimerEngine

    var body: some View {
        Form {
            Section {
                Toggle("Enable Break Reminder", isOn: Binding(
                    get: { settings.isEnabled },
                    set: { _ in timerEngine.toggle() }
                ))

                Toggle("Launch at Login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.launchAtLogin = $0 }
                ))

                Toggle("Play sounds", isOn: $settings.soundEnabled)
            }

            Section {
                Toggle("Show skip button during breaks", isOn: $settings.showSkipButton)
                Toggle("Strict mode (can't skip)", isOn: $settings.strictMode)
                    .help("When enabled, break overlays cannot be skipped")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Break Settings Tab
struct BreakSettingsTab: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section("Blink Break (5s)") {
                HStack {
                    Text("Every")
                    Slider(value: $settings.blinkInterval, in: 5...30, step: 5)
                    Text("\(Int(settings.blinkInterval)) min")
                        .frame(width: 55, alignment: .trailing)
                        .monospacedDigit()
                }
            }
            
            Section("Posture Break (5s)") {
                HStack {
                    Text("Every")
                    Slider(value: $settings.postureInterval, in: 15...60, step: 5)
                    Text("\(Int(settings.postureInterval)) min")
                        .frame(width: 55, alignment: .trailing)
                        .monospacedDigit()
                }
            }

            Section("Look Away Break (20s)") {
                HStack {
                    Text("Every")
                    Slider(value: $settings.lookAwayInterval, in: 20...120, step: 10)
                    Text("\(Int(settings.lookAwayInterval)) min")
                        .frame(width: 55, alignment: .trailing)
                        .monospacedDigit()
                }
            }

            Section("Walk Break") {
                HStack {
                    Text("Every")
                    Slider(value: $settings.walkInterval, in: 30...240, step: 30)
                    Text("\(Int(settings.walkInterval)) min")
                        .frame(width: 55, alignment: .trailing)
                        .monospacedDigit()
                }

                HStack {
                    Text("Duration")
                    Slider(value: $settings.walkDuration, in: 60...600, step: 60)
                    Text("\(Int(settings.walkDuration)) sec")
                        .frame(width: 55, alignment: .trailing)
                        .monospacedDigit()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Focus Mode Tab
struct FocusModeTab: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section(header: Text("Auto-Pause Breaks When")) {
                Toggle(isOn: $settings.pauseForMeetings) {
                    Label("In a Meeting or Call", systemImage: "mic.fill")
                }
                .help("Pauses when your microphone is actively in use")
                
                Toggle(isOn: $settings.pauseForScreenRecording) {
                    Label("Screen Recording", systemImage: "record.circle")
                }
                .help("Pauses when OBS, ScreenFlow, etc. are running")
            }
            
            Text("Breaks will resume automatically when the activity ends.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About Tab
struct AboutTab: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            if let image = NSImage(named: "AppIcon") {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 80, height: 80)
            } else {
                Image(systemName: "eye")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Don't look closer")
                .font(.title)
                .fontWeight(.semibold)

            Text("Version 2.0.0")
                .foregroundColor(.secondary)

            Text("Take care of your eyes and body.\nBuilt with ❤️ by Vivek Kumar.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.callout)

            Spacer()

            Text("© 2026 Vivek Kumar")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
