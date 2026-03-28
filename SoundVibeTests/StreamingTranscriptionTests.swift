import XCTest
@testable import SoundVibe

// MARK: - Minimal conformer that does NOT override transcribeStreaming (uses default)

private class MinimalEngine: TranscriptionEngine {
    var isModelLoaded: Bool = true
    var currentModelPath: String? = "/test"

    func loadModel(at path: String) throws {}
    func unloadModel() {}

    func transcribe(audioData: [Float], language: String?, detectLanguage: Bool) async throws -> TranscriptionResult {
        return TranscriptionResult(text: "minimal result", language: "en", duration: 1.0)
    }
}

// MARK: - StreamingTranscriptionTests

final class StreamingTranscriptionTests: XCTestCase {

    private var engine: MockTranscriptionEngine!

    override func setUp() {
        super.setUp()
        engine = MockTranscriptionEngine()
        try? engine.loadModel(at: "/test")
    }

    // MARK: - 7b.1: transcribeStreaming delivers segments in order

    func testTranscribeStreamingDeliversSegmentsInOrder() async throws {
        let segments = ["Hello", "world", "how are you"]
        engine.setMockSegments(segments)

        var received: [String] = []
        let result = try await engine.transcribeStreaming(
            audioData: Array(repeating: Float(0.1), count: 16000),
            language: "en",
            detectLanguage: false,
            onSegment: { text in
                received.append(text)
            }
        )

        XCTAssertEqual(received, segments, "Segments should be delivered in order")
        XCTAssertFalse(result.text.isEmpty, "Should return a TranscriptionResult")
    }

    // MARK: - 7b.2: falls back to single onSegment call when no mock segments configured

    func testTranscribeStreamingFallsBackToSingleCallWhenNoSegments() async throws {
        // No segments configured — should fall back to single call with full mock result
        let customResult = TranscriptionResult(text: "fallback text", language: "en", duration: 1.0)
        engine.setMockResult(customResult, forLanguage: "en")

        var received: [String] = []
        let result = try await engine.transcribeStreaming(
            audioData: Array(repeating: Float(0.1), count: 16000),
            language: "en",
            detectLanguage: false,
            onSegment: { text in
                received.append(text)
            }
        )

        XCTAssertEqual(received.count, 1, "Should call onSegment exactly once when no mock segments configured")
        XCTAssertEqual(received.first, "fallback text", "Should deliver mock result text")
        XCTAssertEqual(result.text, "fallback text", "Result should match mock result")
    }

    // MARK: - 7b.3: throws correctly when setFailure is configured

    func testTranscribeStreamingThrowsWhenFailureConfigured() async {
        engine.setFailure(.transcriptionFailed(reason: "Simulated streaming error"))

        do {
            let _ = try await engine.transcribeStreaming(
                audioData: Array(repeating: Float(0.1), count: 16000),
                language: "en",
                detectLanguage: false,
                onSegment: { _ in }
            )
            XCTFail("Should have thrown an error")
        } catch let error as WhisperError {
            if case .transcriptionFailed = error {
                // Expected
            } else {
                XCTFail("Should throw transcriptionFailed, got \(error)")
            }
        } catch {
            XCTFail("Should throw WhisperError, got \(error)")
        }
    }

    // MARK: - 7b.4: default protocol extension calls onSegment exactly once

    func testDefaultProtocolExtensionCallsOnSegmentOnce() async throws {
        let minimalEngine = MinimalEngine()

        var callCount = 0
        var receivedText = ""
        let _ = try await minimalEngine.transcribeStreaming(
            audioData: Array(repeating: Float(0.1), count: 16000),
            language: "en",
            detectLanguage: false,
            onSegment: { text in
                callCount += 1
                receivedText = text
            }
        )

        XCTAssertEqual(callCount, 1,
                       "Default protocol extension should call onSegment exactly once")
        XCTAssertEqual(receivedText, "minimal result",
                       "Default extension should pass the full transcription result text")
    }

    // MARK: - Throws on empty audio

    func testTranscribeStreamingThrowsOnEmptyAudio() async {
        do {
            let _ = try await engine.transcribeStreaming(
                audioData: [],
                language: "en",
                detectLanguage: false,
                onSegment: { _ in }
            )
            XCTFail("Should throw on empty audio")
        } catch let error as WhisperError {
            if case .invalidAudioData = error {
                // Expected
            } else {
                XCTFail("Should throw invalidAudioData, got \(error)")
            }
        } catch {
            XCTFail("Should throw WhisperError")
        }
    }

    // MARK: - 7b.6: onSegment text contains no Whisper timestamp tokens

    /// Verifies that segment text delivered to onSegment never contains raw Whisper
    /// timestamp tokens (e.g. "<|0.00|>", "<|2.56|>"). These appear when
    /// DecodingOptions.skipSpecialTokens / withoutTimestamps are not set on the
    /// streaming path. The mock won't exercise real WhisperKit decoding, so we also
    /// verify the contract through a helper that validates any arbitrary segment string.
    func testSegmentTextContainsNoTimestampTokens() async throws {
        let segments = ["Hello world", " how are you", " nice to meet you"]
        engine.setMockSegments(segments)

        var received: [String] = []
        let _ = try await engine.transcribeStreaming(
            audioData: Array(repeating: Float(0.1), count: 16000),
            language: "en",
            detectLanguage: false,
            onSegment: { text in
                received.append(text)
            }
        )

        for text in received {
            XCTAssertFalse(
                Self.containsTimestampToken(text),
                "Segment text must not contain Whisper timestamp tokens, got: \(text)"
            )
        }
    }

    func testTimestampTokenDetectorWorks() {
        // Confirm the helper correctly identifies the problematic format
        XCTAssertTrue(Self.containsTimestampToken("<|0.00|>"))
        XCTAssertTrue(Self.containsTimestampToken("Hello <|1.20|> world"))
        XCTAssertTrue(Self.containsTimestampToken("<|0.00|>Hello<|2.56|>"))
        // Clean text should not match
        XCTAssertFalse(Self.containsTimestampToken("Hello world"))
        XCTAssertFalse(Self.containsTimestampToken(""))
        XCTAssertFalse(Self.containsTimestampToken("How are you today?"))
    }

    /// Returns true if the string contains a Whisper timestamp token like `<|0.00|>`.
    private static func containsTimestampToken(_ text: String) -> Bool {
        // Whisper timestamp tokens are formatted as <|N.NN|> where N is a number
        let pattern = #"<\|\d+\.\d+\|>"#
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - resetFailure works after streaming failure

    func testResetFailureWorksAfterStreamingFailureConfigured() async throws {
        engine.setFailure(.transcriptionFailed(reason: "Error"))
        engine.resetFailure()

        var callCount = 0
        let _ = try await engine.transcribeStreaming(
            audioData: Array(repeating: Float(0.1), count: 16000),
            language: nil,
            detectLanguage: true,
            onSegment: { _ in callCount += 1 }
        )
        XCTAssertEqual(callCount, 1, "Should succeed after resetFailure()")
    }
}
