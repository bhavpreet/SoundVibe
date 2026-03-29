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

    /// Active streaming transcription session (preview-only, runs during recording).
    private var streamingSession: StreamingTranscriptionSession?

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

                // Start streaming preview if enabled
                startStreamingSession()
            } catch {
                NSLog("[SoundVibe] Audio capture failed: \(error)")
                let msg = error.localizedDescription
                updateState(.error(msg))
                menuBarManager.updateState(.error)
                floatingIndicatorManager.showError(message: msg)
                playSoundFeedback(.error)
                stopAudioLevelPolling()
                stopSilenceMonitoring()
                streamingSession = nil
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

        // NOTE: Stop sound is deferred to finalizeStopDictation()
        // to avoid the "Pop" being captured by the microphone
        // during the tail recording window.

        tailRecordingTask = Task {
            // VAD-based early cutoff: poll audio level during tail window
            // and stop early if silence is detected
            let tailDelay = settingsManager.tailRecordingDelay
            let useVAD = settingsManager.vadEarlyStopEnabled
            let silenceThreshold: Float = 0.05
            let silenceRequiredMs: Int = 200
            let pollIntervalNs: UInt64 = 50_000_000 // 50ms

            if useVAD {
                let totalPolls = Int(tailDelay / 0.05)
                var consecutiveSilentPolls = 0
                let silencePolls = silenceRequiredMs / 50

                for _ in 0..<totalPolls {
                    try? await Task.sleep(nanoseconds: pollIntervalNs)
                    guard !Task.isCancelled else { return }

                    let level = await audioCapture.smoothedAudioLevel
                    if level < silenceThreshold {
                        consecutiveSilentPolls += 1
                        if consecutiveSilentPolls >= silencePolls {
                            // Silence detected — stop early
                            break
                        }
                    } else {
                        consecutiveSilentPolls = 0
                    }
                }
            } else {
                // Fixed timer fallback
                try? await Task.sleep(
                    nanoseconds: UInt64(tailDelay * 1_000_000_000)
                )
            }

            guard !Task.isCancelled else { return }
            await finalizeStopDictation()
        }
    }

    /// Immediately stops recording and processes audio.
    private func finalizeStopDictation() async {
        isRecording = false
        stopAudioLevelPolling()
        stopSilenceMonitoring()

        // Keep a reference — do NOT stop the streaming session yet
        // so we can use confirmTail() if streaming-as-final is enabled.
        let activeStreamingSession = streamingSession

        let audioSamples = await audioCapture.stopCapture()

        // A6: Play stop sound AFTER capture is fully stopped so the
        // "Pop" doesn't contaminate the recorded audio.
        playSoundFeedback(.stop)

        logger.debug(
            "Audio capture stopped, captured \(audioSamples.count) samples"
        )

        guard !audioSamples.isEmpty else {
            logger.warning("No audio was captured")
            let msg = "No audio captured. Please try speaking again."
            await activeStreamingSession?.stop()
            streamingSession = nil
            updateState(.error(msg))
            menuBarManager.updateState(.error)
            floatingIndicatorManager.showError(message: msg)
            playSoundFeedback(.error)
            return
        }

        if settingsManager.showFloatingIndicator {
            floatingIndicatorManager.showProcessing()
        }

        // Try streaming-as-final strategy
        if settingsManager.useStreamingAsFinal,
           let session = activeStreamingSession,
           await session.hasContent()
        {
            do {
                let streamingResult = try await session.confirmTail(
                    audioSamples: audioSamples
                )

                // Quality heuristic: check result isn't too short
                // or hallucinated
                let text = streamingResult.text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count >= 3 {
                    // Stop streaming session now
                    await session.stop()
                    streamingSession = nil

                    // Use streaming result directly
                    await performTranscriptionPipeline(
                        audioSamples: audioSamples,
                        streamingResult: streamingResult
                    )
                    return
                } else {
                    NSLog(
                        "[SoundVibe] Streaming result too short "
                        + "(\(text.count) chars), falling back"
                    )
                }
            } catch {
                NSLog(
                    "[SoundVibe] confirmTail failed: "
                    + "\(error.localizedDescription), falling back"
                )
            }
        }

        // Fallback: stop streaming session and do full re-transcription
        await activeStreamingSession?.stop()
        streamingSession = nil

        await performTranscriptionPipeline(audioSamples: audioSamples)
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

        // Re-start streaming session if it was stopped during tail window
        if streamingSession == nil {
            startStreamingSession()
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

        let session = streamingSession
        streamingSession = nil
        Task {
            await session?.stop()
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

    /// Creates and starts a streaming transcription session if enabled in settings.
    private func startStreamingSession() {
        guard settingsManager.streamingTranscriptionEnabled,
              settingsManager.showFloatingIndicator,
              transcriptionEngine.isModelLoaded else { return }

        floatingIndicatorManager.clearLivePreview()

        let config = StreamingTranscriptionConfig(
            chunkInterval: settingsManager.streamingChunkInterval
        )
        let lang = settingsManager.autoLanguageDetection ? nil : settingsManager.selectedLanguage
        let detectLang = settingsManager.autoLanguageDetection

        let session = StreamingTranscriptionSession(
            engine: transcriptionEngine,
            config: config,
            language: lang,
            detectLanguage: detectLang,
            onPreviewUpdate: { [weak self] text in
                self?.floatingIndicatorManager.updateLivePreview(text)
            }
        )

        streamingSession = session
        session.start(audioProvider: { [weak self] in
            await self?.audioCapture.captureSnapshot() ?? []
        })
    }

    private func performTranscriptionPipeline(
        audioSamples: [Float],
        streamingResult: TranscriptionResult? = nil
    ) async {
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

            let durationSec = Double(audioSamples.count) / 16000.0
            NSLog(
                "[SoundVibe] Transcribing \(audioSamples.count)"
                + " samples (\(String(format: "%.1f", durationSec))s)"
            )

            // Trim leading/trailing silence if enabled
            let samplesToTranscribe: [Float]
            if settingsManager.vadTrimEnabled, streamingResult == nil {
                let trimResult = AudioTrimmer.trimSilence(
                    from: audioSamples, sampleRate: 16000
                )
                NSLog("[SoundVibe] Audio trim: \(trimResult.logSummary)")
                samplesToTranscribe = trimResult.samples
            } else {
                samplesToTranscribe = audioSamples
            }

            // Pre-transcription check: skip if audio has insufficient
            // speech energy (would likely produce hallucinations)
            if streamingResult == nil,
               !TranscriptionFilter.hasSufficientSpeech(
                   in: samplesToTranscribe
               )
            {
                NSLog(
                    "[SoundVibe] Audio has insufficient speech energy"
                    + " — skipping transcription"
                )
                updateState(.idle)
                menuBarManager.updateState(.idle)
                if settingsManager.showFloatingIndicator {
                    floatingIndicatorManager.showError(
                        message: "No speech detected"
                    )
                }
                return
            }

            // Use streaming result if provided, otherwise full re-transcription
            let transcriptionResult: TranscriptionResult
            if let streaming = streamingResult {
                NSLog("[SoundVibe] Using streaming-as-final result")
                transcriptionResult = streaming
            } else {
                transcriptionResult = try await transcriptionEngine.transcribe(
                    audioData: samplesToTranscribe,
                    language: settingsManager.autoLanguageDetection
                        ? nil : settingsManager.selectedLanguage,
                    detectLanguage: settingsManager.autoLanguageDetection
                )
            }
            NSLog(
                "[SoundVibe] Transcription: "
                + "\"\(transcriptionResult.text)\""
            )

            // Post-transcription check: filter hallucinated output
            if TranscriptionFilter.isHallucination(
                transcriptionResult.text
            ) {
                NSLog(
                    "[SoundVibe] Hallucination filtered: "
                    + "\"\(transcriptionResult.text)\""
                )
                updateState(.idle)
                menuBarManager.updateState(.idle)
                if settingsManager.showFloatingIndicator {
                    floatingIndicatorManager.showError(
                        message: "No speech detected"
                    )
                }
                return
            }

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
            floatingIndicatorManager.clearLivePreview()

            updateState(.idle)
            menuBarManager.updateState(.idle)

        } catch {
            let msg = error.localizedDescription
            NSLog("[SoundVibe] Pipeline error: \(msg)")
            NSLog("[SoundVibe] Error type: \(type(of: error))")
            logger.error("Pipeline error: \(msg)")
            streamingSession = nil
            floatingIndicatorManager.clearLivePreview()
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
