# SoundVibe - Reset Settings Guide

This guide shows you how to reset all SoundVibe settings and run the app from scratch.

## Quick Reset Methods

### Method 1: Using Terminal (Fastest)

```bash
# Navigate to the project directory
cd /path/to/SoundVibe

# Make the script executable
chmod +x reset-settings.sh

# Run the reset script
./reset-settings.sh
```

### Method 2: Using Swift Script

```bash
swift ResetSoundVibeSettings.swift
```

### Method 3: Using Xcode Debug Menu

1. Run the app in Debug mode
2. Look for the SoundVibe icon in your menu bar (top-right)
3. Click it and select **"Reset All Settings"**
4. Confirm and quit the app
5. Run it again

### Method 4: Manual UserDefaults Reset

```bash
# Remove all SoundVibe settings
defaults delete NSGlobalDomain soundvibe.triggerMode
defaults delete NSGlobalDomain soundvibe.hotkey
defaults delete NSGlobalDomain soundvibe.selectedModelSize
defaults delete NSGlobalDomain soundvibe.selectedLanguage
defaults delete NSGlobalDomain soundvibe.autoLanguageDetection
defaults delete NSGlobalDomain soundvibe.autoPunctuation
defaults delete NSGlobalDomain soundvibe.postProcessingEnabled
defaults delete NSGlobalDomain soundvibe.postProcessingMode
defaults delete NSGlobalDomain soundvibe.customPostProcessingPrompt
defaults delete NSGlobalDomain soundvibe.launchAtLogin
defaults delete NSGlobalDomain soundvibe.showFloatingIndicator
defaults delete NSGlobalDomain soundvibe.clipboardRestoreEnabled
defaults delete NSGlobalDomain soundvibe.pasteDelay
defaults delete NSGlobalDomain soundvibe.silenceTimeout
defaults delete NSGlobalDomain soundvibe.selectedInputDevice
defaults delete NSGlobalDomain SoundVibe_OnboardingCompleted
```

## After Resetting

Once you've reset the settings:

1. **Quit the app** if it's running (Cmd+Q or click menu bar icon → Quit)
2. **Run the app** again from Xcode or Finder
3. You'll see the **onboarding window** on first launch
4. Follow the setup wizard to configure your preferences

## What Gets Reset?

- ✅ Trigger mode (Hold to Talk / Toggle)
- ✅ Hotkey combination
- ✅ Model size selection
- ✅ Language preferences
- ✅ Post-processing settings
- ✅ UI preferences (floating indicator, etc.)
- ✅ Onboarding completion flag
- ✅ All other app settings

## Troubleshooting

### App Still Shows Old Settings

If the app still shows old settings after reset:

1. Quit the app completely
2. Run the reset script again
3. Clear Xcode's derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/SoundVibe-*
   ```
4. Clean and rebuild in Xcode (Cmd+Shift+K, then Cmd+B)

### Menu Bar Icon Not Appearing

The app is a **menu bar application**, so look in the top-right corner of your screen for a waveform icon (🌊). If you still don't see it:

1. Check Console.app for errors
2. Make sure accessibility permissions are granted
3. Try running from Xcode to see logs

### Running the App

After reset, simply:
```bash
# In Xcode, press Cmd+R to run
# Or build and run the app
```

The app will appear in your menu bar (top-right corner of your screen).

## Need Help?

Check the logs in Console.app by filtering for "soundvibe" or "SoundVibe" to see what's happening during startup.
