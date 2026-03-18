# SoundVibe — Product Requirements Document

**Version:** 1.0
**Date:** March 17, 2026
**Status:** Draft

---

## 1. Overview

SoundVibe is a macOS application that provides system-wide voice-to-text dictation triggered by a user-defined hotkey. It runs a local Whisper model for speech recognition, inserts transcribed text into any active text field via clipboard, and optionally post-processes output using a local LLM powered by Apple's MLX framework. The app is designed for developers and power users who value privacy, low latency, and deep configurability.

### 1.1 Problem Statement

macOS ships with built-in dictation, but it relies on Apple's servers (unless on Apple Silicon with on-device mode enabled), offers limited customization, lacks post-processing capabilities, and provides no control over the speech recognition model or its behavior. Third-party alternatives are typically cloud-dependent, subscription-based, or both.

### 1.2 Vision

A fast, private, fully local dictation tool that works in any app, gives users full control over the recognition engine and output formatting, and optionally cleans up transcription with a local LLM — all from a single hotkey.

### 1.3 Target Audience

Developers, power users, and technical professionals who are comfortable with system preferences, keyboard shortcuts, and local model management. Users who prioritize privacy and want their voice data to never leave their machine.

---

## 2. Goals and Non-Goals

### 2.1 Goals

- Provide accurate, low-latency speech-to-text that works in any macOS text field.
- Run entirely locally with no network requests for core functionality.
- Support configurable hotkey with both hold-to-talk and toggle trigger modes.
- Include optional LLM-based post-processing (grammar, filler word removal, reformatting) using MLX.
- Support multiple languages and auto-punctuation.
- Deliver a clean, minimal UI that stays out of the way.

### 2.2 Non-Goals

- Real-time collaboration or multi-user features.
- Mobile (iOS) version in the initial release.
- Cloud-based transcription (no cloud fallback in v1).
- Custom vocabulary/domain-specific model fine-tuning in v1.
- Acting as a full voice assistant (no command execution, app control, etc.).

---

## 3. User Personas

### 3.1 Alex — Software Developer

Alex writes code and documentation all day. They want to quickly dictate commit messages, Slack replies, and documentation without switching context. They care about privacy and want everything local. They're comfortable installing Homebrew packages and tweaking settings.

### 3.2 Priya — Technical Writer

Priya drafts long-form content and wants to dictate first drafts into her text editor. She values the LLM post-processing feature to clean up filler words and fix grammar on the fly. She works in multiple languages (English and Hindi) and needs language switching.

---

## 4. Functional Requirements

### 4.1 Hotkey Trigger System

| ID | Requirement | Priority |
|----|-------------|----------|
| F-HK-01 | User can define a global hotkey (any modifier + key combination) in settings. | P0 |
| F-HK-02 | App supports **hold-to-talk** mode: recording starts on key-down, stops on key-up. | P0 |
| F-HK-03 | App supports **toggle** mode: first press starts recording, second press stops. | P0 |
| F-HK-04 | User selects their preferred trigger mode in settings. | P0 |
| F-HK-05 | Hotkey works system-wide regardless of the focused application. | P0 |
| F-HK-06 | Hotkey conflicts with other apps are detected and the user is warned. | P1 |
| F-HK-07 | Default hotkey is `Fn` twice (double-tap) to mirror Apple's dictation shortcut, with option to change. | P1 |

### 4.2 Audio Capture

