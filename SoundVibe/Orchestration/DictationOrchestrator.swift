import Foundation
import Combine
import AVFoundation

#if os(macOS)
import AppKit
#endif

// MARK: - Dictation State Enum

/// Represents the current state of the dictation system
enum DictationState: Equatable {
    case idle
    case warmingUp
    case listening
    case finishing
    case transcribing
    case postProcessing
    case inserting
    case error(String)

    var isActive: Bool {
        switch self {
        case .idle, .error:
            return false
        case .warmingUp, .listening, .finishing,
             .transcribing, .postProcessing, .inserting:
            return true
        }
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }

    var displayDescription: String {
        switch self {
        case .idle: return "idle"
        case .warmingUp: return "warmingUp"
        case .listening: return "listening"
        case .finishing: return "finishing"
        case .transcribing: return "transcribing"
        case .postProcessing: return "postProcessing"
        case .inserting: return "inserting"
        case .error(let msg): return "error(\(msg))"
        }
    }
}

// MARK: - Dictation Orchestrator

/// Central coordinator that orchestrates the entire dictation workflow.
/// Manages the flow from audio capture through transcription, post-processing, and text insertion.
#if os(macOS)
@MainActor
final class DictationOrchestrator: NSObject, ObservableObject, HotkeyManagerDelegate {
    // MARK: - Published Properties

    @Published private(set) var state: DictationState = .idle
    @Published private(set) var lastTranscription: String?
    @Published private(set) var recentTranscriptions: [String] = []

    // MARK: - Private Properties

    private let audioCapture: AudioCaptureManager
    private let transcriptionEngine: any TranscriptionEngine
    private let postProcessingPipeline: PostProcessingPipeline
    private let textInsertion: TextInsertionEngine
    private let settingsManager: SettingsManager
    private let hotkeyManager: HotkeyManager
    private let menuBarManager: MenuBarManager
    private let floatingIndicatorManager: FloatingIndicatorManager
    private let silenceDetector: SilenceDetector
    private let logger = Logger(
        subsystem: "com.soundvibe.orchestrator",
        category: "Orchestrator"
    )

    private var isRecording = false
    private var audioTask: Task<Void, Never>?
    private var audioLevelTask: Task<Void, Never>?
    private var silenceMonitorTask: Task<Void, Never>?

    /// Duration to keep recording after hotkey release (A2)
    private let tailRecordingDelay: TimeInterval = 1.5

