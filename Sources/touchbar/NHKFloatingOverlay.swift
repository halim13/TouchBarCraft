import SwiftUI
import AppKit

// MARK: - NHK Floating Window Manager

private enum FKC: String {
    case enabled, fontSize, textColorHex, furiganaFontSize, furiganaColorHex
    case windowWidth, windowHeight, windowX, windowY
    var key: String { "NHKF_\(rawValue)" }
}

@MainActor
@Observable
public final class NHKFloatingWindowManager: NSObject {
    public static let shared = NHKFloatingWindowManager()

    private let defaults = UserDefaults.standard

    // -- Config --
    public var isEnabled: Bool {
        get { defaults.bool(forKey: FKC.enabled.key) }
        set { defaults.set(newValue, forKey: FKC.enabled.key) }
    }

    public var fontSize: Double {
        get { max(10, defaults.double(forKey: FKC.fontSize.key).nonZero ?? 16) }
        set { defaults.set(newValue, forKey: FKC.fontSize.key) }
    }

    public var textColorHex: String {
        get { defaults.string(forKey: FKC.textColorHex.key) ?? "#FFFFFF" }
        set { defaults.set(newValue, forKey: FKC.textColorHex.key) }
    }

    public var furiganaFontSize: Double {
        get { defaults.double(forKey: FKC.furiganaFontSize.key) }
        set { defaults.set(newValue, forKey: FKC.furiganaFontSize.key) }
    }

    public var furiganaColorHex: String {
        get { defaults.string(forKey: FKC.furiganaColorHex.key) ?? "#FFD60A" }
        set { defaults.set(newValue, forKey: FKC.furiganaColorHex.key) }
    }

    // -- Window state --
    public var isShowing: Bool = false
    private var overlayWindow: NSPanel?
    private var host: NHKFloatingOverlayHost?
    private var isProgrammaticResize: Bool = false

    private override init() {
        super.init()
    }

    public func toggle() {
        if isShowing {
            hide()
        } else {
            if !isEnabled { isEnabled = true }
            show()
        }
    }

    public func show() {
        guard isEnabled else { return }
        if overlayWindow == nil {
            createWindow()
        }
        overlayWindow?.orderFront(nil)
        isShowing = true
        host?.refreshContent()
    }

    public func hide() {
        overlayWindow?.orderOut(nil)
        isShowing = false
    }

    public func refreshContent() {
        guard isShowing else { return }
        host?.refreshContent()
    }

    private func createWindow() {
        let defaultWidth: CGFloat = 500
        let defaultHeight: CGFloat = 400
        let defaultX: CGFloat
        let defaultY: CGFloat
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            defaultX = frame.midX - defaultWidth / 2
            defaultY = frame.minY + 80
        } else {
            defaultX = 400
            defaultY = 80
        }

        let styleMask: NSWindow.StyleMask = [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView]
        let savedWidth = CGFloat(defaults.double(forKey: FKC.windowWidth.key)).clamped(to: 300...1200, default: defaultWidth)
        let savedHeight = CGFloat(defaults.double(forKey: FKC.windowHeight.key)).clamped(to: 200...800, default: defaultHeight)
        let savedX = CGFloat(defaults.double(forKey: FKC.windowX.key))
        let savedY = CGFloat(defaults.double(forKey: FKC.windowY.key))

        let contentRect = NSRect(
            x: savedX > 0 ? savedX : defaultX,
            y: savedY > 0 ? savedY : defaultY,
            width: savedWidth,
            height: savedHeight
        )

        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.title = "NHK Easy News"
        panel.titleVisibility = .hidden
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = NSColor.clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.delegate = self

        let h = NHKFloatingOverlayHost()
        self.host = h

        let hostingView = NSHostingView(rootView: NHKFloatingContentView(host: h))
        hostingView.frame = contentRect
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        self.overlayWindow = panel
    }

    private func saveWindowFrame() {
        guard let panel = overlayWindow else { return }
        defaults.set(panel.frame.width, forKey: FKC.windowWidth.key)
        defaults.set(panel.frame.height, forKey: FKC.windowHeight.key)
        defaults.set(panel.frame.origin.x, forKey: FKC.windowX.key)
        defaults.set(panel.frame.origin.y, forKey: FKC.windowY.key)
    }
}

// MARK: - NSPanel Delegate

extension NHKFloatingWindowManager: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        isShowing = false
        saveWindowFrame()
    }

    public func windowDidResize(_ notification: Notification) {
        guard !isProgrammaticResize else { return }
        saveWindowFrame()
    }

    public func windowDidMove(_ notification: Notification) {
        saveWindowFrame()
    }
}

