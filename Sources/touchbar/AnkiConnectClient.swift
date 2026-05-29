import Foundation

// MARK: - AnkiConnect Data Models

public struct AnkiCard: Sendable {
    public let cardId: Int
    public let question: String
    public let answer: String
    public let deckName: String
    public let buttonCount: Int  // number of answer buttons (typically 2-4)
    public let audioText: String

    public var soundFilename: String? {
        if audioText.isEmpty { return nil }
        if let range = audioText.range(of: "\\[sound:([^\\]]+)\\]", options: .regularExpression) {
            let tag = audioText[range]
            return tag.replacingOccurrences(of: "[sound:", with: "")
                      .replacingOccurrences(of: "]", with: "")
                      .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = audioText.range(of: "src=\"([^\"]+)\"", options: .regularExpression) {
            let matched = audioText[range]
            return matched.replacingOccurrences(of: "src=\"", with: "")
                          .replacingOccurrences(of: "\"", with: "")
                          .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let trimmed = audioText.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        if lower.hasSuffix(".mp3") || lower.hasSuffix(".wav") || lower.hasSuffix(".m4a") || lower.hasSuffix(".ogg") {
            return trimmed
        }
        return nil
    }
}

public struct AnkiDeckStats: Sendable {
    public let newCount: Int
    public let learnCount: Int
    public let reviewCount: Int
}

// MARK: - AnkiConnect Client

public actor AnkiConnectClient {
    public static let shared = AnkiConnectClient()
    
    private let baseURL = URL(string: "http://127.0.0.1:8765")!
    private let apiVersion = 6
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Core API Call
    
    private func request(action: String, params: [String: Any]? = nil) async throws -> Any? {
        var body: [String: Any] = [
            "action": action,
            "version": apiVersion
        ]
        if let params = params {
            body["params"] = params
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        var urlRequest = URLRequest(url: baseURL)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = jsonData
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, _) = try await session.data(for: urlRequest)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AnkiError.invalidResponse
        }
        
        if let error = json["error"] as? String {
            throw AnkiError.apiError(error)
        }
        
        return json["result"]
    }
    
    // MARK: - Public API Methods
    
    /// Check if AnkiConnect is reachable
    public func isConnected() async -> Bool {
        do {
            let result = try await request(action: "version")
            return result != nil
        } catch {
            return false
        }
    }
    
    /// Get list of all deck names
    public func getDeckNames() async -> [String] {
        do {
            let result = try await request(action: "deckNames")
            return (result as? [String]) ?? []
        } catch {
            print("AnkiConnect: Failed to get deck names: \(error)")
            return []
        }
    }
    
    /// Open a deck for review in Anki GUI
    public func startDeckReview(name: String) async -> Bool {
        do {
            let result = try await request(action: "guiDeckReview", params: ["name": name])
            return (result as? Bool) ?? (result != nil)
        } catch {
            print("AnkiConnect: Failed to start review for '\(name)': \(error)")
            return false
        }
    }
    
    /// Get the current card being reviewed
    public func getCurrentCard(questionField: String = "Front", answerField: String = "Back", audioField: String = "Audio") async -> AnkiCard? {
        do {
            guard let result = try await request(action: "guiCurrentCard") as? [String: Any] else {
                return nil
            }
            
            let cardId = result["cardId"] as? Int ?? 0
            let deckName = result["deckName"] as? String ?? ""
            let buttonCount = result["buttons"] as? Int ??
                              (result["buttons"] as? [Any])?.count ?? 4
            
            // Extract question and answer fields, strip HTML
            let fieldsDict = result["fields"] as? [String: [String: Any]] ?? [:]
            var questionText = ""
            var answerText = ""
            
            // Try custom user-defined fields first (supports comma-separated fields, e.g. "Word, Furigana")
            let qFields = questionField.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            var qValues: [String] = []
            for field in qFields {
                if let val = fieldsDict[field]?["value"] as? String {
                    let stripped = stripHTML(val)
                    if !stripped.isEmpty {
                        qValues.append(stripped)
                    }
                }
            }
            if !qValues.isEmpty {
                questionText = qValues.joined(separator: " / ")
            }
            
            let aFields = answerField.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            var aValues: [String] = []
            for field in aFields {
                if let val = fieldsDict[field]?["value"] as? String {
                    let stripped = stripHTML(val)
                    if !stripped.isEmpty {
                        aValues.append(stripped)
                    }
                }
            }
            if !aValues.isEmpty {
                answerText = aValues.joined(separator: " / ")
            }
            
            // Fallback: Try common field names if empty
            if questionText.isEmpty {
                if let frontField = fieldsDict["Front"]?["value"] as? String {
                    questionText = stripHTML(frontField)
                } else if let firstField = fieldsDict.values.first?["value"] as? String {
                    questionText = stripHTML(firstField)
                }
            }
            
            if answerText.isEmpty {
                if let backField = fieldsDict["Back"]?["value"] as? String {
                    answerText = stripHTML(backField)
                } else if fieldsDict.count > 1 {
                    let values = Array(fieldsDict.values)
                    if let secondField = values[1]["value"] as? String {
                        answerText = stripHTML(secondField)
                    }
                }
            }
            
            // Fallback: use question/answer from modelName if fields are still empty
            if questionText.isEmpty {
                questionText = result["question"] as? String ?? "Card"
                questionText = stripHTML(questionText)
            }
            if answerText.isEmpty {
                answerText = result["answer"] as? String ?? "Answer"
                answerText = stripHTML(answerText)
            }
            
            // Extract custom audio field or search all fields for a [sound:] tag
            var audioText = ""
            if !audioField.isEmpty, let val = fieldsDict[audioField]?["value"] as? String {
                audioText = val
            }
            if audioText.isEmpty {
                for (_, fieldDict) in fieldsDict {
                    if let val = fieldDict["value"] as? String, val.contains("[sound:") {
                        audioText = val
                        break
                    }
                }
            }
            
            return AnkiCard(
                cardId: cardId,
                question: truncateForTouchBar(questionText),
                answer: truncateForTouchBar(answerText),
                deckName: deckName,
                buttonCount: buttonCount,
                audioText: audioText
            )
        } catch {
            print("AnkiConnect: Failed to get current card: \(error)")
            return nil
        }
    }
    
    /// Show answer for current card in Anki GUI
    public func showAnswer() async -> Bool {
        do {
            let result = try await request(action: "guiShowAnswer")
            return (result as? Bool) ?? true
        } catch {
            print("AnkiConnect: Failed to show answer: \(error)")
            return false
        }
    }
    
    /// Answer the current card with given ease (1=Again, 2=Hard, 3=Good, 4=Easy)
    public func answerCard(ease: Int) async -> Bool {
        do {
            let result = try await request(action: "guiAnswerCard", params: ["ease": ease])
            return (result as? Bool) ?? true
        } catch {
            print("AnkiConnect: Failed to answer card: \(error)")
            return false
        }
    }
    
    /// Trigger sync in Anki
    public func sync() async -> Bool {
        do {
            _ = try await request(action: "sync")
            return true
        } catch {
            print("AnkiConnect: Failed to sync: \(error)")
            return false
        }
    }
    
    /// Start the card timer (for accurate review time tracking)
    public func startCardTimer() async {
        do {
            _ = try await request(action: "guiStartCardTimer")
        } catch {
            // Non-critical, silently ignore
        }
    }
    
    /// Retrieve a media file by name from AnkiConnect
    public func retrieveMediaFile(filename: String) async -> Data? {
        do {
            guard let result = try await request(action: "retrieveMediaFile", params: ["filename": filename]) as? String else {
                return nil
            }
            return Data(base64Encoded: result)
        } catch {
            print("AnkiConnect: Failed to retrieve media file '\(filename)': \(error)")
            return nil
        }
    }
    
    /// Get the statistics (new, learn, review counts) for a deck
    public func getDeckStats(name: String) async -> AnkiDeckStats? {
        do {
            guard let result = try await request(action: "getDeckStats", params: ["decks": [name]]) as? [String: [String: Any]] else {
                return nil
            }
            if let statsDict = result.values.first(where: { ($0["name"] as? String) == name }) ?? result.values.first {
                let newCount = statsDict["new_count"] as? Int ?? 0
                let learnCount = statsDict["learn_count"] as? Int ?? 0
                let reviewCount = statsDict["review_count"] as? Int ?? 0
                return AnkiDeckStats(newCount: newCount, learnCount: learnCount, reviewCount: reviewCount)
            }
            return nil
        } catch {
            print("AnkiConnect: Failed to get deck stats for '\(name)': \(error)")
            return nil
        }
    }
    
    // MARK: - Helpers
    
    private func stripHTML(_ html: String) -> String {
        var text = html
        // Remove <br>, <br/>, <br /> as spaces first
        text = text.replacingOccurrences(of: "<br\\s*/?>", with: " ", options: .regularExpression)
        // Remove all HTML tags EXCEPT b, strong, i, em, u
        text = text.replacingOccurrences(of: "<(?!/?(b|strong|i|em|u)\\b)[^>]+>", with: "", options: .regularExpression)
        // Decode common HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        // Collapse whitespace
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Truncate text to fit Touch Bar (~55 chars max visible)
    private func truncateForTouchBar(_ text: String, maxLength: Int = 55) -> String {
        if text.count <= maxLength { return text }
        return String(text.prefix(maxLength - 1)) + "…"
    }
}

// MARK: - Errors

public enum AnkiError: Error, LocalizedError {
    case invalidResponse
    case apiError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from AnkiConnect"
        case .apiError(let msg): return "AnkiConnect: \(msg)"
        }
    }
}
