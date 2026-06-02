import SwiftUI

// MARK: - Color Hex Extension
public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 30, 30, 36) // Fallback Obsidian Gray
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Template Parser Helper
@MainActor
public func parseTemplate(title: String, widget: TouchBarWidget, state: AppState) -> String {
    var result = title
    var timeString = state.currentTime
    if !widget.showSeconds && timeString.count == 8 {
        timeString = String(timeString.prefix(5))
    }
    result = result.replacingOccurrences(of: "{time}", with: timeString)
    result = result.replacingOccurrences(of: "{date}", with: state.currentDate)
    result = result.replacingOccurrences(of: "{battery}", with: "\(state.batteryLevel)%")
    result = result.replacingOccurrences(of: "{cpu}", with: String(format: "%.0f%%", state.cpuUsage))
    result = result.replacingOccurrences(of: "{ram}", with: String(format: "%.0f%%", state.ramUsage))
    return result
}

// MARK: - Animation Frames Presets
public extension AnimationPreset {
    var frames: [String] {
        switch self {
        case .cat:
            return ["🐱 🐾 🐾 🐾", "🐾 🐱 🐾 🐾", "🐾 🐾 🐱 🐾", "🐾 🐾 🐾 🐱"]
        case .heart:
            return ["❤️", "💖", "💗", "💖"]
        case .spinner:
            return ["🕐", "🕒", "🕕", "🕘"]
        case .coffee:
            return ["☕️     ", "☕️ 💨   ", "☕️ 💨 💨 ", "☕️      "]
        case .matrix:
            return ["💻 01", "👾 10", "💾 11", "📡 00"]
        }
    }
}

// MARK: - Widget Views

public struct WidgetButtonView: View {
    let widget: TouchBarWidget
    let state: AppState
    let isSimulator: Bool
    
