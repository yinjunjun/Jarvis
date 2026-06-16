import AVFoundation
import AppKit

enum Permissions {
    static func microphoneStatus() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }

    /// Triggers the microphone prompt (needs NSMicrophoneUsageDescription in Info.plist).
    @discardableResult
    static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }

    /// Opens System Settings ▸ Privacy & Security ▸ Microphone so the user can
    /// grant access after a previous denial (macOS won't prompt a second time).
    static func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
