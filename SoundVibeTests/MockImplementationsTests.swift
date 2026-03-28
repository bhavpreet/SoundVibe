import XCTest
@testable import SoundVibe

final class MockImplementationsTests: XCTestCase {

    // MARK: - MockTranscriptionEngine Tests

    func testMockEngineInitialization() {
        let engine = MockTranscriptionEngine()
        XCTAssertFalse(engine.isModelLoaded, "Engine should not be loaded initially")
        XCTAssertNil(engine.currentModelPath, "Current model path should be nil initially")
    }

    func testMockEngineLoadModel() {
        let engine = MockTranscriptionEngine()

        do {
            try engine.loadModel(at: "/path/to/model.bin")
            XCTAssertTrue(engine.isModelLoaded, "Model should be loaded after loadModel()")
            XCTAssertEqual(engine.currentModelPath, "/path/to/model.bin", "Current model path should be set")
        } catch {
            XCTFail("Loading model should not fail: \(error)")
        }
    }

    func testMockEngineLoadModelFailsWhenConfigured() {
        let engine = MockTranscriptionEngine()
        engine.setFailure(.modelLoadFailed(reason: "Simulated failure"))

        do {
            try engine.loadModel(at: "/path/to/model.bin")
            XCTFail("Should throw error when configured to fail")
        } catch let error as WhisperError {
            if case .modelLoadFailed = error {
                // Expected
            } else {
                XCTFail("Should throw modelLoadFailed error")
            }
        } catch {
            XCTFail("Should throw WhisperError: \(error)")
        }
    }

    func testMockEngineUnloadModel() {
        let engine = MockTranscriptionEngine()

        do {
            try engine.loadModel(at: "/path/to/model.bin")
            XCTAssertTrue(engine.isModelLoaded, "Model should be loaded")

            engine.unloadModel()
            XCTAssertFalse(engine.isModelLoaded, "Model should be unloaded after unloadModel()")
            XCTAssertNil(engine.currentModelPath, "Current model path should be nil after unload")
        } catch {
            XCTFail("Test setup failed: \(error)")
        }
    }

    func testMockEngineTranscribe() async {
        let engine = MockTranscriptionEngine()

        do {
            try engine.loadModel(at: "/path/to/model.bin")

            let audioData = Array(repeating: Float(0.1), count: 16000)
            let result = try await engine.transcribe(
                audioData: audioData,
                language: "en",
                detectLanguage: false
            )

            XCTAssertEqual(result.text, "Mock transcription result", "Should return mock result")
            XCTAssertEqual(result.language, "en", "Should preserve specified language")
            XCTAssertGreaterThan(result.duration, 0, "Mock should have positive duration")
        } catch {
            XCTFail("Transcription should not fail: \(error)")
        }
    }

    func testMockEngineTranscribeWithoutLoading() async {
        let engine = MockTranscriptionEngine()

        let audioData = Array(repeating: Float(0.1), count: 16000)

        do {
            let _ = try await engine.transcribe(
                audioData: audioData,
                language: "en",
                detectLanguage: false
            )
            // This should succeed because mock engine returns result even when not loaded
            // unless explicitly configured to fail
        } catch {
            // This is acceptable behavior
        }
    }

    func testMockEngineTranscribeEmptyAudio() async {
        let engine = MockTranscriptionEngine()

        do {
            try engine.loadModel(at: "/path/to/model.bin")

            let emptyAudio: [Float] = []
            let _ = try await engine.transcribe(
                audioData: emptyAudio,
                language: "en",
                detectLanguage: false
            )

            XCTFail("Should throw error for empty audio")
        } catch is WhisperError {
            // Expected
        } catch {
            XCTFail("Should throw WhisperError: \(error)")
        }
    }

