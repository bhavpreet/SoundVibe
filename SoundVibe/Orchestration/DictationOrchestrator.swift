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
    case listening
    case transcribing
    case postProcessing
    case inserting
    case error(String)

    var isActive: Bool {
        switch self {
        case .idle, .error:
            return false
        case .listening, .transcribing, .postProcessing, .inserting:
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
        case .listening: return "listening"
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
    private let logger = Logger(subsystem: "com.soundvibe.orchestrator", category: "Orchestrator")

    private var isRecording = false
    private var audioTask: Task<Void, Never>?
    private var audioLevelTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        audioCapture: AudioCaptureManager,
        transcriptionEngine: any TranscriptionEngine,
        postProcessingPipeline: PostProcessingPipeline,
        textInsertion: TextInsertionEngine,
        settingsManager: SettingsManager,
        hotkeyManager: HotkeyManager,
        menuBarManager: MenuBarManager,
        floatingIndicatorManager: FloatingIndicatorManager
    ) {
        self.audioCapture = audioCapture
        self.transcriptionEngine = transcriptionEngine
        self.postProcessingPipeline = postProcessingPipeline
        self.textInsertion = textInsertion
        self.settingsManager = settingsManager
        self.hotkeyManager = hotkeyManager
        self.menuBarManager = menuBarManager
        self.floatingIndicatorManager = floatingIndicatorManager

        super.init()

        // Delegate is set by AppDelegate after construction
        logger.debug("DictationOrchestrator initialized")
    }

    // MARK: - Public Methods

    func startDictation() {
        NSLog("[SoundVibe] startDictation() called, state=\(state.displayDescription)")

        guard !isRecording else {
            NSLog("[SoundVibe] Already recording, ignoring")
            return
        }

        // Allow restarting from error state (recovery)
        guard state == .idle || state.isError else {
            NSLog("[SoundVibe] Cannot start in state: \(state.displayDescription)")
            return
        }

        isRecording = true
        updateState(.listening)
        menuBarManager.updateState(.listening)

        if settingsManager.showFloatingIndicator {
            floatingIndicatorManager.showListening()
        }

        audioTask = Task {
            do {
                try await audioCapture.startCapture()
                NSLog("[SoundVibe] Audio capture started")
            } catch {
                NSLog("[SoundVibe] Audio capture failed: \(error)")
                updateState(.error(error.localizedDescription))
                menuBarManager.updateState(.error)
                floatingIndicatorManager.showError()
                isRecording = false
            }
        }

        // Poll audio levels at ~20Hz and push to the floating indicator
        startAudioLevelPolling()
    }

    func stopDictation() {
        NSLog("[SoundVibe] stopDictation() called, isRecording=\(isRecording)")

        guard isRecording else {
            NSLog("[SoundVibe] Not recording, ignoring stop")
            return
        }

        isRecording = false
        stopAudioLevelPolling()

        audioTask = Task {
            let audioData = await audioCapture.stopCapture()
            logger.debug("Audio capture stopped, captured \(audioData.count) bytes")

            guard !audioData.isEmpty else {
                logger.warning("No audio was captured")
                updateState(.error("No audio captured. Please try speaking again."))
                menuBarManager.updateState(.error)
                floatingIndicatorManager.showError()
                return
            }

            if settingsManager.showFloatingIndicator {
                floatingIndicatorManager.showProcessing()
            }

            await performTranscriptionPipeline(audioData: audioData)
        }
    }

    func cancelDictation() {
        logger.debug("cancelDictation() called")

        guard isRecording else { return }

        isRecording = false
        stopAudioLevelPolling()
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

    /// Polls the audio capture manager's RMS level at ~20Hz
    /// and pushes values to the floating indicator waveform.
    private func startAudioLevelPolling() {
        audioLevelTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                let level = await self.audioCapture.audioLevel
                self.floatingIndicatorManager.updateAudioLevel(level)
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            }
        }
    }

    private func stopAudioLevelPolling() {
        audioLevelTask?.cancel()
        audioLevelTask = nil
    }

    // MARK: - Private Methods

    private func performTranscriptionPipeline(audioData: Data) async {
        do {
            updateState(.transcribing)

            // Check if model is loaded before trying to transcribe
            guard transcriptionEngine.isModelLoaded else {
                NSLog("[SoundVibe] Model not loaded yet — still downloading")
                updateState(.error("Whisper model is still downloading. Please wait."))
                menuBarManager.updateState(.error)
                floatingIndicatorManager.showError()
                return
            }

            let audioSamples = convertDataToFloatArray(audioData)
            NSLog("[SoundVibe] Transcribing \(audioSamples.count) samples (\(String(format: "%.1f", Double(audioSamples.count) / 16000.0))s audio)")

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
            floatingIndicatorManager.showError()
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
            switch settingsManager.triggerMode {
            case .holdToTalk:
                self.startDictation()
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
            guard settingsManager.triggerMode == .holdToTalk else { return }
            self.stopDictation()
        }
    }
}
#endif
