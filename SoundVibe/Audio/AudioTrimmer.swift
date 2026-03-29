import Accelerate
import Foundation

/// Utility for trimming leading and trailing silence from audio samples.
///
/// Uses RMS energy detection (similar to `AudioCaptureManager.calculateRMSLevel`)
/// to find speech boundaries and returns only the portion of audio containing
/// actual speech content. A configurable margin is preserved around detected
/// speech to avoid clipping word onsets and offsets.
struct AudioTrimmer {

    /// Trims leading and trailing silence from audio samples.
    ///
    /// Walks from the start of the buffer forward to find the first frame where
    /// RMS energy exceeds the threshold, and from the end backward to find the
    /// last such frame. Returns the slice between them with a small margin on
    /// each side to avoid clipping word boundaries.
    ///
    /// - Parameters:
    ///   - samples: Raw mono Float audio samples.
    ///   - sampleRate: Sample rate in Hz (e.g. 16000).
    ///   - threshold: Normalized RMS level (0.0-1.0) below which audio is
    ///     considered silence. Default 0.05 matches `SilenceDetector`.
    ///   - minSpeechDuration: Minimum duration of speech (in seconds) required
    ///     for the result to be considered valid. If the detected speech region
    ///     is shorter than this, the original samples are returned untrimmed
    ///     to avoid discarding legitimate short utterances.
    ///   - leadingMarginSeconds: Margin (in seconds) to preserve before the
    ///     first detected speech frame. Default 0.2s (200ms) — generous to
    ///     avoid clipping plosive consonant onsets (p, t, k, b, d, g).
    ///   - trailingMarginSeconds: Margin (in seconds) to preserve after the
    ///     last detected speech frame. Default 0.05s (50ms) — tight because
    ///     trailing silence is the primary cause of Whisper hallucinations.
    /// - Returns: A `TrimResult` containing the trimmed samples and statistics.
    static func trimSilence(
        from samples: [Float],
        sampleRate: Double,
        threshold: Float = 0.05,
        minSpeechDuration: Double = 0.3,
        leadingMarginSeconds: Double = 0.2,
        trailingMarginSeconds: Double = 0.05
    ) -> TrimResult {
        let originalDuration = Double(samples.count) / sampleRate

        guard !samples.isEmpty, sampleRate > 0 else {
            return TrimResult(
                samples: samples,
                originalDuration: 0,
                trimmedDuration: 0,
                leadingTrimmed: 0,
                trailingTrimmed: 0
            )
        }

        // RMS frame size: 20ms windows for energy analysis
        let frameSize = max(1, Int(sampleRate * 0.02))
        let totalFrames = samples.count / frameSize

        guard totalFrames > 0 else {
            return TrimResult(
                samples: samples,
                originalDuration: originalDuration,
                trimmedDuration: originalDuration,
                leadingTrimmed: 0,
                trailingTrimmed: 0
            )
        }

        // Find first frame with energy above threshold (walking forward)
        var firstSpeechFrame = -1
        for frameIndex in 0..<totalFrames {
            let start = frameIndex * frameSize
            let level = rmsLevel(
                samples: samples, offset: start, count: frameSize
            )
            if level >= threshold {
                firstSpeechFrame = frameIndex
                break
            }
        }

        // No speech detected at all — return original to avoid discarding
        guard firstSpeechFrame >= 0 else {
            return TrimResult(
                samples: samples,
                originalDuration: originalDuration,
                trimmedDuration: originalDuration,
                leadingTrimmed: 0,
                trailingTrimmed: 0
            )
        }

        // Find last frame with energy above threshold (walking backward)
        var lastSpeechFrame = firstSpeechFrame
        for frameIndex in stride(from: totalFrames - 1, through: firstSpeechFrame, by: -1) {
            let start = frameIndex * frameSize
            let level = rmsLevel(
                samples: samples, offset: start, count: frameSize
            )
            if level >= threshold {
                lastSpeechFrame = frameIndex
                break
            }
        }

        // Convert frame indices to sample indices with asymmetric margins
        let leadingMarginSamples = Int(leadingMarginSeconds * sampleRate)
        let trailingMarginSamples = Int(trailingMarginSeconds * sampleRate)
        let speechStartSample = max(
            0, firstSpeechFrame * frameSize - leadingMarginSamples
        )
        let speechEndSample = min(
            samples.count,
            (lastSpeechFrame + 1) * frameSize + trailingMarginSamples
        )

        // Check minimum speech duration
        let speechSamples = speechEndSample - speechStartSample
        let speechDuration = Double(speechSamples) / sampleRate
        if speechDuration < minSpeechDuration {
            // Too short — return original untrimmed
            return TrimResult(
                samples: samples,
                originalDuration: originalDuration,
                trimmedDuration: originalDuration,
                leadingTrimmed: 0,
                trailingTrimmed: 0
            )
        }

        let trimmed = Array(samples[speechStartSample..<speechEndSample])
        let trimmedDuration = Double(trimmed.count) / sampleRate
        let leadingTrimmed = Double(speechStartSample) / sampleRate
        let trailingTrimmed = Double(samples.count - speechEndSample) / sampleRate

        return TrimResult(
            samples: trimmed,
            originalDuration: originalDuration,
            trimmedDuration: trimmedDuration,
            leadingTrimmed: leadingTrimmed,
            trailingTrimmed: trailingTrimmed
        )
    }

    // MARK: - Private Helpers

    /// Calculates normalized RMS level for a segment of audio samples.
    /// Uses the same formula as `AudioCaptureManager.calculateRMSLevel`.
    private static func rmsLevel(
        samples: [Float],
        offset: Int,
        count: Int
    ) -> Float {
        let end = min(offset + count, samples.count)
        let length = end - offset
        guard length > 0 else { return 0 }

        // Use vDSP for vectorized sum-of-squares
        var sumOfSquares: Float = 0
        samples.withUnsafeBufferPointer { buffer in
            let ptr = buffer.baseAddress! + offset
            vDSP_dotpr(ptr, 1, ptr, 1, &sumOfSquares, vDSP_Length(length))
        }

        let meanSquare = sumOfSquares / Float(length)
        let rms = sqrt(meanSquare)

        // Normalize to 0-1 range (same formula as AudioCaptureManager)
        let normalized = (20 * log10(rms + 0.001) + 60) / 60
        return max(0, min(1, normalized))
    }
}

// MARK: - TrimResult

/// Contains the result of audio trimming along with statistics.
struct TrimResult {
    /// The trimmed audio samples.
    let samples: [Float]

    /// Duration of the original audio in seconds.
    let originalDuration: Double

    /// Duration of the trimmed audio in seconds.
    let trimmedDuration: Double

    /// Duration of silence trimmed from the beginning in seconds.
    let leadingTrimmed: Double

    /// Duration of silence trimmed from the end in seconds.
    let trailingTrimmed: Double

    /// Whether any trimming was actually performed.
    var wasTrimmed: Bool {
        leadingTrimmed > 0 || trailingTrimmed > 0
    }

    /// Human-readable summary for logging.
    var logSummary: String {
        if wasTrimmed {
            return String(
                format: "Trimmed %.1fs -> %.1fs (leading: %.2fs, trailing: %.2fs)",
                originalDuration, trimmedDuration,
                leadingTrimmed, trailingTrimmed
            )
        } else {
            return String(
                format: "No trimming needed (%.1fs)",
                originalDuration
            )
        }
    }
}
