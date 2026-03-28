import XCTest
import AVFoundation
@testable import SoundVibe

final class AudioBufferTests: XCTestCase {

    // MARK: - Helpers

    private func makeBuffer(sampleCount: Int, value: Float = 0.5, sampleRate: Double = 16000) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(sampleCount))!
        buffer.frameLength = AVAudioFrameCount(sampleCount)
        if let data = buffer.floatChannelData?[0] {
            for i in 0..<sampleCount {
                data[i] = value
            }
        }
        return buffer
    }

    // MARK: - 7a.1: snapshot() is non-destructive

    func testSnapshotReturnsSameDataAsConsolidate() async {
        let buffer = AudioSampleBuffer()
        let pcmBuffer = makeBuffer(sampleCount: 160)
        await buffer.append(pcmBuffer)

        let snapshotResult = await buffer.snapshot(sampleRate: 16000)
        let consolidateResult = await buffer.consolidate(sampleRate: 16000)

        XCTAssertEqual(snapshotResult.count, consolidateResult.count,
                       "snapshot() should return same sample count as consolidate()")
        XCTAssertFalse(snapshotResult.isEmpty, "snapshot() should return non-empty data")
    }

    func testSnapshotDoesNotClearBuffer() async {
        let buffer = AudioSampleBuffer()
        let pcmBuffer = makeBuffer(sampleCount: 160)
        await buffer.append(pcmBuffer)

        // Call snapshot — should NOT clear the buffer
        _ = await buffer.snapshot(sampleRate: 16000)

        // Buffer should still have duration > 0
        let durationAfterSnapshot = await buffer.duration
        XCTAssertGreaterThan(durationAfterSnapshot, 0,
                             "Buffer duration should still be > 0 after snapshot()")

        // And consolidate should still return data
        let afterConsolidate = await buffer.consolidate(sampleRate: 16000)
        XCTAssertFalse(afterConsolidate.isEmpty,
                       "Buffer should still have data after snapshot() call")
    }

    // MARK: - 7a.2: snapshot() is idempotent

    func testSnapshotIsIdempotent() async {
        let buffer = AudioSampleBuffer()
        let pcmBuffer = makeBuffer(sampleCount: 160, value: 0.3)
        await buffer.append(pcmBuffer)

        let first = await buffer.snapshot(sampleRate: 16000)
        let second = await buffer.snapshot(sampleRate: 16000)

        XCTAssertEqual(first.count, second.count,
                       "Two successive snapshot() calls should return same count")
        for i in 0..<min(first.count, second.count) {
            XCTAssertEqual(first[i], second[i], accuracy: 0.0001,
                           "Two successive snapshot() calls should return identical samples")
        }
    }

    // MARK: - 7a.3: snapshot() on empty buffer

    func testSnapshotOnEmptyBufferReturnsEmpty() async {
        let buffer = AudioSampleBuffer()
        let result = await buffer.snapshot(sampleRate: 16000)
        XCTAssertTrue(result.isEmpty, "snapshot() on empty buffer should return empty array")
    }

    // MARK: - Append and reset still work correctly

    func testResetClearsAfterSnapshot() async {
        let buffer = AudioSampleBuffer()
        let pcmBuffer = makeBuffer(sampleCount: 160)
        await buffer.append(pcmBuffer)

        _ = await buffer.snapshot(sampleRate: 16000)
        await buffer.reset()

        let afterReset = await buffer.snapshot(sampleRate: 16000)
        XCTAssertTrue(afterReset.isEmpty, "Buffer should be empty after explicit reset()")
    }

    func testMultipleAppendsThenSnapshot() async {
        let buffer = AudioSampleBuffer()

        for _ in 0..<5 {
            let pcmBuffer = makeBuffer(sampleCount: 160, value: 0.2)
            await buffer.append(pcmBuffer)
        }

        let result = await buffer.snapshot(sampleRate: 16000)
        XCTAssertEqual(result.count, 800, "snapshot() should include samples from all appended buffers")
    }
}
