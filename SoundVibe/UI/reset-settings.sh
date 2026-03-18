#!/bin/bash

# Reset SoundVibe Settings Script
# This script clears all UserDefaults for the SoundVibe app

echo "🔄 Resetting SoundVibe settings..."

# Array of all UserDefaults keys used by SoundVibe
keys=(
    "soundvibe.triggerMode"
    "soundvibe.hotkey"
    "soundvibe.selectedModelSize"
    "soundvibe.selectedLanguage"
    "soundvibe.autoLanguageDetection"
    "soundvibe.autoPunctuation"
    "soundvibe.postProcessingEnabled"
    "soundvibe.postProcessingMode"
    "soundvibe.customPostProcessingPrompt"
    "soundvibe.launchAtLogin"
    "soundvibe.showFloatingIndicator"
    "soundvibe.clipboardRestoreEnabled"
    "soundvibe.pasteDelay"
    "soundvibe.silenceTimeout"
    "soundvibe.selectedInputDevice"
    "SoundVibe_OnboardingCompleted"
)

# Remove each key
for key in "${keys[@]}"; do
    defaults delete NSGlobalDomain "$key" 2>/dev/null && echo "  ✓ Removed: $key" || echo "  - Skipped: $key (not set)"
done

echo ""
echo "✅ All SoundVibe settings have been reset!"
echo "🚀 You can now run the app again."
echo ""
