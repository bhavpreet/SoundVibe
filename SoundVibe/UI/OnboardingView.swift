#if os(macOS)

import SwiftUI
import AVFoundation
import WhisperKit

/// First-run setup flow for SoundVibe
struct OnboardingView: View {
  @State private var currentStep: Int = 0
  @State private var microphoneGranted: Bool = false
  @State private var accessibilityGranted: Bool = false
  @State private var selectedHotkey: String =
    HotkeyCombo.defaultHotkey.displayString
  @State private var selectedLanguage: SupportedLanguage =
    .english
  @State private var recordingHotkey = false
  @State private var selectedTriggerMode: TriggerMode =
    .holdToTalk

  @State private var checkAccessibilityTimer: Timer?
  @State private var modelDownloadComplete: Bool = false
  @State private var modelDownloadProgress: Double = 0.0
  @State private var modelDownloadStatus: String = "Waiting..."
  @State private var modelFolderPath: String = ""

  // B6: Model selection during onboarding
  @State private var selectedOnboardingModel: WhisperModelSize =
    DeviceProfiler.recommendedModel()

  let totalSteps = 8

  var body: some View {
    ZStack {
      Color(.windowBackgroundColor)
      .ignoresSafeArea()

      VStack(spacing: 30) {
        HStack(spacing: 8) {
          ForEach(0..<totalSteps, id: \.self) { step in
            Circle()
              .fill(
                step <= currentStep
                  ? Color.blue
                  : Color.gray.opacity(0.3)
              )
              .frame(width: 10, height: 10)
          }
        }
        .padding(.top, 20)

        TabView(selection: $currentStep) {
          WelcomeStep()
            .tag(0)

          MicrophonePermissionStep(
            granted: $microphoneGranted
          )
          .tag(1)

          AccessibilityPermissionStep(
            granted: $accessibilityGranted
          )
          .tag(2)

          HotkeyStep(
            selectedHotkey: $selectedHotkey,
            recordingHotkey: $recordingHotkey,
            selectedTriggerMode: $selectedTriggerMode
          )
          .tag(3)

          LanguageStep(selectedLanguage: $selectedLanguage)
            .tag(4)

          // B6: New model selection step
          ModelSelectionStep(
            selectedModel: $selectedOnboardingModel
          )
          .tag(5)

          ModelDownloadStep(
            downloadComplete: $modelDownloadComplete,
            downloadProgress: $modelDownloadProgress,
            downloadStatus: $modelDownloadStatus,
            modelFolderPath: $modelFolderPath,
            selectedModel: selectedOnboardingModel
          )
          .tag(6)

          ReadyStep()
            .tag(7)
        }
        .tabViewStyle(.automatic)
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        HStack(spacing: 20) {
          if currentStep > 0 {
            Button(action: { currentStep -= 1 }) {
              Text("Back")
                .frame(minWidth: 80)
            }
            .keyboardShortcut(.cancelAction)
          }

          Spacer()

          if currentStep < totalSteps - 1 {
            Button(action: { currentStep += 1 }) {
              Text("Next")
                .frame(minWidth: 80)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canProceedToNext())
          } else {
            Button(action: completeOnboarding) {
              Text("Start Using SoundVibe")
                .frame(minWidth: 150)
            }
            .keyboardShortcut(.defaultAction)
          }
        }
        .padding(.bottom, 20)
      }
      .padding(40)
    }
    .frame(width: 600, height: 700)
    .onAppear {
      checkMicrophonePermission()
    }
    .onDisappear {
      checkAccessibilityTimer?.invalidate()
    }
  }

  private func canProceedToNext() -> Bool {
    switch currentStep {
    case 1: return microphoneGranted
    case 2: return accessibilityGranted
    case 3: return !selectedHotkey.isEmpty
    case 6: return modelDownloadComplete
    default: return true
    }
  }

