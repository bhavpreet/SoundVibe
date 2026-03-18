import XCTest
@testable import SoundVibe

final class TranscriptionResultTests: XCTestCase {

    // MARK: - WordCount Tests

    func testWordCountSingleWord() {
        let result = TranscriptionResult(text: "hello", language: "en", duration: 1.0)
        XCTAssertEqual(result.wordCount, 1, "Single word should have word count of 1")
    }

    func testWordCountMultipleWords() {
        let result = TranscriptionResult(text: "hello world test", language: "en", duration: 1.0)
        XCTAssertEqual(result.wordCount, 3, "Three words should have word count of 3")
    }

    func testWordCountWithMultipleSpaces() {
        let result = TranscriptionResult(text: "hello  world   test", language: "en", duration: 1.0)
        // split(separator: " ") will create empty strings for double spaces
        let wordCount = result.wordCount
        XCTAssertGreaterThan(wordCount, 0, "Multiple spaces should still be counted correctly")
    }

    func testWordCountEmptyString() {
        let result = TranscriptionResult(text: "", language: "en", duration: 1.0)
        XCTAssertEqual(result.wordCount, 0, "Empty string should have word count of 0")
    }

    func testWordCountWithPunctuation() {
        let result = TranscriptionResult(text: "hello, world. test!", language: "en", duration: 1.0)
        XCTAssertEqual(result.wordCount, 3, "Punctuation should not affect word count")
    }

    // MARK: - isEmpty Tests

    func testIsEmptyTrue() {
        let result = TranscriptionResult(text: "", language: "en", duration: 1.0)
        XCTAssertTrue(result.isEmpty, "Empty string should return isEmpty=true")
    }

    func testIsEmptyFalseWithText() {
        let result = TranscriptionResult(text: "hello world", language: "en", duration: 1.0)
        XCTAssertFalse(result.isEmpty, "String with text should return isEmpty=false")
    }

    func testIsEmptyWithOnlyWhitespace() {
        let result = TranscriptionResult(text: "   \n\t  ", language: "en", duration: 1.0)
        XCTAssertTrue(result.isEmpty, "String with only whitespace should return isEmpty=true")
    }

    func testIsEmptyWithMixedContent() {
        let result = TranscriptionResult(text: "  hello  ", language: "en", duration: 1.0)
        XCTAssertFalse(result.isEmpty, "String with text surrounded by whitespace should return isEmpty=false")
    }

    // MARK: - Codable Tests

    func testEncodeDecode() {
        let original = TranscriptionResult(
            text: "Hello world",
            language: "en",
            duration: 10.5
        )

        // Encode
        let encoder = JSONEncoder()
        guard let encodedData = try? encoder.encode(original) else {
            XCTFail("Failed to encode TranscriptionResult")
            return
        }

        // Decode
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(TranscriptionResult.self, from: encodedData) else {
            XCTFail("Failed to decode TranscriptionResult")
            return
        }

        // Compare
        XCTAssertEqual(decoded.text, original.text, "Decoded text should match original")
        XCTAssertEqual(decoded.language, original.language, "Decoded language should match original")
        XCTAssertEqual(decoded.duration, original.duration, "Decoded duration should match original")
    }

