import Foundation

// MARK: - Models

public struct NHKNewsArticle: Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let titleFuri: String
    public let description: String
    public let descriptionFuri: String
    public let url: URL
    public let imageURL: URL?
    public let audioURL: URL?
    public let publishDate: Date
    public var contentChunks: [String]

    public init(id: String, title: String, titleFuri: String = "", description: String = "", descriptionFuri: String = "", url: URL, imageURL: URL? = nil, audioURL: URL? = nil, publishDate: Date, contentChunks: [String] = []) {
        self.id = id
        self.title = title
        self.titleFuri = titleFuri
        self.description = description
        self.descriptionFuri = descriptionFuri
        self.url = url
        self.imageURL = imageURL
        self.audioURL = audioURL
        self.publishDate = publishDate
        self.contentChunks = contentChunks
    }
}

public enum NHKNewsError: Error, LocalizedError {
    case networkError(String)
    case parseError(String)
    case invalidURL

    public var errorDescription: String? {
        switch self {
        case .networkError(let msg): return "Network: \(msg)"
        case .parseError(let msg): return "Parse: \(msg)"
        case .invalidURL: return "Invalid URL"
        }
    }
}

// MARK: - Serverless API (via nhkeasier.com RSS)

public actor NHKEasyNewsAPI {
    public static let shared = NHKEasyNewsAPI()

    private let session: URLSession
    private let feedURL = URL(string: "https://nhkeasier.com/feed/")!

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = [
            "User-Agent": "TouchBarCraft/1.0"
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - Article List

    public func fetchArticleList() async throws -> [NHKNewsArticle] {
        let (data, response) = try await session.data(from: feedURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NHKNewsError.networkError("Failed to fetch RSS feed")
        }

        let parser = RSSParser(data: data)
        return parser.items
    }

    // MARK: - Content (from pre-parsed RSS)

    nonisolated func fetchFullContent(url: URL) async throws -> String {
        // Content is already loaded from RSS feed.
        // We return the URL so the caller can look up the cached article.
        // This method exists for compatibility with the existing flow.
        throw NHKNewsError.parseError("Use RSS article data directly")
    }
}

// MARK: - RSS Parser

private class RSSParser: NSObject, XMLParserDelegate {
    private(set) var items: [NHKNewsArticle] = []

    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentDescription = ""
    private var currentPubDate = ""
    private var currentGUID = ""
    private var currentEnclosureURL = ""
    private var inItem = false
    private var inDescription = false

    init(data: Data) {
        super.init()
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "item" {
            inItem = true
            resetCurrent()
        }
        if elementName == "description" && inItem {
            inDescription = true
        }
        if elementName == "enclosure" && inItem {
            currentEnclosureURL = attributeDict["url"] ?? ""
        }
        currentElement = elementName
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inItem {
            switch currentElement {
            case "title": currentTitle += string
            case "link": currentLink += string
            case "description" where inDescription: currentDescription += string
            case "pubDate": currentPubDate += string
            case "guid": currentGUID += string
            default: break
            }
        }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard inItem, let string = String(data: CDATABlock, encoding: .utf8) else { return }
        if currentElement == "description" && inDescription {
            currentDescription += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" && inItem {
            finalizeItem()
            inItem = false
        }
        if elementName == "description" {
            inDescription = false
        }
        currentElement = ""
    }

    private func resetCurrent() {
        currentTitle = ""
        currentLink = ""
        currentDescription = ""
        currentPubDate = ""
        currentGUID = ""
        currentEnclosureURL = ""
    }

    private func finalizeItem() {
        let title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
        let descHTML = currentDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let pubDateStr = currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines)
        let guid = currentGUID.trimmingCharacters(in: .whitespacesAndNewlines)
        let audioURL = currentEnclosureURL.isEmpty ? nil : URL(string: currentEnclosureURL)

        guard !link.isEmpty, let url = URL(string: link) else { return }

        // Parse date
        let date = parseRSSDate(pubDateStr)

        // Extract article ID from link or GUID
        let articleID = extractArticleID(from: url, guid: guid)

        // Extract image URL from description
        let imageURL = extractImageURL(from: descHTML)

        // Convert HTML ruby tags → kanji[furi] and strip other HTML
        let titleFuri = convertHTMLToFuri(title)
        let (cleanDesc, descFuri) = parseDescriptionHTML(descHTML)

        // Split furigana-rich description into chunks
        let chunks = splitIntoChunks(descFuri.isEmpty ? cleanDesc : descFuri, maxLength: 80)

        let article = NHKNewsArticle(
            id: articleID,
            title: title,
            titleFuri: titleFuri,
            description: cleanDesc,
            descriptionFuri: descFuri,
            url: url,
            imageURL: imageURL,
            audioURL: audioURL,
            publishDate: date,
            contentChunks: chunks
        )
        items.append(article)
    }

    private func parseRSSDate(_ str: String) -> Date {
        let formats = [
            "E, d MMM yyyy HH:mm:ss Z",
            "E, d MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss'Z'"
        ]
        for fmt in formats {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = fmt
            if let d = f.date(from: str) { return d }
        }
        return Date()
    }

    private func extractArticleID(from url: URL, guid: String) -> String {
        // From URL like https://nhkeasier.com/story/9672/ → "9672"
        let path = url.pathComponents
        if let idx = path.firstIndex(of: "story"), idx + 1 < path.count {
            return path[idx + 1]
        }
        // From GUID like https://nhkeasier.com/story/9672/
        if let last = guid.split(separator: "/").last, !last.isEmpty {
            return String(last)
        }
        return url.lastPathComponent
    }

    private func extractImageURL(from html: String) -> URL? {
        let patterns = [
            "<img[^>]+src=\"([^\"]+)\"",
            "<img[^>]+src='([^']+)'"
        ]
        for pattern in patterns {
            if let match = html.range(of: pattern, options: .regularExpression) {
                let matched = String(html[match])
                if let start = matched.range(of: "src=\"") ?? matched.range(of: "src='") {
                    let s = start.upperBound
                    let end = matched[s...].range(of: "\"")?.lowerBound ?? matched[s...].range(of: "'")?.lowerBound ?? matched.endIndex
                    let urlStr = String(matched[s..<end])
                    if urlStr.hasPrefix("http") {
                        return URL(string: urlStr)
                    }
                }
            }
        }
        return nil
    }
}