| ID | Requirement | Priority |
|----|-------------|----------|
| F-AC-01 | Capture audio from the system's default input device (built-in mic or connected device). | P0 |
| F-AC-02 | User can select a specific input device in settings. | P1 |
| F-AC-03 | Audio is captured at 16kHz mono (Whisper's expected format) to minimize processing overhead. | P0 |
| F-AC-04 | A noise gate / minimum volume threshold filters out background noise before processing. | P2 |
| F-AC-05 | In toggle mode, an optional silence detection timeout (configurable, e.g., 3s) auto-stops recording. | P1 |

### 4.3 Speech-to-Text Engine (Whisper)

| ID | Requirement | Priority |
|----|-------------|----------|
| F-STT-01 | Use whisper.cpp for local Whisper inference. | P0 |
| F-STT-02 | Support multiple Whisper model sizes: tiny, base, small, medium, large-v3. | P0 |
| F-STT-03 | User selects model size in settings with clear guidance on accuracy vs. speed vs. memory trade-offs. | P0 |
| F-STT-04 | Ship with the `base` model bundled; larger models downloaded on demand from within settings. | P0 |
| F-STT-05 | Model downloads show progress and can be cancelled/resumed. | P1 |
| F-STT-06 | On Apple Silicon, use Core ML–optimized Whisper models for faster inference. | P0 |
| F-STT-07 | On Intel Macs, fall back to CPU-based whisper.cpp inference with appropriate performance warnings. | P0 |
| F-STT-08 | Transcription latency target: < 2 seconds for a 10-second utterance on Apple Silicon with `base` model. | P0 |
| F-STT-09 | Support streaming/chunked transcription for long dictations (process audio in segments as the user speaks). | P1 |

### 4.4 Language Support

| ID | Requirement | Priority |
|----|-------------|----------|
| F-LN-01 | User selects a primary dictation language in settings. | P0 |
| F-LN-02 | Support all languages supported by the selected Whisper model (99 languages for large-v3). | P0 |
| F-LN-03 | Optional auto-language-detection mode (let Whisper detect the spoken language). | P1 |
| F-LN-04 | Quick language switching via a secondary hotkey or menu bar toggle. | P2 |

### 4.5 Punctuation and Formatting

| ID | Requirement | Priority |
|----|-------------|----------|
| F-PF-01 | Auto-punctuation enabled by default (Whisper natively produces punctuation with appropriate prompting). | P0 |
| F-PF-02 | Support voice commands for formatting: "new line", "new paragraph", "period", "comma", "question mark", "exclamation point", "colon", "semicolon", "open quote", "close quote". | P1 |
| F-PF-03 | Auto-capitalize the first word of each sentence. | P0 |
| F-PF-04 | User can enable/disable auto-punctuation in settings. | P1 |
| F-PF-05 | Voice command recognition is handled as a post-processing step, not requiring a separate model. | P1 |

### 4.6 Text Insertion

| ID | Requirement | Priority |
|----|-------------|----------|
| F-TI-01 | Transcribed text is copied to the system clipboard. | P0 |
| F-TI-02 | After copying, the app simulates `Cmd+V` to paste into the active text field. | P0 |
| F-TI-03 | The previous clipboard content is saved before overwriting and restored after paste (configurable). | P1 |
| F-TI-04 | A brief delay (configurable, default 50ms) between clipboard write and paste simulation to ensure reliability. | P0 |
| F-TI-05 | If the focused element is not a text input, the text remains on the clipboard and the user is notified. | P2 |

### 4.7 LLM Post-Processing (MLX)

| ID | Requirement | Priority |
|----|-------------|----------|
| F-PP-01 | Optional post-processing step between transcription and text insertion. | P0 |
| F-PP-02 | Uses Apple MLX framework for on-device LLM inference. | P0 |
| F-PP-03 | Default model: a small, fast model suitable for text cleanup (e.g., Phi-3-mini, Qwen2-0.5B, or similar ~1-3B parameter model quantized to 4-bit). | P0 |
| F-PP-04 | User can download and select from multiple MLX-compatible models in settings. | P1 |
| F-PP-05 | Post-processing modes (user-selectable): | P0 |
|    | — **Clean**: Remove filler words (um, uh, like), fix obvious grammar errors. | |
|    | — **Formal**: Rewrite in a professional tone. | |
|    | — **Concise**: Shorten while preserving meaning. | |
|    | — **Custom**: User provides their own system prompt. | |
| F-PP-06 | Post-processing can be toggled on/off via a menu bar toggle or hotkey. | P0 |
| F-PP-07 | Post-processing adds no more than 1 second of latency for typical utterances (< 50 words) on Apple Silicon. | P1 |
| F-PP-08 | On Intel Macs, post-processing is available but with a performance warning; user can disable it. | P1 |
| F-PP-09 | Show a "processing" indicator while LLM is running. | P1 |

### 4.8 Settings and Configuration

| ID | Requirement | Priority |
|----|-------------|----------|
| F-ST-01 | A dedicated settings/preferences window accessible from the menu bar icon. | P0 |
| F-ST-02 | **General tab**: Hotkey configuration, trigger mode (hold/toggle), launch at login, menu bar icon style. | P0 |
| F-ST-03 | **Audio tab**: Input device selection, noise gate threshold, silence timeout. | P1 |
| F-ST-04 | **Transcription tab**: Whisper model selection, model download management, language selection, auto-punctuation toggle. | P0 |
| F-ST-05 | **Post-processing tab**: Enable/disable, mode selection, custom prompt editor, MLX model selection and downloads. | P0 |
| F-ST-06 | **Advanced tab**: Clipboard restore behavior, paste delay, debug logging toggle, data storage location. | P1 |
| F-ST-07 | All settings persist across app restarts using UserDefaults or a local config file. | P0 |
| F-ST-08 | Settings are exportable/importable as JSON for backup or sharing. | P2 |

### 4.9 Menu Bar and UI

| ID | Requirement | Priority |
|----|-------------|----------|
| F-UI-01 | App lives in the macOS menu bar with a monochrome icon. | P0 |
| F-UI-02 | Menu bar icon changes state to indicate: idle, listening, processing, error. | P0 |
| F-UI-03 | Clicking the menu bar icon shows a dropdown with: current status, quick toggles (post-processing on/off, language), recent transcriptions (last 5), and links to Settings / Quit. | P0 |
| F-UI-04 | A small floating indicator (optional, toggleable) shows real-time audio level and transcription status near the cursor. | P1 |
| F-UI-05 | No Dock icon (LSUIElement = true). | P0 |
| F-UI-06 | Support macOS light and dark mode. | P0 |
| F-UI-07 | Transcription history panel accessible from settings, showing past transcriptions with timestamps and copy buttons. | P2 |

---

## 5. Non-Functional Requirements

### 5.1 Performance

| ID | Requirement | Target |
|----|-------------|--------|
| NF-P-01 | App memory footprint (idle, no model loaded) | < 50 MB |
| NF-P-02 | Memory with Whisper `base` model loaded | < 200 MB |
| NF-P-03 | Memory with Whisper `large-v3` loaded | < 2 GB |
| NF-P-04 | Hotkey-to-recording-start latency | < 100 ms |
| NF-P-05 | Transcription latency (10s audio, `base` model, M1) | < 2 s |
| NF-P-06 | Transcription latency (10s audio, `large-v3`, M1 Pro) | < 5 s |
| NF-P-07 | Post-processing latency (50 words, 1B model, M1) | < 1 s |
| NF-P-08 | CPU usage while idle | < 1% |

### 5.2 Privacy and Security

| ID | Requirement |
|----|-------------|
| NF-S-01 | Zero network requests for core functionality (transcription, post-processing, text insertion). |
| NF-S-02 | Audio data is never written to disk; processed in-memory only. |
| NF-S-03 | Transcription history stored locally in an encrypted SQLite database (optional, can be disabled). |
| NF-S-04 | No analytics, telemetry, or crash reporting that phones home (unless user explicitly opts in). |
| NF-S-05 | Model downloads use HTTPS with checksum verification. |
| NF-S-06 | App requests only necessary macOS permissions: microphone access and accessibility (for paste simulation). |

### 5.3 Compatibility

| ID | Requirement |
|----|-------------|
| NF-C-01 | macOS 13 (Ventura) and later. |
| NF-C-02 | Apple Silicon (M1, M2, M3, M4 families) — full feature support including MLX. |
| NF-C-03 | Intel Macs (macOS 13+) — supported with performance limitations documented; MLX post-processing may be unavailable or significantly slower. |
| NF-C-04 | Works with all standard macOS text inputs (NSTextField, NSTextView, web browsers, Electron apps, terminal emulators). |

### 5.4 Reliability

| ID | Requirement |
|----|-------------|
| NF-R-01 | App should recover gracefully from model loading failures (corrupt download, insufficient memory). |
| NF-R-02 | If transcription fails, the user is notified via the menu bar icon and an optional system notification. |
| NF-R-03 | Hotkey registration survives sleep/wake cycles and display changes. |
| NF-R-04 | App should not crash or hang if the microphone is disconnected mid-recording. |

---

## 6. Technical Architecture

### 6.1 Recommended Tech Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| **Language** | Swift | Native performance, first-class macOS API access, required for MLX Swift bindings. |
| **UI Framework** | SwiftUI (settings) + AppKit (menu bar, floating indicator) | SwiftUI for rapid settings UI development; AppKit for menu bar integration and system-level features that SwiftUI doesn't yet handle well. |
| **Audio Capture** | AVFoundation (AVAudioEngine) | Low-latency audio capture with configurable format, built-in noise processing. |
| **STT Engine** | whisper.cpp (via Swift C interop or whisper.cpp Swift package) | Best-in-class local Whisper implementation; supports Core ML acceleration on Apple Silicon. |
| **LLM Inference** | MLX Swift | Apple's framework optimized for Apple Silicon; runs quantized models efficiently with unified memory. |
| **Global Hotkey** | CGEvent tap (Quartz Event Services) | Reliable system-wide hotkey capture; works even when app is not focused. |
| **Text Insertion** | NSPasteboard + CGEvent (Cmd+V simulation) | Clipboard-based insertion is the most reliable cross-app method. |
| **Data Storage** | UserDefaults (settings) + SQLite/SwiftData (history) | Lightweight, local, no external dependencies. |
| **Model Management** | URLSession (downloads) + FileManager (local storage) | Models stored in `~/Library/Application Support/SoundVibe/Models/`. |

### 6.2 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        SoundVibe App                        │
├──────────┬──────────┬──────────┬──────────┬────────────────┤
│  Menu    │ Settings │ Hotkey   │ Floating │  Model         │
│  Bar     │ Window   │ Manager  │ Indicator│  Manager       │
│  Module  │ (SwiftUI)│ (CGEvent)│ (AppKit) │  (Download/    │
│ (AppKit) │          │          │          │   Load/Cache)  │
├──────────┴──────────┴────┬─────┴──────────┴────────────────┤
│                          │                                  │
│    ┌─────────────────────▼──────────────────────┐          │
│    │           Audio Pipeline                    │          │
│    │  AVAudioEngine → Buffer → Resampler (16kHz) │          │
│    └─────────────────────┬──────────────────────┘          │
│                          │                                  │
│    ┌─────────────────────▼──────────────────────┐          │
│    │        Whisper Engine (whisper.cpp)          │          │
│    │  Core ML backend (Apple Silicon)            │          │
│    │  CPU backend (Intel fallback)               │          │
│    └─────────────────────┬──────────────────────┘          │
│                          │                                  │
│    ┌─────────────────────▼──────────────────────┐          │
│    │     Post-Processor (Optional)               │          │
│    │  Voice command parser → MLX LLM cleanup     │          │
│    └─────────────────────┬──────────────────────┘          │
│                          │                                  │
│    ┌─────────────────────▼──────────────────────┐          │
│    │        Text Insertion Engine                 │          │
│    │  NSPasteboard write → CGEvent Cmd+V         │          │
│    └────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

### 6.3 Key Technical Decisions

**Why whisper.cpp over other Whisper implementations:** whisper.cpp is the most mature C/C++ Whisper port, has excellent Apple Silicon optimization via Core ML and Metal, can be called from Swift with minimal overhead, and has an active community.

**Why MLX over Ollama or bundled models:** MLX is Apple's own framework, optimized for the unified memory architecture of Apple Silicon. It avoids the overhead of running a separate server process (Ollama) and integrates natively with Swift. The quantized model format (MLX 4-bit) is compact and fast.

**Why clipboard-paste over keystroke simulation:** Simulating individual keystrokes is slow for long text, has encoding issues with special characters and non-Latin scripts, and can be intercepted by key remapping software. Clipboard + Cmd+V is faster, encoding-safe, and works in virtually all macOS text inputs.

---

## 7. macOS Permissions

The app requires the following system permissions, each of which triggers a macOS consent dialog on first use:

| Permission | Why | Consequence if Denied |
|------------|-----|----------------------|
| **Microphone** (Privacy & Security → Microphone) | Audio capture for dictation. | App cannot function; shows setup guide. |
| **Accessibility** (Privacy & Security → Accessibility) | Simulate Cmd+V keystroke for text insertion and register global hotkeys. | Text remains on clipboard but cannot auto-paste; user must paste manually. |
| **Input Monitoring** (Privacy & Security → Input Monitoring) | Detect hotkey presses system-wide including modifier keys. | Hotkey won't work; falls back to menu bar click to start/stop. |

The app should include a first-run onboarding flow that explains each permission and guides the user to grant them.

---

## 8. Distribution Strategy

The PRD considers three distribution paths. The recommendation is to start with open source + direct download, then evaluate App Store later.

### 8.1 Open Source (GitHub)

**Pros:** Community contributions, trust (users can verify no data leaves the machine), no Apple review delays, full system access.
**Cons:** No built-in update mechanism (use Sparkle framework), users must trust the developer or build from source.
**License recommendation:** MIT — permissive, encourages adoption.

### 8.2 Direct Download (Notarized)

**Pros:** Full system access (no sandbox restrictions), control over update cadence, can use Sparkle for auto-updates.
**Cons:** Users see "downloaded from the internet" warning (mitigated by notarization), no App Store discovery.

### 8.3 Mac App Store

**Pros:** Discovery, trusted distribution, automatic updates, familiar install experience.
**Cons:** App Sandbox significantly restricts accessibility APIs and global hotkey registration. The sandboxed environment may make CGEvent taps and input monitoring impossible or require a helper tool. Apple's review process may flag accessibility usage. Revenue share (15-30%).

**Recommendation:** Start with **open source on GitHub + notarized direct download**. This gives maximum flexibility for the accessibility and input monitoring APIs the app requires. Evaluate App Store feasibility later, potentially with a sandboxed "lite" version that uses Apple's built-in dictation APIs instead of a global hotkey.

---

## 9. User Flows

### 9.1 First Launch

1. User opens SoundVibe for the first time.
2. Onboarding screen explains the app's purpose and required permissions.
3. App requests Microphone permission → user grants.
4. App requests Accessibility permission → user grants in System Settings.
5. App requests Input Monitoring permission → user grants in System Settings.
6. App downloads/verifies the bundled Whisper `base` model.
7. User is prompted to set their preferred hotkey (default suggested: `⌥ Option` + `D`).
8. User selects trigger mode (hold-to-talk or toggle).
9. User selects primary language.
10. Onboarding complete → app minimizes to menu bar.

### 9.2 Basic Dictation (Hold-to-Talk)

1. User is typing in any app (e.g., VS Code, Safari, Notes).
2. User holds the configured hotkey.
3. Menu bar icon changes to "listening" state; optional floating indicator appears.
4. User speaks.
5. User releases the hotkey.
6. Audio is sent to Whisper engine → transcription produced.
7. If post-processing is enabled, transcription is cleaned by the MLX LLM.
8. Final text is written to clipboard → Cmd+V simulated → text appears at cursor.
9. Menu bar icon returns to idle.

### 9.3 Dictation with Toggle Mode

1. User presses the configured hotkey once → recording starts.
2. User speaks freely (can be a longer dictation).
3. User presses the hotkey again → recording stops.
4. Transcription and insertion proceed as above.

### 9.4 Changing Whisper Model

1. User opens Settings → Transcription tab.
2. User sees a list of available Whisper models with size, accuracy rating, and speed estimate for their hardware.
3. User selects `medium` → download begins (progress bar shown).
4. Download completes → model is loaded → settings confirm the active model.

---

## 10. Milestones and Phasing

### Phase 1 — MVP (Core Dictation)

- Global hotkey registration (single mode: hold-to-talk).
- Audio capture via AVAudioEngine.
- Whisper transcription via whisper.cpp with `base` model.
- Clipboard-based text insertion.
- Minimal menu bar UI (icon with status indication).
- Basic settings: hotkey, language, model size.
- macOS permission handling and onboarding.

### Phase 2 — Complete Input System

- Toggle trigger mode.
- Auto-punctuation and voice commands (new line, period, etc.).
- Floating recording indicator.
- Input device selection.
- Silence detection timeout.
- Model download manager (multiple Whisper model sizes).
- Transcription history.

### Phase 3 — LLM Post-Processing

- MLX integration for local LLM inference.
- Post-processing modes (clean, formal, concise, custom).
- Model download and management for MLX models.
- Post-processing toggle via menu bar and hotkey.
- Performance optimization for Intel fallback.

### Phase 4 — Polish and Distribution

- Multi-language quick switching.
- Auto-language detection.
- Settings export/import.
- Sparkle auto-updater integration.
- Notarization and distribution packaging.
- Comprehensive error handling and edge case coverage.
- Documentation and README.

---

## 11. Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Whisper model too slow on Intel Macs | Poor UX for Intel users | High | Default to `tiny` model on Intel; show clear performance guidance; consider Intel-only optimizations in whisper.cpp. |
| Accessibility permission changes in future macOS versions | Text insertion breaks | Medium | Abstract the insertion layer; monitor macOS betas; implement fallback (manual paste notification). |
| Large model download sizes deter users | Users stuck with lower-accuracy small models | Medium | Bundle `base` model (~150 MB); use delta downloads if possible; clear size/accuracy trade-off documentation. |
| MLX not available on Intel | Post-processing unavailable for Intel users | High | Detect hardware at launch; disable post-processing on Intel gracefully with explanation; consider llama.cpp as CPU fallback in future. |
| CGEvent tap rejected by App Store review | Cannot distribute on App Store | High | Primary distribution is direct download; App Store version would need alternative architecture (see §8.3). |
| User's hotkey conflicts with other apps | Hotkey doesn't fire reliably | Medium | Detect conflicts at registration time; warn user; suggest alternatives. |

---

## 12. Success Metrics

For an open-source project, success is measured by adoption, reliability, and community engagement rather than revenue.

- **Transcription accuracy**: ≥ 90% word accuracy for clear speech in English with `base` model (benchmarked against Whisper's published metrics).
- **End-to-end latency**: < 3 seconds from releasing the hotkey to text appearing (10s utterance, `base` model, M1).
- **Crash-free sessions**: > 99.5% (measured via optional opt-in crash reporting).
- **GitHub stars**: 1,000+ within 6 months of release (indicates product-market fit).
- **Active contributors**: 5+ contributors within 6 months.
- **User-reported issues**: < 10 open bugs at any time after Phase 2.

---

## 13. Open Questions

1. **Streaming transcription**: Should Phase 1 support streaming (transcribing as the user speaks) or batch-only (transcribe after recording stops)? Streaming is more complex but significantly better UX for long dictations.

2. **Custom wake word**: Should the app support a voice-activated wake word (e.g., "Hey SoundVibe") as an alternative to the hotkey? This would require an always-on lightweight audio monitor.

3. **Per-app profiles**: Should users be able to configure different settings (language, post-processing mode, model) per application? For example, "formal" mode in Mail but "clean" mode in Slack.

4. **Dictation log / training data**: Should the app offer an option to save anonymized transcription pairs (audio + text) locally for potential future model fine-tuning?

5. **Keyboard shortcut for undo**: Should there be a hotkey to undo the last dictation insertion (restore previous clipboard and remove inserted text)?

---

## 14. Appendix

### A. Whisper Model Size Reference

| Model | Parameters | Disk Size | Relative Speed | English Accuracy (WER) |
|-------|-----------|-----------|----------------|----------------------|
| tiny | 39M | ~75 MB | ~10x | ~7.7% |
| base | 74M | ~150 MB | ~7x | ~5.0% |
| small | 244M | ~500 MB | ~4x | ~3.4% |
| medium | 769M | ~1.5 GB | ~2x | ~2.9% |
| large-v3 | 1550M | ~3 GB | 1x | ~2.0% |

*WER = Word Error Rate on LibriSpeech clean test set. Speed is relative (higher = faster).*

### B. Competitive Landscape

| App | Local? | Open Source? | Post-Processing? | Price |
|-----|--------|-------------|-------------------|-------|
| macOS Dictation | Partial (on-device on AS) | No | No | Free |
| Whisper Transcription (Mac app) | Yes | No | No | $4.99 |
| Superwhisper | Yes | No | Yes (cloud LLM) | $10/mo |
| Talon Voice | Yes | No (closed beta) | No (command-focused) | Free |
| **SoundVibe** | **Yes** | **Yes** | **Yes (local LLM)** | **Free** |
