import AVFoundation

/// Records microphone input to a temporary 16-bit PCM WAV file while running.
/// AVAudioEngine taps the input node; AVAudioFile converts the float buffers
/// to 16-bit on write.
final class AudioRecorder {
    private var engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var fileURL: URL?
    private var activity: NSObjectProtocol?

    func start() throws {
        // Build a fresh engine each time so it binds to the *current* input
        // device/format. A long-lived engine goes stale across sleep/wake (lid
        // close) and audio route changes, and then captures only silence.
        engine = AVAudioEngine()

        // Keep the app out of App Nap while recording. With the lid closed or the
        // window occluded, macOS otherwise throttles us and the audio tap stops
        // firing after a moment — capturing only the first word or two.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Recording microphone audio"
        )

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0) // hardware float format

        // A 0 Hz / 0-channel format means no usable input device is available;
        // recording it would just produce a silent file.
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw NSError(domain: "AudioRecorder", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "No usable audio input (format \(format.sampleRate)Hz, \(format.channelCount)ch)"
            ])
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("dictation-\(UUID().uuidString).wav")
        fileURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        file = try AVAudioFile(forWriting: url, settings: settings)

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            try? self?.file?.write(from: buffer)
        }

        engine.prepare()
        try engine.start()
    }

    /// Stops recording and returns the finished file (or nil if nothing recorded).
    func stop() -> URL? {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil // closing the AVAudioFile finalizes the WAV header

        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
            self.activity = nil
        }
        return fileURL
    }
}