  private func checkMicrophonePermission() {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      microphoneGranted = true
    default:
      microphoneGranted = false
    }
  }

  private func completeOnboarding() {
    let settings = SettingsManager.shared
    settings.selectedLanguage = selectedLanguage.rawValue
    settings.triggerMode = selectedTriggerMode
    // B6: Save selected model
    settings.selectedModelSize = selectedOnboardingModel

    if !modelFolderPath.isEmpty {
      UserDefaults.standard.set(
        modelFolderPath,
        forKey: "soundvibe.whisperModelFolder"
      )
    }

    UserDefaults.standard.set(
      true,
      forKey: "SoundVibe_OnboardingCompleted"
    )

    NotificationCenter.default.post(
      name: NSNotification.Name(
        "SoundVibe_OnboardingCompleted"
      ),
      object: nil
    )
  }
}

// MARK: - Onboarding Steps

struct WelcomeStep: View {
  var body: some View {
    VStack(spacing: 30) {
      Spacer()

      Image(systemName: "waveform.circle.fill")
        .font(.system(size: 80))
        .foregroundColor(.blue)

      VStack(spacing: 12) {
        Text("Welcome to SoundVibe")
          .font(.title)
          .fontWeight(.bold)

        Text("Private, local dictation for macOS")
          .font(.title3)
          .foregroundColor(.secondary)
      }

      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          Image(systemName: "lock.fill")
            .foregroundColor(.green)
          Text(
            "100% private - all processing happens locally"
          )
        }

        HStack(spacing: 12) {
          Image(systemName: "hare.fill")
            .foregroundColor(.green)
          Text(
            "Fast and responsive with multiple model sizes"
          )
        }

        HStack(spacing: 12) {
          Image(systemName: "terminal.fill")
            .foregroundColor(.green)
          Text(
            "Supports multiple languages and "
              + "auto-punctuation"
          )
        }
      }
      .font(.body)

      Spacer()
    }
  }
}

struct MicrophonePermissionStep: View {
  @Binding var granted: Bool

  var body: some View {
    VStack(spacing: 30) {
      Spacer()

      VStack(spacing: 20) {
        Image(systemName: "mic.circle.fill")
          .font(.system(size: 80))
          .foregroundColor(.blue)

        Text("Microphone Access")
          .font(.title2)
          .fontWeight(.bold)

        Text(
          "SoundVibe needs access to your microphone "
            + "to record audio for transcription."
        )
        .multilineTextAlignment(.center)
        .foregroundColor(.secondary)
      }

      HStack(spacing: 12) {
        if granted {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
            .font(.system(size: 20))

          Text("Microphone access granted")
            .foregroundColor(.green)
        } else {
          Button(action: requestMicrophoneAccess) {
            HStack(spacing: 8) {
              Image(systemName: "mic.fill")
              Text("Grant Microphone Access")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(6)
          }
        }
      }

      Spacer()
    }
  }

  private func requestMicrophoneAccess() {
    AVCaptureDevice.requestAccess(for: .audio) { allowed in
      DispatchQueue.main.async {
        granted = allowed
      }
    }
  }
}

struct AccessibilityPermissionStep: View {
  @Binding var granted: Bool
  @State private var checkTimer: Timer?

  var body: some View {
    VStack(spacing: 30) {
      Spacer()

      VStack(spacing: 20) {
        Image(systemName: "hand.raised.circle.fill")
          .font(.system(size: 80))
          .foregroundColor(.blue)

        Text("Accessibility Permissions")
          .font(.title2)
          .fontWeight(.bold)

        Text(
          "SoundVibe needs accessibility permissions "
            + "to paste transcriptions into other "
            + "applications."
        )
        .multilineTextAlignment(.center)
        .foregroundColor(.secondary)
      }

      HStack(spacing: 12) {
        if granted {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
            .font(.system(size: 20))

          Text("Accessibility access granted")
            .foregroundColor(.green)
        } else {
          Button(action: openAccessibilitySettings) {
            HStack(spacing: 8) {
              Image(systemName: "lock.open.fill")
              Text("Grant Accessibility Access")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(6)
          }
        }
      }

      if !granted {
        Text(
          "1. Click the button above\n"
            + "2. System Settings will open to "
            + "Accessibility\n"
            + "3. Toggle SoundVibe ON in the list"
        )
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
      }

      Spacer()
    }
    .onAppear {
      startCheckingAccessibility()
    }
    .onDisappear {
      checkTimer?.invalidate()
    }
  }

  private func openAccessibilitySettings() {
    let options = [
      kAXTrustedCheckOptionPrompt
        .takeUnretainedValue(): true
    ] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)

    startCheckingAccessibility()
  }

