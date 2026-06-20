import Foundation

// MARK: - AnkiConnect Data Models

public struct AnkiCard: Sendable {
    public let cardId: Int
    public let question: String
    public let answer: String
    public let deckName: String
    public let buttonCount: Int  // number of answer buttons (typically 2-4)
    public let audioText: String
    public let touchBarAudioText: String
    public let fields: [String: String]  // all field values keyed by field name
    public let cardType: Int  // 0=new, 1=learning, 2=review, -1=unknown
    public let buttonLabels: [Int: String]  // ease -> formatted label from Anki (e.g. "35m", "3.5mo")

    /// Human-readable label for the card type.
    public var cardTypeLabel: String {
        switch cardType {
        case 0: return "N"
        case 1: return "L"
        case 2: return "R"
        case 3: return "Relearn"
        default: return ""
        }
    }

    /// Hex color for the card type: New=blue, Learn=orange, Review=green, Relearn=purple.
    public var cardTypeColorHex: String {
        switch cardType {
        case 0: return "#007AFF"
        case 1: return "#FF9500"
        case 2: return "#34C759"
        case 3: return "#AF52DE"
        default: return "#FFFFFF"
        }
    }

    public var soundFilename: String? {
        extractFilename(from: audioText)
    }
    
    public var touchBarSoundFilename: String? {
        extractFilename(from: touchBarAudioText)
    }
    
