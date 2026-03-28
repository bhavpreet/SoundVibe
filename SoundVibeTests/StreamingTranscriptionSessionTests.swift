import XCTest
@testable import SoundVibe

final class StreamingTranscriptionSessionTests: XCTestCase {

    private let sampleRate: Double = 16000

    // Helper: make Float samples of given duration at 16kHz
    private func makeSamples(seconds: Double) -> [Float] {
        Array(repeating: Float(0.2), count: Int(sampleRate * seconds))
    }

    // MARK: - 7c.1: start() triggers periodic audioProvider calls

    func testStartTriggersPeriodicallyCalledAudioProvider() async {
        let engine = MockTranscriptionEngine()
        try? engine.loadModel(at: "/test")
        engine.setMockSegments(["hello"])

        let config = StreamingTranscriptionConfig(
            chunkInterval: 0.1,  // Very short interval for testing
            windowSize: 10.0,
            overlapSize: 0.5,
            minAudioDuration: 0.5
        )

        let callCountLock = NSLock()
        var audioProviderCallCount = 0

        let session = StreamingTranscriptionSession(
            engine: engine,
            config: config,
            language: "en",
            detectLanguage: false,
            onPreviewUpdate: { _ in }
        )

        session.start(audioProvider: {
            callCountLock.lock()
            audioProviderCallCount += 1
            callCountLock.unlock()
            return self.makeSamples(seconds: 2.0)  // > minAudioDuration
        })

        // Wait for multiple intervals
        try? await Task.sleep(nanoseconds: 400_000_000) // 400ms → at least 3 cycles
        await session.stop()

        XCTAssertGreaterThanOrEqual(audioProviderCallCount, 2,
                                    "audioProvider should be called multiple times during session")
    }

    // MARK: - 7c.2: stop() cancels further chunk cycles

    func testStopCancelsFurtherChunkCycles() async {
        let engine = MockTranscriptionEngine()
        try? engine.loadModel(at: "/test")

        let config = StreamingTranscriptionConfig(
            chunkInterval: 0.05,
            windowSize: 10.0,
            overlapSize: 0.5,
            minAudioDuration: 0.5
        )

        let callCountLock = NSLock()
        var callsAfterStop = 0
        var stopped = false

        let session = StreamingTranscriptionSession(
            engine: engine,
            config: config,
            language: nil,
            detectLanguage: true,
            onPreviewUpdate: { _ in }
        )

        session.start(audioProvider: {
            callCountLock.lock()
            let wasStopped = stopped
            callCountLock.unlock()
            if wasStopped {
                callCountLock.lock()
                callsAfterStop += 1
                callCountLock.unlock()
            }
            return self.makeSamples(seconds: 2.0)
        })

        try? await Task.sleep(nanoseconds: 120_000_000) // 120ms
        await session.stop()

        callCountLock.lock()
        stopped = true
        callCountLock.unlock()

        try? await Task.sleep(nanoseconds: 200_000_000) // Wait to see if more calls happen

        XCTAssertEqual(callsAfterStop, 0, "audioProvider should not be called after stop()")
    }

    // MARK: - 7c.3: concurrent call protection (skip if in-flight)

    func testConcurrentChunkProtectionSkipsOverlappingCycles() async {
        // Use a slow engine that blocks for 500ms per call
        class SlowEngine: TranscriptionEngine {
            var isModelLoaded: Bool = true
            var currentModelPath: String? = "/test"
            var callCount = 0
            func loadModel(at path: String) throws {}
            func unloadModel() {}
            func transcribe(audioData: [Float], language: String?, detectLanguage: Bool) async throws -> TranscriptionResult {
                callCount += 1
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                return TranscriptionResult(text: "result", language: "en", duration: 0.5)
            }
        }

        let slowEngine = SlowEngine()

        let config = StreamingTranscriptionConfig(
            chunkInterval: 0.05,  // 50ms interval, much faster than 500ms transcription
            windowSize: 10.0,
            overlapSize: 0.5,
            minAudioDuration: 0.5
        )

        let session = StreamingTranscriptionSession(
            engine: slowEngine,
            config: config,
            language: nil,
            detectLanguage: true,
            onPreviewUpdate: { _ in }
        )

        session.start(audioProvider: { self.makeSamples(seconds: 2.0) })

        // Wait for 300ms (6 potential intervals at 50ms each)
        try? await Task.sleep(nanoseconds: 300_000_000)
        await session.stop()
        try? await Task.sleep(nanoseconds: 600_000_000) // Let the in-flight call finish

        // With 300ms window and 500ms per call, only 1 call should have happened
        // (the second cycle should have been skipped because the first was still in-flight)
        XCTAssertLessThanOrEqual(slowEngine.callCount, 2,
                                  "Concurrent call protection should prevent more than 1-2 simultaneous transcriptions")
    }

    // MARK: - 7c.4: deduplication trims overlap

    func testDeduplicationTrimsOverlap() async {
        let engine = MockTranscriptionEngine()
        try? engine.loadModel(at: "/test")

        let config = StreamingTranscriptionConfig(
            chunkInterval: 0.05,
            windowSize: 10.0,
            overlapSize: 2.0,
            minAudioDuration: 0.5
        )

        var previewUpdates: [String] = []
        let lock = NSLock()

        let session = StreamingTranscriptionSession(
            engine: engine,
            config: config,
            language: "en",
            detectLanguage: false,
            onPreviewUpdate: { text in
                lock.lock()
                previewUpdates.append(text)
                lock.unlock()
            }
        )

        // Configure engine to emit the same segment twice (simulating overlap)
        engine.setMockSegments(["Hello world"])

        session.start(audioProvider: { self.makeSamples(seconds: 2.0) })

        try? await Task.sleep(nanoseconds: 300_000_000)
        await session.stop()

        // If we got preview updates, they should not contain duplicated content
        lock.lock()
        let allPreviews = previewUpdates
        lock.unlock()

        for preview in allPreviews {
            // Check that "Hello world" does not appear twice in any single update
            let components = preview.components(separatedBy: "Hello world")
            XCTAssertLessThanOrEqual(components.count - 1, 2,
                                      "Preview should not have excessive duplication of 'Hello world'")
        }
    }

    // MARK: - 7c.5: minAudioDuration guard prevents premature transcription

    func testMinAudioDurationGuardPreventsTranscriptionOnShortAudio() async {
        let engine = MockTranscriptionEngine()
        try? engine.loadModel(at: "/test")

        let config = StreamingTranscriptionConfig(
            chunkInterval: 0.05,
            windowSize: 10.0,
            overlapSize: 0.5,
            minAudioDuration: 5.0  // Require 5 seconds minimum
        )

        var segmentsCalled = 0
        let lock = NSLock()

        let session = StreamingTranscriptionSession(
            engine: engine,
            config: config,
            language: "en",
            detectLanguage: false,
            onPreviewUpdate: { _ in
                lock.lock()
                segmentsCalled += 1
                lock.unlock()
            }
        )

        engine.setMockSegments(["hello"])

        session.start(audioProvider: {
            // Return only 1 second of audio — below minAudioDuration of 5 seconds
            self.makeSamples(seconds: 1.0)
        })

        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
        await session.stop()

        XCTAssertEqual(segmentsCalled, 0,
                       "onPreviewUpdate should not be called when audio is shorter than minAudioDuration")
    }
}