// MARK: - Floating Overlay Host (Observable)

@MainActor
public final class NHKFloatingOverlayHost: ObservableObject {
    @Published public var title: String = ""
    @Published public var chunks: [String] = []
    @Published public var currentIndex: Int = 0
    @Published public var isAudioAvailable: Bool = false
    @Published public var isAudioPlaying: Bool = false
    @Published public var articleCount: Int = 0
    @Published public var currentArticleIndex: Int = 0
    @Published public var isReadingMode: Bool = false
    @Published public var articleTitles: [(index: Int, title: String, description: String)] = []
    @Published public var articleURL: URL?

    public var nhkState: NHKNewsState? {
        AppState.shared?.nhkNewsState
    }

    public func refreshContent() {
        guard let nhk = nhkState else { return }
        title = nhk.currentArticle?.title ?? ""
        chunks = (nhk.currentArticle?.contentChunks ?? []).filter { !isFooterChunk($0) }
        currentIndex = nhk.currentChunkIndex
        isAudioAvailable = nhk.isAudioAvailable
        isAudioPlaying = nhk.isAudioPlaying
        articleCount = nhk.articles.count
        currentArticleIndex = nhk.currentArticleIndex
        isReadingMode = nhk.mode == .reading
        articleTitles = nhk.articles.enumerated().map {
            (index: $0.offset, title: $0.element.title, description: $0.element.description)
        }
        articleURL = nhk.currentArticle?.url
    }

    private func isFooterChunk(_ chunk: String) -> Bool {
        let t = chunk.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.contains("original") || t.contains("permalink") { return true }
        if t.hasPrefix("http://") || t.hasPrefix("https://") { return true }
        return false
    }

    public func selectArticle(_ index: Int) {
        guard let nhk = nhkState, index >= 0, index < nhk.articles.count else { return }
        nhk.currentArticleIndex = index
        nhk.currentChunkIndex = 0
        nhk.mode = .articleList
        refreshContent()
    }

    public func previousChunk() { nhkState?.previousChunk(); refreshContent() }
    public func nextChunk() { nhkState?.nextChunk(); refreshContent() }
    public func previousArticle() { nhkState?.previousArticle(); refreshContent() }
    public func nextArticle() { nhkState?.nextArticle(); refreshContent() }
    public func playPauseAudio() { nhkState?.playPauseAudio(); refreshContent() }
    public func stopAudio() { nhkState?.stopAudio(); refreshContent() }
    public func returnToList() { nhkState?.returnToList(); refreshContent() }
}

// MARK: - SwiftUI Content View

public struct NHKFloatingContentView: View {
    @ObservedObject var host: NHKFloatingOverlayHost

    private var fSize: CGFloat { CGFloat(NHKFloatingWindowManager.shared.fontSize) }
    private var fColor: Color { Color(hex: NHKFloatingWindowManager.shared.textColorHex) }
    private var furiSize: CGFloat {
        let s = NHKFloatingWindowManager.shared.furiganaFontSize
        return s > 0 ? max(4, CGFloat(s)) : 0
    }
    private var furiColor: Color { Color(hex: NHKFloatingWindowManager.shared.furiganaColorHex) }