  private func startCheckingAccessibility() {
    checkTimer = Timer.scheduledTimer(
      withTimeInterval: 0.5,
      repeats: true
    ) { _ in
      granted = AXIsProcessTrusted()
    }
  }
}

struct HotkeyStep: View {
  @Binding var selectedHotkey: String
  @Binding var recordingHotkey: Bool
  @Binding var selectedTriggerMode: TriggerMode
  @State private var eventMonitor: Any?
  @State private var recordedCombo: HotkeyCombo?

  var body: some View {
    VStack(spacing: 30) {
      Spacer()

      VStack(spacing: 20) {
        Image(systemName: "keyboard.circle.fill")
          .font(.system(size: 80))
          .foregroundColor(.blue)

        Text("Hotkey Setup")
          .font(.title2)
          .fontWeight(.bold)

        Text(
          "Choose how you want to activate "
            + "SoundVibe recording."
        )
        .multilineTextAlignment(.center)
        .foregroundColor(.secondary)
      }

      VStack(alignment: .leading, spacing: 16) {
        Text("Trigger Mode")
          .fontWeight(.semibold)

        Picker("", selection: $selectedTriggerMode) {
          Text("Hold to Talk (hold hotkey)")
            .tag(TriggerMode.holdToTalk)
          Text("Toggle (press to start/stop)")
            .tag(TriggerMode.toggle)
        }
        .pickerStyle(.radioGroup)
      }

      VStack(alignment: .leading, spacing: 16) {
        Text("Hotkey")
          .fontWeight(.semibold)

        Button(action: {
          if recordingHotkey {
            stopRecordingHotkey()
          } else {
            startRecordingHotkey()
          }
        }) {
          if recordingHotkey {
            HStack(spacing: 8) {
              ProgressView()
                .scaleEffect(0.8)
              Text(
                "Press your hotkey now... "
                  + "(Esc to cancel)"
              )
              .foregroundColor(.secondary)
            }
            .frame(
              maxWidth: .infinity,
              alignment: .leading
            )
            .padding()
            .background(
              Color.accentColor.opacity(0.15)
            )
            .cornerRadius(6)
          } else {
            HStack(spacing: 8) {
              Image(systemName: "keyboard")
              Text(
                selectedHotkey.isEmpty
                  ? "Click to record hotkey"
                  : selectedHotkey
              )
            }
            .frame(
              maxWidth: .infinity,
              alignment: .leading
            )
            .padding()
            .background(
              Color(.controlBackgroundColor)
            )
            .cornerRadius(6)
            .foregroundColor(.primary)
          }
        }

        if recordingHotkey {
          Text(
            "Press your desired key combination "
              + "(e.g., ⌥D, ⌘;)"
          )
          .font(.caption)
          .foregroundColor(.secondary)
        } else if !selectedHotkey.isEmpty {
          Text("Hotkey recorded: \(selectedHotkey)")
            .font(.caption)
            .foregroundColor(.green)
        }
      }

      Spacer()
    }
    .onDisappear {
      stopRecordingHotkey()
    }
  }

