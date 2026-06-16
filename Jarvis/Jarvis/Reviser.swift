import Foundation

enum RevisionError: Error { case missingKey, badResponse(Int), empty }

/// Sends transcribed text to an LLM and returns a cleaned-up, polished version
/// (fixes grammar / filler / punctuation while preserving meaning and tone).
///
/// Uses OpenAI's Chat Completions API so it can reuse the same OPENAI_API_KEY as
/// the Transcriber. To use Claude instead, point `endpoint` at
/// https://api.anthropic.com/v1/messages, send the Anthropic headers
/// (x-api-key / anthropic-version), and decode the `content` array.
final class Reviser {

    private let model = "gpt-4o-mini"

    private let systemPrompt = """
    You are an editor. Rewrite the user's dictated text so it reads clearly and \
    professionally: fix grammar, punctuation, and remove filler words and false \
    starts, while preserving the original meaning, tone, and intent. Do not add \
    new information or commentary. Return only the revised text.
    """

    func revise(_ text: String) async throws -> String {
        let apiKey = APIKey.openAI
        guard !apiKey.isEmpty else { throw RevisionError.missingKey }

        let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Message: Encodable { let role: String; let content: String }
        struct Payload: Encodable {
            let model: String
            let messages: [Message]
            let temperature: Double
        }
        request.httpBody = try JSONEncoder().encode(Payload(
            model: model,
            messages: [
                Message(role: "system", content: systemPrompt),
                Message(role: "user", content: text)
            ],
            temperature: 0.3
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw RevisionError.badResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        struct Result: Decodable {
            struct Choice: Decodable {
                struct Msg: Decodable { let content: String }
                let message: Msg
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(Result.self, from: data)
        guard let content = decoded.choices.first?.message.content,
              !content.isEmpty else { throw RevisionError.empty }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
