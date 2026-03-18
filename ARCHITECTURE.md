# SoundVibe Architecture Documentation

This document provides a comprehensive technical overview of the SoundVibe macOS dictation app for developers and future LLM implementations. It covers the architecture, module design, threading model, state management, and key technical decisions.

**Last Updated:** March 17, 2026
**Target Audience:** Developers, system architects, LLMs, and contributors

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Architecture Overview](#architecture-overview)
3. [Module Documentation](#module-documentation)
4. [Threading Model](#threading-model)
5. [State Machine](#state-machine)
6. [Error Handling](#error-handling)
7. [Settings Persistence](#settings-persistence)
8. [Model Management](#model-management)
9. [Testing Strategy](#testing-strategy)
10. [Key Design Decisions](#key-design-decisions)
11. [How to Modify SoundVibe](#how-to-modify-soundvibe)
12. [LLM-Specific Guidance](#llm-specific-guidance)
13. [Common Pitfalls](#common-pitfalls)

---

## Project Structure

```
SoundVibe/
├── Package.swift                      # Swift package manifest
├── SoundVibe/                         # Main app bundle
│   ├── App/
│   │   ├── AppDelegate.swift          # Lifecycle, initialization orchestration
│   │   └── SoundVibeApp.swift         # @main entry point, SwiftUI app
│   ├── Models/
│   │   ├── WhisperModel.swift         # Whisper model enums, metadata
│   │   └── AudioBuffer.swift          # Audio buffer management (if exists)
│   ├── Audio/
│   │   └── AudioCaptureManager.swift  # AVAudioEngine wrapper, microphone input
│   ├── Hotkey/
│   │   └── HotkeyManager.swift        # CGEvent tap, global hotkey registration
│   ├── Transcription/
│   │   ├── WhisperEngine.swift        # whisper.cpp wrapper, transcription logic
│   │   ├── ModelManager.swift         # Model downloads, disk management, checksums
│   │   └── TranscriptionEngine.swift  # Protocol for pluggable engines
│   ├── TextInsertion/
│   │   └── TextInsertionEngine.swift  # Clipboard + CGEvent Cmd+V simulation
│   ├── PostProcessing/
│   │   ├── PostProcessor.swift        # MLX LLM wrapper, post-processing modes
│   │   ├── PostProcessingPipeline.swift # Voice command parser + LLM processor
│   │   └── VoiceCommandParser.swift   # Voice command detection (if separate)
│   ├── Settings/
│   │   └── SettingsManager.swift      # UserDefaults persistence, @Published properties
│   ├── UI/
│   │   ├── MenuBarManager.swift       # Menu bar status item, menu construction
│   │   ├── SettingsView.swift         # SwiftUI settings window (5 tabs)
│   │   ├── OnboardingView.swift       # First-run setup flow
│   │   └── FloatingIndicatorWindow.swift # NSPanel floating indicator + view
│   └── Orchestration/
│       └── DictationOrchestrator.swift # Main coordinator, state machine, pipeline
├── Resources/
│   ├── Info.plist                     # App metadata (bundle identifier, version)
│   └── Assets/                        # Images, icons (if any bundled)
└── Tests/
    ├── TranscriptionEngineTests.swift
    ├── TextInsertionEngineTests.swift
    ├── PostProcessingTests.swift
    └── MockImplementations.swift       # Test doubles

```

### Key File Descriptions

| File | Lines | Purpose |
|------|-------|---------|
| `AppDelegate.swift` | 242 | Initializes all components in correct order, handles lifecycle |
| `SoundVibeApp.swift` | 29 | SwiftUI @main entry, delegates to AppDelegate |
| `DictationOrchestrator.swift` | 436 | State machine, coordinates audio → transcription → post-processing → insertion |
| `HotkeyManager.swift` | 223 | CGEvent tap, thread-safe hotkey detection |
| `AudioCaptureManager.swift` | 245 | AVAudioEngine wrapper, async audio capture, permission handling |
| `WhisperEngine.swift` | 333 | whisper.cpp C interop, async transcription |
| `TextInsertionEngine.swift` | 228 | Clipboard + CGEvent, Cmd+V simulation, clipboard restoration |
| `PostProcessingPipeline.swift` | 282 | Voice command parsing + MLX LLM pipeline |
| `SettingsManager.swift` | 420 | UserDefaults @Published properties, settings export/import |
| `MenuBarManager.swift` | 357 | NSStatusItem menu, icon updates, UI state reflection |
| `ModelManager.swift` | 408 | Model downloads with progress, checksum verification, disk management |

---

## Architecture Overview

SoundVibe follows a **modular, layered architecture** with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                     SoundVibe App                            │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │             DictationOrchestrator (@MainActor)      │   │
│  │  • Manages entire dictation workflow                │   │
│  │  • State machine (idle → listening → transcribing...) │   │
│  │  • Coordinates all modules                          │   │
│  └──────────────────────────────────────────────────────┘   │
│           │                     │                  │         │
│           ▼                     ▼                  ▼         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────┐  │
│  │   Hotkey        │  │  Audio Capture  │  │ Settings   │  │
│  │   Manager       │  │  Manager        │  │ Manager    │  │
│  │ (actor)         │  │ (actor)         │  │(@Published)│  │
│  └────────┬────────┘  └────────┬────────┘  └────────────┘  │
│           │                     │                            │
│     🎹 User presses        🎤 Records audio              │
│     hotkey                   → converts 16kHz mono PCM    │
│                              → Float[] format             │
│           │                     │                            │
│           └──────────┬──────────┘                            │
│                      │                                       │
│                      ▼                                       │
│           ┌──────────────────────┐                           │
│           │  Whisper Engine      │                           │
│           │  (asyncTaskQueue)    │                           │
│           └──────────┬───────────┘                           │
│                      │                                       │
│         🤖 Transcription:                                  │
│         whisper.cpp C context                            │
│         Core ML on Apple Silicon                         │
│                      │                                       │
│                      ▼                                       │
│      ┌───────────────────────────────────┐                  │
│      │ PostProcessing Pipeline (actor)   │                  │
│      │ • Voice command parser            │                  │
│      │ • MLX LLM (if enabled)            │                  │
│      └───────────────┬───────────────────┘                  │
│                      │                                       │
│         ✨ Optional LLM cleanup                            │
│         (clean, formal, concise, custom)                 │
│                      │                                       │
│                      ▼                                       │
│      ┌───────────────────────────────────┐                  │
│      │ Text Insertion Engine             │                  │
│      │ • Clipboard write                 │                  │
│      │ • CGEvent Cmd+V simulation        │                  │
│      │ • Clipboard restoration           │                  │
│      └───────────────────────────────────┘                  │
│                      │                                       │
│         📋 Final text:                                    │
│         Inserted into active text field                  │
│                      │                                       │
│  ┌───────────────────┴────────────────┐                     │
│  ▼                                    ▼                     │
│ MenuBarManager                   FloatingIndicatorManager │
│ • Updates menu bar icon          • Shows listening/       │
│ • Shows recent transcriptions      processing/success     │
│ • Reflects state (idle/listening)   states               │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Hotkey Press**: User presses configured hotkey
2. **Audio Capture**: `AudioCaptureManager` records from default microphone at 16kHz mono
3. **Transcription**: `WhisperEngine` processes audio via whisper.cpp
4. **Voice Commands**: `PostProcessingPipeline` parses commands ("period", "new line", etc.)
5. **LLM Post-Processing** (optional): `MLXPostProcessor` cleans text using local LLM
6. **Text Insertion**: `TextInsertionEngine` writes to clipboard and simulates Cmd+V
7. **Clipboard Restoration**: Original clipboard content is restored after paste
8. **UI Updates**: `MenuBarManager` and `FloatingIndicatorManager` reflect state

---

## Module Documentation

### 1. App Initialization (`App/`)

#### `SoundVibeApp.swift`
- **Role**: SwiftUI @main entry point
- **Responsibilities**:
  - Creates `AppDelegate` via `@NSApplicationDelegateAdaptor`
  - Defines `Settings` scene for preferences window
- **Key Exports**: None (pure entry point)
- **Thread Safety**: N/A (initialization only)

#### `AppDelegate.swift`
- **Role**: Orchestrates app lifecycle and full initialization
- **Responsibilities**:
  - **On launch**: Checks onboarding completion, initializes all components in strict order
  - **Component initialization order** (CRITICAL):
    1. `SettingsManager` (loads user preferences)
    2. Check onboarding; show if first launch
    3. `MenuBarManager` (creates menu bar icon)
    4. `AudioCaptureManager` (prepares audio engine)
    5. `FloatingIndicatorManager` (creates floating window)
    6. Model directory creation + Whisper engine initialization
    7. `TextInsertionEngine`
    8. `PostProcessingPipeline`
    9. `HotkeyManager` (with delegate set to orchestrator)
    10. `DictationOrchestrator` (main coordinator)
  - **On termination**: Cleanup (stop hotkey, stop audio, unload models)
  - **Error handling**: Shows alert dialogs for critical failures
- **Public API**:
  - None (internal lifecycle management)
- **Dependencies**:
  - All major modules
  - `OnboardingView` (for first-run flow)
- **Thread Safety**: Dispatches UI work to `DispatchQueue.main.async`

### 2. Models (`Models/`)

#### `WhisperModel.swift`
- **Role**: Metadata for Whisper model sizes
- **Responsibilities**:
  - Define available model sizes (tiny, base, small, medium, large-v3)
  - Provide metadata: display names, file sizes, download URLs, checksums
  - Computed properties for relative speed and accuracy metrics
  - Ensure models directory exists
- **Public API**:
  - `enum WhisperModelSize`: Codable enum of model options
  - Properties: `displayName`, `fileName`, `downloadURL`, `diskSize`, `parameterCount`, `relativeSpeed`, `wordErrorRate`
  - Static: `modelsDirectory`, `ensureModelsDirectoryExists()`
- **Dependencies**: None
- **Thread Safety**: Value type, immutable
- **Storage**: Models stored in `~/Library/Application Support/SoundVibe/Models/`

### 3. Audio Capture (`Audio/`)

#### `AudioCaptureManager.swift`
- **Role**: Manages microphone audio capture at 16kHz mono PCM
- **Responsibilities**:
  - Request microphone permission
  - Configure AVAudioEngine with 16kHz, 1 channel format
  - Collect audio buffers, consolidate into continuous stream
  - Support input device selection
  - Calculate audio level for UI feedback
  - Convert audio to float array (normalized -1.0 to 1.0)
  - Convert float to 16-bit PCM Data for Whisper
- **Public API**:
  ```swift
  actor AudioCaptureManager {
    func startCapture() async throws
    func stopCapture() -> Data  // Returns 16-bit PCM data
    func setInputDevice(_ deviceUID: String?) throws
    func listInputDevices() throws -> [(uid: String, name: String)]
    var isCapturing: Bool { get }
    var audioLevel: Float { get }  // RMS level 0-1
  }
  ```
- **Dependencies**:
  - `AVFoundation` (AVAudioEngine, AVAudioSession)
  - `AudioBuffer` (internal buffer accumulation)
- **Thread Safety**: `actor` (isolated), callbacks dispatch to delegate queue
- **Error Types**:
  - `microphonePermissionDenied`: User didn't grant permission
  - `deviceNotFound`: Selected input device doesn't exist
  - `engineStartFailed`: Audio engine startup failed
  - `noAudioCaptured`: Recording completed but no audio data
- **Key Details**:
  - Audio is 16-bit signed PCM, little-endian
  - Sample rate fixed at 16kHz (Whisper requirement)
  - RMS level calculation for floating indicator animation

### 4. Hotkey Management (`Hotkey/`)

#### `HotkeyManager.swift`
- **Role**: Global system-wide hotkey registration via CGEvent tap
- **Responsibilities**:
  - Install CGEvent tap for keyboard events (key down/up)
  - Match against configured hotkey (key code + modifiers)
  - Handle hold-to-talk (fire on key down, release on key up)
  - Handle toggle mode (fire on odd presses, release on even presses)
  - Require accessibility permission
  - Support hotkey updates at runtime
  - Run loop management for event delivery
- **Public API**:
  ```swift
  actor HotkeyManager {
    init(hotkey: HotkeyCombo, triggerMode: TriggerMode)
    func start() throws  // Requires accessibility permission
    func stop()
    func updateHotkey(_ combo: HotkeyCombo)
    func updateTriggerMode(_ mode: TriggerMode)
    var isEnabled: Bool { get }
    var currentHotkey: HotkeyCombo { get }
    weak var delegate: HotkeyManagerDelegate?
  }

  protocol HotkeyManagerDelegate: AnyObject {
    func hotkeyPressed()
    func hotkeyReleased()
  }
  ```
- **Dependencies**:
  - `Quartz` (CGEvent tap, CGEventTapProxy)
  - `ApplicationServices` (AXIsProcessTrusted)
- **Thread Safety**: `actor` (isolated); nonisolated callback dispatches to delegate queue
- **Error Types**:
  - `accessibilityPermissionDenied`: Missing accessibility in System Settings
  - `eventTapCreationFailed`: Failed to create CGEvent tap (rare)
  - `conflict`: Hotkey may conflict with other apps
- **Key Details**:
  - CGEvent tap is `CGHIDEventTap` (global hardware level)
  - Callback is nonisolated, dispatches to main thread via delegate queue
  - Modifier key matching is strict (all required modifiers must match exactly)
  - Toggle mode uses flag marker to track state

### 5. Transcription (`Transcription/`)

#### `WhisperEngine.swift`
- **Role**: Wraps whisper.cpp C library for speech-to-text inference
- **Responsibilities**:
  - Load Whisper model from disk
  - Perform transcription on float audio samples
  - Support language specification or auto-detection
  - Support translation and prompting
  - Async execution on background queue
  - Thread-safe model loading/unloading
- **Public API**:
  ```swift
  protocol TranscriptionEngine: AnyObject {
    func loadModel(at path: String) throws
    func transcribe(audioData: [Float], language: String?, detectLanguage: Bool)
      async throws -> TranscriptionResult
    var isModelLoaded: Bool { get }
    var currentModelPath: String? { get }
    func unloadModel()
  }

  struct TranscriptionResult {
    let text: String
    let language: String?
    let confidence: Double?
    let duration: TimeInterval
  }
  ```
- **Dependencies**:
  - `whisper.cpp` (via Swift bindings or C interop)
  - `Foundation` (async/await, DispatchQueue)
- **Thread Safety**: Non-atomic async transcription on background queue
- **Error Types**:
  - `modelNotLoaded`: No model loaded before transcribing
  - `modelLoadFailed(reason)`: Model file inaccessible or corrupted
  - `transcriptionFailed(reason)`: Whisper inference failed
  - `invalidAudioData`: Audio is empty or malformed
  - `cancelled`: Task cancelled during transcription
- **Key Details**:
  - Audio samples are Float32, expected at 16kHz
  - `WhisperContext` is internal wrapper around C context pointer
  - Async transcription uses `withCheckedThrowingContinuation`
  - Configuration methods: `setLanguage()`, `setTranslationEnabled()`, `setPrompt()`
- **MockImplementation**: `MockTranscriptionEngine` for testing

#### `ModelManager.swift`
- **Role**: Manages Whisper model downloads, storage, and disk lifecycle
- **Responsibilities**:
  - Download models from HuggingFace with progress tracking
  - Verify checksum (SHA256) for integrity
  - Cache models locally in `~/Library/Application Support/SoundVibe/Models/`
  - Check available disk space before download
  - Support download cancellation and resumption
  - Delete models to free disk space
  - Set active model for transcription
  - Track download progress (@Published)
- **Public API**:
  ```swift
  @MainActor
  class ModelManager: NSObject, ObservableObject {
    @Published var availableModels: [WhisperModel]
    @Published var downloadProgress: [WhisperModelSize: Double]
    @Published var activeModel: WhisperModelSize?

    func modelPath(for model: WhisperModelSize) -> URL
    func isModelDownloaded(_ model: WhisperModelSize) -> Bool
    func downloadModel(_ model: WhisperModelSize) async throws
    func cancelDownload(_ model: WhisperModelSize)
    func deleteModel(_ model: WhisperModelSize) throws
    func setActiveModel(_ model: WhisperModelSize) throws
  }
  ```
- **Dependencies**:
  - `Foundation` (URLSession, FileManager)
  - `CommonCrypto` (SHA256 verification)
- **Thread Safety**: `@MainActor` (UI thread only)
- **Error Types**:
  - `downloadFailed(reason)`: Network or server error
  - `checksumMismatch`: File integrity check failed
  - `diskSpaceInsufficient`: Not enough free space
  - `modelNotFound`: Model file doesn't exist
  - `deletionFailed(reason)`: Couldn't delete file
- **Key Details**:
  - Downloads from HuggingFace `ggerganov/whisper.cpp` repository
  - SHA256 checksum verification prevents corruption
  - 2x disk space buffer enforced during download
  - Progress updates published for UI binding
  - Models stored with descriptive filenames (`ggml-base.bin`, etc.)

### 6. Text Insertion (`TextInsertion/`)

#### `TextInsertionEngine.swift`
- **Role**: Pastes transcribed text into the active text field
- **Responsibilities**:
  - Write text to system clipboard
  - Simulate Cmd+V keystroke via CGEvent
  - Save and restore original clipboard content
  - Apply configurable delays for reliability
  - Verify accessibility permission
- **Public API**:
  ```swift
  class TextInsertionEngine {
    static let defaultPasteDelay: TimeInterval = 0.05
    static let defaultClipboardRestoreDelay: TimeInterval = 0.1

    func insertText(
      _ text: String,
      restoreClipboard: Bool = true,
      pasteDelay: TimeInterval = 0.05,
      restoreDelay: TimeInterval = 0.1
    ) async throws
  }
  ```
- **Dependencies**:
  - `AppKit` (NSPasteboard)
  - `CoreGraphics` (CGEvent)
  - `ApplicationServices` (AXIsProcessTrusted)
- **Thread Safety**: Async with Task.sleep for delays
- **Error Types**:
  - `accessibilityPermissionDenied`: Missing accessibility permission
  - `pasteSimulationFailed(reason)`: CGEvent creation or posting failed
  - `clipboardWriteFailed(reason)`: NSPasteboard write failed
  - `clipboardReadFailed(reason)`: NSPasteboard read failed
- **Key Details**:
  - Saves multiple clipboard formats (string, RTF, HTML, TIFF)
  - 'V' key code is 0x09 in standard US layout
  - Paste delay default 50ms; configurable 10-200ms
  - Clipboard restoration delay default 100ms
  - CGEvent tap is `.cghidEventTap` (hardware-level simulation)
  - Error recovery: attempts to restore clipboard even if paste fails

### 7. Post-Processing (`PostProcessing/`)

#### `PostProcessingPipeline.swift`
- **Role**: Orchestrates voice command parsing and optional LLM post-processing
- **Responsibilities**:
  - Parse voice commands from transcribed text
  - Delegate to LLM post-processor if enabled
  - Graceful degradation if post-processor unavailable
  - Log pipeline execution
- **Public API**:
  ```swift
  actor PostProcessingPipeline {
    init(postProcessor: TextPostProcessor? = nil)
    func process(_ text: String, settings: SettingsManager)
      async throws -> String
  }

  protocol TextPostProcessor: AnyObject, Sendable {
    func process(_ text: String, mode: PostProcessingMode) async throws -> String
    var isAvailable: Bool { get }
    var isProcessing: Bool { get }
  }
  ```
- **Dependencies**:
  - `PostProcessor.swift` (MLXPostProcessor)
  - `SettingsManager` (for mode and prompt)
- **Thread Safety**: `actor` (isolated)
- **Pipeline Steps**:
  1. Parse voice commands (punctuation, formatting, structure)
  2. If post-processing enabled AND available:
     - Call `postProcessor.process()` with selected mode
     - On success: return processed text
     - On failure: log error, return voice-command-parsed text (graceful degradation)
  3. If post-processing disabled: return voice-command-parsed text only

#### `PostProcessor.swift`
- **Role**: Local LLM inference for text cleanup using MLX
- **Responsibilities**:
  - Load quantized LLM models (e.g., Phi-3-mini)
  - Apply post-processing modes: clean, formal, concise, custom
  - Hardware detection (Apple Silicon only)
  - Async generation with timeout
  - Mode-specific system prompts
- **Public API**:
  ```swift
  public actor MLXPostProcessor: TextPostProcessor {
    public func loadModel(named modelName: String) async throws
    public func unloadModel()
    public func process(_ text: String, mode: PostProcessingMode) async throws -> String
    public var isAvailable: Bool { get }  // true only on Apple Silicon
    public var isProcessing: Bool { get }
  }

  public enum PostProcessingMode: String, CaseIterable {
    case clean      // Remove filler words, fix grammar
    case formal     // Business tone
    case concise    // Shorten while preserving meaning
    case custom     // User-provided prompt
  }
  ```
- **Dependencies**:
  - `MLX` Swift framework (Apple Silicon only)
  - `Foundation` (async/await)
- **Thread Safety**: `actor` (isolated)
- **Error Types**:
  - `modelNotLoaded`: Model not loaded before processing
  - `processingFailed(String)`: LLM inference failed
  - `modelLoadFailed(String)`: MLX model initialization failed
  - `unsupportedHardware`: Not on Apple Silicon
  - `cancelled`: Processing cancelled
- **Key Details**:
  - Apple Silicon detection: check `utsname` machine field for "arm64"
  - Simulated prompts (see system prompts in code)
  - Actual MLX integration requires Swift MLX bindings (commented TODO)
  - Text cleanup heuristics provided for simulation (remove filler words, capitalize, etc.)
- **MockImplementation**: `MockPostProcessor` for testing

#### `VoiceCommandParser` (within PostProcessingPipeline.swift)
- **Role**: Parses voice commands embedded in transcribed text
- **Voice Commands**:
  - **Punctuation**: "period", "comma", "question mark", "exclamation", "colon", "semicolon"
  - **Formatting**: "capitalize [word]", "uppercase [word]"
  - **Structure**: "new line", "new paragraph"
- **Implementation**: Regex-based pattern matching and replacement
- **Thread Safety**: Stateless (pure functions)

### 8. Settings Management (`Settings/`)

#### `SettingsManager.swift`
- **Role**: Centralized settings management with UserDefaults persistence
- **Responsibilities**:
  - Define all user-configurable settings
  - Persist to UserDefaults with @Published properties
  - Support settings export/import as JSON
  - Reset to defaults
  - Launch-at-login integration
- **Public API**:
  ```swift
  final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // Published properties (auto-persist on change)
    @Published var triggerMode: TriggerMode
    @Published var hotkey: HotkeyCombo
    @Published var selectedModelSize: WhisperModelSize
    @Published var selectedLanguage: String
    @Published var autoLanguageDetection: Bool
    @Published var autoPunctuation: Bool
    @Published var postProcessingEnabled: Bool
    @Published var postProcessingMode: PostProcessingMode
    @Published var customPostProcessingPrompt: String
    @Published var launchAtLogin: Bool
    @Published var showFloatingIndicator: Bool
    @Published var clipboardRestoreEnabled: Bool
    @Published var pasteDelay: TimeInterval
    @Published var silenceTimeout: TimeInterval
    @Published var selectedInputDevice: String?

    func resetToDefaults()
    func exportSettings() -> Data
    func importSettings(_ data: Data) throws
  }

  enum TriggerMode: String, Codable {
    case holdToTalk
    case toggle
  }

  struct HotkeyCombo: Codable, Equatable {
    let keyCode: UInt16
    let modifiers: UInt32
  }
  ```
- **Dependencies**:
  - `Foundation` (UserDefaults, Codable)
  - `AppKit` (NSEvent for hotkey description)
- **Thread Safety**: Main thread only (ObservableObject)
- **Storage**: `UserDefaults.standard` (domain: com.soundvibe)
- **Settings Keys**:
  - `soundvibe.triggerMode`, `soundvibe.hotkey`, `soundvibe.selectedModelSize`, etc.
  - Follows naming convention `soundvibe.<setting>`
- **Key Details**:
  - Hotkey default: key code 49 (spacebar), modifiers 0x80000 (Option)
  - Settings loaded in `init()`, saved on every @Published change
  - Export/import uses JSONSerialization for compatibility
  - Codable conformance for hotkey and trigger mode

### 9. User Interface (`UI/`)

#### `MenuBarManager.swift`
- **Role**: Menu bar status item, dropdown menu, and state reflection
- **Responsibilities**:
  - Create and manage NSStatusItem (menu bar icon)
  - Build dynamic menu with status, toggles, recent transcriptions
  - Update icon based on state (idle/listening/processing/error)
  - Show recent transcriptions (last 5)
  - Link to settings and about dialogs
- **Public API**:
  ```swift
  class MenuBarManager: NSObject, ObservableObject {
    static let shared = MenuBarManager()

    @Published var state: MenuBarState = .idle

    func updateState(_ state: MenuBarState)
    func addRecentTranscription(_ text: String)
  }

  enum MenuBarState {
    case idle
    case listening
    case processing
    case error
  }
  ```
- **Dependencies**:
  - `AppKit` (NSStatusBar, NSMenu, NSImage)
  - `SwiftUI` (NSHostingView for SettingsView)
  - `SettingsManager` (for post-processing toggle, language selection)
- **Thread Safety**: Main thread only (ObservableObject)
- **Menu Structure**:
  1. Status text (disabled)
  2. Separator
  3. Post-Processing toggle
  4. Language submenu (11 languages)
  5. Separator
  6. Recent Transcriptions submenu
  7. Separator
  8. Settings...
  9. About SoundVibe
  10. Separator
  11. Quit SoundVibe
- **Icons**:
  - Idle: `waveform.circle` (gray)
  - Listening: `waveform.circle.fill` (red)
  - Processing: `ellipsis.circle` (blue)
  - Error: `exclamationmark.circle` (red)
- **Key Details**:
  - Menu rebuilds on every state update
  - Recent transcriptions limited to 5 items
  - Long transcriptions truncated to 50 chars in menu

#### `SettingsView.swift`
- **Role**: SwiftUI settings window with 5 tabs
- **Responsibilities**:
  - Display and edit all settings
  - Show download progress for models
  - Launch settings in System Settings for permissions
  - Support settings export/import
- **Public API**:
  ```swift
  struct SettingsView: View {
    // TabView with 5 sub-views
  }

  // Sub-views:
  struct GeneralSettingsView: View        // Hotkey, trigger mode, launch at login
  struct AudioSettingsView: View          // Input device, silence timeout, noise gate
  struct TranscriptionSettingsView: View  // Model selection, language, auto-punctuation
  struct PostProcessingSettingsView: View // Enable, mode, custom prompt, model info
  struct AdvancedSettingsView: View       // Clipboard, paste delay, debug logging, export/import
  ```
- **Dependencies**:
  - `SwiftUI`
  - `AVFoundation` (audio device list)
  - `SettingsManager`
  - `AppKit` (save/open dialogs)
- **Thread Safety**: Main thread only (SwiftUI)
- **Key Details**:
  - Model download shown with ProgressView and simulated progress
  - Hotkey recorder sub-view shows button state (recording/recorded)
  - Advanced tab allows export to JSON and import from JSON
  - Reset to defaults shows confirmation alert

#### `OnboardingView.swift`
- **Role**: First-run setup flow for new users
- **Responsibilities**:
  - Guide through 6 steps (welcome, permissions, hotkey, language)
  - Request microphone permission
  - Direct to System Settings for accessibility
  - Automatically detect accessibility permission changes
  - Record hotkey and language selection
  - Save onboarding completion flag
- **Public API**:
  ```swift
  struct OnboardingView: View {
    // 6 TabView pages + progress indicator
    // Navigation: Back/Next buttons, conditional "Start Using SoundVibe"
  }

  // Step views:
  struct WelcomeStep: View
  struct MicrophonePermissionStep: View
  struct AccessibilityPermissionStep: View
  struct HotkeyStep: View
  struct LanguageStep: View
  struct ReadyStep: View
  ```
- **Dependencies**:
  - `SwiftUI`
  - `AVFoundation` (microphone permission request)
  - `AppKit` (NSWorkspace for opening System Settings)
- **Thread Safety**: Main thread only (SwiftUI)
- **Key Details**:
  - Progress indicator (6 circles, filled as you progress)
  - Accessibility detection polls with 0.5s timer
  - Settings URL: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
  - Onboarding completion flag: `SoundVibe_OnboardingCompleted` in UserDefaults
  - Hotkey and language saved before closing window

#### `FloatingIndicatorWindow.swift`
- **Role**: Non-activating floating panel showing recording/processing status
- **Responsibilities**:
  - Show listening state with animated waveform
  - Show processing state with spinner
  - Show success flash (1s)
  - Show error state (3s)
  - Auto-hide after timeout
  - Position near cursor
  - Render within SwiftUI
- **Public API**:
  ```swift
  class FloatingIndicatorManager {
    static let shared = FloatingIndicatorManager()

    func showListening()
    func showProcessing()
    func showSuccess()
    func showError()
    func hide()
  }

  class FloatingIndicatorWindow: NSPanel {
    func showListening()
    func showProcessing()
    func showSuccess()
    func showError()
    func hideIndicator()
  }
  ```
- **Dependencies**:
  - `AppKit` (NSPanel, NSScreen)
  - `SwiftUI` (FloatingIndicatorContentView)
- **Thread Safety**: Main thread only (AppKit)
- **Window Properties**:
  - `nonactivatingPanel` (won't steal focus)
  - `isFloatingPanel = true` (above all windows)
  - `.canJoinAllSpaces` (visible on all spaces/desktops)
  - Shadow and clear background
- **Animation**:
  - Waveform: sine wave animation at 0.05s intervals
  - Phase accumulates: `phase += 0.1`, wraps at 2π
  - 20 bars in waveform, height varies sinusoidally
- **Auto-Hide Timers**:
  - Listening: 30s
  - Processing: 10s
  - Success: 1s
  - Error: 3s

### 10. Orchestration (`Orchestration/`)

#### `DictationOrchestrator.swift`
- **Role**: Central state machine and pipeline coordinator
- **Responsibilities**:
  - Manage `DictationState` (idle, listening, transcribing, post-processing, inserting, error)
  - Implement `HotkeyManagerDelegate` (respond to hotkey pressed/released)
  - Orchestrate full pipeline: audio → transcription → post-processing → insertion
  - Update UI (menu bar, floating indicator) as state changes
  - Track recent transcriptions
  - Handle errors gracefully
- **Public API**:
  ```swift
  @MainActor
  final class DictationOrchestrator: NSObject,
                                     ObservableObject,
                                     HotkeyManagerDelegate {
    @Published private(set) var state: DictationState = .idle
    @Published private(set) var lastTranscription: String?
    @Published private(set) var recentTranscriptions: [String] = []

    init(
      audioCapture: AudioCaptureManager,
      transcriptionEngine: any TranscriptionEngine,
      postProcessingPipeline: PostProcessingPipeline,
      textInsertion: TextInsertionEngine,
      settingsManager: SettingsManager,
      hotkeyManager: HotkeyManager,
      menuBarManager: MenuBarManager,
      floatingIndicatorManager: FloatingIndicatorManager
    )

    func startDictation()
    func stopDictation()
    func cancelDictation()

    // HotkeyManagerDelegate
    nonisolated func hotkeyPressed()
    nonisolated func hotkeyReleased()
  }

  enum DictationState: Equatable {
    case idle
    case listening
    case transcribing
    case postProcessing
    case inserting
    case error(String)

    var isActive: Bool { ... }  // true if not idle or error
  }
  ```
- **Dependencies**:
  - All other modules (audio, hotkey, transcription, etc.)
- **Thread Safety**: `@MainActor` (main thread only)
- **State Machine**:
  ```
  idle
    ↓
  (user presses hotkey)
    ↓
  listening ← (audio recording)
    ↓
  (user releases hotkey or toggles)
    ↓
  transcribing ← (whisper.cpp processes audio)
    ↓
  postProcessing ← (if enabled, MLX cleans text)
    ↓
  inserting ← (clipboard write + Cmd+V)
    ↓
  idle ← (or error on any failure)
  ```
- **Pipeline Details**:
  1. `startDictation()`: Transition to `.listening`, start audio capture
  2. `stopDictation()`: Stop audio, convert to float array, start pipeline
  3. `performTranscriptionPipeline()`: Async method that:
     - Transition to `.transcribing`
     - Call `WhisperEngine.transcribe()`
     - Transition to `.postProcessing`
     - Call `PostProcessingPipeline.process()` (if enabled)
     - Transition to `.inserting`
     - Call `TextInsertionEngine.insertText()`
     - Update `lastTranscription` and `recentTranscriptions`
     - Transition to `.idle` (or `.error` if any step fails)
  4. Error handling:
     - Catches typed errors (TextInsertionError, WhisperError, PostProcessingError)
     - Transitions to `.error(message)`
     - Updates menu bar and floating indicator with error state
     - Logs all errors
  5. Recent transcriptions:
     - Kept in array, max 10 items
     - New items inserted at index 0 (LIFO)
     - Non-empty strings only
- **Key Details**:
  - State updates always logged
  - UI updates happen immediately on state change
  - Audio data converted to float array in `convertDataToFloatArray()`
  - Audio→data conversion: 16-bit signed PCM, little-endian
  - Hotkey delegate methods are nonisolated (called from hotkey manager's delegate queue)
  - Delegate methods dispatch to main actor asynchronously

---

## Threading Model

SoundVibe uses a hybrid threading model:

### Main Thread (@MainActor)

Everything UI-related runs on the main thread:
- `DictationOrchestrator` (state machine, pipeline coordination)
- `SettingsManager` (@ObservableObject, @Published)
- `MenuBarManager` (menu bar UI)
- `FloatingIndicatorManager` (window updates)
- `AppDelegate` (initialization)

### Background Queues

- **`AudioCaptureManager.delegateQueue`**: Concurrent queue for audio buffer delivery
- **`WhisperEngine.operationQueue`**: Serial queue for transcription (QoS: `.userInitiated`)
- **`HotkeyManager.delegateQueue`**: Concurrent queue for hotkey events
- **Thread-safe primitives**: Actors (`HotkeyManager`, `AudioCaptureManager`, `PostProcessingPipeline`, `MLXPostProcessor`)

### Async/Await

- `startCapture()` → `async throws`
- `stopCapture()` → returns data synchronously
- `transcribe()` → `async throws`
- `insertText()` → `async throws`
- `process()` → `async throws`
- `downloadModel()` → `async throws`

### Thread Safety Guarantees

| Component | Thread Safety | Mechanism |
|-----------|---------------|-----------|
| `HotkeyManager` | Isolated | `actor` |
| `AudioCaptureManager` | Isolated | `actor` |
| `PostProcessingPipeline` | Isolated | `actor` |
| `MLXPostProcessor` | Isolated | `actor` |
| `DictationOrchestrator` | Isolated | `@MainActor` |
| `SettingsManager` | Main thread | `@ObservableObject` |
| `MenuBarManager` | Main thread | `ObservableObject`, UI updates `DispatchQueue.main` |
| `WhisperEngine` | Background queue | `DispatchQueue.operationQueue` |
| `TextInsertionEngine` | Async, main-thread final | CGEvent/NSPasteboard on main, async Task.sleep |

### CGEvent Tap Callback

The CGEvent tap callback is `nonisolated` because C function pointers can't capture. It dispatches back to the actor:

```swift
nonisolated func handleEventCallback(
  proxy: CGEventTapProxy,
  type: CGEventType,
  event: CGEvent
) -> Unmanaged<CGEvent>? {
  Task {
    await self.processEvent(type: type, event: event)
  }
  return Unmanaged.passUnretained(event)
}
```

---

## State Machine

### Dictation State Diagram

```
                    ┌─────────────┐
                    │   ERROR     │
                    │ (terminal)  │
                    └──────▲──────┘
                           │
                  [any step fails]
                           │
    ┌──────────────────────┴──────────────────────┐
    │                                              │
    │                                              │
┌───┴──────────┐      ┌──────────────┐      ┌──────┴─────┐      ┌────────────┐      ┌─────────┐
│    IDLE      │─────→│  LISTENING   │─────→│ TRANSCRIBING│─────→│POST-PROCESS│─────→│INSERTING│
└──────────────┘      └──────────────┘      └──────┬─────┘      └────┬───────┘      └────┬────┘
       ▲                                            │                 │                    │
       │                                            └─────[skip if disabled]───┐         │
       │                                                                       │         │
       └───────────────────────────────────────────────────────────────────────┴─────────┘
                                        [success]
```

### State Properties

| State | `isActive` | User Action | Entry Condition | Exit Condition |
|-------|-----------|-------------|-----------------|----------------|
| `idle` | false | — | App launch, after success | Hotkey pressed |
| `listening` | true | Speak | Hotkey pressed (hold-to-talk or toggle start) | Hotkey released (hold-to-talk) or pressed again (toggle) |
| `transcribing` | true | — | Audio captured | Transcription complete |
| `postProcessing` | true | — | Transcription complete AND enabled | Processing complete or skipped |
| `inserting` | true | — | Post-processing complete | Text inserted to clipboard + Cmd+V sent |
| `error(String)` | false | — | Any step fails | User restart (press hotkey again) |

### State Transitions

**Hold-to-Talk Mode:**
1. Hotkey press → `hotkeyPressed()` → `startDictation()` → `.listening`
2. Hotkey release → `hotkeyReleased()` → `stopDictation()` → `.transcribing` → `.postProcessing` → `.inserting` → `.idle` (or `.error`)

**Toggle Mode:**
1. Hotkey press (1st) → `hotkeyPressed()` → `startDictation()` → `.listening`
2. Hotkey press (2nd) → `hotkeyReleased()` → `stopDictation()` → `.transcribing` → `.postProcessing` → `.inserting` → `.idle` (or `.error`)

**Cancellation:**
- At any point: `cancelDictation()` → `.idle` immediately

**Error Recovery:**
- From `.error`: Next hotkey press restarts the cycle

---

## Error Handling

### Error Types

Each module defines its own error enum:

| Module | Error Type | Cases |
|--------|-----------|-------|
| Audio | `AudioCaptureError` | `microphonePermissionDenied`, `deviceNotFound`, `engineStartFailed`, `noAudioCaptured` |
| Hotkey | `HotkeyError` | `accessibilityPermissionDenied`, `eventTapCreationFailed`, `conflict` |
| Transcription | `WhisperError` | `modelNotLoaded`, `modelLoadFailed(reason)`, `transcriptionFailed(reason)`, `invalidAudioData`, `cancelled`, `audioProcessingFailed(reason)` |
| Text Insertion | `TextInsertionError` | `accessibilityPermissionDenied`, `pasteSimulationFailed(reason)`, `clipboardWriteFailed(reason)`, `clipboardReadFailed(reason)` |
| Post-Processing | `PostProcessingError` | `modelNotLoaded`, `processingFailed(String)`, `modelLoadFailed(String)`, `unsupportedHardware`, `cancelled` |
| Model Management | `ModelManagerError` | `downloadFailed(reason)`, `checksumMismatch`, `diskSpaceInsufficient`, `modelNotFound`, `deletionFailed(reason)`, `invalidModelPath` |

### Error Handling in Orchestrator

```swift
do {
  // Pipeline steps...
  let result = try await transcriptionEngine.transcribe(...)
  let processed = try await postProcessingPipeline.process(...)
  try await textInsertion.insertText(...)
} catch let error as TextInsertionError {
  updateState(.error(error.localizedDescription))
  // ...
} catch let error as WhisperError {
  updateState(.error(error.localizedDescription))
  // ...
} catch let error as PostProcessingError {
  updateState(.error(error.localizedDescription))
  // ...
} catch {
  updateState(.error("An unexpected error occurred..."))
  // ...
}
```

### User Notification

- **Menu bar icon**: Changes to error state (red exclamation circle)
- **Floating indicator**: Shows error state for 3 seconds
- **State property**: `@Published var state` observed by UI
- **No system notifications** (by design—keep unobtrusive)

### Graceful Degradation

- **Post-processing failure**: Voice commands still applied; LLM error logged but doesn't block
- **Model not loaded**: Show user-friendly error, suggest downloading
- **Accessibility permission missing**: Text stays on clipboard; user can paste manually

---

## Settings Persistence

### UserDefaults Domain

- **Bundle ID**: `com.soundvibe` (inferred from app identifier)
- **Plist location**: `~/Library/Preferences/com.soundvibe.plist`
- **Keys pattern**: `soundvibe.<setting>`

### Persisted Settings

All `@Published` properties in `SettingsManager` are auto-persisted:

```swift
@Published var triggerMode: TriggerMode {
  didSet { defaults.set(encoded, forKey: "soundvibe.triggerMode") }
}
```

### Encoding

- Simple types (Bool, String, TimeInterval): Direct storage
- Enums (TriggerMode, PostProcessingMode): Raw value or JSONEncoder
- Structs (HotkeyCombo): JSONEncoder to Data

### Import/Export

Settings can be exported to JSON for backup or sharing:

```swift
let json = manager.exportSettings()  // Data (JSON)
try manager.importSettings(jsonData)
```

JSON structure:
```json
{
  "triggerMode": "holdToTalk",
  "hotkey": { "keyCode": 49, "modifiers": 524288 },
  "selectedModelSize": "base",
  "selectedLanguage": "en",
  "autoLanguageDetection": false,
  "postProcessingEnabled": false,
  "postProcessingMode": "clean",
  "customPostProcessingPrompt": "",
  "launchAtLogin": false,
  "showFloatingIndicator": true,
  "clipboardRestoreEnabled": true,
  "pasteDelay": 0.05,
  "silenceTimeout": 3.0,
  "selectedInputDevice": null
}
```

### Reset to Defaults

```swift
manager.resetToDefaults()  // All settings → original values, UserDefaults cleared
```

---

## Model Management

### Model Storage

- **Directory**: `~/Library/Application Support/SoundVibe/Models/`
- **Filename pattern**: `ggml-<size>.bin` (e.g., `ggml-base.bin`)
- **Created by**: `WhisperModel.ensureModelsDirectoryExists()`

### Download Flow

1. **Disk space check**: Verify 2x model size available
2. **Download**: From HuggingFace `ggerganov/whisper.cpp` (HTTPS)
3. **Progress tracking**: URLSessionDownloadDelegate updates `@Published` property
4. **Checksum verification**: SHA256 match against known value
5. **Move to final location**: From temp download dir to Models/
6. **Set active**: Model is ready to use

### Model Checksums

Hard-coded in `WhisperModel.swift`:

```swift
var sha256Checksum: String {
  switch self {
  case .tiny:
    return "37465047ff01ba0a881e1f5cd67e5a0ddcfbaf1d9e8eb43eb90cf3071a41a3cb"
  case .base:
    return "e4efb3851f7e06471c3411c580b06ee89ac2d63d3f6b6a9f4798763b3245483f"
  // ...
  }
}
```

### Download Resume/Cancel

- **Cancel**: `ModelManager.cancelDownload()` stops URLSessionDownloadTask
- **Resume**: Restart download; file is re-downloaded (no delta support)

---

## Testing Strategy

### What's Tested

- **Transcription pipeline**: Mock engine returns configurable results
- **Post-processing modes**: Voice commands, text transformations
- **State transitions**: State machine from idle → success → idle
- **Settings persistence**: Export/import, reset to defaults
- **Error handling**: Each module catches and handles its errors

### What's Mocked

- **WhisperEngine**: `MockTranscriptionEngine` with configurable results
- **MLXPostProcessor**: `MockPostProcessor` with instant processing
- **AudioCaptureManager**: Can be mocked or test with real audio (requires mic access)
- **TextInsertionEngine**: Can be tested without Accessibility permission by mocking NSPasteboard

### Test Structure

```
SoundVibeTests/
├── TranscriptionEngineTests.swift      // WhisperEngine, MockEngine
├── TextInsertionEngineTests.swift      // Clipboard, CGEvent simulation
├── PostProcessingTests.swift           // Pipeline, voice commands
├── SettingsManagerTests.swift          // Persistence, import/export
├── DictationOrchestratorTests.swift    // State machine, pipeline
└── MockImplementations.swift           // Test doubles (MockEngine, etc.)
```

### Running Tests

```bash
swift test
# or
xcode: Product → Test (Cmd+U)
```

---

## Key Design Decisions

### Why whisper.cpp (not Apple Speech Recognition API)

| Criterion | whisper.cpp | Apple Speech |
|-----------|------------|---------|
| **Language Support** | 99+ languages natively | ~50 languages (via API) |
| **Privacy** | ✓ Local, no network | ✗ Requires Apple servers (unless on-device) |
| **Customization** | ✓ Full control over model | ✗ Minimal control |
| **Accuracy** | Excellent (2-8% WER) | Good (2-5% WER) |
| **Cost** | Free | Free (Apple Silicon) or cloud $$$ |
| **Model Choice** | 5 sizes, fine-tune your accuracy/speed | One size fits all |

**Decision**: whisper.cpp gives maximum control, privacy, and flexibility. Apple Speech is fine for casual use but SoundVibe targets power users.

### Why Clipboard + CGEvent Paste (not Keystroke Simulation)

**Keystroke simulation issues:**
- Slow for long text (thousands of keystrokes)
- Encoding problems with special characters, non-Latin scripts
- Can be intercepted/modified by key remapping software
- Breaks in password fields and restricted inputs

**Clipboard paste benefits:**
- Fast (single Cmd+V event)
- Encoding-safe (NSPasteboard handles all formats)
- Works in nearly all macOS text inputs
- Secure (no key simulation that can be intercepted)

**Decision**: Clipboard + CGEvent is the standard approach for text insertion in macOS. It's reliable, fast, and respects security.

### Why MLX (not Ollama or Other LLMs)

| Criterion | MLX | Ollama | LM Studio |
|-----------|-----|--------|-----------|
| **Native Integration** | ✓ Apple framework | ✗ Separate server process | ✗ Separate server |
| **Unified Memory** | ✓ Apple Silicon unified memory | ✗ Separate memory pools | ✗ Separate memory |
| **Latency** | Fast (< 1s for 50 words) | Moderate (overhead of process) | Moderate |
| **Deployment** | Single binary | Requires Ollama install | Requires LM Studio install |
| **Swift Integration** | ✓ Native bindings | ✗ HTTP API | ✗ HTTP API |

**Decision**: MLX is the only framework that integrates natively with Swift and leverages Apple Silicon's unified memory. Running Ollama/LM Studio would require users to install separate applications—not scalable.

### Why CGEvent Tap (not NSEvent Monitoring)

- **CGEvent tap**: Global, system-wide keyboard monitoring (hardware level)
- **NSEvent**: Local to app, doesn't work when app isn't focused (doesn't meet requirements)

**Decision**: CGEvent tap is the only way to achieve global hotkey functionality that works in any app.

### Why Async/Await (not Callbacks or RxSwift)

- **Modern Swift concurrency**: Built-in, no external dependencies, compiler-checked
- **Readability**: Linear flow, easier to understand
- **Error handling**: Integrated with Swift error handling (try/catch)
- **Thread safety**: Actors and MainActor provide isolation guarantees

**Decision**: Async/await is the Swift standard (5.9+) and simplifies complex async workflows.

---

## How to Modify SoundVibe

### Adding a New Feature

**Example: Add noise gate to audio capture**

1. **Extend `AudioCaptureManager`**:
   ```swift
   public var noiseGateThreshold: Float = -40.0  // dB

   private func shouldFilterFrame(_ buffer: AVAudioPCMBuffer) -> Bool {
     let level = calculateRMSLevel(buffer)
     let dB = 20 * log10(level + 0.001)
     return dB < noiseGateThreshold
   }
   ```

2. **Update `SettingsManager`**:
   ```swift
   @Published var noiseGateEnabled: Bool = false
   @Published var noiseGateThreshold: Float = -40.0
   ```

3. **Update `SettingsView`**:
   ```swift
   struct AudioSettingsView: View {
     Toggle("Enable Noise Gate", isOn: $settings.noiseGateEnabled)
     Slider(value: $settings.noiseGateThreshold, in: -60...0)
   }
   ```

4. **Test**: Create `NoiseGateTests.swift`, mock silent audio, verify filtering

### Adding a New Post-Processing Mode

1. **Add to `PostProcessingMode` enum**:
   ```swift
   enum PostProcessingMode: String, CaseIterable {
     case clean, formal, concise, custom
     case summarize  // NEW
   }
   ```

2. **Add system prompt in `MLXPostProcessor`**:
   ```swift
   private func systemPrompt(for mode: PostProcessingMode) -> String {
     case .summarize:
       return "Condense the following into a 1-2 sentence summary..."
   }
   ```

3. **Update UI in `SettingsView`**:
   ```swift
   Picker("Mode", selection: $settings.postProcessingMode) {
     Text("Summarize").tag(PostProcessingMode.summarize)
   }
   ```

### Swapping the Transcription Engine

1. **Create new engine implementing `TranscriptionEngine` protocol**:
   ```swift
   class CloudWhisperEngine: TranscriptionEngine {
     func transcribe(audioData: [Float], language: String?, detectLanguage: Bool)
       async throws -> TranscriptionResult {
       // Call your cloud API
     }
   }
   ```

2. **Update `AppDelegate` initialization**:
   ```swift
   let engine = CloudWhisperEngine()  // or WhisperEngine()
   let orchestrator = DictationOrchestrator(
     transcriptionEngine: engine,
     ...
   )
   ```

3. **Add feature flag if needed**:
   ```swift
   #if USE_CLOUD
   let engine = CloudWhisperEngine()
   #else
   let engine = WhisperEngine()
   #endif
   ```

### Adding a New Language

1. **Update supported languages in `MenuBarManager`**:
   ```swift
   enum SupportedLanguage: String, CaseIterable {
     // Add new case
     case vietnamese = "vi"
   }
   ```

2. **Test with Whisper model** (all languages are already supported by Whisper)

---

## LLM-Specific Guidance

### For LLMs Modifying This Codebase

#### Key Principles

1. **Thread Safety is Critical**: Actors and @MainActor isolate mutable state. Don't access properties across threads without proper isolation.

2. **Async/Await is Mandatory**: Network, file I/O, and long-running compute must be async. No blocking calls on main thread.

3. **Error Handling is Explicit**: Each module has its own error type. Catch and handle specifically, then convert to user-facing messages.

4. **Settings Persist Immediately**: @Published properties auto-save to UserDefaults. Changes apply instantly.

5. **State Machine Transitions Matter**: DictationOrchestrator state must be updated on every state change. UI depends on state to render.

#### Common Tasks

**Reading settings:**
```swift
let settings = SettingsManager.shared
let language = settings.selectedLanguage
let hotkey = settings.hotkey  // HotkeyCombo(keyCode, modifiers)
```

**Updating settings (auto-persists):**
```swift
SettingsManager.shared.postProcessingMode = .formal
```

**Checking if running on Apple Silicon:**
```swift
var systemInfo = utsname()
uname(&systemInfo)
let machine = String(cString: &systemInfo.machine.0)
let isAppleSilicon = machine.contains("arm64")
```

**Dispatching UI updates from background:**
```swift
DispatchQueue.main.async {
  await self.updateState(.idle)  // if self is @MainActor
}
```

**Handling async errors:**
```swift
do {
  try await someAsyncOperation()
} catch let error as SpecificError {
  logger.error("Specific error: \(error.localizedDescription)")
  state = .error(error.localizedDescription)
} catch {
  logger.error("Unknown error: \(error)")
  state = .error("An unexpected error occurred")
}
```

#### File Paths

- **Models**: `~/Library/Application Support/SoundVibe/Models/`
- **Settings**: `~/Library/Preferences/com.soundvibe.plist` (managed by UserDefaults)
- **Logs** (if debug enabled): Console.app (system logs)

#### Key Classes to Understand

1. **DictationOrchestrator**: Read state, subscribe to @Published
2. **SettingsManager**: Read/write settings, import/export JSON
3. **WhisperEngine**: Load model, transcribe, unload model
4. **PostProcessingPipeline**: Process text with optional LLM
5. **TextInsertionEngine**: Insert text via clipboard + Cmd+V
6. **AudioCaptureManager**: Capture audio from microphone
7. **HotkeyManager**: Register global hotkey, delegate pattern

#### Dependencies to Avoid

- Do NOT hardcode file paths (use FileManager)
- Do NOT call blocking I/O on main thread (use async)
- Do NOT mutate @Published properties outside MainActor
- Do NOT access actor properties without await
- Do NOT skip error handling for convenience

---

## Common Pitfalls

### 1. Modifying @Published Properties Off Main Thread

**Wrong:**
```swift
Task {
  settings.postProcessingEnabled = true  // ❌ Off main thread
}
```

**Right:**
```swift
Task { @MainActor in
  settings.postProcessingEnabled = true  // ✓ On main thread
}
```

### 2. Awaiting Across Executor Boundaries Without Isolation

**Wrong:**
```swift
let result = try await orchestrator.process()  // ❌ Not isolated
orchestrator.state = .idle  // ❌ Race condition possible
```

**Right:**
```swift
let result = try await orchestrator.process()  // ✓ Already @MainActor
// orchestrator.state is updated inside process()
```

### 3. Forgetting CGEvent Tap Requires Accessibility Permission

**Wrong:**
```swift
try hotkey.start()  // ❌ Will fail if permission missing
```

**Right:**
```swift
do {
  try hotkey.start()
} catch HotkeyError.accessibilityPermissionDenied {
  // Guide user to System Settings
  showAccessibilityPermissionPrompt()
}
```

### 4. Assuming Microphone Permission is Granted

**Wrong:**
```swift
try audioCapture.startCapture()  // ❌ Will fail if permission missing
```

**Right:**
```swift
do {
  try audioCapture.startCapture()
} catch AudioCaptureError.microphonePermissionDenied {
  // Request permission or show setup guide
}
```

### 5. Blocking Main Thread with Sync I/O

**Wrong:**
```swift
@MainActor
func loadModel() {
  let data = try Data(contentsOf: modelURL)  // ❌ Blocks main thread
  try engine.loadModel(data)
}
```

**Right:**
```swift
@MainActor
func loadModel() async {
  let data = try await loadDataAsync(modelURL)
  try engine.loadModel(data)
}

private func loadDataAsync(_ url: URL) async throws -> Data {
  return try await Task.detached {
    try Data(contentsOf: url)
  }.value
}
```

### 6. Not Updating State on Pipeline Completion

**Wrong:**
```swift
try await transcribe()
try await postProcess()
try await insertText()
// ❌ Never transition back to .idle
```

**Right:**
```swift
try await transcribe()
try await postProcess()
try await insertText()
self.state = .idle  // ✓ Always return to idle on success
```

### 7. Catching Generic `Error` and Ignoring Type Information

**Wrong:**
```swift
do {
  try await transcribe()
} catch {
  state = .error("Transcription failed")  // ❌ No specific handling
}
```

**Right:**
```swift
do {
  try await transcribe()
} catch let error as WhisperError {
  state = .error(error.localizedDescription)  // ✓ Specific message
} catch {
  state = .error("Unexpected error")
}
```

### 8. Not Restoring Clipboard After Paste Failure

**Wrong:**
```swift
let savedClipboard = save()
try writeToClipboard(text)
try simulateCommandV()
// ❌ If simulateCommandV throws, clipboard is lost
restore(savedClipboard)
```

**Right:**
```swift
let savedClipboard = save()
do {
  try writeToClipboard(text)
  try simulateCommandV()
} catch {
  restore(savedClipboard)  // ✓ Always restore on error
  throw error
}
```

### 9. Assuming Model is Downloaded Before Transcribing

**Wrong:**
```swift
let result = try await engine.transcribe(audio)  // ❌ Model might not be loaded
```

**Right:**
```swift
if !engine.isModelLoaded {
  throw WhisperError.modelNotLoaded
}
let result = try await engine.transcribe(audio)  // ✓ Guaranteed to work
```

### 10. Not Handling Toggle Mode State Correctly

**Wrong:**
```swift
// In toggle mode, flag should persist across key events
func handleKeyDown() {
  if !hotkeyPressedFlags.isEmpty {  // ❌ Will always be true on 2nd press
    delegate?.hotkeyReleased()
  }
}
```

**Right:**
```swift
// Toggle mode: odd presses = pressed, even presses = released
func handleKeyDown() {
  if hotkeyPressedFlags.isEmpty {
    hotkeyPressedFlags = [.maskCommand]  // Marker for "pressed"
    delegate?.hotkeyPressed()
  } else {
    hotkeyPressedFlags = []  // Clear marker for "released"
    delegate?.hotkeyReleased()
  }
}
```

---

## Conclusion

SoundVibe is a well-architected, modular macOS application that demonstrates best practices in:
- Swift async/await concurrency
- Actor isolation and thread safety
- Error handling and user feedback
- Layered architecture with clear separation of concerns
- Settings persistence and state management
- User experience with minimal UI friction

When modifying or extending SoundVibe, follow the established patterns, respect thread boundaries, handle errors explicitly, and always update state on transitions.

For LLMs: understand the actor/MainActor patterns first, then trace through the DictationOrchestrator pipeline to grasp the full flow.
