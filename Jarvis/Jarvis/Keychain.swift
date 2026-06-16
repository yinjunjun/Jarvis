import Foundation
import Security

/// Minimal wrapper around a single generic-password Keychain item that holds the
/// OpenAI API key. Keeps the key off disk / out of the repo entirely.
enum Keychain {
    private static let service = "Jarvis"
    private static let account = "OPENAI_API_KEY"

    static func setOpenAIKey(_ key: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary) // replace any existing value

        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return } // empty = remove

        var add = base
        add[kSecValueData as String] = Data(trimmed.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    static func openAIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else { return nil }
        return key
    }
}

/// Single source of truth for the API key. Prefers the OPENAI_API_KEY environment
/// variable (handy when running from Xcode), otherwise reads the Keychain.
enum APIKey {
    static var openAI: String {
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !env.isEmpty {
            return env
        }
        return Keychain.openAIKey() ?? ""
    }

    static var isConfigured: Bool { !openAI.isEmpty }
}
