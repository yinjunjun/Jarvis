import Foundation
import AVFoundation
import Combine

/// View model for the main window. Toggles recording, transcribes the result
/// into `transcribedText`, then polishes it into `revisedText` on demand.
@MainActor
final class DictationController: ObservableObject {
    @Published var transcribedText = ""
    @Published var revisedText = ""
    @Published var isRecording = false
    @Published var isRevising = false
    @Published var statusText = "Ready"

    private let recorder = AudioRecorder()
    private let transcriber = Transcriber()
    private let reviser = Reviser()

    /// Press once to start, press again to stop (and transcribe). Recording only
    /// begins once microphone access is actually granted — otherwise macOS feeds
    /// us a silent stream and the transcript comes back empty.
    func toggleRecording() {
        if isRecording { stopAndTranscribe(); return }

        switch Permissions.microphoneStatus() {
        case .authorized:
            startRecording()
        case .notDetermined:
            statusText = "Requesting microphone…"
            Task {
                if await Permissions.requestMicrophone() {
                    startRecording()
                } else {
                    statusText = "Microphone access denied"
                }
            }
        default: // .denied / .restricted
            statusText = "Microphone denied — enable it in System Settings"
            Permissions.openMicrophoneSettings()
        }
    }

    private func startRecording() {
        guard !isRecording else { return }
        do {
            try recorder.start()
            isRecording = true
            statusText = "Listening…"
        } catch {
            statusText = "Mic error"
            NSLog("recorder.start failed: \(error)")
        }
    }

    private func stopAndTranscribe() {
        guard isRecording else { return }
        isRecording = false
        statusText = "Transcribing…"

        guard let fileURL = recorder.stop() else {
            statusText = "No audio captured"
            return
        }

        guard APIKey.isConfigured else {
            statusText = "Add your OpenAI API key (🔑 button)"
            try? FileManager.default.removeItem(at: fileURL)
            return
        }

        Task {
            do {
                transcribedText = try await transcriber.transcribe(fileURL: fileURL)
                statusText = "Ready"
            } catch {
                statusText = "Transcription failed"
                NSLog("transcribe failed: \(error)")
            }
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Polish the (possibly hand-edited) transcript into the right-hand box.
    func revise() {
        let source = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, !isRevising else { return }
        guard APIKey.isConfigured else {
            statusText = "Add your OpenAI API key (🔑 button)"
            return
        }
        isRevising = true
        statusText = "Revising…"
        Task {
            do {
                revisedText = try await reviser.revise(source)
                statusText = "Ready"
            } catch {
                statusText = "Revision failed"
                NSLog("revise failed: \(error)")
            }
            isRevising = false
        }
    }
}
