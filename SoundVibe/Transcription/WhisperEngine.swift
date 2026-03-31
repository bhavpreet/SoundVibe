import Foundation
import WhisperKit

// MARK: - Errors

/// Errors that can occur during transcription
public enum WhisperError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(reason: String)
    case transcriptionFailed(reason: String)
    case invalidAudioData
    case cancelled
    case audioProcessingFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Whisper model is not loaded"
        case .modelLoadFailed(let reason):
            return "Failed to load Whisper model: \(reason)"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .invalidAudioData:
            return "Invalid or corrupted audio data"
        case .cancelled:
            return "Transcription was cancelled"
        case .audioProcessingFailed(let reason):
            return "Audio processing failed: \(reason)"
        }
    }
}

// MARK: - Protocol Definition

/// Callback type for receiving individual transcription segments as they are produced.
/// Called on an arbitrary background thread; dispatch to main actor for UI updates.
public typealias SegmentCallback = @Sendable (String) -> Void

/// Abstraction for transcription engines (allows swapping implementations)
public protocol TranscriptionEngine: AnyObject {
    func loadModel(at path: String) throws
    func loadModel(variant: String) async throws
    func transcribe(
        audioData: [Float],
        language: String?,
        detectLanguage: Bool
    ) async throws -> TranscriptionResult
    /// Transcribes audio data, calling `onSegment` for each confirmed segment as it is decoded.
    /// Conformers that do not override this fall back to a single-shot transcription.
    func transcribeStreaming(
        audioData: [Float],
        language: String?,
        detectLanguage: Bool,
        onSegment: @escaping SegmentCallback
    ) async throws -> TranscriptionResult
    var isModelLoaded: Bool { get }
    var currentModelPath: String? { get }
    func unloadModel()
}

// Default implementation so existing callers compile
extension TranscriptionEngine {
    public func loadModel(variant: String) async throws {
        throw WhisperError.modelLoadFailed(
            reason: "Variant-based loading not supported"
        )
    }

    /// Default streaming implementation: runs standard transcription and invokes
    /// `onSegment` once with the complete result text.
    public func transcribeStreaming(
        audioData: [Float],
        language: String?,
        detectLanguage: Bool,
        onSegment: @escaping SegmentCallback
    ) async throws -> TranscriptionResult {
        let result = try await transcribe(
            audioData: audioData,
            language: language,
            detectLanguage: detectLanguage
        )
        onSegment(result.text)
        return result
    }
}

// MARK: - WhisperEngine (Real WhisperKit Implementation)

/// Production implementation of TranscriptionEngine using WhisperKit.
/// WhisperKit uses CoreML-optimized Whisper models on Apple Silicon.
public class WhisperEngine: TranscriptionEngine, @unchecked Sendable {

    private var whisperKit: WhisperKit?
    private let operationQueue = DispatchQueue(
        label: "com.soundvibe.whisper-engine",
        qos: .userInitiated
    )

    public private(set) var isModelLoaded: Bool = false
    public private(set) var currentModelPath: String?

    public init() {}

    // MARK: - Model Loading

    /// Load a WhisperKit model by variant name (e.g. "base", "small").
    /// WhisperKit auto-downloads the CoreML model from HuggingFace
    /// into the app's Application Support directory.
    public func loadModel(variant: String) async throws {
        do {
            let downloadBase = WhisperModelSize.modelsDirectory
            try WhisperModelSize.ensureModelsDirectoryExists()

            // Resolve the WhisperKit model identifier from the variant string.
            // Use the centralized whisperKitIdentifier to handle naming quirks
            // (e.g. large-v3_turbo uses underscore, not hyphen, in the hub).
            let modelIdentifier: String
            if let modelSize = WhisperModelSize(rawValue: variant) {
                modelIdentifier = modelSize.whisperKitIdentifier
            } else {
                modelIdentifier = "openai_whisper-\(variant)"
            }

            let config = WhisperKitConfig(
                model: modelIdentifier,
                downloadBase: downloadBase,
                tokenizerFolder: downloadBase,
                verbose: false,
                logLevel: .none,
                prewarm: true,
                load: true
            )
            let kit = try await WhisperKit(config)
            self.whisperKit = kit
            self.isModelLoaded = true
            self.currentModelPath = kit.modelFolder?.path
        } catch {
            throw WhisperError.modelLoadFailed(
                reason: error.localizedDescription
            )
        }
    }

