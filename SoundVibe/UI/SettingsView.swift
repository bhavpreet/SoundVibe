#if os(macOS)

import SwiftUI
import AVFoundation

/// Main settings window with tabbed interface
struct SettingsView: View {
    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AudioSettingsView()
                .tabItem {
                    Label("Audio", systemImage: "mic")
                }

            TranscriptionSettingsView()
                .tabItem {
                    Label("Transcription", systemImage: "doc.text.magnifyingglass")
                }

            PostProcessingSettingsView()
                .tabItem {
                    Label("Post-Processing", systemImage: "wand.and.stars")
                }

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
        .tabViewStyle(.automatic)
        .frame(minWidth: 700, minHeight: 500)
        .padding()
    }
}

// MARK: - General Settings View

struct GeneralSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var isRecordingHotkey = false
    @State private var recordedHotkey: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.headline)

            Form {
                Section {
                    Label("Hotkey", image: "")
                    HotkeyRecorderView(
                        isRecording: $isRecordingHotkey,
                        recordedHotkey: $recordedHotkey
                    )
                }

                Section {
                    Picker("Trigger Mode", selection: $settings.triggerMode) {
                        Text("Hold to Talk").tag(TriggerMode.holdToTalk)
                        Text("Toggle").tag(TriggerMode.toggle)
                    }
                }

                Section {
                    Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Audio Settings View

struct AudioSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Audio Settings")
                .font(.headline)

            Form {
                Section(header: Text("Silence Timeout")) {
                    HStack {
                        Slider(
                            value: $settings.silenceTimeout,
                            in: 0.5...5.0,
                            step: 0.5
                        )
                        Text("\(String(format: "%.1f", settings.silenceTimeout))s")
                            .frame(width: 40)
                    }
                    Text("Automatically stop recording after silence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Transcription Settings View

struct TranscriptionSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var modelDownloadProgress: Double = 0
    @State private var isDownloading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Transcription Settings")
                .font(.headline)

            Form {
                Section(header: Text("Model")) {
                    Picker("Model Size", selection: $settings.selectedModelSize) {
                        Text("Tiny").tag(WhisperModelSize.tiny)
                        Text("Base").tag(WhisperModelSize.base)
                        Text("Small").tag(WhisperModelSize.small)
                        Text("Medium").tag(WhisperModelSize.medium)
                        Text("Large V3").tag(WhisperModelSize.largeV3)
                    }

                    HStack {
                        if isDownloading {
                            ProgressView(value: modelDownloadProgress)
                        } else {
                            Button("Download Model") {
                                downloadModel()
                            }
                        }
                    }
                    .padding(.top, 8)
                }

                Section(header: Text("Language")) {
                    Picker("Primary Language", selection: $settings.selectedLanguage) {
                        ForEach(SupportedLanguage.allCases, id: \.self) { language in
                            Text(language.displayName).tag(language.rawValue)
                        }
                    }
                }

                Section {
                    Toggle("Auto-Punctuation", isOn: $settings.autoPunctuation)
                    Toggle("Auto-Language Detection", isOn: $settings.autoLanguageDetection)
                }
            }

            Spacer()
        }
        .padding()
    }

    private func downloadModel() {
        isDownloading = true
        var progress: Double = 0.0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            progress += Double.random(in: 0.01...0.05)
            modelDownloadProgress = min(progress, 1.0)

            if modelDownloadProgress >= 1.0 {
                timer.invalidate()
                isDownloading = false
            }
        }
    }
}

// MARK: - Post-Processing Settings View

struct PostProcessingSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Post-Processing Settings")
                .font(.headline)

            Form {
                Section {
                    Toggle("Enable Post-Processing", isOn: $settings.postProcessingEnabled)
                }

                if settings.postProcessingEnabled {
                    Section(header: Text("Mode")) {
                        Picker("Processing Mode", selection: $settings.postProcessingMode) {
                            Text("Clean").tag(PostProcessingMode.clean)
                            Text("Formal").tag(PostProcessingMode.formal)
                            Text("Concise").tag(PostProcessingMode.concise)
                            Text("Custom").tag(PostProcessingMode.custom)
                        }
                    }

                    if settings.postProcessingMode == .custom {
                        Section(header: Text("Custom Prompt")) {
                            TextEditor(text: $settings.customPostProcessingPrompt)
                                .frame(height: 150)
                                .border(Color.gray, width: 1)
                            Text("Enter your custom prompt for MLX-based processing")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Section {
                        Text("MLX Model: whisper-mlx-large")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Processes transcriptions locally using MLX framework")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Advanced Settings View

struct AdvancedSettingsView: View {
    @ObservedObject var settings = SettingsManager.shared
    @State private var showResetConfirmation = false
    @State private var showExportSuccess = false
    @State private var showImportSuccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Advanced Settings")
                .font(.headline)

            Form {
                Section(header: Text("Clipboard")) {
                    Toggle("Restore Original Clipboard", isOn: $settings.clipboardRestoreEnabled)
                    Text("Restore clipboard contents after pasting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section(header: Text("Paste Delay")) {
                    HStack {
                        Slider(
                            value: $settings.pasteDelay,
                            in: 0.01...0.2,
                            step: 0.01
                        )
                        Text("\(String(format: "%.0f", settings.pasteDelay * 1000))ms")
                            .frame(width: 50)
                    }
                    Text("Delay before pasting (10-200ms)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button("Export Settings", action: exportSettings)
                    Button("Import Settings", action: importSettings)
                }

                Section {
                    Button(role: .destructive, action: {
                        showResetConfirmation = true
                    }) {
                        Text("Reset to Defaults")
                    }
                }
            }

            Spacer()
        }
        .padding()
        .alert("Reset Settings?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.resetToDefaults()
            }
        } message: {
            Text("This will reset all settings to their default values.")
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK") { }
        } message: {
            Text("Settings have been exported successfully.")
        }
        .alert("Import Successful", isPresented: $showImportSuccess) {
            Button("OK") { }
        } message: {
            Text("Settings have been imported successfully.")
        }
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "soundvibe-settings"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                let data = settings.exportSettings()
                try? data.write(to: url)
                showExportSuccess = true
            }
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            if response == .OK, let url = panel.urls.first {
                if let data = try? Data(contentsOf: url) {
                    try? settings.importSettings(data)
                    showImportSuccess = true
                }
            }
        }
    }
}

// MARK: - Hotkey Recorder View

struct HotkeyRecorderView: View {
    @Binding var isRecording: Bool
    @Binding var recordedHotkey: String
    @ObservedObject private var settings = SettingsManager.shared
    @State private var eventMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                if isRecording {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Press a key combination... (Esc to cancel)")
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Image(systemName: "keyboard")
                        Text(recordedHotkey.isEmpty ? settings.hotkey.displayString : recordedHotkey)
                            .foregroundColor(.primary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(isRecording ? Color.accentColor.opacity(0.15) : Color(.controlBackgroundColor))
            .cornerRadius(6)

            if isRecording {
                Text("Press your desired key combination now")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            recordedHotkey = settings.hotkey.displayString
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        // Ensure the app is active so it receives key events
        NSApp.activate(ignoringOtherApps: true)
        isRecording = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { event in
            if event.type == .keyDown && event.keyCode == 53 {
                // Escape cancels recording
                self.stopRecording()
                return nil
            }

            if event.type == .flagsChanged {
                // Modifier key pressed alone
                let code = UInt16(event.keyCode)
                guard HotkeyCombo.modifierKeyCodes.contains(code) else {
                    return event
                }
                let combo = HotkeyCombo(from: event)
                self.settings.hotkey = combo
                self.recordedHotkey = combo.displayString
                self.stopRecording()
                return nil
            }

            // Regular key (possibly with modifiers)
            let combo = HotkeyCombo(from: event)
            self.settings.hotkey = combo
            self.recordedHotkey = combo.displayString
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

#endif
