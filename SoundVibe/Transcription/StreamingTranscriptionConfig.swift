import Foundation

/// Configuration for the periodic sliding-window streaming transcription strategy.
///
/// The session takes a snapshot of accumulated audio every `chunkInterval` seconds.
/// To keep per-chunk inference cost constant (avoiding quadratic growth), only the
/// last `windowSize` seconds of audio are sent to Whisper per chunk. An `overlapSize`
/// window of the previous chunk is re-included for contextual continuity.
///
/// Example with defaults: every 2.5s, Whisper receives the most recent 10s of audio
/// (with 2s overlap from the prior chunk). No chunk call transcribes more than 12s.
public struct StreamingTranscriptionConfig {

    /// How often (in seconds) to snapshot the audio buffer and run a chunk transcription.
    /// Lower values produce faster preview updates but higher CPU usage.
    /// Recommended range: 1.5–5.0 seconds.
    public var chunkInterval: TimeInterval

    /// Maximum duration (in seconds) of audio to send per chunk call.
    /// Limits per-call inference cost. Audio beyond this window is dropped from the chunk
    /// but remains in the full-session buffer for the final authoritative transcription.
    public var windowSize: TimeInterval

    /// Amount of audio (in seconds) from the end of the previous chunk to re-include
    /// at the start of the next chunk, providing Whisper with context for continuity.
    public var overlapSize: TimeInterval

    /// Minimum audio duration (in seconds) that must be accumulated before the first
    /// chunk transcription attempt. Prevents Whisper from running on very short audio
    /// that typically produces empty or noisy results.
    public var minAudioDuration: TimeInterval

    public init(
        chunkInterval: TimeInterval = 2.5,
        windowSize: TimeInterval = 7.0,
        overlapSize: TimeInterval = 2.0,
        minAudioDuration: TimeInterval = 1.5
    ) {
        self.chunkInterval = chunkInterval
        self.windowSize = windowSize
        self.overlapSize = overlapSize
        self.minAudioDuration = minAudioDuration
    }
}