    public var body: some View {
        Button(action: {
            state.executeAction(for: widget)
        }) {
            HStack(spacing: 6) {
                if !widget.iconName.isEmpty {
                    Image(systemName: widget.iconName)
                        .font(.system(size: isSimulator ? widget.fontSize - 1 : widget.fontSize))
                }
                if !widget.title.isEmpty {
                    Text(parseTemplate(title: widget.title, widget: widget, state: state))
                        .font(.system(size: isSimulator ? widget.fontSize - 1 : widget.fontSize, weight: .medium))
                }
            }
            .padding(.horizontal, isSimulator ? 8 : 12)
            .padding(.vertical, isSimulator ? 5 : 6)
            .background(Color(hex: widget.backgroundColorHex))
            .foregroundColor(Color(hex: widget.textColorHex))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

public struct WidgetLabelView: View {
    let widget: TouchBarWidget
    let state: AppState
    let isSimulator: Bool
    
    public var body: some View {
        HStack(spacing: 6) {
            if !widget.iconName.isEmpty {
                Image(systemName: widget.iconName)
                    .font(.system(size: isSimulator ? widget.fontSize - 1 : widget.fontSize))
                    .foregroundColor(Color(hex: widget.textColorHex))
            }
            Text(parseTemplate(title: widget.title, widget: widget, state: state))
                .font(.system(size: isSimulator ? widget.fontSize - 1 : widget.fontSize, weight: .medium))
                .foregroundColor(Color(hex: widget.textColorHex))
        }
        .padding(.horizontal, isSimulator ? 8 : 12)
        .padding(.vertical, isSimulator ? 5 : 6)
        .background(Color(hex: widget.backgroundColorHex).opacity(0.2))
        .cornerRadius(6)
    }
}

// Computed: select the right icon path based on current battery state
public struct WidgetBatteryAnimationView: View {
    let widget: TouchBarWidget
    let state: AppState
    let isSimulator: Bool

    @State private var currentFrameIndex: Int = 0
    @State private var animTimer: Timer? = nil
    @State private var frames: [NSImage] = []

    // Computed property — SwiftUI tracks state.isBatteryCharging, batteryLevel, etc. automatically
    private var activePath: String {
        if state.isBatteryCharging && !widget.batteryChargingIcon.isEmpty {
            return widget.batteryChargingIcon
        } else if state.batteryLevel <= widget.batteryLowThreshold && !widget.batteryLowIcon.isEmpty {
            return widget.batteryLowIcon
        } else if (state.batteryLevel >= widget.batteryFullThreshold || state.isBatteryFull) && !widget.batteryFullIcon.isEmpty {
            return widget.batteryFullIcon
        } else if !widget.batteryNormalIcon.isEmpty {
            return widget.batteryNormalIcon
        }
        return ""
    }

    public var body: some View {
        Group {
            if !frames.isEmpty {
                if let nsImg = frames[safe: currentFrameIndex % frames.count] {
                    Image(nsImage: nsImg)
                        .resizable()
                        .scaledToFit()
                        .frame(width: widget.customWidth > 0.0 ? widget.customWidth : 40, height: isSimulator ? 20 : 30)
                } else {
                    fallbackIcon
                }
            } else if !activePath.isEmpty, let nsImg = NSImage(contentsOfFile: activePath) {
                Image(nsImage: nsImg)
                    .resizable()
                    .scaledToFit()
                    .frame(width: widget.customWidth > 0.0 ? widget.customWidth : 40, height: isSimulator ? 20 : 30)
            } else {
                fallbackIcon
            }
        }
        .onAppear { loadFrames() }
        .onChange(of: activePath) { loadFrames() }
    }

    private var fallbackIcon: some View {
        let name: String
        if state.isBatteryCharging {
            name = "battery.100.bolt"
        } else if state.batteryLevel <= widget.batteryLowThreshold {
            name = "battery.25"
        } else if state.batteryLevel >= widget.batteryFullThreshold || state.isBatteryFull {
            name = "battery.100"
        } else {
            name = "battery.75"
        }
        return Image(systemName: name)
            .font(.system(size: isSimulator ? widget.fontSize - 2 : widget.fontSize))
            .foregroundColor(state.batteryLevel <= widget.batteryLowThreshold ? .rose : Color(hex: widget.textColorHex))
    }

    private func loadFrames() {
        animTimer?.invalidate()
        animTimer = nil
        frames = []
        currentFrameIndex = 0

        guard !activePath.isEmpty, activePath.lowercased().hasSuffix(".gif") else { return }

        let loaded = SystemUtils.extractGifFrames(from: activePath)
        frames = loaded
        guard !loaded.isEmpty else { return }

        animTimer = Timer.scheduledTimer(withTimeInterval: widget.animationSpeed, repeats: true) { _ in
            Task { @MainActor in
                self.currentFrameIndex += 1
            }
        }
    }
}

public struct WidgetSystemMonitorView: View {
    let widget: TouchBarWidget
    let state: AppState
    let isSimulator: Bool
    
    private var value: Double {
        switch widget.monitorType {
        case .cpu: return state.cpuUsage
        case .ram: return state.ramUsage
        case .battery: return Double(state.batteryLevel)
        }
    }
    
    private var suffix: String {
        switch widget.monitorType {
        case .cpu: return "CPU"
        case .ram: return "RAM"
        case .battery: return "BAT"
        }
    }
    
    private var barColor: Color {
        switch widget.monitorType {
        case .cpu: return .emerald
        case .ram: return .amber
        case .battery: return state.batteryLevel > widget.batteryLowThreshold ? .cyan : .rose
        }
    }
    
    public var body: some View {
        Group {
            if widget.monitorType == .battery {
                if widget.batteryDisplayType == .textOnly {
                    // Text Only: hanya tampilkan persentase, merah jika lemah
                    Text("\(state.batteryLevel)%")
                        .font(.system(size: isSimulator ? widget.fontSize - 1 : widget.fontSize, weight: .bold, design: .monospaced))
                        .foregroundColor(state.batteryLevel <= widget.batteryLowThreshold ? .rose : Color(hex: widget.textColorHex))
                        .padding(.horizontal, isSimulator ? 8 : 12)
                        .padding(.vertical, isSimulator ? 5 : 6)
                        .background(Color(hex: widget.backgroundColorHex).opacity(0.15))
                        .cornerRadius(6)
                } else {
                    // Image or Animation: full animasi, tanpa background/padding (persis seperti widget Animasi)
                    WidgetBatteryAnimationView(widget: widget, state: state, isSimulator: isSimulator)
                }
            } else {
                // CPU / RAM: icon + teks + progress bar seperti biasa
                HStack(spacing: 6) {
                    Image(systemName: widget.iconName)
                        .font(.system(size: isSimulator ? widget.fontSize - 2 : widget.fontSize))
                        .foregroundColor(Color(hex: widget.textColorHex))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: "%.0f%% %@", value, suffix))
                            .font(.system(size: isSimulator ? widget.fontSize - 3 : widget.fontSize - 2, design: .monospaced))
                            .foregroundColor(Color(hex: widget.textColorHex))
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Color.white.opacity(0.15))
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(barColor)
                                    .frame(width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(value / 100.0))))
                            }
                        }
                        .frame(width: isSimulator ? 45 : 60, height: 3)
                    }
                }
                .padding(.horizontal, isSimulator ? 8 : 12)
                .padding(.vertical, isSimulator ? 5 : 6)
                .background(Color(hex: widget.backgroundColorHex).opacity(0.15))
                .cornerRadius(6)
            }
        }
    }
}

public struct WidgetAnimationView: View {
    let widget: TouchBarWidget
    let state: AppState
    let isSimulator: Bool
    