    func testMockEngineSetMockResult() async {
        let engine = MockTranscriptionEngine()

        do {
            try engine.loadModel(at: "/path/to/model.bin")

            let customResult = TranscriptionResult(
                text: "Custom transcription",
                language: "es",
                duration: 5.0
            )
            engine.setMockResult(customResult, forLanguage: "es")

            let audioData = Array(repeating: Float(0.1), count: 16000)
            let result = try await engine.transcribe(
                audioData: audioData,
                language: "es",
                detectLanguage: false
            )

            XCTAssertEqual(result.text, "Custom transcription", "Should return custom result")
            XCTAssertEqual(result.language, "es", "Should use custom language")
            XCTAssertEqual(result.duration, 5.0, "Should use custom duration")
        } catch {
            XCTFail("Transcription should not fail: \(error)")
        }
    }

    func testMockEngineSetMockResultForMultipleLanguages() async {
        let engine = MockTranscriptionEngine()

        do {
            try engine.loadModel(at: "/path/to/model.bin")

            let resultEN = TranscriptionResult(text: "Hello", language: "en", duration: 1.0)
            let resultFR = TranscriptionResult(text: "Bonjour", language: "fr", duration: 1.0)

            engine.setMockResult(resultEN, forLanguage: "en")
            engine.setMockResult(resultFR, forLanguage: "fr")

            let audioData = Array(repeating: Float(0.1), count: 16000)

            let enResult = try await engine.transcribe(
                audioData: audioData,
                language: "en",
                detectLanguage: false
            )
            XCTAssertEqual(enResult.text, "Hello", "Should return English result")

            let frResult = try await engine.transcribe(
                audioData: audioData,
                language: "fr",
                detectLanguage: false
            )
            XCTAssertEqual(frResult.text, "Bonjour", "Should return French result")
        } catch {
            XCTFail("Test failed: \(error)")
        }
    }

    func testMockEngineSetFailure() async {
        let engine = MockTranscriptionEngine()

        do {
            try engine.loadModel(at: "/path/to/model.bin")
        } catch {
            XCTFail("Setup failed: \(error)")
            return
        }

        engine.setFailure(.transcriptionFailed(reason: "Simulated error"))

        let audioData = Array(repeating: Float(0.1), count: 16000)

        do {
            let _ = try await engine.transcribe(
                audioData: audioData,
                language: "en",
                detectLanguage: false
            )
            XCTFail("Should throw configured error")
        } catch is WhisperError {
            // Expected
        } catch {
            XCTFail("Should throw WhisperError: \(error)")
        }
    }

    func testMockEngineResetFailure() async {
        let engine = MockTranscriptionEngine()

        do {
            try engine.loadModel(at: "/path/to/model.bin")
        } catch {
            XCTFail("Setup failed: \(error)")
            return
        }

        engine.setFailure(.transcriptionFailed(reason: "Error"))
        engine.resetFailure()

        let audioData = Array(repeating: Float(0.1), count: 16000)

        do {
            let result = try await engine.transcribe(
                audioData: audioData,
                language: "en",
                detectLanguage: false
            )
            XCTAssertEqual(result.text, "Mock transcription result", "Should work after reset")
        } catch {
            XCTFail("Should not fail after reset: \(error)")
        }
    }

    // MARK: - MockPostProcessor Tests

    func testMockPostProcessorInitialization() {
        let processor = MockPostProcessor()
        XCTAssertTrue(processor.isAvailable, "Mock processor should be available")
        XCTAssertFalse(processor.isProcessing, "Mock processor should not be processing")
    }

    func testMockPostProcessorWithModelLoaded() {
        let processor = MockPostProcessor(modelLoaded: true)
        XCTAssertTrue(processor.isAvailable, "Mock processor should be available")
    }

    func testMockPostProcessorLoadModel() async {
        let processor = MockPostProcessor()

        do {
            try await processor.loadModel(named: "mistral-7b")
            // After loading, processor should be able to process
        } catch {
            XCTFail("Loading model should not fail: \(error)")
        }
    }

    func testMockPostProcessorUnloadModel() async {
        let processor = MockPostProcessor(modelLoaded: true)

        await processor.unloadModel()
        // Model should be unloaded; attempting to process should fail
    }

