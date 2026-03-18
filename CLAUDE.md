# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SoundVibe is a macOS menu bar application providing privacy-focused, local speech-to-text dictation. It uses whisper.cpp for transcription and MLX for optional LLM-based post-processing. All processing happens on-device — no cloud dependencies.

- **Language:** Swift 5.9+
- **UI:** SwiftUI + AppKit
- **Platform:** macOS 13.0+ (Ventura), menu bar app (LSUIElement)
- **Build system:** Swift Package Manager

## Build & Test Commands

```bash
swift build -c debug          # Debug build
swift build -c release        # Release build
swift test                    # Run all tests
swift test --verbose          # Run tests with verbose output
swift test --filter SoundVibeTests.SettingsManagerTests  # Run a single test class
swift package resolve         # Resolve dependencies
```

## Architecture

The app follows a layered architecture centered on a state-machine orchestrator:

**DictationOrchestrator** (`SoundVibe/Orchestration/`) — Central coordinator with enum-based states: `idle → listening → transcribing → postProcessing → inserting → idle` (or `error`). Manages the full dictation lifecycle.

**Key subsystems:**
- **Audio** (`SoundVibe/Audio/`) — `AudioCaptureManager` (actor) captures mic input at 16kHz mono via AVAudioEngine. `AudioBuffer` handles sample buffering.
- **Transcription** (`SoundVibe/Transcription/`) — `WhisperEngine` wraps whisper.cpp via C interop, conforming to the `TranscriptionEngine` protocol. `ModelManager` handles model downloading/lifecycle.
- **PostProcessing** (`SoundVibe/PostProcessing/`) — Optional MLX-based LLM pipeline for cleaning/formatting transcribed text. Apple Silicon only.
- **TextInsertion** (`SoundVibe/TextInsertion/`) — Inserts text via clipboard + simulated Cmd+V paste.
- **Hotkey** (`SoundVibe/Hotkey/`) — `HotkeyManager` (actor) uses CGEvent tap for global hotkey. Supports hold-to-talk and toggle modes.
- **Settings** (`SoundVibe/Settings/`) — `SettingsManager` singleton persists to UserDefaults (`com.soundvibe.plist`), uses `@Published` for SwiftUI reactivity.
- **UI** (`SoundVibe/UI/`) — Menu bar management, settings window, onboarding flow, floating recording indicator.

**Threading model:** Uses Swift actors for thread safety. `AudioCaptureManager` and `HotkeyManager` are actors. UI components use `@MainActor`. Async/await throughout — no completion handlers.

## Code Style

- **Indentation:** 2 spaces
- **Line length:** < 100 characters
- **Trailing commas** in multi-line collections
- **MARK: comments** for section organization (`// MARK: - Public Methods`)
- **Access control:** Mark internals `private`/`fileprivate`
- **Error handling:** Custom error enums conforming to `LocalizedError` (e.g., `WhisperError`, `AudioCaptureError`)
- **Naming:** Clear, descriptive — no abbreviations
- **Comments:** Explain "why", not "what"

## Commit Message Format

```
type: Brief summary

type is one of: feat, fix, docs, refactor, test, perf, chore
```

## Testing

Tests are in `SoundVibeTests/` and use mock implementations for dependency injection (e.g., `MockTranscriptionEngine`). Follow Arrange-Act-Assert pattern with descriptive test names like `testTranscribeWithValidAudioReturnsText()`.

## Hardware Considerations

- **Apple Silicon:** Full support with GPU acceleration, <2s transcription latency
- **Intel Macs:** CPU-only, slower (~5-10s), no post-processing (MLX unavailable)
