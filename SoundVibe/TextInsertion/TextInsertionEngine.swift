import Foundation

#if os(macOS)
import AppKit
import CoreGraphics
#endif

// MARK: - Types and Enums (Cross-platform)

/// Errors related to text insertion
public enum TextInsertionError: LocalizedError {
    case accessibilityPermissionDenied
    case pasteSimulationFailed(reason: String)
    case clipboardWriteFailed(reason: String)
    case clipboardReadFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "Accessibility permissions not granted. Enable in System Preferences > Security & Privacy > Accessibility"
        case .pasteSimulationFailed(let reason):
            return "Failed to simulate paste operation: \(reason)"
        case .clipboardWriteFailed(let reason):
            return "Failed to write text to clipboard: \(reason)"
        case .clipboardReadFailed(let reason):
            return "Failed to read from clipboard: \(reason)"
        }
    }
}

// MARK: - TextInsertionEngine

/// Inserts text into the active application via clipboard + Cmd+V simulation
public class TextInsertionEngine {
    /// Default delay before simulating paste (in seconds)
    public static let defaultPasteDelay: TimeInterval = 0.05

    /// Default delay for clipboard restoration (in seconds)
    public static let defaultClipboardRestoreDelay: TimeInterval = 0.1

    public init() {}

    // MARK: - Public Methods

    /// Insert text into the active application
    /// - Parameters:
    ///   - text: The text to insert
    ///   - restoreClipboard: Whether to restore clipboard contents after insertion
    ///   - pasteDelay: Delay before simulating Cmd+V (default 50ms)
    ///   - restoreDelay: Delay before restoring clipboard (default 100ms)
    public func insertText(
        _ text: String,
        restoreClipboard: Bool = true,
        pasteDelay: TimeInterval = TextInsertionEngine.defaultPasteDelay,
        restoreDelay: TimeInterval = TextInsertionEngine.defaultClipboardRestoreDelay
    ) async throws {
        #if os(macOS)
        try await insertTextMacOS(
            text,
            restoreClipboard: restoreClipboard,
            pasteDelay: pasteDelay,
            restoreDelay: restoreDelay
        )
        #else
        throw TextInsertionError.pasteSimulationFailed(reason: "Text insertion requires macOS")
        #endif
    }

    // MARK: - Private Methods (macOS-specific)

    #if os(macOS)
    private func insertTextMacOS(
        _ text: String,
        restoreClipboard: Bool,
        pasteDelay: TimeInterval,
        restoreDelay: TimeInterval
    ) async throws {
        let pasteboard = NSPasteboard.general

        // Step 1: Save current clipboard contents if needed
        let savedClipboardContents: [NSPasteboard.PasteboardType: Any]? = restoreClipboard
            ? saveClipboardContents(pasteboard)
            : nil

        do {
            // Step 2: Write text to clipboard
            try writeToClipboard(text, pasteboard: pasteboard)

            // Step 3: Wait for clipboard to settle
            try await Task.sleep(nanoseconds: UInt64(pasteDelay * 1_000_000_000))

            // Step 4: Check accessibility permissions and simulate Cmd+V
            try simulateCommandV()

            // Step 5: Wait for paste to complete
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms

            // Step 6: Restore clipboard if needed
            if let savedContents = savedClipboardContents {
                try await Task.sleep(nanoseconds: UInt64(restoreDelay * 1_000_000_000))
                try restoreClipboardContents(savedContents, pasteboard: pasteboard)
            }
        } catch {
            // If insertion fails, attempt to restore clipboard immediately
            if let savedContents = savedClipboardContents {
                try? restoreClipboardContents(savedContents, pasteboard: pasteboard)
            }
            throw error
        }
    }

    /// Save current clipboard contents
    private func saveClipboardContents(_ pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType: Any]? {
        var contents: [NSPasteboard.PasteboardType: Any] = [:]

        if let string = pasteboard.string(forType: .string) {
            contents[.string] = string
        }

        if let rtf = pasteboard.string(forType: .rtf) {
            contents[.rtf] = rtf
        }

        if let html = pasteboard.string(forType: .html) {
            contents[.html] = html
        }

        if let image = pasteboard.data(forType: .tiff) {
            contents[.tiff] = image
        }

        return contents.isEmpty ? nil : contents
    }

    /// Restore clipboard contents
    private func restoreClipboardContents(
        _ contents: [NSPasteboard.PasteboardType: Any],
        pasteboard: NSPasteboard
    ) throws {
        pasteboard.clearContents()

        for (type, value) in contents {
            if let string = value as? String {
                pasteboard.setString(string, forType: type)
            } else if let data = value as? Data {
                pasteboard.setData(data, forType: type)
            }
        }
    }

    /// Write text to clipboard
    private func writeToClipboard(_ text: String, pasteboard: NSPasteboard) throws {
        pasteboard.clearContents()

        guard pasteboard.setString(text, forType: .string) else {
            throw TextInsertionError.clipboardWriteFailed(reason: "Failed to set string on pasteboard")
        }
    }

    /// Simulate Cmd+V keypress using CGEvent
    private func simulateCommandV() throws {
        // Check accessibility permissions
        guard AXIsProcessTrusted() else {
            throw TextInsertionError.accessibilityPermissionDenied
        }

        // Get the 'V' key code (0x09 in the standard US keyboard layout)
        let vKeyCode: CGKeyCode = 0x09

        // Create and post keyDown event
        guard let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: vKeyCode,
            keyDown: true
        ) else {
            throw TextInsertionError.pasteSimulationFailed(reason: "Failed to create keyDown event")
        }

        // Set Command modifier flag
        keyDownEvent.flags = .maskCommand

        // Create and post keyUp event
        guard let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: vKeyCode,
            keyDown: false
        ) else {
            throw TextInsertionError.pasteSimulationFailed(reason: "Failed to create keyUp event")
        }

        keyUpEvent.flags = .maskCommand

        // Post events to the system
        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
    }
    #endif
}

#if os(macOS)
import ApplicationServices
#endif
