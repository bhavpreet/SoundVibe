# SoundVibe — Private, Local Dictation for macOS

SoundVibe is a powerful macOS application that brings speech-to-text dictation to any text field on your Mac—without sending your voice data anywhere. Built for developers and power users who value privacy and control.

**Tagline:** Dictate, don't wait. All processing happens locally on your device.

## Table of Contents

- [Features](#features)
- [Screenshots](#screenshots)
- [System Requirements](#system-requirements)
- [Installation](#installation)
- [First Launch Guide](#first-launch-guide)
- [Usage Guide](#usage-guide)
- [Configuration Reference](#configuration-reference)
- [Troubleshooting](#troubleshooting)
- [Building from Source](#building-from-source)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **100% Private**: All speech recognition and processing happens locally on your device. Your voice data never leaves your machine.
- **System-Wide Dictation**: Press your hotkey in any macOS text field—VS Code, Safari, Notes, Slack, Gmail, and more.
- **Multiple Whisper Models**: Choose from 5 model sizes (tiny through large-v3) to balance speed and accuracy.
- **Supports 99 Languages**: Transcribe in any language supported by Whisper, with optional auto-language detection.
- **Optional LLM Post-Processing**: Clean up transcriptions with a local AI model—remove filler words, fix grammar, rewrite in formal tone, or apply custom transformations.
- **Voice Commands**: Use spoken commands like "period", "new line", "question mark" to control formatting.
- **Two Trigger Modes**: Hold-to-talk or toggle—choose what works best for you.
- **Menu Bar Integration**: Quick access to settings, recent transcriptions, and post-processing toggles.
- **Floating Indicator**: Real-time visual feedback on recording and processing status (optional).
- **Auto-Punctuation**: Whisper generates properly punctuated output by default.
- **Configurable Settings**: Fine-tune hotkeys, delays, model selection, language, and more.

---

## Screenshots

*[Placeholder for screenshots]*

- Menu bar icon and dropdown menu
- Settings window (General, Audio, Transcription, Post-Processing, Advanced tabs)
- Onboarding flow
- Floating indicator window showing listening/processing states

---

## System Requirements

### Minimum

- **macOS 13.0 (Ventura)** or later
- **2 GB of free disk space** (for base Whisper model; larger models require more)
- **Microphone** (built-in or external USB device)

### Recommended

- **Apple Silicon Mac** (M1, M2, M3, M4 or later)
  - Fastest transcription and post-processing
  - Full support for all features and model sizes
  - < 2 seconds latency for 10-second utterances with base model

### Intel Mac Support

- **Supported but with caveats**:
  - Transcription works (uses CPU inference instead of GPU)
  - Noticeably slower: expect 5-10+ seconds for 10-second utterances with base model
  - Post-processing (LLM) unavailable (requires Apple Silicon MLX framework)
  - Recommended: use tiny or base model only for acceptable performance

---

## Installation

### Option 1: Download DMG (Recommended)

1. Download **SoundVibe.dmg** from the [latest release](https://github.com/bhavpreet/SoundVibe/releases/latest)
2. Open the DMG and drag **SoundVibe** to **Applications**
3. Launch SoundVibe from Applications

> **⚠️ macOS Gatekeeper Warning:** Since SoundVibe is not signed with an Apple Developer ID, macOS will show a warning: *"Apple could not verify SoundVibe is free of malware."*
>
> **To bypass this:**
> - **Right-click** (or Control-click) SoundVibe.app → click **"Open"** → click **"Open"** again in the dialog
> - Or run in Terminal: `xattr -cr /Applications/SoundVibe.app`
>
> macOS will remember your choice and won't ask again.

### Option 2: Build from Source

```bash
git clone https://github.com/bhavpreet/SoundVibe.git
cd SoundVibe
swift build -c release
```

To create an installable DMG:
```bash
bash scripts/make-dmg.sh
# Output: dist/SoundVibe.dmg
```

---

## First Launch Guide

When you launch SoundVibe for the first time, the **onboarding flow** will guide you through essential setup:

### 1. Welcome Screen
- Learn about SoundVibe's features and privacy promise

### 2. Microphone Permissions
- Grant microphone access so SoundVibe can record audio
- You'll see a macOS system dialog—click "Allow"
- SoundVibe will confirm when access is granted

### 3. Accessibility Permissions
- Grant accessibility permissions to simulate Cmd+V (text pasting)
- You'll need to open System Settings manually
- Follow the on-screen instructions: Settings → Privacy & Security → Accessibility → Add SoundVibe
- Once enabled, come back to the onboarding window and proceed

### 4. Input Monitoring Permissions (Optional)
- For reliable global hotkey detection, grant input monitoring permissions
- This is optional but recommended for best hotkey reliability
- Same process: System Settings → Privacy & Security → Input Monitoring

### 5. Configure Hotkey
- Choose your trigger mode: **Hold-to-Talk** (press and hold) or **Toggle** (press once to start, press again to stop)
- Record your hotkey by clicking "Record Hotkey" and pressing your desired key combination
- Suggestion: `⌥ Option + D` or `⌘ Command + ;` are common choices

### 6. Select Primary Language
- Choose the language you'll most often dictate in (English, Spanish, French, German, Chinese, etc.)
- You can change this anytime in Settings

### 7. You're All Set!
- SoundVibe is ready to use
- The app minimizes to the menu bar (no Dock icon)
- Start dictating by pressing your configured hotkey

---

## Usage Guide

### Basic Dictation Workflow

#### Hold-to-Talk Mode
1. Click into a text field (in any app)
2. **Press and hold** your configured hotkey
3. Speak clearly into your microphone
4. **Release** the hotkey
5. SoundVibe transcribes your audio and pastes the result into the text field

#### Toggle Mode
1. Click into a text field
2. **Press** your hotkey once → recording starts (you'll see the menu bar icon change)
3. Speak (you can pause naturally—silence won't stop recording)
4. **Press** your hotkey again → recording stops and transcription begins
5. Text appears in the field

### Configuring the Hotkey

1. Open **Settings** (click the menu bar icon and select "Settings...")
2. Go to the **General** tab
3. Click the hotkey button to record a new hotkey
4. Press any key combination (e.g., `⌥ Option + D`, `⌘ Command + ;`, `⌃ Control + Shift + V`)
5. Your new hotkey is saved immediately

**Hotkey Tips:**
- Avoid keys used by other apps (check System Settings → Keyboard → Keyboard Shortcuts)
- Modifier keys alone (like double-tapping Fn) are supported on newer Macs
- Default suggestion: `⌥ Option + D` or `⌘ Command + ;`

### Hold-to-Talk vs. Toggle Mode

| Mode | Best For | Behavior |
|------|----------|----------|
| **Hold-to-Talk** | Short transcriptions, quick dictation | Press and hold → speak → release to finish |
| **Toggle** | Longer dictation, hands-free | Press once to start → speak freely → press again to stop |

Change modes in Settings → General → Trigger Mode.

### Voice Commands

SoundVibe recognizes spoken punctuation and formatting commands within your dictation:

#### Punctuation Commands
| Command | Result |
|---------|--------|
| "period" or "full stop" | `.` |
| "comma" | `,` |
| "question mark" | `?` |
| "exclamation mark" or "exclamation" | `!` |
| "colon" | `:` |
| "semicolon" | `;` |
| "open quote" or "quote" | `"` |
| "close quote" | `"` |

#### Formatting Commands
| Command | Result |
|---------|--------|
| "new line" or "next line" | Line break |
| "new paragraph" | Double line break |
| "capitalize [word]" | Capitalize the next word |
| "uppercase [word]" | Make the next word ALL CAPS |

**Example:** "Hello, how are you question mark new line Thanks period"
**Result:** `Hello, how are you? Thanks.`

### Post-Processing Modes

If you enable post-processing (Settings → Post-Processing → Enable Post-Processing), SoundVibe can clean up your transcriptions using a local AI model:

#### Clean Mode
- Removes filler words: "um", "uh", "like", "you know", "basically", "actually"
- Fixes obvious grammar errors
- Preserves your original meaning and tone
- **Best for:** Casual notes, Slack messages, quick emails

#### Formal Mode
- Rewrites transcription in professional, business tone
- Improves word choice and grammar
- Ensures proper structure
- **Best for:** Work emails, formal documents, professional communication

#### Concise Mode
- Shortens text while keeping core meaning
- Removes redundancy and filler
- **Best for:** Summaries, headlines, tight writing

#### Custom Mode
- You provide your own system prompt
- SoundVibe applies your custom instructions
- **Best for:** Domain-specific transformations (e.g., converting to code comments, medical transcription)

**Toggle post-processing** on/off quickly:
- From the menu bar dropdown: check/uncheck "Post-Processing"
- Or via Settings → Post-Processing → Enable Post-Processing

### Model Selection Guide

Choose your Whisper model based on your hardware and accuracy needs:

| Model | Size | Speed | Accuracy (WER) | Best For |
|-------|------|-------|---|----------|
| **Tiny** | 39 MB | ~30x faster | 7.7% error | Quick tests, low-power devices |
| **Base** | 140 MB | ~7x faster | 5.0% error | **Recommended default**, good balance |
| **Small** | 466 MB | ~4x faster | 3.4% error | High accuracy, still fast on Apple Silicon |
| **Medium** | 1.5 GB | ~2x faster | 2.9% error | Very high accuracy, slower on Intel |
| **Large V3** | 2.9 GB | 1x (baseline) | 2.0% error | Highest accuracy, requires 4+ GB RAM |

**How to choose:**
- **Apple Silicon (M1+):** Start with **Base** (fast), upgrade to **Small** or **Medium** if you need better accuracy
- **Intel Mac:** Use **Tiny** or **Base** only; anything larger will be very slow
- **Limited disk space:** **Tiny** (39 MB) or **Base** (140 MB) are compact

**Switching models:**
1. Open Settings → Transcription tab
2. Select a model from the "Model Size" dropdown
3. Click "Download Model" if it's not already downloaded
4. Progress bar shows download status
5. Once downloaded, that model is automatically used

Models are stored in: `~/Library/Application Support/SoundVibe/Models/`

---

## Configuration Reference

All settings are accessible from Settings (click menu bar icon → "Settings...").

### General Tab

| Setting | Options | Default | Description |
|---------|---------|---------|-------------|
| **Hotkey** | Any key combination | ⌥ Option + D | Press and hold (or toggle) to start recording |
| **Trigger Mode** | Hold-to-Talk, Toggle | Hold-to-Talk | How the hotkey triggers recording |
| **Launch at Login** | On/Off | Off | Auto-launch SoundVibe when you log in |
| **Menu Bar Icon Style** | Compact, Detailed | Compact | Icon appearance in menu bar |

### Audio Tab

| Setting | Options | Default | Description |
|---------|---------|---------|-------------|
| **Input Device** | Your microphones | Default | Which microphone to use |
| **Silence Timeout** | 0.5s - 5.0s | 3.0s | Auto-stop toggle mode after N seconds of silence |
| **Noise Gate** | On/Off | Off | Filter background noise (coming soon) |

### Transcription Tab

| Setting | Options | Default | Description |
|---------|---------|---------|-------------|
| **Model Size** | Tiny, Base, Small, Medium, Large V3 | Base | Whisper model for transcription |
| **Download Model** | Button | — | Download a larger model (shows progress) |
| **Primary Language** | 99+ languages | English | Language for transcription |
| **Auto-Language Detection** | On/Off | Off | Let Whisper detect the language automatically |
| **Auto-Punctuation** | On/Off | On | Add periods, commas, etc. automatically |

### Post-Processing Tab

| Setting | Options | Default | Description |
|---------|---------|---------|-------------|
| **Enable Post-Processing** | On/Off | Off | Use a local LLM to clean up text |
| **Processing Mode** | Clean, Formal, Concise, Custom | Clean | How to transform text |
| **Custom Prompt** | Text | (empty) | Your custom instructions (only for Custom mode) |
| **MLX Model** | (info) | Built-in | Shows the current LLM model |

### Advanced Tab

| Setting | Options | Default | Description |
|---------|---------|---------|-------------|
| **Restore Clipboard** | On/Off | On | Save and restore clipboard after pasting |
| **Paste Delay** | 10ms - 200ms | 50ms | Wait time before simulating Cmd+V |
| **Debug Logging** | On/Off | Off | Log detailed events (for troubleshooting) |
| **Storage Path** | (info) | `~/Library/Application Support/SoundVibe` | Where settings and models are stored |
| **Export Settings** | Button | — | Save settings to a JSON file |
| **Import Settings** | Button | — | Load settings from a JSON file |
| **Reset to Defaults** | Button | — | Restore all settings to original values |

### Settings Persistence

- Settings are saved automatically to **UserDefaults** (`~/Library/Preferences/com.soundvibe.plist`)
- You can export/import settings as JSON for backup or migration between machines
- Settings survive app updates and system reboots

---

## Troubleshooting

### Hotkey Doesn't Work

**Symptom:** Pressing the hotkey doesn't start recording.

**Causes and fixes:**
1. **Accessibility permission not granted**
   - Open System Settings → Privacy & Security → Accessibility
   - Find "SoundVibe" in the list—ensure it's checked
   - Restart SoundVibe

2. **Hotkey conflicts with another app**
   - Check if another app is using the same hotkey
   - Try a different key combination in Settings
   - Common conflicts: `⌘ Command + Space` (Spotlight), `⌘ Command + Tab` (app switcher)

3. **Input Monitoring permission missing** (new in some macOS versions)
   - Go to System Settings → Privacy & Security → Input Monitoring
   - Add SoundVibe to the list
   - Restart SoundVibe

### No Audio Captured / "No audio was captured" Error

**Symptom:** Recording happens but transcription fails with "No audio captured."

**Causes and fixes:**
1. **Microphone not working**
   - Test your mic: System Settings → Sound → Input
   - Select your microphone and speak—the level bar should move
   - Try a different mic if available

2. **App doesn't have microphone permission**
   - Go to System Settings → Privacy & Security → Microphone
   - Find SoundVibe and ensure it's allowed
   - Restart SoundVibe

3. **Audio level too low**
   - Speak louder or closer to the microphone
   - Check System Settings → Sound → Input Level

4. **Wrong input device selected**
   - In Settings → Audio, switch to a different device
   - If you have multiple mics, try each one

### Transcription Very Slow (5+ seconds for 10 seconds of audio)

**Symptom:** Transcription takes a long time; you're on Intel Mac.

**Cause and fixes:**
- **Intel Macs use CPU inference (not GPU)**, which is inherently slow
- **Solution:** Use a smaller model
  - Switch to **Tiny** or **Base** model in Settings → Transcription
  - Accept lower accuracy for faster speed
  - Consider upgrading to Apple Silicon Mac for <2 second latency

### Text Didn't Paste / Clipboard Error

**Symptom:** Transcription completes but text doesn't appear in the field.

**Causes and fixes:**
1. **Accessibility permission not granted**
   - Go to System Settings → Privacy & Security → Accessibility
   - Add SoundVibe to the list
   - Text remains on clipboard—you'll see a menu bar notification

2. **Focus moved to a different app**
   - SoundVibe pastes into the app that was focused when you pressed the hotkey
   - If you switched apps during recording, click back into your text field
   - Click paste manually (Cmd+V)

3. **App doesn't support paste**
   - Some specialized apps (game chat, voice apps) may not support clipboard paste
   - Try pasting manually (Cmd+V)
   - Contact support if the app should work

### Post-Processing Disabled / Not Available

**Symptom:** Post-Processing tab shows "unavailable" or toggling doesn't work.

**Causes and fixes:**
1. **Intel Mac** (no MLX support)
   - Post-processing requires Apple Silicon
   - Workaround: use **Clean mode** (basic punctuation/grammar post-processing)
   - Or upgrade to an Apple Silicon Mac

2. **Model not loaded**
   - Download a model in Settings → Transcription → Download Model
   - Post-processing requires a local LLM model

### App Crashes or Won't Start

**Symptom:** SoundVibe crashes on launch or during use.

**Troubleshooting steps:**
1. **Check debug logs** (if enabled)
   - Settings → Advanced → Debug Logging (On)
   - Open Console.app and search for "SoundVibe"

2. **Reset settings to defaults**
   - Settings → Advanced → Reset to Defaults
   - Restart the app

3. **Reinstall**
   - Quit SoundVibe
   - Delete the app from Applications
   - Download and install a fresh copy
   - Note: Settings in `~/Library/Application Support/SoundVibe` are preserved

4. **Check system requirements**
   - Ensure you're on macOS 13 or later
   - Have at least 2 GB free disk space
   - Install latest OS updates

### Menu Bar Icon Missing / App Minimizes to Dock

**Symptom:** No menu bar icon; app shows in Dock instead.

**Fix:**
- SoundVibe is a menu bar app and should not appear in the Dock
- If it does, there may be a launch issue
- Try: Quit app (Cmd+Q), re-open it, it should go to menu bar
- If Dock icon persists, reset settings (Settings → Advanced → Reset to Defaults)

### Model Download Fails / Checksum Mismatch

**Symptom:** Download fails or shows "Checksum verification failed."

**Causes and fixes:**
1. **Network issue**
   - Check your internet connection
   - Try again—downloads may be temporarily unavailable
   - Models are hosted on HuggingFace; check status page

2. **Corrupted download**
   - Clear the partial download: `rm ~/Library/Application\ Support/SoundVibe/Models/*.partial`
   - Try downloading again

3. **Disk space**
   - Ensure you have 2-3x the model size free (for download + extraction)
   - Clear cache: `rm ~/Library/Caches/SoundVibe`

---

## Building from Source

### Prerequisites

- **Xcode 15.0+** (with Command Line Tools)
- **Swift 5.9+**
- **macOS 13+** development tools

### Build Steps

```bash
# Clone the repo
git clone https://github.com/yourusername/soundvibe.git
cd soundvibe

# Build for release
swift build -c release

# Or open in Xcode for development
open SoundVibe.xcodeproj
```

### Xcode Build

1. Open `SoundVibe.xcodeproj` in Xcode
2. Select the SoundVibe scheme
3. Select your Mac as the target
4. Product → Build (Cmd+B) or Product → Run (Cmd+R)

### Install

Move the built app to your Applications folder:

```bash
cp -r .build/release/SoundVibe.app /Applications/
```

### Dependencies

- **whisper.cpp** (speech-to-text): via Swift Package Manager
- **MLX** (post-processing on Apple Silicon): built-in framework
- **AVFoundation** (audio capture): macOS framework
- **AppKit** (menu bar, hotkey): macOS framework
- **SwiftUI** (settings UI): macOS framework

---

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on:

- Setting up your development environment
- Code style and best practices
- Running tests
- Submitting pull requests
- Reporting issues

**Areas we'd love help with:**
- Improving transcription accuracy
- Optimizing performance on Intel Macs
- Adding more languages and locale support
- Enhancing post-processing with better LLM prompts
- Improving documentation and translations
- Testing and bug reports

---

## License

SoundVibe is released under the **MIT License**. See [LICENSE](LICENSE) for full text.

MIT License gives you:
- ✓ Free use, personal and commercial
- ✓ Right to modify and redistribute
- ✓ No warranty (use at your own risk)
- ✓ Must retain the license and copyright notice

---

## Support

For questions, bug reports, or feature requests:

- **GitHub Issues**: [soundvibe/issues](https://github.com/yourusername/soundvibe/issues)
- **GitHub Discussions**: [soundvibe/discussions](https://github.com/yourusername/soundvibe/discussions)
- **Email**: contact@soundvibe.example (coming soon)

---

**Made with ❤️ by the SoundVibe community.**

Your privacy matters. Your voice stays with you.