  private func startRecordingHotkey() {
    NSApp.activate(ignoringOtherApps: true)
    recordingHotkey = true

    eventMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.keyDown, .flagsChanged]
    ) { event in
      if event.type == .keyDown && event.keyCode == 53 {
        self.stopRecordingHotkey()
        return nil
      }

      if event.type == .flagsChanged {
        let code = UInt16(event.keyCode)
        guard HotkeyCombo.modifierKeyCodes.contains(code)
        else {
          return event
        }
        let combo = HotkeyCombo(from: event)
        self.recordedCombo = combo
        self.selectedHotkey = combo.displayString
        SettingsManager.shared.hotkey = combo
        self.stopRecordingHotkey()
        return nil
      }

      let combo = HotkeyCombo(from: event)
      self.recordedCombo = combo
      self.selectedHotkey = combo.displayString
      SettingsManager.shared.hotkey = combo
      self.stopRecordingHotkey()
      return nil
    }
  }

  private func stopRecordingHotkey() {
    recordingHotkey = false
    if let monitor = eventMonitor {
      NSEvent.removeMonitor(monitor)
      eventMonitor = nil
    }
  }
}

struct LanguageStep: View {
  @Binding var selectedLanguage: SupportedLanguage

  var body: some View {
    VStack(spacing: 30) {
      Spacer()

      VStack(spacing: 20) {
        Image(systemName: "globe.circle.fill")
          .font(.system(size: 80))
          .foregroundColor(.blue)

        Text("Language Selection")
          .font(.title2)
          .fontWeight(.bold)

        Text("Choose your primary transcription language.")
          .multilineTextAlignment(.center)
          .foregroundColor(.secondary)
      }

      Picker("Language", selection: $selectedLanguage) {
        ForEach(
          SupportedLanguage.allCases,
          id: \.self
        ) { language in
          Text(language.displayName).tag(language)
        }
      }
      .pickerStyle(.radioGroup)

      Spacer()
    }
  }
}

// MARK: - Model Selection Step (B6)

/// Onboarding step for choosing a Whisper model with
/// device-aware recommendation
struct ModelSelectionStep: View {
  @Binding var selectedModel: WhisperModelSize
  private let profile = DeviceProfiler.detectProfile()
  private let recommended = DeviceProfiler.recommendedModel()

  var body: some View {
    VStack(spacing: 20) {
      Spacer()

      VStack(spacing: 12) {
        Image(systemName: "cpu.fill")
          .font(.system(size: 60))
          .foregroundColor(.blue)

        Text("Choose Speech Model")
          .font(.title2)
          .fontWeight(.bold)

        Text(
          "Select a model based on your device. "
            + "Larger models are more accurate "
            + "but slower."
        )
        .multilineTextAlignment(.center)
        .foregroundColor(.secondary)
        .font(.body)
      }

      // Device info
      HStack(spacing: 16) {
        Label(
          profile.chipDescription,
          systemImage: "chip"
        )
        Label(
          profile.ramDescription,
          systemImage: "memorychip"
        )
        Label(
          profile.diskSpaceDescription + " free",
          systemImage: "internaldrive"
        )
      }
      .font(.caption)
      .foregroundColor(.secondary)

      // Model picker with ScrollView for overflow protection
      ScrollView {
        VStack(spacing: 8) {
          ForEach(
            WhisperModelSize.allCases,
            id: \.self
          ) { model in
            ModelSelectionRow(
              model: model,
              isSelected: selectedModel == model,
              isRecommended: model == recommended
            )
            .onTapGesture {
              selectedModel = model
            }
          }
        }
        .padding(.horizontal)
      }
      .frame(maxHeight: 300)

      Spacer()
    }
  }
}

/// A single row in the model selection list
private struct ModelSelectionRow: View {
  let model: WhisperModelSize
  let isSelected: Bool
  let isRecommended: Bool

  var body: some View {
    HStack(spacing: 12) {
      Image(
        systemName: isSelected
          ? "checkmark.circle.fill"
          : "circle"
      )
      .foregroundColor(isSelected ? .blue : .gray)
      .font(.system(size: 18))

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(model.rawValue.capitalized)
            .fontWeight(.medium)

          if isRecommended {
            Text("Recommended")
              .font(.caption2)
              .fontWeight(.semibold)
              .foregroundColor(.white)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.green)
              .cornerRadius(4)
          }
        }

        HStack(spacing: 8) {
          Text(model.diskSizeDescription)
            .font(.caption)
            .foregroundColor(.secondary)

          Text(model.speedRating)
            .font(.caption2)

          Text(model.accuracyRating)
            .font(.caption2)
        }

