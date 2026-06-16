import Foundation

enum TranscriptionError: Error { case missingKey, badResponse(Int) }

/// Sends the recorded WAV to OpenAI's transcription endpoint and returns text.
/// Batch (not streaming) — perfect for press-and-hold dictation.
final class Transcriber {

    // "gpt-4o-transcribe" is the higher-accuracy option; "whisper-1" also works.
    // Check OpenAI's docs for the current model names before shipping.
    private let model = "gpt-4o-transcribe"

    func transcribe(fileURL: URL) async throws -> String {
        let apiKey = APIKey.openAI
        guard !apiKey.isEmpty else { throw TranscriptionError.missingKey }

        let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")

        var body = Data()
        func field(_ s: String) { body.append(s.data(using: .utf8)!) }

        field("--\(boundary)\r\n")
        field("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        field("\(model)\r\n")

        let audio = try Data(contentsOf: fileURL)
        field("--\(boundary)\r\n")
        field("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
        field("Content-Type: audio/wav\r\n\r\n")
        body.append(audio)
        field("\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw TranscriptionError.badResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        struct Result: Decodable { let text: String }
        return try JSONDecoder().decode(Result.self, from: data).text
    }
}