// MARK: - Ruby/Furigana HTML Conversion

/// Convert `<ruby>漢字<rt>かんじ</rt></ruby>` → `漢字[かんじ]`
private func convertHTMLToFuri(_ html: String) -> String {
    var result = html
    // Pattern 1: <ruby>...<rt>reading</rt></ruby>
    if let regex = try? NSRegularExpression(pattern: "<ruby[^>]*>(.*?)<rt[^>]*>(.*?)</rt>.*?</ruby>", options: [.dotMatchesLineSeparators, .caseInsensitive]) {
        result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1[$2]")
    }
    // Pattern 2: standalone <rt> (fallback)
    result = result.replacingOccurrences(of: "<rt>", with: "[")
    result = result.replacingOccurrences(of: "</rt>", with: "]")
    // Remove remaining HTML tags
    if let tagRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
        result = tagRegex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
    }
    // Decode HTML entities
    let entities = [
        "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
        "&#39;": "'", "&nbsp;": " "
    ]
    for (key, val) in entities {
        result = result.replacingOccurrences(of: key, with: val)
    }
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Parse the RSS description HTML: return (plainText, furiganaRichText)
private func parseDescriptionHTML(_ html: String) -> (String, String) {
    let furiText = convertHTMLToFuri(html)

    // Plain text: remove all tags and decode
    var plain = html
    if let tagRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
        plain = tagRegex.stringByReplacingMatches(in: plain, range: NSRange(plain.startIndex..., in: plain), withTemplate: "")
    }
    let entities = [
        "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
        "&#39;": "'", "&nbsp;": " "
    ]
    for (key, val) in entities {
        plain = plain.replacingOccurrences(of: key, with: val)
    }
    plain = plain.trimmingCharacters(in: .whitespacesAndNewlines)

    return (plain, furiText)
}

// MARK: - Chunking

private func splitIntoChunks(_ text: String, maxLength: Int) -> [String] {
    guard !text.isEmpty else { return [] }

    // Split by sentence boundaries
    let separators = CharacterSet(charactersIn: "。！？\n\r")
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

    if sentences.isEmpty {
        return stride(from: 0, to: text.count, by: maxLength).map { i in
            let start = text.index(text.startIndex, offsetBy: i)
            let end = text.index(start, offsetBy: min(maxLength, text.count - i))
            return String(text[start..<end]).trimmingCharacters(in: .whitespaces)
        }
    }

    var chunks: [String] = []
    var currentChunk = ""
    for sentence in sentences {
        if currentChunk.count + sentence.count <= maxLength {
            currentChunk += (currentChunk.isEmpty ? "" : "") + sentence
        } else {
            if !currentChunk.isEmpty { chunks.append(currentChunk) }
            currentChunk = sentence
        }
    }
    if !currentChunk.isEmpty { chunks.append(currentChunk) }
    return chunks.isEmpty ? [text] : chunks
}
