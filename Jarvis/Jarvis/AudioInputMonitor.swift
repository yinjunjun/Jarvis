import SwiftUI
import Combine
import CoreAudio
import IOKit

/// Watches the current default audio input device so the UI can show which mic
/// is live and warn when the built-in mic is selected but the lid is closed
/// (clamshell), where macOS disables it and recording would capture nothing.
@MainActor
final class AudioInputMonitor: ObservableObject {
    @Published var deviceName = "—"
    /// Built-in mic is the active input but the lid is closed → it won't work.
    @Published var builtInUnavailable = false

    private var timer: Timer?

    func start() {
        refresh()
        // The default input device and the lid state can both change while the
        // window is open; poll cheaply so the readout/warning stay current.
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard let id = Self.defaultInputDeviceID() else {
            deviceName = "No input device"
            builtInUnavailable = false
            return
        }
        deviceName = Self.deviceName(id) ?? "Unknown"
        let isBuiltIn = Self.transportType(id) == kAudioDeviceTransportTypeBuiltIn
        builtInUnavailable = isBuiltIn && Self.isLidClosed()
    }

    // MARK: - CoreAudio

    private static func defaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)
        return status == noErr && deviceID != 0 ? deviceID : nil
    }

    private static func deviceName(_ id: AudioDeviceID) -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var cfName: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &cfName) {
            AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0)
        }
        return status == noErr ? cfName as String? : nil
    }

    private static func transportType(_ id: AudioDeviceID) -> UInt32? {
        var transport = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &transport)
        return status == noErr ? transport : nil
    }

    // MARK: - Lid state

    /// True when the laptop lid is shut (clamshell). Desktops report no clamshell
    /// state and return false.
    private static func isLidClosed() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        guard let prop = IORegistryEntryCreateCFProperty(
            service, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0) else { return false }
        return (prop.takeRetainedValue() as? Bool) ?? false
    }
}
