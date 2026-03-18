# Contributing to SoundVibe

Thank you for considering contributing to SoundVibe! We welcome contributions from the community, whether they're bug reports, feature requests, documentation improvements, or code changes.

This document provides guidelines for contributing to the project.

---

## Table of Contents

- [Getting Started](#getting-started)
- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Code Style Guidelines](#code-style-guidelines)
- [Running Tests](#running-tests)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)
- [Reporting Issues](#reporting-issues)
- [Asking Questions](#asking-questions)

---

## Getting Started

1. **Fork the repository**: Click "Fork" on GitHub to create your own copy
2. **Clone your fork**: `git clone https://github.com/YOUR_USERNAME/soundvibe.git`
3. **Add upstream**: `git remote add upstream https://github.com/ORIGINAL_OWNER/soundvibe.git`
4. **Create a branch**: `git checkout -b feature/your-feature-name`
5. **Make changes** and commit regularly
6. **Push to your fork** and open a Pull Request

---

## Code of Conduct

Please be respectful and inclusive. We're committed to providing a welcoming environment for all contributors. Harassment, discrimination, or abusive behavior will not be tolerated.

---

## How to Contribute

### Report a Bug

1. **Check existing issues** first to avoid duplicates
2. **Use the bug report template** (if available)
3. **Include**:
   - macOS version and hardware (Apple Silicon or Intel)
   - SoundVibe version
   - Steps to reproduce
   - Expected behavior vs. actual behavior
   - Screenshots (if applicable)
   - Relevant logs (System Console or debug logs if enabled)

**Example**:
```
**Describe the bug**
Hotkey doesn't work after waking from sleep.

**To reproduce**
1. Configure hotkey as ⌥ Option + D
2. Sleep the Mac (Cmd+Eject)
3. Wake the Mac
4. Try to use the hotkey
→ Nothing happens

**Expected behavior**
Hotkey should work immediately after waking.

**Environment**
- macOS 14.2
- M2 MacBook Pro
- SoundVibe v1.0

**Additional context**
Logs show "Global hotkey registered and listening" but no key events detected after wake.
```

### Request a Feature

1. **Check existing issues/discussions** to see if it's already requested
2. **Describe the use case**: Why do you need this feature?
3. **Suggest an implementation** (if you have ideas)
4. **Be open to feedback**: The maintainers may suggest alternatives

**Example**:
```
**Feature request**
Add support for custom vocabulary for improved accuracy in domain-specific terms.

**Use case**
I dictate medical notes frequently. Terms like "hypertension" or "arrhythmia" are often misheard.

**Proposed solution**
Allow users to upload a custom vocabulary list in Settings > Transcription > Custom Vocabulary.

**Alternatives**
- Fine-tune Whisper model (more complex)
- Use post-processing to correct common mistakes (less accurate)
```

### Improve Documentation

1. Fork and clone the repo
2. Edit relevant `.md` files (README.md, ARCHITECTURE.md, etc.)
3. Test that links and code examples work
4. Submit a PR with your improvements

---

## Development Setup

### Prerequisites

- **Xcode 15.0+** with Command Line Tools
- **Swift 5.9+**
- **macOS 13+** for development
- **Git**

### Setup Steps

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/soundvibe.git
cd soundvibe

# Install dependencies (managed by Swift Package Manager)
swift package resolve

# Open in Xcode
open SoundVibe.xcodeproj

# Or build from command line
swift build -c debug
```

### Verify Setup

```bash
# Run tests
swift test

# Build the app
swift build -c release

# Check code compiles
swiftc SoundVibe/App/*.swift -typecheck
```

---

## Code Style Guidelines

### Swift Style

Follow **Apple's Swift Style Guide** with these additions:

#### Naming

```swift
// ✓ Clear, descriptive names
func startDictation() { }
var isRecording: Bool = false

// ✗ Vague abbreviations
func startDict() { }
var rec: Bool = false
```

#### Formatting

```swift
// Indentation: 2 spaces (Xcode default)
if condition {
  doSomething()
}

// Line length: Aim for < 100 characters (Xcode default)
// If line exceeds, break logically:
func transcribe(
  audioData: [Float],
  language: String?,
  detectLanguage: Bool
) async throws -> TranscriptionResult {
  // ...
}

// Trailing commas in collections
let array = [
  1,
  2,
  3,  // ✓ trailing comma for clarity
]
```

#### Comments

```swift
// ✓ Explain why, not what
// Whisper requires 16kHz mono audio; resample from device sample rate
let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)

// ✗ State the obvious
// Set the format
let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)

// MARK: for section headers
// MARK: - Public Methods
// MARK: - Private Methods
```

#### Access Control

```swift
// Mark internal implementation details as private
private var audioBuffer: AudioBuffer

// Mark public APIs that are safe to use
public func transcribe(audioData: [Float]) async throws -> TranscriptionResult

// Use fileprivate sparingly
fileprivate var setupOnce = false
```

#### Actors and MainActor

```swift
// Use @MainActor for UI-related code
@MainActor
final class MenuBarManager: ObservableObject {
  @Published var state: MenuBarState
}

// Use actor for background state isolation
actor AudioCaptureManager {
  func startCapture() async throws
}

// Nonisolated for functions that don't need isolation
nonisolated func checkAccessibilityPermission() -> Bool
```

#### Error Handling

```swift
// Define specific error types
enum WhisperError: LocalizedError {
  case modelNotLoaded
  case transcriptionFailed(reason: String)

  var errorDescription: String? {
    switch self {
    case .modelNotLoaded: return "No Whisper model loaded"
    case .transcriptionFailed(let reason): return "Failed: \(reason)"
    }
  }
}

// Catch specific errors
do {
  try await transcribe()
} catch let error as WhisperError {
  logger.error("Whisper failed: \(error.localizedDescription)")
} catch {
  logger.error("Unexpected: \(error)")
}
```

#### Async/Await

```swift
// Use async/await for async operations
func transcribe(audioData: [Float]) async throws -> TranscriptionResult {
  // ...
}

// Don't nest Completion handlers
// ✗ Don't do this
func transcribe(audioData: [Float], completion: @escaping (Result<String, Error>) -> Void) {
  // callback hell
}

// ✓ Do this instead
func transcribe(audioData: [Float]) async throws -> TranscriptionResult {
  // linear flow
}
```

---

## Running Tests

### Unit Tests

```bash
# Run all tests
swift test

# Run specific test
swift test TranscriptionEngineTests

# Run with verbose output
swift test --verbose

# Run tests in Xcode
Product → Test (Cmd+U)
```

### Test Coverage

Aim for > 80% coverage of public APIs:

```bash
# Generate coverage report (requires platform-specific tools)
# This is optional but encouraged for critical modules
```

### Writing Tests

```swift
// Use descriptive test names
func testTranscribeWithValidAudioReturnsText() {
  // Arrange
  let engine = MockTranscriptionEngine()
  let expectedResult = TranscriptionResult(text: "Hello world", language: "en")
  engine.setMockResult(expectedResult)

  // Act
  let result = try await engine.transcribe(audioData: mockAudio)

  // Assert
  XCTAssertEqual(result.text, "Hello world")
}

// Mock dependencies for isolation
let mockEngine = MockTranscriptionEngine()
let orchestrator = DictationOrchestrator(
  transcriptionEngine: mockEngine,
  // ...
)
```

---

## Commit Messages

Write clear, concise commit messages:

### Format

```
[Type] Brief summary (50 chars or less)

Longer explanation if needed (72 chars per line).

Closes #123
```

### Types

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation only
- `refactor:` Code restructuring (no functional change)
- `test:` Adding or updating tests
- `perf:` Performance improvement
- `chore:` Dependency updates, build changes

### Examples

```
✓ feat: Add noise gate to audio capture

Implement configurable noise gate in AudioCaptureManager to filter
background noise before transcription. Adds settings control in Audio tab.

Closes #45

---

✓ fix: Prevent hotkey registering twice on app launch

HotkeyManager.start() was called twice during initialization, causing
the second call to fail silently. Now ensure only one start() call.

Fixes #78

---

✓ docs: Update architecture guide with threading model

Add section explaining actor isolation, MainActor usage, and background
queues. Include examples of thread-safe patterns.
```

---

## Pull Request Process

### Before You Start

1. **Check existing PRs** to avoid duplicate work
2. **Open an issue first** for major features (discuss approach)
3. **Keep PRs focused**: One feature or bug fix per PR
4. **Stay in sync**: `git pull upstream main` before opening PR

### Creating a PR

1. **Push to your fork**: `git push origin feature/your-feature`
2. **Open PR on GitHub**: Click "New Pull Request"
3. **Fill out template** (if available):
   - Description: What does this change do?
   - Why: Why is this change needed?
   - Testing: How did you test this?
   - Breaking changes: Any API changes?

### PR Guidelines

- **Title**: Brief, descriptive (e.g., "Add noise gate to audio capture")
- **Description**: Explain the change and why it's needed
- **Tests**: Include tests for new functionality
- **Documentation**: Update docs if behavior changes
- **No merge conflicts**: Rebase on main if needed
- **Passing CI**: All tests and checks must pass

### Review Process

1. **Maintainers review** your PR
2. **Respond to feedback**: Be open to suggestions
3. **Make requested changes** in new commits
4. **Push updates**: `git push origin feature/your-feature`
5. **Approval**: Once approved, maintainers will merge

### PR Checklist

Before submitting, ensure:

- [ ] Code follows style guidelines
- [ ] Tests pass (`swift test`)
- [ ] Tests cover new functionality
- [ ] Documentation is updated
- [ ] Commit messages are clear
- [ ] No unrelated changes included
- [ ] Branch is up-to-date with main
- [ ] PR description is detailed

---

## Reporting Issues

### Security Issues

**Do NOT open a public issue for security vulnerabilities**. Email security@soundvibe.example (coming soon) instead.

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Your name/attribution (optional)

### Other Issues

Use the **Issues** tab on GitHub. Provide:

1. **Title**: Concise description of the problem
2. **Environment**: macOS version, hardware (M1/Intel), SoundVibe version
3. **Steps to reproduce**: How to trigger the issue
4. **Expected behavior**: What should happen
5. **Actual behavior**: What actually happens
6. **Screenshots/logs**: If applicable, attach Console logs or debug output
7. **Attempted fixes**: What have you tried?

---

## Asking Questions

- **Questions about usage?** Check README.md and ARCHITECTURE.md first
- **GitHub Discussions** (if available): Use for general questions
- **GitHub Issues**: Use for bugs and feature requests, not Q&A
- **Email**: Contact the maintainers (coming soon)

---

## Recognition

Contributors will be recognized in:
- **README**: List of contributors
- **Release notes**: Mention in changelog
- **GitHub**: Auto-recognized as contributor

Thank you for making SoundVibe better!

---

## Helpful Resources

- **Swift Style Guide**: https://google.github.io/swift/
- **Apple's Swift Docs**: https://developer.apple.com/swift/
- **macOS App Development**: https://developer.apple.com/documentation/appkit/
- **Async/Await Guide**: https://developer.apple.com/videos/play/wwdc2021/10132/
- **GitHub Flow**: https://guides.github.com/introduction/flow/

---

## Questions?

- Open an issue with the `question` label
- Refer to [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
- Check existing discussions for similar topics

---

**Happy contributing! 🙌**