    private func extractFilename(from text: String) -> String? {
        if text.isEmpty { return nil }
        if let range = text.range(of: "\\[sound:([^\\]]+)\\]", options: .regularExpression) {
            let tag = text[range]
            return tag.replacingOccurrences(of: "[sound:", with: "")
                      .replacingOccurrences(of: "]", with: "")
                      .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = text.range(of: "src=\"([^\"]+)\"", options: .regularExpression) {
            let matched = text[range]
            return matched.replacingOccurrences(of: "src=\"", with: "")
                          .replacingOccurrences(of: "\"", with: "")
                          .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
    public func getCurrentCard(questionField: String = "Front", answerField: String = "Back", audioField: String = "Audio", touchBarAudioField: String = "Audio") async -> AnkiCard? {
        do {
            guard let result = try await request(action: "guiCurrentCard") as? [String: Any] else {
                return nil
            }
            
            let cardId = result["cardId"] as? Int ?? 0
            let deckName = result["deckName"] as? String ?? ""
            let buttonCount = result["buttons"] as? Int ??
                              (result["buttons"] as? [Any])?.count ?? 4
            let cardType = result["type"] as? Int ?? -1
            
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
            
            // Extract custom audio field for play/stop button
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
            
            // Extract custom audio field for Touch Bar text tap
            var touchBarAudioText = ""
            if !touchBarAudioField.isEmpty, let val = fieldsDict[touchBarAudioField]?["value"] as? String {
                touchBarAudioText = val
            }
            if touchBarAudioText.isEmpty {
                for (_, fieldDict) in fieldsDict {
                    if let val = fieldDict["value"] as? String, val.contains("[sound:") {
                        touchBarAudioText = val
                        break
                    }
                }
            }
            
            // Build a dictionary of all field values
            var allFields: [String: String] = [:]
            for (name, fieldDict) in fieldsDict {
                if let value = fieldDict["value"] as? String {
                    allFields[name] = value
                }
            }
            
            // Parse nextReviews + buttons to build button label map
            var buttonLabels: [Int: String] = [:]
            let nextReviews = result["nextReviews"] as? [String] ?? []
            let buttons: [Int] = {
                if let raw = result["buttons"] as? [Int] { return raw }
                if let count = result["buttons"] as? Int { return Array(1...count) }
                return []
            }()
            if !nextReviews.isEmpty {
                let clean: (String) -> String = { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\u{2068}\u{2069}")) }
                for i in 0..<nextReviews.count {
                    buttonLabels[i + 1] = clean(nextReviews[i])
                }
            }

            // If cardType is unknown, try cardsInfo fallback (more reliable)
            var resolvedType = cardType
            if resolvedType < 0 && cardId > 0 {
                resolvedType = await getCardType(cardId: cardId)
            }

            return AnkiCard(
                cardId: cardId,
                question: questionText,
                answer: answerText,
                deckName: deckName,
                buttonCount: buttonCount,
                audioText: audioText,
                touchBarAudioText: touchBarAudioText,
                fields: allFields,
                cardType: resolvedType,
                buttonLabels: buttonLabels
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
    
    /// Get card type by card ID using cardsInfo API (more reliable fallback)
    public func getCardType(cardId: Int) async -> Int {
        guard cardId > 0 else { return -1 }
        do {
            guard let result = try await request(action: "cardsInfo", params: ["cards": [cardId]]) as? [[String: Any]],
                  let firstCard = result.first else {
                return -1
            }
            // Try queue first (more accurate for current state), fall back to type
            if let queue = firstCard["queue"] as? Int {
                return queue
            }
            if let type = firstCard["type"] as? Int {
                return type
            }
            return -1
        } catch {
            print("AnkiConnect: Failed to get card type for '\(cardId)': \(error)")
            return -1
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
    
    /// Get button label strings directly from Anki's nextReviews field.
    /// Returns ease → formatted label (e.g. 1→"35m", 3→"3.5mo"), or empty if unavailable.
    public func getButtonLabels() async -> [Int: String] {
        guard let cardResult = try? await request(action: "guiCurrentCard") as? [String: Any] else { return [:] }
        let nextReviews = cardResult["nextReviews"] as? [String] ?? []
        let buttons: [Int] = {
            if let raw = cardResult["buttons"] as? [Int] { return raw }
            if let count = cardResult["buttons"] as? Int { return Array(1...count) }
            return []
        }()
        guard !nextReviews.isEmpty else { return [:] }
        var labels: [Int: String] = [:]
        let clean: (String) -> String = { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\u{2068}\u{2069}")) }
        for i in 0..<nextReviews.count {
            labels[i + 1] = clean(nextReviews[i])
        }
        return labels
    }

    /// Get scheduling states (intervals) for each rating button.
    /// Falls back to computing approximate intervals from cardsInfo if unavailable.
    public func getSchedulingStates() async -> [Int: Int] {
        if let rawResult = try? await request(action: "getSchedulingStates") {
            // Direct dict: { "1": {"interval": X, ...}, ... }
            if let result = rawResult as? [String: [String: Any]] {
                var intervals: [Int: Int] = [:]
                for (key, value) in result {
                    guard let ease = Int(key) else { continue }
                    if let secs = value["scheduled_seconds"] as? Int {
                        intervals[ease] = secs
                    } else if let secs = value["scheduled_seconds"] as? Double {
                        intervals[ease] = Int(secs)
                    } else if let interval = value["interval"] as? Int {
                        intervals[ease] = interval
                    } else if let interval = value["interval"] as? Double {
                        intervals[ease] = Int(interval)
                    }
                }
                if !intervals.isEmpty { return intervals }
            }
            // Dict of arrays: { "1": [interval, due], ... }
            if let dictArrayResult = rawResult as? [String: [Any]] {
                var intervals: [Int: Int] = [:]
                for (key, value) in dictArrayResult {
                    guard let ease = Int(key), value.count >= 1, let interval = value[0] as? Int else { continue }
                    intervals[ease] = interval
                }
                if !intervals.isEmpty { return intervals }
            }
            // Array: [[1, interval, due], ...]
            if let arrayResult = rawResult as? [[Any]] {
                var intervals: [Int: Int] = [:]
                for item in arrayResult {
                    if item.count >= 2, let ease = item[0] as? Int, let interval = item[1] as? Int {
                        intervals[ease] = interval
                    }
                }
                if !intervals.isEmpty { return intervals }
            }
        }
        return await computeApproximateIntervals()
    }

    /// Compute approximate button intervals from cardsInfo data.
    /// Used when getSchedulingStates is not available in AnkiConnect.
    private func computeApproximateIntervals() async -> [Int: Int] {
        do {
            guard let cardResult = try await request(action: "guiCurrentCard") as? [String: Any],
                  let cardId = cardResult["cardId"] as? Int,
                  cardId > 0,
                  let info = try await request(action: "cardsInfo", params: ["cards": [cardId]]) as? [[String: Any]],
                  let cardData = info.first else {
                return [:]
            }

            let cardType = cardData["type"] as? Int ?? -1
            let queue = cardData["queue"] as? Int ?? -1
            let ivl = cardData["ivl"] as? Int ?? 0       // interval in days (review cards)
            let factor = cardData["factor"] as? Int ?? 0  // ease factor (2500 = 2.5x)
            let reps = cardData["reps"] as? Int ?? 0

            var intervals: [Int: Int] = [:]

            if cardType == 2 || queue == 2 {
                // Review card
                let easeFactor = Double(factor > 0 ? max(1300, factor) : 2500) / 1000.0
                let hardFactor = 1.2
                let easyBonus = 1.3
                let maxIvl = 36500  // 100 years in days

                // Again: goes to learning (typically 1 minute)
                intervals[1] = 60
                // Hard: max(ivl * hardFactor, 1) days in seconds
                let hardDays = max(1, min(maxIvl, Int(Double(ivl) * hardFactor)))
                intervals[2] = hardDays * 86400
                // Good: ivl * easeFactor in seconds
                let goodDays = max(1, min(maxIvl, Int(Double(ivl) * easeFactor)))
                intervals[3] = goodDays * 86400
                // Easy: good * easyBonus in seconds
                let easyDays = max(1, min(maxIvl, Int(Double(goodDays) * easyBonus)))
                intervals[4] = easyDays * 86400
            } else if cardType == 1 || queue == 1 || queue == 3 {
                // Learning card
                intervals[1] = 60     // 1 minute
                intervals[2] = 600    // 10 minutes
                intervals[3] = 1440   // 24 minutes
                intervals[4] = 86400  // 1 day
            } else if cardType == 0 || queue == 0 {
                // New card — estimate learning steps from reps
                if reps == 0 {
                    intervals[1] = 60    // 1 minute
                    intervals[2] = 600   // 10 minutes
                    intervals[3] = 1440  // 24 minutes
                    intervals[4] = 86400 // 1 day
                } else {
                    intervals[1] = 60
                    intervals[2] = 600
                    intervals[3] = 86400   // 1 day
                    intervals[4] = 259200  // 3 days
                }
            }

            return intervals
        } catch {
            print("AnkiConnect: cardsInfo fallback failed: \(error)")
            return [:]
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