    public var body: some View {
        VStack(spacing: 0) {
            headerView
            articleNavView
            Divider().background(Color.white.opacity(0.1))
            if host.isReadingMode {
                readingContent
                chunkNavView
            } else {
                listContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.9)
        )
        .background(Color.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var headerView: some View {
        if host.isReadingMode, !host.title.isEmpty {
            Text(host.title)
                .font(.system(size: fSize + 2, weight: .bold))
                .foregroundColor(fColor)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 6)

            Divider().background(Color.white.opacity(0.15))
        }
    }

    private var articleNavView: some View {
        HStack(spacing: 8) {
            Button(action: { host.previousArticle() }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .foregroundColor(fColor.opacity(0.7))

            Text("\(host.currentArticleIndex + 1)/\(host.articleCount)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray)

            Button(action: { host.nextArticle() }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .foregroundColor(fColor.opacity(0.7))

            Spacer()

            if host.isAudioAvailable {
                Button(action: { host.playPauseAudio() }) {
                    Image(systemName: host.isAudioPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.plain)
                .foregroundColor(fColor.opacity(0.7))

                Button(action: { host.stopAudio() }) {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.plain)
                .foregroundColor(fColor.opacity(0.7))
            }

            if host.isReadingMode, let url = host.articleURL {
                Button(action: { NSWorkspace.shared.open(url) }) {
                    Image(systemName: "safari")
                }
                .buttonStyle(.plain)
                .foregroundColor(fColor.opacity(0.7))
                .help("Open in Browser")
            }

            Button(action: { host.returnToList() }) {
                Image(systemName: "list.bullet")
            }
            .buttonStyle(.plain)
            .foregroundColor(fColor.opacity(0.7))
        }
        .font(.system(size: 12))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var readingContent: some View {
        ScrollView {
            contentList
        }
    }

    private var listContent: some View {
        ScrollView {
            if host.articleTitles.isEmpty {
                Text("No articles")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(16)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(host.articleTitles, id: \.index) { item in
                        let isCurrent = item.index == host.currentArticleIndex
                        Button(action: {
                            host.selectArticle(item.index)
                            host.nhkState?.startReading()
                        }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: isCurrent ? fSize : max(11, fSize - 1), weight: isCurrent ? .bold : .regular))
                                    .foregroundColor(isCurrent ? fColor : fColor.opacity(0.8))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if !item.description.isEmpty {
                                    Text(item.description)
                                        .font(.system(size: max(9, fSize - 4)))
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(8)
                            .background(isCurrent ? Color.blue.opacity(0.15) : Color.clear)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private var contentList: some View {
        if host.chunks.isEmpty {
            Text("No content")
                .font(.system(size: 13))
                .foregroundColor(.gray)
                .padding(16)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(host.chunks.enumerated()), id: \.offset) { idx, chunk in
                    chunkRow(idx: idx, chunk: chunk)
                }
            }
            .padding(16)
        }
    }

    private func chunkRow(idx: Int, chunk: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if chunk.contains("[") && chunk.contains("]") {
                parseFuriganaWrappingView(in: chunk)
            } else {
                Text(chunk)
                    .font(.system(size: fSize))
                    .foregroundColor(fColor)
            }
        }
        .padding(10)
    }

    private func parseFuriganaWrappingView(in text: String) -> some View {
        let segments = parseRichSegments(from: text)
        let computedFuriFontSize: CGFloat = furiSize > 0 ? max(3, furiSize) : max(4, fSize * 0.25)
        let furiHeight = computedFuriFontSize * 1.4
        return WrappingHStack(spacing: 2, lineSpacing: 4) {
            ForEach(segments) { item in
                if let furi = item.furigana {
                    VStack(spacing: 0) {
                        Text(furi)
                            .font(.system(size: computedFuriFontSize, weight: .medium))
                            .foregroundColor(furiColor.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .fixedSize()
                        Text(item.text)
                            .font(.system(size: fSize, weight: item.isBold ? .bold : .regular))
                            .foregroundColor(item.isBold ? Color(hex: "#FFD60A") : fColor)
                            .if(item.isItalic) { $0.italic() }
                            .if(item.isUnderline) { $0.underline() }
                    }
                } else {
                    Text(item.text)
                        .font(.system(size: fSize, weight: item.isBold ? .bold : .regular))
                        .foregroundColor(item.isBold ? Color(hex: "#FFD60A") : fColor)
                        .if(item.isItalic) { $0.italic() }
                        .if(item.isUnderline) { $0.underline() }
                        .padding(.top, furiHeight)
                }
            }
        }
    }

    @ViewBuilder
    private var chunkNavView: some View {
        if !host.chunks.isEmpty {
            Divider().background(Color.white.opacity(0.1))
            HStack(spacing: 12) {
                Button(action: { host.previousChunk() }) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .foregroundColor(fColor.opacity(0.7))

                Text("\(host.currentIndex + 1)/\(host.chunks.count)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)

                Button(action: { host.nextChunk() }) {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .foregroundColor(fColor.opacity(0.7))
            }
            .font(.system(size: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Helpers

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>, default defaultValue: CGFloat) -> CGFloat {
        if self < range.lowerBound || self > range.upperBound { return defaultValue }
        return self
    }
}

private extension Double {
    /// Returns self if non-zero, otherwise returns the given fallback.
    var nonZero: Double? { self == 0 ? nil : self }
}

// MARK: - Wrapping HStack Layout

struct WrappingHStack: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var currentX: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                totalHeight += currentRowHeight + lineSpacing
                currentX = size.width
                currentRowHeight = size.height
            } else {
                currentX += size.width + spacing
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }
        totalHeight += currentRowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth + bounds.minX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