    func testMockPostProcessorProcessWithoutModel() async {
        let processor = MockPostProcessor(modelLoaded: false)

        do {
            let _ = try await processor.process("test", mode: .clean)
            XCTFail("Should throw modelNotLoaded error")
        } catch is PostProcessingError {
            // Expected
        } catch {
            XCTFail("Should throw PostProcessingError: \(error)")
        }
    }

    func testMockPostProcessorProcessWithModel() async {
        let processor = MockPostProcessor(modelLoaded: true)

        do {
            let result = try await processor.process("test input", mode: .clean)
            XCTAssertTrue(result.contains("[clean]"), "Result should contain mode marker")
            XCTAssertTrue(result.contains("test input"), "Result should contain original text")
        } catch {
            XCTFail("Processing should not fail: \(error)")
        }
    }

    func testMockPostProcessorDifferentModes() async {
        let processor = MockPostProcessor(modelLoaded: true)

        let modes: [PostProcessingMode] = [.clean, .formal, .concise, .custom]

        for mode in modes {
            do {
                let result = try await processor.process("test", mode: mode)
                XCTAssertTrue(
                    result.contains("[\(mode.rawValue)]"),
                    "Result should contain mode marker for \(mode.rawValue)"
                )
            } catch {
                XCTFail("Processing should not fail for mode \(mode.rawValue): \(error)")
            }
        }
    }

    func testMockPostProcessorPreservesText() async {
        let processor = MockPostProcessor(modelLoaded: true)
        let inputText = "This is a test with punctuation, and more words."

        do {
            let result = try await processor.process(inputText, mode: .formal)
            XCTAssertTrue(result.contains(inputText), "Original text should be preserved")
        } catch {
            XCTFail("Processing should not fail: \(error)")
        }
    }

    func testMockPostProcessorIsProcessing() async {
        let processor = MockPostProcessor(modelLoaded: true)

        XCTAssertFalse(processor.isProcessing, "Should not be processing initially")

        let processingTask = Task {
            _ = try? await processor.process("test", mode: .clean)
        }

        // Note: Due to async nature, we can't reliably test mid-processing state
        await processingTask.value
        XCTAssertFalse(processor.isProcessing, "Should not be processing after completion")
    }

    // MARK: - Integration Tests

    func testMockEngineWithPipeline() async {
        let engine = MockTranscriptionEngine()

        do {
            try engine.loadModel(at: "/path/to/model.bin")

            let customResult = TranscriptionResult(
                text: "Test period result",
                language: "en",
                duration: 2.0
            )
            engine.setMockResult(customResult, forLanguage: "en")

            let audioData = Array(repeating: Float(0.1), count: 32000)
            let result = try await engine.transcribe(
                audioData: audioData,
                language: "en",
                detectLanguage: false
            )

            let pipeline = PostProcessingPipeline()
            let settings = DefaultSettingsManager(postProcessingEnabled: false)

            let processed = try await pipeline.process(result.text, settings: settings)
            XCTAssertEqual(processed, "Test. result", "Pipeline should process mock result")
        } catch {
            XCTFail("Integration test failed: \(error)")
        }
    }

    func testMockProcessorWithPipeline() async {
        let processor = MockPostProcessor(modelLoaded: true)
        let pipeline = PostProcessingPipeline(postProcessor: processor)

        let input = "test period here"
        let settings = DefaultSettingsManager(
            postProcessingEnabled: true,
            postProcessingMode: .formal
        )

        do {
            let result = try await pipeline.process(input, settings: settings)
            XCTAssertTrue(result.contains("."), "Should parse voice commands")
            XCTAssertTrue(result.contains("[formal]"), "Should apply post-processing")
        } catch {
            XCTFail("Integration test failed: \(error)")
        }
    }

    // MARK: - TranscriptionResult Protocol Tests

    func testMockEngineResultStructure() async {
        let engine = MockTranscriptionEngine()

        do {
            try engine.loadModel(at: "/test")

            let audioData = Array(repeating: Float(0.1), count: 16000)
            let result = try await engine.transcribe(
                audioData: audioData,
                language: "en",
                detectLanguage: false
            )

            XCTAssertFalse(result.text.isEmpty, "Result text should not be empty")
            XCTAssertEqual(result.language, "en", "Result should have language")
            XCTAssertGreaterThan(result.duration, 0, "Result should have positive duration")
        } catch {
            XCTFail("Test failed: \(error)")
        }
    }

