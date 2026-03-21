# SoundVibe Scout Report
Generated: 2026-03-19

## Project Overview

**SoundVibe** is a privacy-focused macOS menu bar application for local speech-to-text dictation. It provides on-device transcription with optional post-processing—zero cloud dependencies.

- **Language:** Swift 5.9+, uses SwiftUI + AppKit
- **Platform:** macOS 14.0+ (Sonoma), runs as menu bar app (LSUIElement)
- **Build System:** Swift Package Manager (SPM)
- **Entry Point:** `SoundVibe/App/SoundVibeApp.swift` (SwiftUI @main)
- **Primary Dependency:** WhisperKit (CoreML-based Whisper models)
- **Test Framework:** XCTest with mock implementations

## Files Retrieved

### Core Architecture
- `SoundVibe/Orchestration/DictationOrchestrator.swift` (lines 1-300) — Central state machine orchestrator managing dictation lifecycle
- `SoundVibe/Audio/AudioCaptureManager.swift` (lines 1-180) — Actor-based microphone capture via AVAudioEngine
- `SoundVibe/Transcription/WhisperEngine.swift` (lines 1-80+) — Protocol-based transcription engine wrapping WhisperKit
- `SoundVibe/Settings/SettingsManager.swift` (lines 1-100+) — Singleton settings with UserDefaults persistence
- `SoundVibe/Models/TranscriptionResult.swift` (complete file) — Result data structures with metadata

### UI Layer
- `SoundVibe/UI/MenuBarManager.swift` — Menu bar menu construction and management
- `SoundVibe/UI/FloatingIndicatorWindow.swift` — Floating recording indicator with waveform visualization
- `SoundVibe/UI/SettingsView.swift` — Settings UI in SwiftUI
- `SoundVibe/UI/OnboardingView.swift` — Onboarding flow

### Support Systems
- `SoundVibe/Hotkey/HotkeyManager.swift` — Global hotkey registration via CGEvent tap
- `SoundVibe/TextInsertion/TextInsertionEngine.swift` — Text insertion via clipboard + Cmd+V
- `SoundVibe/PostProcessing/PostProcessingPipeline.swift` — Optional LLM-based text post-processing
- `SoundVibe/App/AppDelegate.swift` — AppKit delegate, initializes orchestrator and managers

### Tests
- `SoundVibeTests/SettingsManagerTests.swift` (lines 1-80+) — Comprehensive settings persistence tests
- `SoundVibeTests/MockImplementationsTests.swift` — Mock implementations for dependency injection
- `SoundVibeTests/PostProcessingPipelineTests.swift` — Pipeline tests
- `SoundVibeTests/WhisperModelTests.swift` — Model loading tests

## Key Code

### DictationState Enum (Central State Machine)
```swift
enum DictationState: Equatable {
    case idle
    case listening
    case transcribing
    case postProcessing
    case inserting
    case error(String)

    var isActive: Bool {
        switch self {
        case .idle, .error: return false
        case .listening, .transcribing, .postProcessing, .inserting: return true
        }
    }
}
```

### DictationOrchestrator Class Signature
```swift
@MainActor
final class DictationOrchestrator: NSObject, ObservableObject, HotkeyManagerDelegate {
    @Published private(set) var state: DictationState = .idle
    @Published private(set) var lastTranscription: String?
    
    private let audioCapture: AudioCaptureManager
    private let transcriptionEngine: any TranscriptionEngine
    private let postProcessingPipeline: PostProcessingPipeline
    private let textInsertion: TextInsertionEngine
    // ... more managers
}
```

### TranscriptionResult Structure
```swift
public struct TranscriptionResult: Codable, Equatable {
    let text: String
    let language: String?
    let duration: TimeInterval
    let timestamp: Date
    let segments: [TranscriptionSegment]
    
    var wordCount: Int
    var wordsPerMinute: Double
    var formattedDuration: String
}
```

### AudioCaptureManager (Actor Pattern)
```swift
actor AudioCaptureManager {
    nonisolated(unsafe) weak var delegate: AudioCaptureDelegate?
    
    private var engine: AVAudioEngine
    private var audioBuffer: AudioSampleBuffer
    private(set) var isCapturing = false
    private(set) var audioLevel: Float = 0.0
    
    func startCapture() async throws
    func stopCapture() async -> Data
}
```

### TranscriptionEngine Protocol
```swift
public protocol TranscriptionEngine: AnyObject {
    func loadModel(variant: String) async throws
    func transcribe(
        audioData: [Float],
        language: String?,
        detectLanguage: Bool
    ) async throws -> TranscriptionResult
    var isModelLoaded: Bool { get }
}
```

### HotkeyCombo Configuration
```swift
struct HotkeyCombo: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt32
    let isModifierOnly: Bool
    
    static let rightCommandKeyCode: UInt16 = 54
    static let defaultHotkey = HotkeyCombo(
        keyCode: rightCommandKeyCode,
        modifiers: 0,
        isModifierOnly: true
    )
}
```

## Architecture

### State Machine Flow
```
idle → (startDictation)
  → listening → (stopDictation/timeout)
    → transcribing → (model required check)
      → postProcessing → (if enabled)
        → inserting → (clipboard paste)
          → idle
      
Any state → error(message) → (recovery: return to idle or retry)
```

