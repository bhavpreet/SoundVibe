# SoundVibe Installation & UX Improvement Plan

## Context

SoundVibe is a macOS menu bar dictation app at `/Users/bhav/dev/SoundVibe`. Git repo has 3 commits. The app builds with SPM, uses WhisperKit for transcription. Read `CLAUDE.md` and `ARCHITECTURE.md` for full context.

## Reference Files

Before making any change, read these files to understand current state:

- `SoundVibe/App/SoundVibeApp.swift` — has a debug WindowGroup that must be removed
- `SoundVibe/App/AppDelegate.swift` — app initialization, onboarding trigger, model loading
- `SoundVibe/UI/OnboardingView.swift` — 6-step onboarding flow
- `SoundVibe/UI/FloatingIndicatorWindow.swift` — floating indicator with error state
- `SoundVibe/Orchestration/DictationOrchestrator.swift` — calls `floatingIndicatorManager.showError()` without passing message
- `SoundVibe/Transcription/WhisperEngine.swift` — `loadModel(variant:)` is async, downloads from HuggingFace
- `scripts/make-dmg.sh` — current DMG packaging script

---

## TODO 1: Remove Debug WindowGroup

**Files:** `SoundVibe/App/SoundVibeApp.swift`

- [ ] Remove the `WindowGroup` that shows "SoundVibe / Menu Bar Application / Look for the icon in your menu bar". This window pops up on every launch which is wrong for an `LSUIElement` menu bar app.
- [ ] Keep the `Settings` scene (it's needed for the Settings window).
- [ ] The `@NSApplicationDelegateAdaptor(AppDelegate.self)` must remain.
- [ ] For SwiftUI apps without a WindowGroup, you may need a minimal empty `WindowGroup` with `.defaultSize(width: 0, height: 0)` hidden, or use `MenuBarExtra` if targeting macOS 14+. Test that the app launches with only the menu bar icon and no window.

**Verify:** Launch app → no window appears, only menu bar icon. Settings still openable from menu bar.

---

## TODO 2: Pre-populate Default Hotkey in Onboarding

**Files:** `SoundVibe/UI/OnboardingView.swift`

- [ ] In `OnboardingView`, initialize `selectedHotkey` to `HotkeyCombo.defaultHotkey.displayString` (which is `"Right ⌘"`) instead of empty string `""`.
- [ ] This makes `canProceedToNext()` return `true` for step 3 even if user doesn't record a custom hotkey.
- [ ] The "Record Hotkey" button should show `"Right ⌘"` as the current hotkey on the initial state, not "Click to record hotkey".
- [ ] User can still click to record a different hotkey — the pre-populated default just means they can skip.

**Verify:** Fresh onboarding → step 3 shows "Right ⌘" → Next button is enabled without recording.

---

## TODO 3: Robust Onboarding Window Close

**Files:** `SoundVibe/App/AppDelegate.swift`, `SoundVibe/UI/OnboardingView.swift`

- [ ] In `AppDelegate.showOnboarding()`, store the created `NSWindow` in a property: `private var onboardingWindow: NSWindow?`
- [ ] In `OnboardingView.completeOnboarding()`, currently uses `NSApplication.shared.keyWindow?.close()` which can fail if the window lost key status. Instead, post the notification and let AppDelegate close its stored reference.
- [ ] In `AppDelegate.onboardingDidComplete()`, close `onboardingWindow` explicitly: `onboardingWindow?.close(); onboardingWindow = nil`.
- [ ] Remove `NSApplication.shared.keyWindow?.close()` from `completeOnboarding()`.

**Verify:** Click elsewhere during onboarding, then click "Start Using SoundVibe" → window closes reliably.

---

## TODO 4: Add Model Download Step to Onboarding

**Files:** `SoundVibe/UI/OnboardingView.swift`, `SoundVibe/Transcription/WhisperEngine.swift`, `SoundVibe/App/AppDelegate.swift`

This is the largest change. Currently the Whisper model (~150MB) downloads silently in the background after onboarding, and users get "model still downloading" errors when they press the hotkey.

- [ ] Add a new onboarding step **between Language (step 4) and Ready (step 5)** — call it `ModelDownloadStep`. Update `totalSteps` from 6 to 7. Renumber Ready from tag 5 to tag 6.
- [ ] `ModelDownloadStep` should:
  - Show a title "Downloading Speech Model"
  - Show the selected model size name and approximate size (e.g. "Base model — ~150 MB")
  - Show a `ProgressView` with determinate progress (0–100%)
  - Show a status label ("Downloading...", "Loading model...", "Ready!")
  - Auto-start download on appear
  - Block the Next button until download completes
- [ ] To get download progress from WhisperKit: `WhisperKit` init downloads automatically. But we need progress. Check if `WhisperKit.download(variant:progressCallback:)` static method can be used to download first, then init with the local `modelFolder`. The static method signature is: `WhisperKit.download(variant: String, from repo: String, progressCallback: ((Progress) -> Void)?) async throws -> URL`. Call this to download, then store the folder path.
- [ ] After download completes, store the model folder path so `AppDelegate` can init `WhisperKit` with `modelFolder` instead of re-downloading.
- [ ] Save the downloaded model folder path to UserDefaults (key: `soundvibe.whisperModelFolder`).
- [ ] Update `canProceedToNext()`: step 5 (the new model download step) requires download complete.
- [ ] In `AppDelegate.setupApplication()`, check if model folder exists in UserDefaults. If so, init `WhisperEngine` with that path instead of triggering a fresh download.
- [ ] `WhisperEngine` needs a new method: `loadModel(fromFolder path: String) async throws` that creates `WhisperKit(WhisperKitConfig(modelFolder: path, download: false))`.

**Verify:** Fresh install → onboarding reaches model download step → progress bar fills → Ready step becomes available → after completing onboarding, hotkey works immediately.

---

## TODO 5: Move Model Loading After Onboarding

**Files:** `SoundVibe/App/AppDelegate.swift`

- [ ] Currently `loadWhisperModelAsync()` is called at the end of `setupApplication()` and downloads the model in background. After TODO 4, the model is already downloaded during onboarding.
- [ ] Change `loadWhisperModelAsync()` to check for cached model folder first (from UserDefaults `soundvibe.whisperModelFolder`). If found, load from local folder (fast, no download). If not found (e.g. model was deleted), fall back to download.
- [ ] Show "Loading model..." in menu bar during the fast local load. Show "Downloading model..." only if actually downloading.

**Verify:** Second launch (model already downloaded) → menu bar shows "Loading model..." briefly → "Ready" within 2-3 seconds.

---

## TODO 6: Show Error Message in Floating Indicator

**Files:** `SoundVibe/UI/FloatingIndicatorWindow.swift`, `SoundVibe/Orchestration/DictationOrchestrator.swift`

Currently the floating indicator shows a generic ❌ "Error" for all failures. The actual error message (e.g. "Whisper model is still downloading") is in `DictationState.error(String)` but never shown to the user.

- [ ] `IndicatorStateModel`: add `@Published var errorMessage: String = ""`.
- [ ] `FloatingIndicatorWindow.showError()`: change signature to `showError(message: String = "An error occurred")`. Set `stateModel.errorMessage = message`.
- [ ] `FloatingIndicatorManager.showError()`: change signature to `showError(message: String = "An error occurred")`. Pass through to window.
- [ ] `FloatingIndicatorContentView` — in the `.error` case, replace the hardcoded `Text("Error")` with:
  ```swift
  Text(stateModel.errorMessage)
      .font(.caption)
      .foregroundColor(.red)
      .multilineTextAlignment(.center)
      .lineLimit(3)
  ```
- [ ] Optionally increase the indicator frame width from 200 to 250 for error state to fit longer messages.
- [ ] `DictationOrchestrator`: update all 4 call sites from `floatingIndicatorManager.showError()` to `floatingIndicatorManager.showError(message: msg)` where `msg` is the error description. The 4 sites are:
  1. Audio capture failed (~line 132)
  2. No audio captured (~line 160)
  3. Whisper model still downloading (~line 221)
  4. Pipeline error (~line 269)

**Verify:** Hold hotkey briefly and release → floating indicator shows "No audio captured. Please try speaking again." instead of generic "Error".

---

## TODO 7: DMG Background Image

**Files:** `scripts/make-dmg.sh`

- [ ] Generate a DMG background image (600x400 PNG) showing:
  - SoundVibe logo/icon on the left
  - An arrow pointing right toward "Applications"
  - Text: "Drag to install"
- [ ] Use `hdiutil` + `osascript` to set the DMG window size, icon positions, and background image. The standard approach:
  1. Create a read-write DMG
  2. Attach it
  3. Use `osascript` to set Finder view options (icon size, background, icon positions)
  4. Create a `.background` hidden folder with the background PNG
  5. Detach and convert to compressed read-only DMG
- [ ] Set icon size to 128, window size to 600x400
- [ ] Position SoundVibe.app icon at left-center, Applications symlink at right-center

**Verify:** Open DMG → see a polished window with background image showing drag-to-install instruction.

---

## Execution Order

```
TODO 1 (5 min)   → Remove debug window
TODO 2 (5 min)   → Pre-populate hotkey
TODO 3 (5 min)   → Robust window close
TODO 6 (10 min)  → Error messages in indicator
TODO 4 (30 min)  → Model download in onboarding
TODO 5 (10 min)  → Smart model loading in AppDelegate
TODO 7 (20 min)  → DMG background
```

After each TODO: `swift build`, `swift test` (214 tests must pass), then `git commit`.

After all TODOs: run `bash scripts/make-dmg.sh` to rebuild the DMG.

**Total: ~85 minutes, 7 commits.**
