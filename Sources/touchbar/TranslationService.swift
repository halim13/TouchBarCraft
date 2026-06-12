import Foundation

// MARK: - Supported Languages

public struct TranslationLanguage: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let nativeName: String

    public init(code: String, displayName: String, nativeName: String) {
        self.id = code
        self.displayName = displayName
        self.nativeName = nativeName
    }
}

public extension TranslationLanguage {
    static let supported: [TranslationLanguage] = [
        TranslationLanguage(code: "en", displayName: "English", nativeName: "English"),
        TranslationLanguage(code: "id", displayName: "Indonesian", nativeName: "Bahasa Indonesia"),
        TranslationLanguage(code: "ms", displayName: "Malay", nativeName: "Bahasa Melayu"),
        TranslationLanguage(code: "zh-CN", displayName: "Chinese (Simplified)", nativeName: "简体中文"),
        TranslationLanguage(code: "zh-TW", displayName: "Chinese (Traditional)", nativeName: "繁體中文"),
        TranslationLanguage(code: "ko", displayName: "Korean", nativeName: "한국어"),
        TranslationLanguage(code: "vi", displayName: "Vietnamese", nativeName: "Tiếng Việt"),
        TranslationLanguage(code: "th", displayName: "Thai", nativeName: "ไทย"),
        TranslationLanguage(code: "es", displayName: "Spanish", nativeName: "Español"),
        TranslationLanguage(code: "fr", displayName: "French", nativeName: "Français"),
        TranslationLanguage(code: "de", displayName: "German", nativeName: "Deutsch"),
        TranslationLanguage(code: "pt", displayName: "Portuguese", nativeName: "Português"),
        TranslationLanguage(code: "ru", displayName: "Russian", nativeName: "Русский"),
        TranslationLanguage(code: "ar", displayName: "Arabic", nativeName: "العربية"),
        TranslationLanguage(code: "hi", displayName: "Hindi", nativeName: "हिन्दी"),
        TranslationLanguage(code: "it", displayName: "Italian", nativeName: "Italiano"),
        TranslationLanguage(code: "nl", displayName: "Dutch", nativeName: "Nederlands"),
        TranslationLanguage(code: "ja", displayName: "Japanese (original)", nativeName: "日本語"),
    ]

    static func find(by code: String) -> TranslationLanguage {
        supported.first { $0.id == code } ?? supported.first { $0.id == "en" }!
    }

    static let `default` = supported.first { $0.id == "en" }!
}

// MARK: - Translation Error

public enum TranslationError: Error, LocalizedError {
    case encodingFailed
    case invalidURL
    case networkError(String)
    case parseError
    case allProvidersFailed
    case unsupportedLanguage
    case rateLimited
    case serviceUnavailable

    public var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode text for translation"
        case .invalidURL: return "Invalid translation service URL"
        case .networkError(let msg): return "Network error: \(msg)"
        case .parseError: return "Failed to parse translation response"
        case .allProvidersFailed: return "All translation providers failed"
        case .unsupportedLanguage: return "Language pair not supported"
        case .rateLimited: return "Translation rate limited. Please wait."
        case .serviceUnavailable: return "Translation service unavailable"
        }
    }
}

// MARK: - Translation Service

