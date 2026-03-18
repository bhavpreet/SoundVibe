import XCTest
@testable import SoundVibe

final class VoiceCommandParserTests: XCTestCase {

    // MARK: - Punctuation Commands

    func testPeriodCommand() {
        let input = "hello period"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "hello.", "Period command should replace 'period' with '.'")
    }

    func testFullStopCommand() {
        let input = "hello full stop"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "hello.", "Full stop should replace 'full stop' with '.'")
    }

    func testCommaCommand() {
        let input = "hello comma how are you"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "hello, how are you", "Comma command should replace 'comma' with ','")
    }

    func testQuestionMarkCommand() {
        let input = "hello question mark"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "hello?", "Question mark command should replace 'question mark' with '?'")
    }

    func testExclamationMarkCommand() {
        let input = "hello exclamation mark"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "hello!", "Exclamation mark command should replace 'exclamation mark' with '!'")
    }

    func testExclamationCommand() {
        let input = "hello exclamation"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "hello!", "Exclamation command should replace 'exclamation' with '!'")
    }

    func testColonCommand() {
        let input = "list colon"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "list:", "Colon command should replace 'colon' with ':'")
    }

    func testSemicolonCommand() {
        let input = "first semicolon second"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "first; second", "Semicolon command should replace 'semicolon' with ';'")
    }

    // MARK: - Spacing Tests

    func testPeriodSpacingNoExtraSpace() {
        let input = "hello period"
        let result = VoiceCommandParser.parse(input)
        // Period should replace "period" exactly, no double spacing
        XCTAssertEqual(result, "hello.", "Period should not create extra spacing")
    }

    func testCommaSpacingNoExtraSpace() {
        let input = "hello comma world"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "hello, world", "Comma should not create extra spacing")
    }

    // MARK: - Case Insensitivity

    func testNewLineCommandCaseInsensitive() {
        let input = "hello NEW LINE world"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "hello\nworld", "NEW LINE (uppercase) should work")
    }

    func testNewLineCommand() {
        let input = "hello new line world"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "hello\nworld", "new line command should create a newline")
    }

    func testNextLineCommand() {
        let input = "hello next line world"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "hello\nworld", "next line command should create a newline")
    }

    func testNewParagraphCommand() {
        let input = "first sentence new paragraph second sentence"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "first sentence\n\nsecond sentence", "new paragraph should create two newlines")
    }

    func testPeriodCommandCaseInsensitive() {
        let input = "hello PERIOD"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "hello.", "PERIOD (uppercase) should work")
    }

    func testCommaCommandCaseInsensitive() {
        let input = "hello COMMA world"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "hello, world", "COMMA (uppercase) should work")
    }

    func testMixedCaseCommand() {
        let input = "hello NeW LiNe world"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "hello\nworld", "Mixed case commands should work")
    }

    // MARK: - Multiple Commands

    func testMultipleCommands() {
        let input = "hello comma how are you question mark"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "hello, how are you?", "Multiple commands should all be processed")
    }

    func testMultiplePunctuationCommands() {
        let input = "first period second comma third question mark"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "first. second, third?", "All punctuation commands should be replaced")
    }

    // MARK: - Commands at Beginning and End

    func testCommandAtBeginning() {
        let input = "period hello world"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, ". hello world", "Command at beginning should be processed")
    }

    func testCommandAtEnd() {
        let input = "hello world period"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "hello world.", "Command at end should be processed")
    }

    func testMultipleCommandsAtEnd() {
        let input = "hello question mark"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "hello?", "Commands at end should be processed")
    }

    // MARK: - Regular Text Preservation

    func testRegularTextNotAffected() {
        let input = "this is regular text with no commands"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, input, "Regular text should not be affected")
    }

    func testCommandWordsInsideOtherWords() {
        let input = "periodically comma separated"
        let result = VoiceCommandParser.parse(input)
        // "periodically" contains "period" but should NOT be affected due to word boundary
        // "comma" is part of another context, check if it's affected
        // Based on regex with \b, it should only match whole words
        XCTAssertTrue(result.contains("periodically"), "Partial word matches should not be replaced")
    }

    // MARK: - Empty and Edge Cases

    func testEmptyString() {
        let input = ""
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "", "Empty string should remain empty")
    }

    func testStringWithOnlySpaces() {
        let input = "   "
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "   ", "String with only spaces should remain unchanged")
    }

    func testStringWithNoCommands() {
        let input = "just some regular words here"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, input, "String with no commands should be unchanged")
    }

    // MARK: - Complex Scenarios

    func testFormattingCommands() {
        let input = "capitalize hello world"
        let result = VoiceCommandParser.parse(input)
        // The parser handles "capitalize word" pattern
        XCTAssertTrue(result.contains("Hello"), "Capitalize command should uppercase first letter")
    }

    func testUppercaseCommand() {
        let input = "uppercase hello world"
        let result = VoiceCommandParser.parse(input)
        // The parser handles "uppercase word" pattern
        XCTAssertTrue(result.contains("HELLO"), "Uppercase command should uppercase the word")
    }

    func testComplexSentence() {
        let input = "this is a test period new line here comma and here question mark"
        let result = VoiceCommandParser.parse(input)
        XCTAssertEqual(result, "this is a test.\nhere, and here?", "Complex sentence with multiple commands should be processed correctly")
    }

    func testNewParagraphPreservesContent() {
        let input = "first part new paragraph second part"
        let result = VoiceCommandParser.parse(input)
        XCTAssertTrue(result.contains("first part"), "Content before new paragraph should be preserved")
        XCTAssertTrue(result.contains("second part"), "Content after new paragraph should be preserved")
        XCTAssertTrue(result.contains("\n\n"), "new paragraph should create double newline")
    }
}