    @State private var currentFrameIndex: Int = 0
    @State private var timer: Timer? = nil
    @State private var customFrames: [NSImage] = []
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: widget.iconName)
                .font(.system(size: isSimulator ? widget.fontSize - 2 : widget.fontSize))
                .foregroundColor(Color(hex: widget.textColorHex))
            
            if !customFrames.isEmpty {
                if let image = customFrames[safe: currentFrameIndex % customFrames.count] {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: widget.customWidth > 0.0 ? widget.customWidth : 40, height: isSimulator ? 20 : 30)
                }
            } else {
                Text(currentFrame)
                    .font(.system(size: isSimulator ? widget.fontSize - 1 : widget.fontSize, design: .monospaced))
                    .foregroundColor(Color(hex: widget.textColorHex))
            }
        }
        .padding(.horizontal, isSimulator ? 8 : 12)
        .padding(.vertical, isSimulator ? 5 : 6)
        .background(Color(hex: widget.backgroundColorHex).opacity(0.2))
        .cornerRadius(6)
        .onAppear {
            loadFramesAndStart()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: widget.animationType) {
            currentFrameIndex = 0
            loadFramesAndStart()
        }
        .onChange(of: widget.customGifPath) {
            currentFrameIndex = 0
            loadFramesAndStart()
        }
        .onChange(of: widget.animationSpeed) {
            startAnimation()
        }
    }
    
    private func loadFramesAndStart() {
        if !widget.customGifPath.isEmpty {
            customFrames = SystemUtils.extractGifFrames(from: widget.customGifPath)
        } else {
            customFrames = []
        }
        startAnimation()
    }
    
    private var currentFrame: String {
        let frames = widget.animationType.frames
        guard !frames.isEmpty else { return "" }
        return frames[currentFrameIndex % frames.count]
    }
    
    private func startAnimation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: widget.animationSpeed, repeats: true) { _ in
            DispatchQueue.main.async {
                let total = !customFrames.isEmpty ? customFrames.count : widget.animationType.frames.count
                if total > 0 {
                    currentFrameIndex = (currentFrameIndex + 1) % total
                }
            }
        }
    }
}

// Safe array lookup helper
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Furigana Support

public struct FuriganaSegment {
    public let text: String
    public let furigana: String?
}

private struct StyledChunk {
    let text: String
    let isBold: Bool
    let isItalic: Bool
    let isUnderline: Bool
}

/// Check if a character is a CJK Unified Ideograph (kanji).
private func isCJK(_ c: Character) -> Bool {
    guard let scalar = c.unicodeScalars.first else { return false }
    return (0x4E00...0x9FFF).contains(scalar.value)
}

/// Extract trailing CJK (kanji) characters from `rawBase` as the furigana base.
/// Everything before the trailing kanji run becomes a plain text prefix.
/// E.g. "が 豊" → ("が ", "豊"), "はとても表" → ("はとても", "表"), "勉強" → ("", "勉強")
private func splitFuriganaBase(_ rawBase: String) -> (prefix: String, kanjiBase: String) {
    var kanjiStart = rawBase.endIndex
    for i in rawBase.indices.reversed() {
        guard isCJK(rawBase[i]) else { break }
        kanjiStart = i
    }
    guard kanjiStart < rawBase.endIndex else { return ("", rawBase) }
    return (String(rawBase[..<kanjiStart]), String(rawBase[kanjiStart...]))
}

public func parseFuriganaSegments(_ text: String) -> [FuriganaSegment] {
    var segments: [FuriganaSegment] = []
    var remaining = text[...]
    
    while !remaining.isEmpty {
        if let openBracket = remaining.firstIndex(of: "["),
           let closeBracket = remaining[openBracket...].firstIndex(of: "]"),
           openBracket > remaining.startIndex {
            let rawBase = String(remaining[..<openBracket])
            let furiganaText = String(remaining[remaining.index(after: openBracket)..<closeBracket])
            
            // Split trailing kanji from rawBase: kanji gets the furigana, prefix is plain text
            let (prefix, kanjiBase) = splitFuriganaBase(rawBase)
            
            if !prefix.isEmpty {
                segments.append(FuriganaSegment(text: prefix, furigana: nil))
            }
            if !kanjiBase.isEmpty {
                segments.append(FuriganaSegment(text: kanjiBase, furigana: furiganaText))
            }
            
            remaining = remaining[remaining.index(after: closeBracket)...]
        } else {
            segments.append(FuriganaSegment(text: String(remaining), furigana: nil))
            remaining = ""
        }
    }
    
    return segments
}

