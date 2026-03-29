import XCTest
@testable import SoundVibe

final class TranscriptionFilterTests: XCTestCase {

  // MARK: - isHallucination Tests

  func testKnownHallucinationsAreDetected() {
    let hallucinations = [
      "Thanks for watching",
      "THANKS FOR WATCHING",
      "thank you for watching.",
      "Subscribe to my channel!",
      "  like and subscribe  ",
      "Subtitles by",
      "translated by",
      "see you next time",
    ]

    for text in hallucinations {
      XCTAssertTrue(
        TranscriptionFilter.isHallucination(text),
        "Should detect hallucination: \"\(text)\""
      )
    }
  }

  func testLegitimateTextIsNotFiltered() {
    let legitimate = [
      "Hello world",
      "Send the email to John",
      "Meeting at 3pm tomorrow",
      "The quick brown fox jumps over the lazy dog",
      "I need to buy groceries",
      "Please review the pull request",
      "Goodbye",  // common word, should NOT be filtered
      "Music",    // common word, should NOT be filtered
      "You",      // common word, should NOT be filtered
      "Visit the website",
      "Go to the store",
      "The end of the road",
    ]

    for text in legitimate {
      XCTAssertFalse(
        TranscriptionFilter.isHallucination(text),
        "Should NOT filter legitimate text: \"\(text)\""
      )
    }
  }

  func testEmptyAndShortTextIsHallucination() {
    XCTAssertTrue(TranscriptionFilter.isHallucination(""))
    XCTAssertTrue(TranscriptionFilter.isHallucination(" "))
    XCTAssertTrue(TranscriptionFilter.isHallucination("a"))
    XCTAssertTrue(TranscriptionFilter.isHallucination("."))
  }

  func testRepeatedWordsAreHallucination() {
    XCTAssertTrue(
      TranscriptionFilter.isHallucination("the the the"),
      "Three repeated words should be detected"
    )
    XCTAssertTrue(
      TranscriptionFilter.isHallucination("um um um um"),
      "Repeated filler words should be detected"
    )
  }

  func testTwoRepeatedWordsAreNotFiltered() {
    // Two repeated words is too aggressive to filter — could be
    // legitimate (e.g. "bye bye" as a name, "no no")
    XCTAssertFalse(
      TranscriptionFilter.isHallucination("no no"),
      "Two repeated words should not be filtered"
    )
  }

  func testPunctuationIsStrippedForMatching() {
    XCTAssertTrue(
      TranscriptionFilter.isHallucination("Thanks for watching!"),
      "Punctuation should be stripped before matching"
    )
    XCTAssertTrue(
      TranscriptionFilter.isHallucination("...subtitles by..."),
      "Dots should be stripped before matching"
    )
  }

  // MARK: - hasSufficientSpeech Tests

  func testAllZeroSamplesHaveNoSpeech() {
    let silence = [Float](repeating: 0, count: 16000) // 1 second
    XCTAssertFalse(
      TranscriptionFilter.hasSufficientSpeech(in: silence),
      "All-zero audio should have no speech"
    )
  }

  func testEmptySamplesHaveNoSpeech() {
    XCTAssertFalse(
      TranscriptionFilter.hasSufficientSpeech(in: []),
      "Empty audio should have no speech"
    )
  }

  func testSineWaveHasSpeech() {
    // Generate a 440Hz sine wave at 16kHz — clearly has energy
    let sampleRate: Double = 16000
    let duration: Double = 1.0
    let count = Int(sampleRate * duration)
    var samples = [Float](repeating: 0, count: count)
    for i in 0..<count {
      samples[i] = 0.5 * sin(2.0 * .pi * 440.0 * Float(i) / Float(sampleRate))
    }

    XCTAssertTrue(
      TranscriptionFilter.hasSufficientSpeech(in: samples),
      "Sine wave should be detected as having speech energy"
    )
  }

  func testVeryQuietAudioHasNoSpeech() {
    // Audio at ~-80dB — too quiet for speech
    let count = 16000
    var samples = [Float](repeating: 0, count: count)
    for i in 0..<count {
      samples[i] = 0.0001 * sin(2.0 * .pi * 440.0 * Float(i) / 16000.0)
    }

    XCTAssertFalse(
      TranscriptionFilter.hasSufficientSpeech(in: samples),
      "Very quiet audio should not be detected as speech"
    )
  }

  func testMostlySilentWithBriefSpeechPasses() {
    // 2 seconds of audio, first 1.8s silent, last 0.2s has signal
    // 10% of frames have speech = meets the threshold
    let sampleRate: Double = 16000
    let totalSamples = Int(sampleRate * 2.0)
    let speechStart = Int(sampleRate * 1.6) // speech in last 0.4s = 20%
    var samples = [Float](repeating: 0, count: totalSamples)
    for i in speechStart..<totalSamples {
      samples[i] = 0.3 * sin(2.0 * .pi * 300.0 * Float(i) / Float(sampleRate))
    }

    XCTAssertTrue(
      TranscriptionFilter.hasSufficientSpeech(in: samples),
      "Audio with 20% speech should pass the 10% threshold"
    )
  }
}
