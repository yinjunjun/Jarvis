import AppKit
import Carbon.HIToolbox // kVK_ANSI_V

/// Drops text into whatever app/field is currently focused.
/// Method: stash the clipboard, set our text, synthesize ⌘V, restore clipboard.
/// This is the only approach that works reliably everywhere, including web
/// text fields in browsers (Claude / ChatGPT in Safari, etc.).
enum TextInserter {
    static func insert(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string) // may be nil

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        synthesizePaste()

        // Restore the user's previous clipboard once the paste lands.
        if let saved {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                pasteboard.clearContents()
                pasteboard.setString(saved, forType: .string)
            }
        }
    }

    private static func synthesizePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let v = CGKeyCode(kVK_ANSI_V)

        let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        up?.flags = .maskCommand

        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