/// Parse HTML tags into styled chunks. Returns an array of StyledChunk.
private func parseHTMLStyledChunks(from text: String) -> [StyledChunk] {
    var chunks: [StyledChunk] = []
    var currentText = ""
    var isBold = false
    var isItalic = false
    var isUnderline = false
    
    var index = text.startIndex
    while index < text.endIndex {
        if text[index...].hasPrefix("<b>") || text[index...].hasPrefix("<strong>") {
            if !currentText.isEmpty {
                chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                currentText = ""
            }
            if text[index...].hasPrefix("<b>") {
                index = text.index(index, offsetBy: 3)
            } else {
                index = text.index(index, offsetBy: 8)
            }
            isBold = true
        } else if text[index...].hasPrefix("</b>") || text[index...].hasPrefix("</strong>") {
            if !currentText.isEmpty {
                chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                currentText = ""
            }
            if text[index...].hasPrefix("</b>") {
                index = text.index(index, offsetBy: 4)
            } else {
                index = text.index(index, offsetBy: 9)
            }
            isBold = false
        } else if text[index...].hasPrefix("<i>") || text[index...].hasPrefix("<em>") {
            if !currentText.isEmpty {
                chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                currentText = ""
            }
            if text[index...].hasPrefix("<i>") {
                index = text.index(index, offsetBy: 3)
            } else {
                index = text.index(index, offsetBy: 4)
            }
            isItalic = true
        } else if text[index...].hasPrefix("</i>") || text[index...].hasPrefix("</em>") {
            let hasEmClose = text[index...].hasPrefix("</em>")
            if !currentText.isEmpty {
                chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                currentText = ""
            }
            if hasEmClose {
                index = text.index(index, offsetBy: 5)
            } else {
                index = text.index(index, offsetBy: 4)
            }
            isItalic = false
        } else if text[index...].hasPrefix("<u>") {
            if !currentText.isEmpty {
                chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                currentText = ""
            }
            index = text.index(index, offsetBy: 3)
            isUnderline = true
        } else if text[index...].hasPrefix("</u>") {
            if !currentText.isEmpty {
                chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                currentText = ""
            }
            index = text.index(index, offsetBy: 4)
            isUnderline = false
        } else {
            currentText.append(text[index])
            index = text.index(after: index)
        }
    }
    
    if !currentText.isEmpty {
        chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
    }
    
    return chunks
}

private struct RichSegment: Identifiable {
    let id = UUID()
    let text: String
    let furigana: String?
    let isBold: Bool
    let isItalic: Bool
    let isUnderline: Bool
}

/// Build a flat list of RichSegments from HTML-styled chunks and furigana parsing.
private func parseRichSegments(from text: String) -> [RichSegment] {
    let chunks = parseHTMLStyledChunks(from: text)
    return chunks.flatMap { chunk -> [RichSegment] in
        let segments = parseFuriganaSegments(chunk.text)
        return segments.map { seg in
            RichSegment(text: seg.text, furigana: seg.furigana, isBold: chunk.isBold, isItalic: chunk.isItalic, isUnderline: chunk.isUnderline)
        }
    }
}