    /// Load from a local path. For compatibility with the protocol.
    /// With WhisperKit, use `loadModel(variant:)` instead.
    public func loadModel(at path: String) throws {
        // WhisperKit needs async loading; this sync version
        // sets a placeholder that the caller should replace
        // with the async variant.
        currentModelPath = path
    }

    /// Load a pre-downloaded model from a local folder path.
    /// Skips model downloading — the model must already exist on disk.
    /// The tokenizer may still be fetched on first load and is stored
    /// alongside the model inside Application Support.
    public func loadModel(fromFolder path: String) async throws {
        do {
            let downloadBase = WhisperModelSize.modelsDirectory
            try WhisperModelSize.ensureModelsDirectoryExists()

            let config = WhisperKitConfig(
                downloadBase: downloadBase,
                modelFolder: path,
                tokenizerFolder: downloadBase,
                verbose: false,
                logLevel: .none,
                prewarm: true,
                load: true,
                download: false
            )
            let kit = try await WhisperKit(config)
            self.whisperKit = kit
            self.isModelLoaded = true
            self.currentModelPath = path
        } catch {
            throw WhisperError.modelLoadFailed(
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Transcription

    public func transcribe(
        audioData: [Float],
        language: String? = nil,
        detectLanguage: Bool = true
    ) async throws -> TranscriptionResult {
        guard let whisperKit = whisperKit, isModelLoaded else {
            throw WhisperError.modelNotLoaded
        }

        guard !audioData.isEmpty else {
            throw WhisperError.invalidAudioData
        }

        let startTime = Date()

        do {
            let options = DecodingOptions(
                verbose: false,
                task: .transcribe,
                language: detectLanguage ? nil : language,
                temperature: 0.0,
                temperatureFallbackCount: 2,
                topK: 5,
                usePrefillPrompt: false,
                usePrefillCache: false,
                detectLanguage: detectLanguage ? true : nil,
                skipSpecialTokens: true,
                withoutTimestamps: true,
                clipTimestamps: [],
                suppressBlank: true,
                compressionRatioThreshold: 2.4,
                logProbThreshold: -0.8,
                firstTokenLogProbThreshold: -1.0,
                noSpeechThreshold: 0.4
            )

            let wkResults = try await whisperKit.transcribe(
                    audioArray: audioData,
                    decodeOptions: options
                )

            let fullText = wkResults
                .map { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let detectedLanguage = wkResults.first?.language ?? language
            let duration = Date().timeIntervalSince(startTime)

            return TranscriptionResult(
                text: fullText,
                language: detectedLanguage,
                duration: duration
            )
        } catch {
            throw WhisperError.transcriptionFailed(
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Streaming Transcription

    /// Transcribes audio data, calling `onSegment` for each confirmed segment as WhisperKit
    /// decodes it. Uses the `segmentCallback` direct parameter to avoid instance-property
    /// threading hazards when multiple sessions might overlap.
    public func transcribeStreaming(
        audioData: [Float],
        language: String? = nil,
        detectLanguage: Bool = true,
        onSegment: @escaping SegmentCallback
    ) async throws -> TranscriptionResult {
        guard let whisperKit = whisperKit, isModelLoaded else {
            throw WhisperError.modelNotLoaded
        }

        guard !audioData.isEmpty else {
            throw WhisperError.invalidAudioData
        }

        let startTime = Date()

        do {
            let options = DecodingOptions(
                verbose: false,
                task: .transcribe,
                language: detectLanguage ? nil : language,
                temperature: 0.0,
                temperatureFallbackCount: 2,
                topK: 5,
                usePrefillPrompt: false,
                usePrefillCache: false,
                detectLanguage: detectLanguage ? true : nil,
                skipSpecialTokens: true,
                withoutTimestamps: true,
                clipTimestamps: [],
                suppressBlank: true,
                compressionRatioThreshold: 2.4,
                logProbThreshold: -0.8,
                firstTokenLogProbThreshold: -1.0,
                noSpeechThreshold: 0.4
            )

            // Use the direct segmentCallback parameter (not the instance property)
            // to avoid threading hazards if two sessions overlap.
            // SegmentDiscoveryCallback receives [TranscriptionSegment] (non-optional array).
            let segmentCallback: SegmentDiscoveryCallback = { segments in
                for segment in segments {
                    let text = segment.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        onSegment(text)
                    }
                }
            }


            let wkResults = try await whisperKit.transcribe(
                audioArray: audioData,
                decodeOptions: options,
                callback: nil,
                segmentCallback: segmentCallback
            )

            let fullText = wkResults
                .map { $0.text }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let detectedLanguage = wkResults.first?.language ?? language
            let duration = Date().timeIntervalSince(startTime)

            return TranscriptionResult(
                text: fullText,
                language: detectedLanguage,
                duration: duration
            )
        } catch {
            throw WhisperError.transcriptionFailed(
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Cleanup

    public func unloadModel() {
        whisperKit = nil
        isModelLoaded = false
        currentModelPath = nil
    }
}

// MARK: - MockTranscriptionEngine (for Testing)

public class MockTranscriptionEngine: TranscriptionEngine {
    public private(set) var isModelLoaded: Bool = false
    public private(set) var currentModelPath: String?

    private var mockResults: [String: TranscriptionResult] = [:]
    private var mockSegments: [String] = []
    private var shouldFail: Bool = false
    private var failureError: WhisperError = .transcriptionFailed(
        reason: "Mock failure"
    )

    public init() {}

    public func loadModel(at path: String) throws {
        if shouldFail { throw failureError }
        isModelLoaded = true
        currentModelPath = path
    }

    public func loadModel(variant: String) async throws {
        if shouldFail { throw failureError }
        isModelLoaded = true
        currentModelPath = "/mock/\(variant)"
    }

    public func transcribe(
        audioData: [Float],
        language: String?,
        detectLanguage: Bool
    ) async throws -> TranscriptionResult {
        if shouldFail { throw failureError }
        guard !audioData.isEmpty else {
            throw WhisperError.invalidAudioData
        }

        let key = language ?? "default"
        if let result = mockResults[key] {
            return result
        }

        return TranscriptionResult(
            text: "Mock transcription result",
            language: language ?? "en",
            duration: TimeInterval(audioData.count) / 16000.0
        )
    }

    public func unloadModel() {
        isModelLoaded = false
        currentModelPath = nil
    }

    public func setMockResult(
        _ result: TranscriptionResult,
        forLanguage language: String = "default"
    ) {
        mockResults[language] = result
    }

    public func setMockSegments(_ segments: [String]) {
        mockSegments = segments
    }

    public func setFailure(_ error: WhisperError) {
        shouldFail = true
        failureError = error
    }

    public func resetFailure() {
        shouldFail = false
    }

    public func transcribeStreaming(
        audioData: [Float],
        language: String?,
        detectLanguage: Bool,
        onSegment: @escaping SegmentCallback
    ) async throws -> TranscriptionResult {
        if shouldFail { throw failureError }
        guard !audioData.isEmpty else {
            throw WhisperError.invalidAudioData
        }

        if mockSegments.isEmpty {
            // Fall back: call onSegment once with the full mock result
            let key = language ?? "default"
            let text = mockResults[key]?.text ?? "Mock transcription result"
            onSegment(text)
        } else {
            // Emit each segment with a small simulated delay
            for segment in mockSegments {
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                onSegment(segment)
            }
        }

        // Return final result
        let key = language ?? "default"
        if let result = mockResults[key] {
            return result
        }
        // If no custom result and segments are empty, use the same fallback text
        let fallbackText = mockSegments.isEmpty
            ? "Mock transcription result"
            : mockSegments.joined(separator: " ")
        return TranscriptionResult(
            text: fallbackText,
            language: language ?? "en",
            duration: TimeInterval(audioData.count) / 16000.0
        )
    }
}
