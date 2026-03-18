import Foundation

/// Represents a segment of transcription with timing information
public struct TranscriptionSegment: Codable, Equatable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String

    var duration: TimeInterval {
        endTime - startTime
    }

    enum CodingKeys: String, CodingKey {
        case startTime = "start"
        case endTime = "end"
        case text
    }
}

/// Represents the complete result of a transcription operation
public struct TranscriptionResult: Codable, Equatable {
    /// The transcribed text
    let text: String

    /// Detected language (ISO 639-1 code, e.g., "en", "es", "fr")
    let language: String?

    /// Total duration of the audio in seconds
    let duration: TimeInterval

    /// Timestamp when the transcription was created
    let timestamp: Date

    /// Array of transcription segments with timing information
    let segments: [TranscriptionSegment]

    /// Creates a new TranscriptionResult
    init(
        text: String,
        language: String? = nil,
        duration: TimeInterval,
        timestamp: Date = Date(),
        segments: [TranscriptionSegment] = []
    ) {
        self.text = text
        self.language = language
        self.duration = duration
        self.timestamp = timestamp
        self.segments = segments
    }

    /// Equality: compare text, language, duration (ignore timestamp)
    public static func == (
        lhs: TranscriptionResult,
        rhs: TranscriptionResult
    ) -> Bool {
        lhs.text == rhs.text
            && lhs.language == rhs.language
            && lhs.duration == rhs.duration
            && lhs.segments == rhs.segments
    }

    /// The number of words in the transcribed text
    var wordCount: Int {
        text.split(separator: " ").count
    }

    /// Whether the transcription is empty
    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Estimated words per minute (based on total duration)
    var wordsPerMinute: Double {
        guard duration > 0 else { return 0 }
        return Double(wordCount) / (duration / 60.0)
    }

    /// Human-readable duration format (e.g., "1:23")
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    enum CodingKeys: String, CodingKey {
        case text
        case language
        case duration
        case timestamp
        case segments
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        segments = try container.decodeIfPresent([TranscriptionSegment].self, forKey: .segments) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encode(duration, forKey: .duration)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(segments, forKey: .segments)
    }
}