        Text(model.latencyDescription)
          .font(.caption2)
          .foregroundColor(.secondary)
      }

      Spacer()
    }
    .padding(10)
    .background(
      isSelected
        ? Color.blue.opacity(0.1)
        : Color(.controlBackgroundColor)
    )
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(
          isSelected ? Color.blue : Color.clear,
          lineWidth: 1.5
        )
    )
  }
}

struct ModelDownloadStep: View {
  @Binding var downloadComplete: Bool
  @Binding var downloadProgress: Double
  @Binding var downloadStatus: String
  @Binding var modelFolderPath: String

  // B6: Use the model selected in the previous step
  var selectedModel: WhisperModelSize

  @State private var isDownloading = false

  var body: some View {
    VStack(spacing: 30) {
      Spacer()

      VStack(spacing: 20) {
        Image(systemName: "arrow.down.circle.fill")
          .font(.system(size: 80))
          .foregroundColor(.blue)

        Text("Downloading Speech Model")
          .font(.title2)
          .fontWeight(.bold)

        Text("\(selectedModel.displayName)")
          .font(.body)
          .foregroundColor(.secondary)
      }

      VStack(spacing: 16) {
        ProgressView(value: downloadProgress, total: 1.0)
          .progressViewStyle(.linear)
          .frame(maxWidth: 300)

        Text(downloadStatus)
          .font(.subheadline)
          .foregroundColor(.secondary)

        if downloadComplete {
          HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.green)
            Text("Model ready!")
              .foregroundColor(.green)
          }
          .font(.headline)
        }

        Text(
          "\(Int(downloadProgress * 100))%"
        )
        .font(.caption)
        .foregroundColor(.secondary)
        .monospacedDigit()
      }

      Spacer()
    }
    .onAppear {
      if !isDownloading && !downloadComplete {
        startDownload()
      }
    }
  }

  private func startDownload() {
    isDownloading = true
    downloadStatus = "Downloading..."
    downloadProgress = 0.0

    let variant =
      "openai_whisper-\(selectedModel.rawValue)"
    let downloadBase = WhisperModelSize.modelsDirectory

    Task {
      do {
        try WhisperModelSize.ensureModelsDirectoryExists()

        let folderURL = try await WhisperKit.download(
          variant: variant,
          downloadBase: downloadBase
        ) { progress in
          DispatchQueue.main.async {
            self.downloadProgress = progress
              .fractionCompleted
            self.downloadStatus =
              "Downloading... "
              + "\(Int(progress.fractionCompleted * 100))%"
          }
        }

        await MainActor.run {
          downloadProgress = 1.0
          downloadStatus = "Download complete!"
          modelFolderPath = folderURL.path
          downloadComplete = true
          isDownloading = false
        }
      } catch {
        await MainActor.run {
          downloadStatus =
            "Error: \(error.localizedDescription)"
          isDownloading = false
        }
      }
    }
  }
}

struct ReadyStep: View {
  var body: some View {
    VStack(spacing: 30) {
      Spacer()

      VStack(spacing: 20) {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 80))
          .foregroundColor(.green)

        Text("You're All Set!")
          .font(.title2)
          .fontWeight(.bold)

        Text("SoundVibe is ready to use.")
          .multilineTextAlignment(.center)
          .foregroundColor(.secondary)
      }

      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          Image(systemName: "lightbulb.fill")
            .foregroundColor(.yellow)
          Text("Use your hotkey to start recording")
        }

        HStack(spacing: 12) {
          Image(systemName: "gearshape.fill")
            .foregroundColor(.gray)
          Text(
            "Adjust settings anytime via the menu bar"
          )
        }

        HStack(spacing: 12) {
          Image(systemName: "doc.text.fill")
            .foregroundColor(.blue)
          Text(
            "Your transcriptions appear in any "
              + "text field"
          )
        }
      }
      .font(.body)

      Spacer()
    }
  }
}

#endif
