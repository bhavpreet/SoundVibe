import Foundation

/// Manages a periodic chunk-transcription loop that runs concurrently with audio recording.
///
/// Every `config.chunkInterval` seconds, `StreamingTranscriptionSession` takes a snapshot
/// of the audio accumulated so far, slices the most recent `windowSize + overlapSize`
/// seconds, and calls `engine.transcribeStreaming(...)`. Confirmed segment text is
/// forwarded to the `onPreviewUpdate` closure for display in the floating indicator.
///
/// The final authoritative transcription is always produced by the orchestrator after
/// recording ends using the full audio buffer — this session is preview-only.
///
/// Thread-safety: An `actor`-based state guard ensures at most one chunk transcription
/// is in-flight at any time. If a cycle fires while a prior transcription is running,
/// that cycle is skipped entirely.
final class StreamingTranscriptionSession {

    // MARK: - Private State (actor-isolated)

    private actor State {
        var isTranscribing = false
        var accumulatedText = ""
        var lastSegmentSuffix = ""

        /// Whether any content has been accumulated
        var hasContent: Bool {
            !accumulatedText.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty
        }

        func beginTranscription() -> Bool {
            guard !isTranscribing else { return false }
            isTranscribing = true
            return true
        }

        func endTranscription() {
            isTranscribing = false
        }

        /// Appends new segment text, deduplicating overlap with previously accumulated text.
        /// Returns the updated accumulated text if new content was added, nil otherwise.
        func appendSegment(_ newSegment: String) -> String? {
            let trimmed = newSegment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            // Deduplication: check if the new segment starts with the suffix of
            // already-accumulated text (caused by the overlap window re-processing
            // audio that was already transcribed in the previous chunk).
            if !accumulatedText.isEmpty {
                // Find the longest suffix of accumulatedText that is a prefix of trimmed
                let overlapLength = longestOverlap(suffix: accumulatedText, prefix: trimmed)
                if overlapLength > 0 {
                    // Strip the overlapping prefix from the new segment
                    let index = trimmed.index(trimmed.startIndex, offsetBy: overlapLength)
                    let netNew = String(trimmed[index...]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if netNew.isEmpty { return nil }
                    accumulatedText += " " + netNew
                } else {
                    accumulatedText += " " + trimmed
                }
            } else {
                accumulatedText = trimmed
            }

            return accumulatedText
        }

        /// Finds the length of the longest suffix of `suffix` that matches a prefix of `prefix`.
        private func longestOverlap(suffix: String, prefix: String) -> Int {
            // Use word-level comparison for robustness (Whisper may add/remove trailing punctuation)
            let suffixWords = suffix.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            let prefixWords = prefix.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

            guard !suffixWords.isEmpty, !prefixWords.isEmpty else { return 0 }

            var bestOverlapCharCount = 0

            // Try matching the last N words of suffix with the first N words of prefix
            for overlapWordCount in 1...min(suffixWords.count, prefixWords.count, 8) {
                let suffixTail = Array(suffixWords.suffix(overlapWordCount))
                let prefixHead = Array(prefixWords.prefix(overlapWordCount))
                if suffixTail == prefixHead {
                    bestOverlapCharCount = prefixHead.joined(separator: " ").count
                }
            }

            return bestOverlapCharCount
        }
    }

    // MARK: - Properties

    private let engine: any TranscriptionEngine
    private let config: StreamingTranscriptionConfig
    private let language: String?
    private let detectLanguage: Bool
    private let onPreviewUpdate: @MainActor (String) -> Void

    private let internalState = State()
    private var loopTask: Task<Void, Never>?

    // MARK: - Initialization

    /// - Parameters:
    ///   - engine: The transcription engine to use for chunk transcription.
    ///   - config: Timing and windowing configuration.
    ///   - language: BCP-47 language code, or nil for auto-detection.
    ///   - detectLanguage: Whether to ask Whisper to detect the language.
    ///   - onPreviewUpdate: Called on the main actor with the accumulated preview text
    ///     after each segment is confirmed. Use this to update the floating indicator.
    init(
        engine: any TranscriptionEngine,
        config: StreamingTranscriptionConfig,
        language: String?,
        detectLanguage: Bool,
        onPreviewUpdate: @escaping @MainActor (String) -> Void
    ) {
        self.engine = engine
        self.config = config
        self.language = language
        self.detectLanguage = detectLanguage
        self.onPreviewUpdate = onPreviewUpdate
    }

    // MARK: - Public Interface

    /// Returns the current accumulated transcription text from all processed chunks.
    func accumulatedText() async -> String {
        await internalState.accumulatedText
    }

    /// Returns true if the session has accumulated any non-empty transcription.
    func hasContent() async -> Bool {
        await internalState.hasContent
    }

    /// Confirms the tail of the audio after recording stops.
    /// Extracts the last `windowSize` seconds, transcribes just that chunk,
    /// deduplicates with accumulated text, and returns the final result.
    func confirmTail(
        audioSamples: [Float]
    ) async throws -> TranscriptionResult {
        let sampleRate: Double = 16000
        let windowSamples = Int(config.windowSize * sampleRate)

        // Extract just the tail segment
        let tailSamples: [Float]
        if audioSamples.count <= windowSamples {
            tailSamples = audioSamples
        } else {
            let startIndex = audioSamples.count - windowSamples
            tailSamples = Array(audioSamples[startIndex...])
        }

        guard !tailSamples.isEmpty else {
            let text = await internalState.accumulatedText
            return TranscriptionResult(
                text: text, language: language, duration: 0
            )
        }

        let startTime = Date()

        // Transcribe the tail with the same options as streaming
        _ = try await engine.transcribeStreaming(
            audioData: tailSamples,
            language: language,
            detectLanguage: detectLanguage,
            onSegment: { [weak self] segmentText in
                guard let self else { return }
                Task {
                    _ = await self.internalState.appendSegment(segmentText)
                }
            }
        )

        let finalText = await internalState.accumulatedText
        let duration = Date().timeIntervalSince(startTime)

        return TranscriptionResult(
            text: finalText, language: language, duration: duration
        )
    }

    /// Starts the periodic transcription loop.
    ///
    /// - Parameter audioProvider: An async closure that returns the current accumulated
    ///   audio buffer as Float samples at 16kHz. Called on every chunk cycle.
    func start(audioProvider: @escaping () async -> [Float]) {
        loopTask = Task { [weak self] in
            guard let self else { return }
            await self.runLoop(audioProvider: audioProvider)
        }
    }

    /// Stops the periodic loop and waits for any in-flight transcription to finish.
    func stop() async {
        loopTask?.cancel()
        loopTask = nil
        // Give in-flight transcription a moment to settle before returning
        // so the caller doesn't race with an ongoing onPreviewUpdate dispatch.
        await Task.yield()
    }

    // MARK: - Private Loop

    private func runLoop(audioProvider: @escaping () async -> [Float]) async {
        let intervalNanos = UInt64(config.chunkInterval * 1_000_000_000)
        let sampleRate: Double = 16000
        let windowSamples = Int(config.windowSize * sampleRate)
        let overlapSamples = Int(config.overlapSize * sampleRate)
        let minSamples = Int(config.minAudioDuration * sampleRate)

        while !Task.isCancelled {
            // Wait for the chunk interval before first attempt too
            try? await Task.sleep(nanoseconds: intervalNanos)
            guard !Task.isCancelled else { break }

            // Skip if a prior transcription is still running
            let canProceed = await internalState.beginTranscription()
            guard canProceed else { continue }

            // Get the current audio snapshot
            let allSamples = await audioProvider()

            // Skip if we don't have enough audio yet
            guard allSamples.count >= minSamples else {
                await internalState.endTranscription()
                continue
            }

            // Slice the fixed sliding window (last windowSize + overlapSize seconds)
            let chunkSamples: [Float]
            if allSamples.count <= windowSamples + overlapSamples {
                chunkSamples = allSamples
            } else {
                let startIndex = allSamples.count - (windowSamples + overlapSamples)
                chunkSamples = Array(allSamples[startIndex...])
            }

            // Trim leading silence from chunk to reduce per-chunk inference time
            let trimmedChunk = AudioTrimmer.trimSilence(
                from: chunkSamples,
                sampleRate: sampleRate,
                threshold: 0.05,
                minSpeechDuration: 0.3,
                leadingMarginSeconds: 0.2,
                trailingMarginSeconds: 0.05
            ).samples

            // Run transcription concurrently (non-blocking for the loop).
            // Use [weak self] to avoid retaining the session past its stop() call.
            Task { [weak self] in
                guard let self else { return }
                defer {
                    Task { [weak self] in await self?.internalState.endTranscription() }
                }

                guard !Task.isCancelled else { return }

                do {
                    _ = try await self.engine.transcribeStreaming(
                        audioData: trimmedChunk,
                        language: self.language,
                        detectLanguage: self.detectLanguage,
                        onSegment: { [weak self] segmentText in
                            guard let self else { return }
                            let onPreviewUpdate = self.onPreviewUpdate
                            Task { [weak self] in
                                guard let self else { return }
                                if let updated = await self.internalState.appendSegment(segmentText) {
                                    let previewText = updated
                                    await MainActor.run {
                                        onPreviewUpdate(previewText)
                                    }
                                }
                            }
                        }
                    )
                } catch {
                    // Silently swallow chunk errors — the final transcription
                    // in the orchestrator is the authoritative result.
                }
            }
        }
    }
}
