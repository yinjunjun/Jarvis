import SwiftUI
import KeyboardShortcuts

// The global shortcut the user holds to talk (push-to-talk).
extension KeyboardShortcuts.Name {
    static let dictate = Self("dictate")
}

@main
struct VoiceTypingApp: App {
    @StateObject private var controller = DictationController()

    init() {
        // Give it a sensible default the first time (⌥-Space). The user can
        // rebind it from the menu.
        if KeyboardShortcuts.getShortcut(for: .dictate) == nil {
            KeyboardShortcuts.setShortcut(.init(.space, modifiers: [.option]), for: .dictate)
        }
    }

    var body: some Scene {
        MenuBarExtra("VoiceTyping", systemImage: controller.isRecording ? "mic.fill" : "mic") {
            Text(controller.statusText)
                .font(.caption)

            Divider()

            // Lets the user pick which key to hold while dictating.
            KeyboardShortcuts.Recorder("Hold to talk:", name: .dictate)

            Divider()

            Button("Quit VoiceTyping") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