    /// Task for the tail recording delay timer (A2)
    private var tailRecordingTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        audioCapture: AudioCaptureManager,
        transcriptionEngine: any TranscriptionEngine,
        postProcessingPipeline: PostProcessingPipeline,
        textInsertion: TextInsertionEngine,
        settingsManager: SettingsManager,
        hotkeyManager: HotkeyManager,
        menuBarManager: MenuBarManager,
        floatingIndicatorManager: FloatingIndicatorManager,
        silenceDetector: SilenceDetector = SilenceDetector()
    ) {
        self.audioCapture = audioCapture
        self.transcriptionEngine = transcriptionEngine
        self.postProcessingPipeline = postProcessingPipeline
        self.textInsertion = textInsertion
        self.settingsManager = settingsManager
        self.hotkeyManager = hotkeyManager
        self.menuBarManager = menuBarManager
        self.floatingIndicatorManager = floatingIndicatorManager
        self.silenceDetector = silenceDetector

        super.init()

        // Delegate is set by AppDelegate after construction
        logger.debug("DictationOrchestrator initialized")
    }

    // MARK: - Public Methods

    func startDictation() {
        NSLog(
            "[SoundVibe] startDictation() called, "
            + "state=\(state.displayDescription)"
        )

        guard !isRecording else {
            NSLog("[SoundVibe] Already recording, ignoring")
            return
        }

        // Allow restarting from error state (recovery)
        guard state == .idle || state.isError else {
            NSLog(
                "[SoundVibe] Cannot start in state: "
                + "\(state.displayDescription)"
            )
            return
        }

        isRecording = true

        // A1: Start audio BEFORE showing indicator (warmingUp)
        updateState(.warmingUp)
        menuBarManager.updateState(.listening)

        if settingsManager.showFloatingIndicator {
            floatingIndicatorManager.showWarmingUp()
        }

        // A6: Play start sound
        playSoundFeedback(.start)

        audioTask = Task {
            do {
                try await audioCapture.startCapture()
                NSLog("[SoundVibe] Audio capture started")

                // Transition from warmingUp → listening
                updateState(.listening)
                if settingsManager.showFloatingIndicator {
                    floatingIndicatorManager.showListening()
                }
            } catch {
                NSLog("[SoundVibe] Audio capture failed: \(error)")
                let msg = error.localizedDescription
                updateState(.error(msg))
                menuBarManager.updateState(.error)
                floatingIndicatorManager.showError(message: msg)
                playSoundFeedback(.error)
                stopAudioLevelPolling()
                stopSilenceMonitoring()
                isRecording = false
            }
        }

        // Poll audio levels at ~20Hz
        startAudioLevelPolling()

        // A5: Start silence monitoring
        startSilenceMonitoring()
    }

    func stopDictation() {
        NSLog(
            "[SoundVibe] stopDictation() called, "
            + "isRecording=\(isRecording)"
        )

        guard isRecording else {
            NSLog("[SoundVibe] Not recording, ignoring stop")
            return
        }

        // A2: Enter finishing state with tail recording delay
        updateState(.finishing)
        if settingsManager.showFloatingIndicator {
            floatingIndicatorManager.showFinishing()
        }

        // A6: Play stop sound
        playSoundFeedback(.stop)

        tailRecordingTask = Task {
            // Keep recording for tail delay
            try? await Task.sleep(
                nanoseconds: UInt64(tailRecordingDelay * 1_000_000_000)
            )

            guard !Task.isCancelled else { return }
            await finalizeStopDictation()
        }
    }

    /// Immediately stops recording and processes audio.
    private func finalizeStopDictation() async {
        isRecording = false
        stopAudioLevelPolling()
        stopSilenceMonitoring()

        let audioData = await audioCapture.stopCapture()
        logger.debug(
            "Audio capture stopped, captured \(audioData.count) bytes"
        )

        guard !audioData.isEmpty else {
            logger.warning("No audio was captured")
            let msg = "No audio captured. Please try speaking again."
            updateState(.error(msg))
            menuBarManager.updateState(.error)
            floatingIndicatorManager.showError(message: msg)
            playSoundFeedback(.error)
            return
        }

        if settingsManager.showFloatingIndicator {
            floatingIndicatorManager.showProcessing()
        }

        await performTranscriptionPipeline(audioData: audioData)
    }

    /// Resumes recording if re-pressed during tail window (A2).
    func resumeRecording() {
        guard state == .finishing else { return }

        NSLog("[SoundVibe] Resuming recording during tail window")

        // Cancel the tail timer
        tailRecordingTask?.cancel()
        tailRecordingTask = nil

        // Reset silence detector to avoid false warnings
        Task { await silenceDetector.reset() }

        // Return to listening state
        updateState(.listening)
        if settingsManager.showFloatingIndicator {
            floatingIndicatorManager.showListening()
        }

        // A6: Play start sound for resume
        playSoundFeedback(.start)
    }

    func cancelDictation() {
        logger.debug("cancelDictation() called")

        guard isRecording else { return }

        isRecording = false
        stopAudioLevelPolling()
        stopSilenceMonitoring()
        tailRecordingTask?.cancel()
        tailRecordingTask = nil
        audioTask?.cancel()
        audioTask = nil

        Task {
            _ = await audioCapture.stopCapture()
        }
        updateState(.idle)
        menuBarManager.updateState(.idle)
        floatingIndicatorManager.hide()
    }

    // MARK: - Audio Level Polling

    /// Polls the audio capture manager's smoothed RMS level at ~20Hz
    /// and pushes values to the floating indicator waveform.
    private func startAudioLevelPolling() {
        audioLevelTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                let level = await self.audioCapture.smoothedAudioLevel
                self.floatingIndicatorManager.updateAudioLevel(level)
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
    }

    private func stopAudioLevelPolling() {
        audioLevelTask?.cancel()
        audioLevelTask = nil
    }

    // MARK: - Silence Monitoring (A5)

    private func startSilenceMonitoring() {
        let threshold = settingsManager.silenceTimeout
        silenceMonitorTask = Task { [weak self] in
            var hasWarnedSilence = false
            while !Task.isCancelled {
                guard let self = self else { break }

                // Only monitor during active listening
                guard self.state == .listening else {
                    try? await Task.sleep(
                        nanoseconds: 100_000_000
                    )
                    continue
                }

                let level = await self.audioCapture
                    .smoothedAudioLevel
                let isSilent = await self.silenceDetector
                    .update(level: level, threshold: 0.05)

                let silenceDuration = await self.silenceDetector
                    .silenceDuration

                if isSilent && silenceDuration > threshold
                    && !hasWarnedSilence
                {
                    self.floatingIndicatorManager
                        .showSilenceWarning()
                    hasWarnedSilence = true
                } else if !isSilent {
                    // Reset warning flag when audio resumes
                    if hasWarnedSilence {
                        hasWarnedSilence = false
                        if self.settingsManager
                            .showFloatingIndicator
                        {
                            self.floatingIndicatorManager
                                .showListening()
                        }
                    }
                }

                try? await Task.sleep(
                    nanoseconds: 100_000_000
                ) // 100ms
            }
        }
    }

    private func stopSilenceMonitoring() {
        silenceMonitorTask?.cancel()
        silenceMonitorTask = nil
        Task {
            await silenceDetector.reset()
        }
    }

    // MARK: - Sound Feedback (A6)

    private enum SoundFeedbackType {
        case start
        case stop
        case error
    }

    private func playSoundFeedback(_ type: SoundFeedbackType) {
        guard settingsManager.soundFeedbackEnabled else { return }

        let soundName: String
        switch type {
        case .start: soundName = "Tink"
        case .stop: soundName = "Pop"
        case .error: soundName = "Basso"
        }

        NSSound(named: NSSound.Name(soundName))?.play()
    }

    // MARK: - Private Methods

    private func performTranscriptionPipeline(audioData: Data) async {
        do {
            updateState(.transcribing)

            // Check if model is loaded before trying to transcribe
            guard transcriptionEngine.isModelLoaded else {
                NSLog("[SoundVibe] Model not loaded yet — still downloading")
                let msg = "Whisper model is still downloading. Please wait."
                updateState(.error(msg))
                menuBarManager.updateState(.error)
                floatingIndicatorManager.showError(message: msg)
                return
            }

            let audioSamples = convertDataToFloatArray(audioData)
            let durationSec = Double(audioSamples.count) / 16000.0
            NSLog(
                "[SoundVibe] Transcribing \(audioSamples.count)"
                + " samples (\(String(format: "%.1f", durationSec))s)"
            )

            let transcriptionResult = try await transcriptionEngine.transcribe(
                audioData: audioSamples,
                language: settingsManager.autoLanguageDetection ? nil : settingsManager.selectedLanguage,
                detectLanguage: settingsManager.autoLanguageDetection
            )
            NSLog("[SoundVibe] Transcription: \"\(transcriptionResult.text)\"")

            updateState(.postProcessing)
            let processedText = try await postProcessingPipeline.process(
                transcriptionResult.text,
                settings: settingsManager
            )

            updateState(.inserting)
            try await textInsertion.insertText(
                processedText,
                restoreClipboard: settingsManager.clipboardRestoreEnabled,
                pasteDelay: settingsManager.pasteDelay,
                restoreDelay: 0.1
            )

            lastTranscription = processedText
            addRecentTranscription(processedText)
            menuBarManager.addRecentTranscription(processedText)

            if settingsManager.showFloatingIndicator {
                floatingIndicatorManager.showSuccess()
            }

            updateState(.idle)
            menuBarManager.updateState(.idle)

        } catch {
            let msg = error.localizedDescription
            NSLog("[SoundVibe] Pipeline error: \(msg)")
            NSLog("[SoundVibe] Error type: \(type(of: error))")
            logger.error("Pipeline error: \(msg)")
            updateState(.error(msg))
            menuBarManager.updateState(.error)
            floatingIndicatorManager.showError(message: msg)
            playSoundFeedback(.error)
        }
    }

    private func updateState(_ newState: DictationState) {
        state = newState
    }

    private func addRecentTranscription(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        recentTranscriptions.insert(trimmed, at: 0)
        if recentTranscriptions.count > 10 {
            recentTranscriptions.removeLast()
        }
    }

    private func convertDataToFloatArray(_ data: Data) -> [Float] {
        let int16Array = data.withUnsafeBytes { buffer -> [Int16] in
            Array(buffer.bindMemory(to: Int16.self))
        }
        return int16Array.map { Float($0) / 32768.0 }
    }

    // MARK: - HotkeyManagerDelegate

    nonisolated func hotkeyPressed() {
        Task { @MainActor in
            // A7: Check typing cooldown for hold-to-talk mode
            if self.settingsManager.triggerMode == .holdToTalk
                && self.settingsManager.typingCooldownEnabled
                && self.hotkeyManager.isBlockedByTypingCooldown()
            {
                NSLog(
                    "[SoundVibe] Hotkey blocked by typing cooldown"
                )
                return
            }

            switch self.settingsManager.triggerMode {
            case .holdToTalk:
                // A2: If finishing, resume instead of starting new
                if self.state == .finishing {
                    self.resumeRecording()
                } else {
                    self.startDictation()
                }
            case .toggle:
                if self.isRecording {
                    self.stopDictation()
                } else {
                    self.startDictation()
                }
            }
        }
    }

    nonisolated func hotkeyReleased() {
        Task { @MainActor in
            guard self.settingsManager.triggerMode == .holdToTalk
            else { return }
            self.stopDictation()
        }
    }
}
#endif