public actor TranslationService {
    public static let shared = TranslationService()

    private let session: URLSession
    private var cache: [String: String] = [:]
    private var lastRequestTime: Date = .distantPast
    private let minRequestInterval: TimeInterval = 0.5

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = ["User-Agent": "TouchBarCraft/1.0"]
        self.session = URLSession(configuration: config)
    }

    /// Translate text from Japanese to the target language.
    /// Strips furigana brackets before translating.
    public func translate(_ text: String, target: String) async throws -> String {
        guard target != "ja" else { return text }
        let plainText = stripFurigana(text)
        let trimmed = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }
        guard trimmed.count < 500 else {
            return try await translateLongText(trimmed, target: target)
        }

        let cacheKey = "ja:\(target):\(trimmed)"
        if let cached = cache[cacheKey] {
            return cached
        }

        try await rateLimit()

        // Try LibreTranslate first, fall back to MyMemory
        var lastError: Error?
        do {
            let translated = try await translateViaLibre(text: trimmed, target: target)
            cache[cacheKey] = translated
            return translated
        } catch {
            lastError = error
            print("TranslationService: LibreTranslate failed: \(error.localizedDescription)")
        }

        do {
            let translated = try await translateViaMyMemory(text: trimmed, target: target)
            cache[cacheKey] = translated
            return translated
        } catch {
            print("TranslationService: MyMemory failed: \(error.localizedDescription)")
            throw lastError ?? error
        }
    }

    /// Translate multiple texts in batch (sequential to respect rate limits)
    public func translateBatch(_ texts: [String], target: String) async throws -> [String] {
        var results: [String] = []
        for text in texts {
            let result = try await translate(text, target: target)
            results.append(result)
        }
        return results
    }

    // MARK: - Rate Limiting

    private func rateLimit() async throws {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRequestTime)
        if elapsed < minRequestInterval {
            try await Task.sleep(nanoseconds: UInt64((minRequestInterval - elapsed) * 1_000_000_000))
        }
        lastRequestTime = Date()
    }

    // MARK: - LibreTranslate

    private func translateViaLibre(text: String, target: String) async throws -> String {
        let url = URL(string: "https://libretranslate.de/translate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "q": text,
            "source": "ja",
            "target": target,
            "format": "text"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.networkError("No response")
        }

        switch httpResponse.statusCode {
        case 200: break
        case 429: throw TranslationError.networkError("Rate limited by LibreTranslate")
        case 400:
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = json["error"] as? String {
                throw TranslationError.networkError(err)
            }
            throw TranslationError.networkError("Bad request")
        case 403: throw TranslationError.networkError("LibreTranslate access denied")
        default: throw TranslationError.networkError("LibreTranslate HTTP \(httpResponse.statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let translatedText = json["translatedText"] as? String else {
            throw TranslationError.parseError
        }

        return translatedText
    }

    // MARK: - MyMemory API (fallback)

    private func translateViaMyMemory(text: String, target: String) async throws -> String {
        var components = URLComponents(string: "https://api.mymemory.translated.net/get")!
        components.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "langpair", value: "ja|\(target)")
        ]

        guard let url = components.url else {
            throw TranslationError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.networkError("No response")
        }

        switch httpResponse.statusCode {
        case 200: break
        case 429: throw TranslationError.rateLimited
        case 503: throw TranslationError.serviceUnavailable
        default: throw TranslationError.networkError("MyMemory HTTP \(httpResponse.statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseData = json["responseData"] as? [String: Any],
              let translatedText = responseData["translatedText"] as? String else {
            throw TranslationError.parseError
        }

        return translatedText
    }

    // MARK: - Long Text Handling

    private func translateLongText(_ text: String, target: String) async throws -> String {
        let sentences = splitSentences(text)
        var translatedParts: [String] = []
        for sentence in sentences {
            let part = try await translate(sentence, target: target)
            translatedParts.append(part)
        }
        return translatedParts.joined(separator: " ")
    }

    private func splitSentences(_ text: String) -> [String] {
        let separators = CharacterSet(charactersIn: "。！？.!?\n\r")
        var sentences: [String] = []
        var current = ""
        for char in text {
            current.append(char)
            if char.unicodeScalars.allSatisfy({ separators.contains($0) }) {
                let s = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty { sentences.append(s) }
                current = ""
            }
        }
        let remaining = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty { sentences.append(remaining) }
        if sentences.isEmpty { return [text] }
        return sentences
    }

    // MARK: - Furigana Stripping

    private func stripFurigana(_ text: String) -> String {
        var result = ""
        var remaining = text[...]
        while !remaining.isEmpty {
            if let open = remaining.firstIndex(of: "["),
               let close = remaining[open...].firstIndex(of: "]"),
               open > remaining.startIndex {
                result += remaining[..<open]
                remaining = remaining[remaining.index(after: close)...]
            } else {
                result += remaining
                break
            }
        }
        return result
    }

    // MARK: - Cache Management

    public func clearCache() {
        cache.removeAll()
    }
}