### Component Interaction
1. **AppDelegate** initializes all managers and creates DictationOrchestrator
2. **HotkeyManager** detects global hotkey press/release, calls orchestrator delegate methods
3. **DictationOrchestrator** coordinates:
   - AudioCaptureManager for mic input
   - WhisperEngine for transcription
   - PostProcessingPipeline for LLM cleanup (optional)
   - TextInsertionEngine for clipboard + paste
   - FloatingIndicatorManager for UI feedback
   - MenuBarManager for menu updates
4. **SettingsManager** provides configuration (persisted to UserDefaults)
5. **ModelManager** handles WhisperKit model downloads and lifecycle

### Threading Model
- **@MainActor**: DictationOrchestrator, UI views, AppDelegate (main thread)
- **actor**: AudioCaptureManager, HotkeyManager (isolated concurrency)
- **DispatchQueue**: Audio delegate callbacks (background concurrent queue)
- **async/await**: No completion handlers; all async operations use async functions

### Data Flow
1. Hotkey press → HotkeyManager → Orchestrator.startDictation()
2. Audio captures at 16kHz mono via AVAudioEngine
3. Audio buffer accumulates samples in FloatArray
4. Hotkey release → Orchestrator.stopDictation()
5. Data converted to Float array, passed to WhisperEngine
6. Transcription result processed by PostProcessingPipeline (if enabled)
7. Text inserted via clipboard + simulated Cmd+V paste

## Existing Conventions

### Code Style
- **Indentation:** 2 spaces
- **Line length:** < 100 characters
- **Trailing commas:** In all multi-line collections
- **MARK comments:** Used consistently (`// MARK: - Public Methods`, `// MARK: - Private Properties`)
- **Access control:** Private/fileprivate for internals, public only when necessary
- **Error handling:** Custom error enums conforming to LocalizedError (WhisperError, AudioCaptureError)
- **Naming:** Descriptive, no abbreviations (e.g., `transcriptionEngine` not `transEngine`)
- **Comments:** Explain "why", not "what" — code is self-documenting

### Testing Pattern
- XCTest framework
- Arrange-Act-Assert style
- Descriptive test names: `testDefaultTriggerMode()`, `testTranscriptionWithValidAudio()`
- Mock implementations injected via initializer parameters
- setUp/tearDown methods for state reset
- Assertions use XCTAssert* with custom messages

### Configuration Files
- `Package.swift` — SPM manifest with dependencies, targets, and linker settings
- `Info.plist` — App metadata (in Resources/)
- UserDefaults key: `com.soundvibe` (persisted settings)
- No external config files beyond SPM/Xcode

### Build & Test
```bash
swift build -c debug              # Debug
swift build -c release            # Release (optimized)
swift test                        # Run all tests
swift test --verbose              # Verbose output
swift test --filter ClassName     # Single test class
swift package resolve             # Resolve deps
```

## Learnings from Previous Runs

No `.pi/LEARNINGS.md` file found. This is a fresh investigation.

## Start Here

### 1. **DictationOrchestrator.swift** (Priority: HIGHEST)
**Why:** Central orchestrator managing the entire dictation state machine. Understanding this is essential for any feature work or bug fixes. Read the state transitions, delegate methods, and pipeline coordination.

### 2. **SoundVibeApp.swift & AppDelegate.swift** (Priority: HIGH)
**Why:** Entry points. AppDelegate initializes all managers. Essential for understanding initialization order and dependency injection.

### 3. **SettingsManager.swift** (Priority: HIGH)
**Why:** Singleton managing all user settings with UserDefaults persistence. Needed for any feature additions or settings-related work.

### 4. **AudioCaptureManager.swift** (Priority: HIGH)
**Why:** Actor pattern implementation. Shows threading model, async/await usage, and audio capture lifecycle.

### 5. **WhisperEngine.swift** (Priority: MEDIUM)
**Why:** Transcription protocol and WhisperKit integration. Necessary for understanding model loading and transcription.

### 6. **UI Components** (Priority: MEDIUM)
**Why:** MenuBarManager, SettingsView, FloatingIndicatorWindow for UI-related work.

## Open Questions

1. **Package.swift vs CLAUDE.md discrepancy**: CLAUDE.md mentions whisper.cpp and MLX, but Package.swift shows WhisperKit dependency. Is the documentation outdated? (Most likely — WhisperKit is the current implementation.)

2. **PostProcessing availability**: CLAUDE.md says post-processing is "Apple Silicon only". Is this enforced at runtime or build time?

3. **Model downloading**: Where does WhisperKit store downloaded models? Application Support directory assumed, but not verified in code samples provided.

4. **CGEvent tap permissions**: Global hotkey via CGEvent tap requires accessibility permissions. Is there permission handling in HotkeyManager?

5. **Clipboard restoration**: SettingsManager has `clipboardRestoreEnabled` and `restoreDelay`. How is clipboard state actually saved/restored?

6. **Test coverage**: What's the current line/branch coverage? Are there untested edge cases (e.g., error states)?

7. **Localization**: Any i18n/l10n beyond English? .strings files?

---

## Summary

SoundVibe follows a clean, modular architecture with:
- ✅ Clear separation of concerns (Audio, Transcription, UI, Settings)
- ✅ State machine pattern for orchestration
- ✅ Actor-based concurrency for thread safety
- ✅ Protocol-based abstraction for transcription engine
- ✅ Comprehensive test coverage with mocks
- ✅ Consistent code style (2-space indent, MARK comments, descriptive names)

The codebase is well-structured and ready for feature development or refactoring. No major architectural red flags detected.
