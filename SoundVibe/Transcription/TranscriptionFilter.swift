import Accelerate
import Foundation

/// Filters out common Whisper hallucination artifacts and validates
/// that audio contains sufficient speech energy before transcription.
struct TranscriptionFilter {

  // MARK: - Hallucination Detection

  /// Known Whisper hallucination phrases from training data artifacts.
  /// These appear when the model encounters silence, noise, or very
  /// short audio and falls back to memorized YouTube subtitle patterns.
  private static let hallucinationPatterns: Set<String> = [
    "thanks for watching",
    "thank you for watching",
    "subscribe to my channel",
    "please subscribe",
    "like and subscribe",
    "thanks for listening",
    "thank you for listening",
    "subtitles by",
    "subtitles made by",
    "amara.org",
    "translated by",
    "captioned by",
    "follow me on",
    "see you next time",
    "see you in the next",
    "music playing",
    "applause",
    "laughter",
  ]

  /// Returns `true` if the transcription text appears to be a
  /// hallucination rather than genuine dictated speech.
  static func isHallucination(_ text: String) -> Bool {
    let cleaned = text
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      // Strip common punctuation for matching
      .replacingOccurrences(of: ".", with: "")
      .replacingOccurrences(of: ",", with: "")
      .replacingOccurrences(of: "!", with: "")
      .replacingOccurrences(of: "?", with: "")
      .trimmingCharacters(in: .whitespaces)

    // Empty or single-character results are not useful
    if cleaned.count < 2 { return true }

    // Exact match against known hallucination phrases
    if hallucinationPatterns.contains(cleaned) { return true }

    // Check if the entire text is just repeated characters/words
    // (e.g. "the the the the" or "............")
    let words = cleaned.split(separator: " ")
    if words.count >= 3 {
      let uniqueWords = Set(words)
      if uniqueWords.count == 1 { return true }
    }

    return false
  }

  // MARK: - Audio Energy Validation

  /// Checks whether the audio samples contain sufficient speech energy
  /// to be worth transcribing. Returns `false` if the audio is mostly
  /// silence or low-level noise, which would likely produce hallucinated
  /// output from Whisper.
  ///
  /// - Parameters:
  ///   - samples: 16kHz mono Float audio samples.
  ///   - sampleRate: Sample rate (typically 16000).
  ///   - threshold: Normalized RMS threshold for speech (default 0.05).
  ///   - minSpeechRatio: Minimum fraction of frames that must exceed
  ///     the threshold (default 0.1 = 10% of frames must have speech).
  /// - Returns: `true` if the audio has sufficient speech content.
  static func hasSufficientSpeech(
    in samples: [Float],
    sampleRate: Double = 16000,
    threshold: Float = 0.05,
    minSpeechRatio: Double = 0.1
  ) -> Bool {
    guard !samples.isEmpty, sampleRate > 0 else { return false }

    let frameSize = max(1, Int(sampleRate * 0.02)) // 20ms frames
    let totalFrames = samples.count / frameSize
    guard totalFrames > 0 else { return false }

    var speechFrames = 0
    for frameIndex in 0..<totalFrames {
      let offset = frameIndex * frameSize
      let end = min(offset + frameSize, samples.count)
      let length = end - offset
      guard length > 0 else { continue }

      var sumOfSquares: Float = 0
      samples.withUnsafeBufferPointer { buffer in
        let ptr = buffer.baseAddress! + offset
        vDSP_dotpr(
          ptr, 1, ptr, 1, &sumOfSquares, vDSP_Length(length)
        )
      }

      let rms = sqrt(sumOfSquares / Float(length))
      let normalized = (20 * log10(rms + 0.001) + 60) / 60
      let level = max(Float(0), min(Float(1), normalized))

      if level >= threshold {
        speechFrames += 1
      }
    }

    let speechRatio = Double(speechFrames) / Double(totalFrames)
    return speechRatio >= minSpeechRatio
  }
}
