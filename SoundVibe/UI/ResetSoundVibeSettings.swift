import Foundation

/// Utility to reset SoundVibe settings
/// Call `ResetSoundVibeSettings.resetAll()` to clear all app settings
struct ResetSoundVibeSettings {
    
    /// Resets all SoundVibe UserDefaults to default values
    static func resetAll() {
        print("🔄 Resetting SoundVibe Settings...")
        
        let defaults = UserDefaults.standard
        
        // All SoundVibe UserDefaults keys
        let settingsKeys = [
            "soundvibe.triggerMode",
            "soundvibe.hotkey",
            "soundvibe.selectedModelSize",
            "soundvibe.selectedLanguage",
            "soundvibe.autoLanguageDetection",
            "soundvibe.autoPunctuation",
            "soundvibe.postProcessingEnabled",
            "soundvibe.postProcessingMode",
            "soundvibe.customPostProcessingPrompt",
            "soundvibe.launchAtLogin",
            "soundvibe.showFloatingIndicator",
            "soundvibe.clipboardRestoreEnabled",
            "soundvibe.pasteDelay",
            "soundvibe.silenceTimeout",
            "soundvibe.selectedInputDevice",
            "soundvibe.whisperModelFolder",
            "SoundVibe_OnboardingCompleted"
        ]
        
        // Remove all keys
        for key in settingsKeys {
            defaults.removeObject(forKey: key)
            print("  ✓ Removed: \(key)")
        }
        
        // Synchronize
        defaults.synchronize()
        
        print("\n✅ All SoundVibe settings have been reset!")
        print("🚀 You can now run the app again with fresh settings.\n")
    }
}