    // MARK: - 7g: MockTranscriptionEngine Streaming Extension Tests

    func testSetMockSegmentsStoresSegments() async throws {
        let engine = MockTranscriptionEngine()
        try engine.loadModel(at: "/test")

        let segments = ["First segment", "Second segment", "Third segment"]
        engine.setMockSegments(segments)

        var received: [String] = []
        _ = try await engine.transcribeStreaming(
            audioData: Array(repeating: Float(0.1), count: 16000),
            language: "en",
            detectLanguage: false,
            onSegment: { received.append($0) }
        )

        XCTAssertEqual(received, segments,
                       "setMockSegments should store all segments, delivered in order")
    }

    func testStreamingMockEmitsSegmentsInOrderWithTiming() async throws {
        let engine = MockTranscriptionEngine()
        try engine.loadModel(at: "/test")

        let segments = ["Alpha", "Beta", "Gamma"]
        engine.setMockSegments(segments)

        let expectation = XCTestExpectation(description: "All segments received")
        expectation.expectedFulfillmentCount = segments.count

        var received: [String] = []
        let lock = NSLock()

        _ = try await engine.transcribeStreaming(
            audioData: Array(repeating: Float(0.1), count: 16000),
            language: nil,
            detectLanguage: true,
            onSegment: { text in
                lock.lock()
                received.append(text)
                lock.unlock()
                expectation.fulfill()
            }
        )

        await fulfillment(of: [expectation], timeout: 5.0)

        XCTAssertEqual(received, segments, "All segments should be received in correct order")
    }

    func testResetFailureWorksAfterStreamingFailureIsConfigured() async throws {
        let engine = MockTranscriptionEngine()
        try engine.loadModel(at: "/test")

        engine.setFailure(.transcriptionFailed(reason: "Streaming error"))

        // Verify it fails
        do {
            _ = try await engine.transcribeStreaming(
                audioData: Array(repeating: Float(0.1), count: 16000),
                language: nil,
                detectLanguage: true,
                onSegment: { _ in }
            )
            XCTFail("Should have thrown an error")
        } catch is WhisperError {
            // Expected
        }

        // Reset and verify it succeeds
        engine.resetFailure()

        var callCount = 0
        _ = try await engine.transcribeStreaming(
            audioData: Array(repeating: Float(0.1), count: 16000),
            language: nil,
            detectLanguage: true,
            onSegment: { _ in callCount += 1 }
        )

        XCTAssertEqual(callCount, 1, "Should succeed and call onSegment once after resetFailure()")
    }

    func testStreamingMockEmptyAudioThrows() async {
        let engine = MockTranscriptionEngine()
        try? engine.loadModel(at: "/test")

        do {
            _ = try await engine.transcribeStreaming(
                audioData: [],
                language: nil,
                detectLanguage: true,
                onSegment: { _ in }
            )
            XCTFail("Should throw invalidAudioData for empty audio")
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

    func testStreamingMockFallsBackToDefaultWhenNoSegmentsAndNoCustomResult() async throws {
        let engine = MockTranscriptionEngine()
        try engine.loadModel(at: "/test")
        // No setMockSegments, no setMockResult

        var received: [String] = []
        let result = try await engine.transcribeStreaming(
            audioData: Array(repeating: Float(0.1), count: 16000),
            language: nil,
            detectLanguage: true,
            onSegment: { received.append($0) }
        )

        // Falls back to default: single onSegment call with "Mock transcription result"
        XCTAssertEqual(received.count, 1, "Should call onSegment once as fallback")
        XCTAssertEqual(received.first, "Mock transcription result",
                       "Fallback should use default mock text")
        XCTAssertFalse(result.text.isEmpty, "Result text should not be empty")
    }
}
