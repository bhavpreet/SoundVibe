import SwiftUI

#if os(macOS)
import AppKit
#endif

/// Main application entry point for SoundVibe
/// This is a menu bar app (LSUIElement), so it does not display a traditional main window.
@main
struct SoundVibeApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        // Main window (for debugging/testing)
        WindowGroup {
            VStack {
                Text("SoundVibe")
                    .font(.largeTitle)
                Text("Menu Bar Application")
                    .foregroundStyle(.secondary)
                Text("Look for the icon in your menu bar 👆")
                    .padding()
            }
            .frame(minWidth: 300, minHeight: 200)
        }
        
        Settings {
            SettingsView()
        }
    }
}

// MARK: - SwiftUI Preview (if needed for development)

#if DEBUG
#Preview {
    Text("SoundVibe is running as a menu bar application")
}
#endif