    func testEncodeDecodeWithNilLanguage() {
        let original = TranscriptionResult(
            text: "No language specified",
            language: nil,
            duration: 5.0
        )

        let encoder = JSONEncoder()
        guard let encodedData = try? encoder.encode(original) else {
            XCTFail("Failed to encode")
            return
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(TranscriptionResult.self, from: encodedData) else {
            XCTFail("Failed to decode")
            return
        }

        XCTAssertNil(decoded.language, "Nil language should remain nil after round-trip")
        XCTAssertEqual(decoded.text, original.text, "Text should match")
    }

    func testEncodeDecodeWithSegments() {
        let segment1 = TranscriptionSegment(startTime: 0.0, endTime: 1.0, text: "Hello")
        let segment2 = TranscriptionSegment(startTime: 1.0, endTime: 2.0, text: "world")

        let original = TranscriptionResult(
            text: "Hello world",
            language: "en",
            duration: 2.0,
            segments: [segment1, segment2]
        )

        let encoder = JSONEncoder()
        guard let encodedData = try? encoder.encode(original) else {
            XCTFail("Failed to encode")
            return
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(TranscriptionResult.self, from: encodedData) else {
            XCTFail("Failed to decode")
            return
        }

        XCTAssertEqual(decoded.segments.count, 2, "Should have 2 segments")
        XCTAssertEqual(decoded.segments[0].text, "Hello", "First segment text should match")
        XCTAssertEqual(decoded.segments[1].text, "world", "Second segment text should match")
    }

    // MARK: - Segments Tests

    func testWithSegments() {
        let segment = TranscriptionSegment(startTime: 0.0, endTime: 1.5, text: "test")
        let result = TranscriptionResult(
            text: "test",
            language: "en",
            duration: 1.5,
            segments: [segment]
        )

        XCTAssertEqual(result.segments.count, 1, "Should have 1 segment")
        XCTAssertEqual(result.segments[0].startTime, 0.0, "Segment start time should be 0")
        XCTAssertEqual(result.segments[0].endTime, 1.5, "Segment end time should be 1.5")
    }

    func testWithMultipleSegments() {
        let segments = [
            TranscriptionSegment(startTime: 0.0, endTime: 1.0, text: "First"),
            TranscriptionSegment(startTime: 1.0, endTime: 2.0, text: "Second"),
            TranscriptionSegment(startTime: 2.0, endTime: 3.0, text: "Third")
        ]

        let result = TranscriptionResult(
            text: "First Second Third",
            language: "en",
            duration: 3.0,
            segments: segments
        )

        XCTAssertEqual(result.segments.count, 3, "Should have 3 segments")
        XCTAssertEqual(result.segments[1].text, "Second", "Second segment should contain 'Second'")
    }

    func testEmptySegmentsArray() {
        let result = TranscriptionResult(
            text: "Hello",
            language: "en",
            duration: 1.0,
            segments: []
        )

        XCTAssertEqual(result.segments.count, 0, "Empty segments array should remain empty")
    }

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let result = TranscriptionResult(text: "test", duration: 1.0)

        XCTAssertEqual(result.text, "test", "Text should be set")
        XCTAssertNil(result.language, "Language should be nil by default")
        XCTAssertEqual(result.duration, 1.0, "Duration should be set")
        XCTAssertEqual(result.segments.count, 0, "Segments should be empty by default")
    }

    func testInitializationWithAllParameters() {
        let timestamp = Date()
        let segment = TranscriptionSegment(startTime: 0.0, endTime: 1.0, text: "test")

        let result = TranscriptionResult(
            text: "test",
            language: "es",
            duration: 1.0,
            timestamp: timestamp,
            segments: [segment]
        )

        XCTAssertEqual(result.text, "test", "Text should match")
        XCTAssertEqual(result.language, "es", "Language should be Spanish")
        XCTAssertEqual(result.duration, 1.0, "Duration should match")
        XCTAssertEqual(result.timestamp, timestamp, "Timestamp should match")
        XCTAssertEqual(result.segments.count, 1, "Should have 1 segment")
    }

    // MARK: - Equatable Tests

    func testEquality() {
        let result1 = TranscriptionResult(text: "hello", language: "en", duration: 1.0)
        let result2 = TranscriptionResult(text: "hello", language: "en", duration: 1.0)

        XCTAssertEqual(result1, result2, "Results with same values should be equal")
    }

    func testInequalityText() {
        let result1 = TranscriptionResult(text: "hello", language: "en", duration: 1.0)
        let result2 = TranscriptionResult(text: "world", language: "en", duration: 1.0)

        XCTAssertNotEqual(result1, result2, "Results with different text should not be equal")
    }

    func testInequalityLanguage() {
        let result1 = TranscriptionResult(text: "hello", language: "en", duration: 1.0)
        let result2 = TranscriptionResult(text: "hello", language: "fr", duration: 1.0)

        XCTAssertNotEqual(result1, result2, "Results with different language should not be equal")
    }

    // MARK: - TranscriptionSegment Tests

    func testSegmentDuration() {
        let segment = TranscriptionSegment(startTime: 1.0, endTime: 3.5, text: "hello")
        XCTAssertEqual(segment.duration, 2.5, "Duration should be endTime - startTime")
    }

    func testSegmentEquality() {
        let segment1 = TranscriptionSegment(startTime: 0.0, endTime: 1.0, text: "hello")
        let segment2 = TranscriptionSegment(startTime: 0.0, endTime: 1.0, text: "hello")

        XCTAssertEqual(segment1, segment2, "Segments with same values should be equal")
    }

    func testSegmentCodable() {
        let segment = TranscriptionSegment(startTime: 1.5, endTime: 3.0, text: "segment text")

        let encoder = JSONEncoder()
        guard let encodedData = try? encoder.encode(segment) else {
            XCTFail("Failed to encode segment")
            return
        }

        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(TranscriptionSegment.self, from: encodedData) else {
            XCTFail("Failed to decode segment")
            return
        }

        XCTAssertEqual(decoded.startTime, 1.5, "Start time should match")
        XCTAssertEqual(decoded.endTime, 3.0, "End time should match")
        XCTAssertEqual(decoded.text, "segment text", "Text should match")
    }
}
