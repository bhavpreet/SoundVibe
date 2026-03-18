#if os(macOS)

import AppKit
import SwiftUI

/// Enum representing the current state of the menu bar icon and status
enum MenuBarState {
    case idle
    case listening
    case processing
    case error
}

/// Manages the menu bar status item and menu for SoundVibe
class MenuBarManager: NSObject, ObservableObject {
    @Published var state: MenuBarState = .idle

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var recentTranscriptions: [String] = []
    private weak var settingsWindow: NSWindow?

    static let shared = MenuBarManager()

    override init() {
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        menu = NSMenu()
        menu?.delegate = self

        buildMenu()

        if let button = statusItem?.button {
            button.action = #selector(statusItemClicked(_:))
            button.target = self
        }

        statusItem?.menu = menu
        updateIcon(for: .idle)
    }

    private func buildMenu() {
        guard let menu = menu else { return }
        menu.removeAllItems()

        let statusItem = NSMenuItem()
        statusItem.title = getStatusText()
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Post-processing toggle
        let postProcessingItem = NSMenuItem(
            title: "Post-processing",
            action: #selector(togglePostProcessing(_:)),
            keyEquivalent: ""
        )
        postProcessingItem.target = self
        postProcessingItem.state = SettingsManager.shared.postProcessingEnabled ? .on : .off
        menu.addItem(postProcessingItem)

        // Language submenu
        let languageSubmenu = NSMenu()
        let currentLanguage = SettingsManager.shared.selectedLanguage

        for language in SupportedLanguage.allCases {
            let languageItem = NSMenuItem(
                title: language.displayName,
                action: #selector(selectLanguage(_:)),
                keyEquivalent: ""
            )
            languageItem.target = self
            languageItem.representedObject = language
            languageItem.state = language.rawValue == currentLanguage ? .on : .off
            languageSubmenu.addItem(languageItem)
        }

        let languageMenu = NSMenuItem(
            title: "Language",
            action: nil,
            keyEquivalent: ""
        )
        languageMenu.submenu = languageSubmenu
        menu.addItem(languageMenu)

        menu.addItem(NSMenuItem.separator())

        // Recent transcriptions submenu
        let recentSubmenu = NSMenu()
        if recentTranscriptions.isEmpty {
            let emptyItem = NSMenuItem(
                title: "No recent transcriptions",
                action: nil,
                keyEquivalent: ""
            )
            emptyItem.isEnabled = false
            recentSubmenu.addItem(emptyItem)
        } else {
            for transcription in recentTranscriptions.prefix(5) {
                let displayText = transcription.count > 50
                    ? String(transcription.prefix(50)) + "..."
                    : transcription

                let item = NSMenuItem(
                    title: displayText,
                    action: #selector(copyRecentTranscription(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = transcription
                recentSubmenu.addItem(item)
            }
        }

        let recentMenu = NSMenuItem(
            title: "Recent Transcriptions",
            action: nil,
            keyEquivalent: ""
        )
        recentMenu.submenu = recentSubmenu
        menu.addItem(recentMenu)

        menu.addItem(NSMenuItem.separator())

        // Settings item
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        // About item
        let aboutItem = NSMenuItem(
            title: "About SoundVibe",
            action: #selector(openAbout(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        // Reset settings item (Debug)
        #if DEBUG
        let resetItem = NSMenuItem(
            title: "Reset All Settings",
            action: #selector(resetSettings(_:)),
            keyEquivalent: ""
        )
        resetItem.target = self
        menu.addItem(resetItem)
        #endif

        menu.addItem(NSMenuItem.separator())

        // Quit item
        let quitItem = NSMenuItem(
            title: "Quit SoundVibe",
            action: #selector(quitApp(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func updateIcon(for state: MenuBarState) {
        guard let button = statusItem?.button else { return }

        let symbolName: String

        switch state {
        case .idle:
            symbolName = "waveform.circle"
        case .listening:
            symbolName = "waveform.circle.fill"
        case .processing:
            symbolName = "ellipsis.circle"
        case .error:
            symbolName = "exclamationmark.circle"
        }

        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            button.image = image
        }
    }

    private func getStatusText() -> String {
        switch state {
        case .idle:
            return "Ready"
        case .listening:
            return "Listening..."
        case .processing:
            return "Processing..."
        case .error:
            return "Error"
        }
    }

    // MARK: - Public Methods

    func updateState(_ state: MenuBarState) {
        DispatchQueue.main.async {
            self.state = state
            self.updateIcon(for: state)
            self.buildMenu()
        }
    }

    /// Update the status text shown in the menu (e.g. "Loading model...")
    func updateStatusText(_ text: String) {
        DispatchQueue.main.async {
            self.buildMenu()
            // Update the first menu item (status text)
            if let firstItem = self.menu?.items.first {
                firstItem.title = text
            }
        }
    }

    func addRecentTranscription(_ text: String) {
        if !text.trimmingCharacters(in: .whitespaces).isEmpty {
            recentTranscriptions.insert(text, at: 0)
            if recentTranscriptions.count > 5 {
                recentTranscriptions.removeLast()
            }
            buildMenu()
        }
    }

    // MARK: - Menu Actions

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        // Menu is shown automatically by AppKit
    }

    @objc private func togglePostProcessing(_ sender: NSMenuItem) {
        SettingsManager.shared.postProcessingEnabled.toggle()
        buildMenu()
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        if let language = sender.representedObject as? SupportedLanguage {
            SettingsManager.shared.selectedLanguage = language.rawValue
            buildMenu()
        }
    }

    @objc private func copyRecentTranscription(_ sender: NSMenuItem) {
        if let text = sender.representedObject as? String {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        // LSUIElement apps must activate explicitly to receive keyboard events
        NSApp.activate(ignoringOtherApps: true)

        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
        } else {
            let settingsView = SettingsView()
            let hostingView = NSHostingView(rootView: settingsView)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.contentView = hostingView
            window.title = "SoundVibe Settings"
            window.center()
            window.makeKeyAndOrderFront(nil)
            window.isReleasedWhenClosed = false

            self.settingsWindow = window
        }
    }

    @objc private func openAbout(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "About SoundVibe"
        alert.informativeText = "Private, local dictation for macOS\n\nVersion 1.0\n\nSoundVibe transcribes audio locally on your device without sending data to external servers."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    #if DEBUG
    @objc private func resetSettings(_ sender: NSMenuItem) {
        let alert = NSAlert()
        alert.messageText = "Reset All Settings?"
        alert.informativeText = "This will reset all settings and clear onboarding. The app will restart."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // Use the utility or SettingsManager
            ResetSoundVibeSettings.resetAll()
            
            // Show confirmation
            let confirm = NSAlert()
            confirm.messageText = "Settings Reset"
            confirm.informativeText = "All settings have been reset. Please quit and restart the app."
            confirm.alertStyle = .informational
            confirm.addButton(withTitle: "Quit Now")
            
            if confirm.runModal() == .alertFirstButtonReturn {
                NSApplication.shared.terminate(nil)
            }
        }
    }
    #endif

    @objc private func quitApp(_ sender: NSMenuItem) {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - NSMenuDelegate

extension MenuBarManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        buildMenu()
    }
}

// MARK: - Supported Language

enum SupportedLanguage: String, CaseIterable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case dutch = "nl"
    case russian = "ru"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .dutch: return "Dutch"
        case .russian: return "Russian"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        }
    }
}

#endif