/// Combines HTML tag parsing (bold/italic/underline) with furigana rendering.
/// Furigana text (e.g. 私[わたし]) is rendered as ruby text with the reading above the kanji.
/// Uses VStack with tight spacing so total height fits within Touch Bar constraints.
@MainActor
public func parseFuriganaRichText(in text: String, defaultColor: Color, boldColor: Color, fontSize: CGFloat, furiganaFontSize: CGFloat = 0, verticalOffset: CGFloat = 0, textOffset: CGFloat = 0) -> some View {
    let segments = parseRichSegments(from: text)
    
    // Determine furigana font size — use user-specified size if set, otherwise auto-calculate
    let computedFuriFontSize: CGFloat
    if furiganaFontSize > 0 {
        computedFuriFontSize = max(3, furiganaFontSize)
    } else {
        computedFuriFontSize = max(4, fontSize * 0.25)
    }
    
    return HStack(spacing: 0) {
        ForEach(segments) { item in
            if let furi = item.furigana {
                // Ruby text: kanji text at normal height, furigana overlaid above so kanji stays aligned with plain text
                Text(item.text)
                    .font(.system(size: fontSize, weight: item.isBold ? .bold : .regular))
                    .foregroundColor(item.isBold ? boldColor : defaultColor)
                    .if(item.isItalic) { $0.italic() }
                    .if(item.isUnderline) { $0.underline() }
                    .overlay(alignment: .top) {
                        Text(furi)
                            .font(.system(size: computedFuriFontSize, weight: .medium))
                            .foregroundColor(item.isBold ? boldColor.opacity(0.65) : defaultColor.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .fixedSize()
                            .offset(y: -(computedFuriFontSize * 1.2 + verticalOffset))
                    }
            } else {
                Text(item.text)
                    .font(.system(size: fontSize, weight: item.isBold ? .bold : .regular))
                    .foregroundColor(item.isBold ? boldColor : defaultColor)
                    .if(item.isItalic) { $0.italic() }
                    .if(item.isUnderline) { $0.underline() }
            }
        }
    }
    .offset(y: textOffset)
}

// MARK: - View extension for conditional modifiers
extension View {
    @ViewBuilder
    public func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

public struct WidgetMediaView: View {
    let widget: TouchBarWidget
    let state: AppState
    let isSimulator: Bool
    
    public var body: some View {
        HStack(spacing: isSimulator ? 4 : 6) {
            // Previous button
            Button(action: {
                executeMedia("previous")
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: isSimulator ? 9 : 11))
                    .padding(5)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // Play/Pause button
            Button(action: {
                executeMedia("playpause")
            }) {
                Image(systemName: "playpause.fill")
                    .font(.system(size: isSimulator ? 10 : 12))
                    .padding(6)
                    .background(Color(hex: widget.backgroundColorHex))
                    .foregroundColor(Color(hex: widget.textColorHex))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // Next button
            Button(action: {
                executeMedia("next")
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: isSimulator ? 9 : 11))
                    .padding(5)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, isSimulator ? 6 : 8)
        .padding(.vertical, isSimulator ? 4 : 5)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
    
    private func executeMedia(_ action: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var scriptString = ""
            switch action {
            case "playpause":
                scriptString = """
                if application "Music" is running then
                    tell application "Music" to playpause
                else if application "Spotify" is running then
                    tell application "Spotify" to playpause
                else
                    tell application "System Events" to key code 16
                end if
                """
            case "next":
                scriptString = """
                if application "Music" is running then
                    tell application "Music" to next track
                else if application "Spotify" is running then
                    tell application "Spotify" to next track
                else
                    tell application "System Events" to key code 19
                end if
                """
            case "previous":
                scriptString = """
                if application "Music" is running then
                    tell application "Music" to previous track
                else if application "Spotify" is running then
                    tell application "Spotify" to previous track
                else
                    tell application "System Events" to key code 18
                end if
                """
            default:
                break
            }
            if !scriptString.isEmpty, let script = NSAppleScript(source: scriptString) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
            }
        }
    }
}

// MARK: - Extra Color Helpers
private extension Color {
    static let emerald = Color(red: 16/255, green: 185/255, blue: 129/255)
    static let amber = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let cyan = Color(red: 6/255, green: 182/255, blue: 212/255)
    static let rose = Color(red: 244/255, green: 63/255, blue: 94/255)
}

public struct WidgetAnkiView: View {
    let widget: TouchBarWidget
    let state: AppState
    let isSimulator: Bool
    
    @AppStorage("AnkiTouchBar.isMediaOnLeft") private var isMediaOnLeft: Bool = false
    
    public var body: some View {
        let anki = state.ankiState
        
        Group {
            if !anki.isConnected {
                offlineContent
            } else if anki.currentCard == nil {
                noCardContent(anki: anki)
            } else if !anki.isShowingAnswer {
                questionPhaseContent(anki: anki)
            } else {
                answerPhaseContent(anki: anki)
            }
        }
        .padding(.horizontal, isSimulator ? 8 : 12)
        .padding(.vertical, isSimulator ? 5 : 6)
        .background(Color(hex: widget.backgroundColorHex).opacity(0.15))
        .cornerRadius(6)
        .if(widget.customWidth > 0) { $0.frame(width: widget.customWidth) }
    }
    
    // MARK: - Offline
    
    private var offlineContent: some View {
        HStack(spacing: 6) {
            Image(systemName: "rectangle.stack.fill.badge.person.crop")
                .font(.system(size: isSimulator ? 11 : 13))
            Text("Anki Offline")
                .font(.system(size: isSimulator ? 11 : 13, weight: .medium))
            Button("Connect") {
                state.ankiState.checkConnection()
            }
            .buttonStyle(.plain)
            .font(.system(size: isSimulator ? 9 : 11))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: widget.backgroundColorHex))
            .cornerRadius(4)
        }
    }
    
    // MARK: - No Card
    
    @ViewBuilder
    private func noCardContent(anki: AnkiState) -> some View {
        HStack(spacing: 8) {
            if isMediaOnLeft {
                Text("Anki: Select Deck")
                    .font(.system(size: isSimulator ? widget.fontSize - 1 : widget.fontSize, weight: .medium))
                syncButtonContent(anki: anki)
            } else {
                syncButtonContent(anki: anki)
                Text("Anki: Select Deck")
                    .font(.system(size: isSimulator ? widget.fontSize - 1 : widget.fontSize, weight: .medium))
            }
        }
    }
    
    // MARK: - Question Phase
    
    @ViewBuilder
    private func questionPhaseContent(anki: AnkiState) -> some View {
        HStack(spacing: 8) {
            if widget.ankiShowRemainingCounts {
                if isMediaOnLeft {
                    countsAndRevealContent(anki: anki)
                    questionTextContent(anki: anki)
                    Spacer()
                    syncButtonContent(anki: anki)
                } else {
                    syncButtonContent(anki: anki)
                    questionTextContent(anki: anki)
                    Spacer()
                    countsAndRevealContent(anki: anki)
                }
            } else {
                if isMediaOnLeft {
                    revealButtonContent
                    questionTextContent(anki: anki)
                    Spacer()
                    syncButtonContent(anki: anki)
                } else {
                    syncButtonContent(anki: anki)
                    questionTextContent(anki: anki)
                    revealButtonContent
                }
            }
        }
    }
    
    // MARK: - Answer Phase
    
    @ViewBuilder
    private func answerPhaseContent(anki: AnkiState) -> some View {
        HStack(spacing: 8) {
            if isMediaOnLeft {
                ratingContent(anki: anki)
                if anki.currentCard?.soundFilename != nil {
                    audioButtonContent(anki: anki)
                }
                answerTextContent(anki: anki)
                Spacer()
                syncButtonContent(anki: anki)
            } else {
                syncButtonContent(anki: anki)
                answerTextContent(anki: anki)
                Spacer()
                ratingContent(anki: anki)
                if anki.currentCard?.soundFilename != nil {
                    audioButtonContent(anki: anki)
                }
            }
        }
    }
    
    // MARK: - Sub-Views
    
    @ViewBuilder
    private func syncButtonContent(anki: AnkiState) -> some View {
        Button(action: {
            anki.syncDecks()
        }) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: isSimulator ? 10 : 12))
                .foregroundColor(Color(hex: widget.textColorHex).opacity(anki.isSyncing ? 0.4 : 1.0))
                .frame(height: 12)
        }
        .buttonStyle(.plain)
        .disabled(anki.isSyncing)
    }
    
    @ViewBuilder
    private func questionTextContent(anki: AnkiState) -> some View {
        if widget.ankiCombineFurigana {
            parseFuriganaRichText(
                in: anki.questionPreview,
                defaultColor: Color(hex: widget.textColorHex),
                boldColor: Color(hex: widget.ankiBoldColorHex),
                fontSize: isSimulator ? widget.fontSize - 1 : widget.fontSize,
                furiganaFontSize: CGFloat(widget.ankiFuriganaFontSize),
                verticalOffset: CGFloat(widget.ankiFuriganaVerticalOffset),
                textOffset: CGFloat(widget.ankiFuriganaTextOffset)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            parseBoldTags(in: anki.questionPreview, defaultColor: Color(hex: widget.textColorHex), boldColor: Color(hex: widget.ankiBoldColorHex), fontSize: isSimulator ? widget.fontSize - 1 : widget.fontSize)
                .if(widget.ankiTrimText) { $0.lineLimit(1).truncationMode(.tail) }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private func answerTextContent(anki: AnkiState) -> some View {
        if widget.ankiCombineFurigana {
            parseFuriganaRichText(
                in: anki.answerPreview,
                defaultColor: Color(hex: widget.textColorHex),
                boldColor: Color(hex: widget.ankiBoldColorHex),
                fontSize: isSimulator ? widget.fontSize - 1 : widget.fontSize,
                furiganaFontSize: CGFloat(widget.ankiFuriganaFontSize),
                verticalOffset: CGFloat(widget.ankiFuriganaVerticalOffset),
                textOffset: CGFloat(widget.ankiFuriganaTextOffset)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .onTapGesture {
                anki.toggleTouchBarAudio()
            }
        } else {
            parseBoldTags(in: anki.answerPreview, defaultColor: Color(hex: widget.textColorHex), boldColor: Color(hex: widget.ankiBoldColorHex), fontSize: isSimulator ? widget.fontSize - 1 : widget.fontSize)
                .if(widget.ankiTrimText) { $0.lineLimit(1).truncationMode(.tail) }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture {
                    anki.toggleTouchBarAudio()
                }
        }
    }
    
    @ViewBuilder
    private func countsAndRevealContent(anki: AnkiState) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Text("\(anki.newCount)")
                    .font(.system(size: isSimulator ? 7 : 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
                Text("\(anki.learnCount)")
                    .font(.system(size: isSimulator ? 7 : 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.orange)
                Text("\(anki.reviewCount)")
                    .font(.system(size: isSimulator ? 7 : 8, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            }
            
            Button(action: {
                anki.revealAnswer()
            }) {
                Text("Reveal ▶")
                    .font(.system(size: isSimulator ? 7 : 8, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color(hex: widget.backgroundColorHex))
                    .foregroundColor(Color(hex: widget.textColorHex))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var revealButtonContent: some View {
        Button(action: {
            state.ankiState.revealAnswer()
        }) {
            Text("Reveal ▶")
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: widget.backgroundColorHex))
                .foregroundColor(Color(hex: widget.textColorHex))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func ratingContent(anki: AnkiState) -> some View {
        HStack(spacing: 4) {
            let count = anki.currentCard?.buttonCount ?? 4
            let buttons = getRatingButtons(for: widget, buttonCount: count)
            
            ForEach(buttons, id: \.rating) { btn in
                Button(action: {
                    anki.submitRating(ease: btn.rating)
                }) {
                    Text(btn.title)
                        .font(.system(size: isSimulator ? 10 : 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(btn.color)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    @ViewBuilder
    private func audioButtonContent(anki: AnkiState) -> some View {
        Button(action: {
            anki.toggleAudio()
        }) {
            Image(systemName: anki.isAudioPlaying ? "stop.fill" : "play.fill")
                .font(.system(size: isSimulator ? 10 : 12))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: widget.backgroundColorHex))
                .foregroundColor(Color(hex: widget.textColorHex))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
    
    private func parseBoldTags(in text: String, defaultColor: Color, boldColor: Color, fontSize: CGFloat) -> Text {
        struct StyledChunk {
            let text: String
            let isBold: Bool
            let isItalic: Bool
            let isUnderline: Bool
        }
        
        var chunks: [StyledChunk] = []
        var currentText = ""
        var isBold = false
        var isItalic = false
        var isUnderline = false
        
        var index = text.startIndex
        while index < text.endIndex {
            if text[index...].hasPrefix("<b>") || text[index...].hasPrefix("<strong>") {
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                if text[index...].hasPrefix("<b>") {
                    index = text.index(index, offsetBy: 3)
                } else {
                    index = text.index(index, offsetBy: 8)
                }
                isBold = true
            } else if text[index...].hasPrefix("</b>") || text[index...].hasPrefix("</strong>") {
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                if text[index...].hasPrefix("</b>") {
                    index = text.index(index, offsetBy: 4)
                } else {
                    index = text.index(index, offsetBy: 9)
                }
                isBold = false
            } else if text[index...].hasPrefix("<i>") || text[index...].hasPrefix("<em>") {
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                if text[index...].hasPrefix("<i>") {
                    index = text.index(index, offsetBy: 3)
                } else {
                    index = text.index(index, offsetBy: 4)
                }
                isItalic = true
            } else if text[index...].hasPrefix("</i>") || text[index...].hasPrefix("</em>") {
                let hasEmClose = text[index...].hasPrefix("</em>")
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                if hasEmClose {
                    index = text.index(index, offsetBy: 5)
                } else {
                    index = text.index(index, offsetBy: 4) // </i>
                }
                isItalic = false
            } else if text[index...].hasPrefix("<u>") {
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                index = text.index(index, offsetBy: 3)
                isUnderline = true
            } else if text[index...].hasPrefix("</u>") {
                if !currentText.isEmpty {
                    chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
                    currentText = ""
                }
                index = text.index(index, offsetBy: 4)
                isUnderline = false
            } else {
                currentText.append(text[index])
                index = text.index(after: index)
            }
        }
        
        if !currentText.isEmpty {
            chunks.append(StyledChunk(text: currentText, isBold: isBold, isItalic: isItalic, isUnderline: isUnderline))
        }
        
        var resultText = Text("")
        for chunk in chunks {
            var t = Text(chunk.text)
            if chunk.isBold {
                t = t.bold()
            }
            if chunk.isItalic {
                t = t.italic()
            }
            if chunk.isUnderline {
                t = t.underline()
            }
            
            t = t.font(.system(size: fontSize))
            if chunk.isBold {
                t = t.foregroundColor(boldColor)
            } else {
                t = t.foregroundColor(defaultColor)
            }
            resultText = resultText + t
        }
        
        return resultText
    }
    
    private func getRatingButtons(for widget: TouchBarWidget, buttonCount: Int) -> [(title: String, rating: Int, color: Color)] {
        var result: [(title: String, rating: Int, color: Color)] = []
        
        let againColor = Color(hex: widget.ankiAgainColorHex)
        let hardColor = Color(hex: widget.ankiHardColorHex)
        let goodColor = Color(hex: widget.ankiGoodColorHex)
        let easyColor = Color(hex: widget.ankiEasyColorHex)
        
        // Anki ease ratings di AnkiConnect bersifat 1-indexed sesuai posisi tombol:
        //   2 tombol: 1=Again, 2=Good
        //   3 tombol: 1=Again, 2=Good, 3=Easy
        //   4 tombol: 1=Again, 2=Hard, 3=Good, 4=Easy
        //
        // Tampilkan tombol sesuai preferensi user. Untuk buttonCount < 4, ease value
        // disesuaikan agar mapping-nya benar di Anki. Hard (ease=2) valid untuk semua
        // jumlah tombol (meski di 2/3 tombol artinya "Good" di Anki). Easy untuk
        // buttonCount=2 menggunakan ease=2 (tombol kedua = Good) sebagai fallback.
        
        if widget.ankiShowAgain {
            result.append((title: "Again", rating: 1, color: againColor))
        }
        if widget.ankiShowHard && buttonCount >= 2 {
            // ease=2 valid untuk semua buttonCount:
            //   2 tombol -> Good, 3 tombol -> Good, 4 tombol -> Hard
            result.append((title: "Hard", rating: 2, color: hardColor))
        }
        if widget.ankiShowGood && buttonCount >= 2 {
            let ease = buttonCount == 2 ? 2 : 3
            result.append((title: "Good", rating: ease, color: goodColor))
        }
        if widget.ankiShowEasy {
            let ease: Int
            if buttonCount >= 4 {
                ease = 4
            } else if buttonCount >= 3 {
                ease = 3
            } else {
                // buttonCount=2: Easy tidak ada di Anki, tapi kita tampilkan
                // dengan ease=2 (tombol kedua = Good) agar tombol tetap muncul.
                ease = 2
            }
            result.append((title: "Easy", rating: ease, color: easyColor))
        }
        
        // Deduplicate: if multiple checked buttons map to the same ease value (happens
        // when buttonCount < 4), keep only the first one to avoid redundant buttons.
        var seenRatings = Set<Int>()
        result = result.filter { seenRatings.insert($0.rating).inserted }
        
        return result
    }
}

public struct WidgetVolumeSliderView: View {
    let widget: TouchBarWidget
    let state: AppState
    let isSimulator: Bool
    
    @State private var volume: Double = 50.0
    
    public var body: some View {
        HStack(spacing: 6) {
            if widget.volumeShowIcon {
                Image(systemName: "speaker.fill")
                    .font(.system(size: isSimulator ? widget.fontSize - 2 : widget.fontSize))
                    .foregroundColor(Color(hex: widget.textColorHex))
            }
            
            Slider(value: $volume, in: 0...100, onEditingChanged: { _ in
                setSystemVolume(Int(volume))
            })
            .accentColor(Color(hex: widget.backgroundColorHex))
            .frame(width: widget.volumeSliderWidth)
            
            if widget.volumeShowIcon {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: isSimulator ? widget.fontSize - 2 : widget.fontSize))
                    .foregroundColor(Color(hex: widget.textColorHex))
            }
        }
        .padding(.horizontal, isSimulator ? 8 : 12)
        .padding(.vertical, isSimulator ? 5 : 6)
        .background(Color(hex: widget.backgroundColorHex).opacity(0.15))
        .cornerRadius(6)
        .onAppear {
            volume = getSystemVolume()
        }
    }
    
    private func getSystemVolume() -> Double {
        var error: NSDictionary?
        if let script = NSAppleScript(source: "output volume of (get volume settings)") {
            let descriptor = script.executeAndReturnError(&error)
            return Double(descriptor.int32Value)
        }
        return 50.0
    }
    
    private func setSystemVolume(_ val: Int) {
        DispatchQueue.global(qos: .userInitiated).async {
            let scriptString = "set volume output volume \(val)"
            if let script = NSAppleScript(source: scriptString) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
            }
        }
    }
}

public struct WidgetBrightnessButtonsView: View {
    let widget: TouchBarWidget
    let state: AppState
    let isSimulator: Bool
    
    public var body: some View {
        HStack(spacing: 4) {
            Button(action: {
                executeBrightnessChange(up: false)
            }) {
                Image(systemName: "sun.min.fill")
                    .font(.system(size: isSimulator ? widget.fontSize - 3 : widget.fontSize - 1))
                    .foregroundColor(Color(hex: widget.textColorHex))
                    .frame(width: isSimulator ? widget.brightnessButtonSize : 30, height: isSimulator ? widget.brightnessButtonSize : 24)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                executeBrightnessChange(up: true)
            }) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: isSimulator ? widget.fontSize - 3 : widget.fontSize - 1))
                    .foregroundColor(Color(hex: widget.textColorHex))
                    .frame(width: isSimulator ? widget.brightnessButtonSize : 30, height: isSimulator ? widget.brightnessButtonSize : 24)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, isSimulator ? 4 : 6)
        .padding(.vertical, isSimulator ? 3 : 4)
        .background(Color(hex: widget.backgroundColorHex).opacity(0.15))
        .cornerRadius(6)
    }
    
    private func executeBrightnessChange(up: Bool) {
        DispatchQueue.global(qos: .userInitiated).async {
            SystemUtils.adjustBrightness(up: up)
        }
    }
}
