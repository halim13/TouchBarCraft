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

public struct WidgetBatteryIconView: View {
    let widget: TouchBarWidget
    let state: AppState
    let isSimulator: Bool
    
    @State private var currentFrameIndex: Int = 0
    @State private var timer: Timer? = nil
    @State private var activeFrames: [NSImage] = []
    @State private var activePath: String = ""
    
    public var body: some View {
        Group {
            if !activeFrames.isEmpty {
                if let nsImg = activeFrames[safe: currentFrameIndex % activeFrames.count] {
                    Image(nsImage: nsImg)
                        .resizable()
                        .scaledToFit()
                        .frame(width: isSimulator ? 18 : 22, height: isSimulator ? 18 : 22)
                } else {
                    fallbackIcon
                }
            } else if !activePath.isEmpty, let nsImg = NSImage(contentsOfFile: activePath) {
                Image(nsImage: nsImg)
                    .resizable()
                    .scaledToFit()
                    .frame(width: isSimulator ? 18 : 22, height: isSimulator ? 18 : 22)
            } else {
                fallbackIcon
            }
        }
        .onAppear {
            updateIcon()
        }
        .onChange(of: state.batteryLevel) { updateIcon() }
        .onChange(of: state.isBatteryCharging) { updateIcon() }
        .onChange(of: state.isBatteryFull) { updateIcon() }
        .onChange(of: widget.batteryChargingIcon) { updateIcon() }
        .onChange(of: widget.batteryFullIcon) { updateIcon() }
        .onChange(of: widget.batteryLowIcon) { updateIcon() }
        .onChange(of: widget.batteryNormalIcon) { updateIcon() }
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
            name = widget.iconName.isEmpty ? "battery.75" : widget.iconName
        }
        return Image(systemName: name)
            .font(.system(size: isSimulator ? widget.fontSize - 2 : widget.fontSize))
            .foregroundColor(state.batteryLevel <= widget.batteryLowThreshold ? .rose : Color(hex: widget.textColorHex))
    }
    
    private func updateIcon() {
        let path: String
        if state.isBatteryCharging && !widget.batteryChargingIcon.isEmpty {
            path = widget.batteryChargingIcon
        } else if state.batteryLevel <= widget.batteryLowThreshold && !widget.batteryLowIcon.isEmpty {
            path = widget.batteryLowIcon
        } else if (state.batteryLevel >= widget.batteryFullThreshold || state.isBatteryFull) && !widget.batteryFullIcon.isEmpty {
            path = widget.batteryFullIcon
        } else if !widget.batteryNormalIcon.isEmpty {
            path = widget.batteryNormalIcon
        } else {
            path = ""
        }
        
        guard path != activePath else { return }
        activePath = path
        
        timer?.invalidate()
        timer = nil
        
        guard !path.isEmpty else {
            activeFrames = []
            return
        }
        
        if path.lowercased().hasSuffix(".gif") {
            activeFrames = SystemUtils.extractGifFrames(from: path)
            if !activeFrames.isEmpty {
                currentFrameIndex = 0
                timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [self] _ in
                    Task { @MainActor in
                        self.currentFrameIndex += 1
                    }
                }
            }
        } else {
            activeFrames = []
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
        HStack(spacing: 6) {
            if widget.monitorType == .battery && widget.batteryDisplayType == .textOnly {
                Text("\(state.batteryLevel)%")
                    .font(.system(size: isSimulator ? widget.fontSize - 1 : widget.fontSize, weight: .bold, design: .monospaced))
                    .foregroundColor(state.batteryLevel <= widget.batteryLowThreshold ? .rose : Color(hex: widget.textColorHex))
            } else {
                if widget.monitorType == .battery {
                    WidgetBatteryIconView(widget: widget, state: state, isSimulator: isSimulator)
                } else {
                    Image(systemName: widget.iconName)
                        .font(.system(size: isSimulator ? widget.fontSize - 2 : widget.fontSize))
                        .foregroundColor(Color(hex: widget.textColorHex))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.0f%% %@", value, suffix))
                        .font(.system(size: isSimulator ? widget.fontSize - 3 : widget.fontSize - 2, design: .monospaced))
                        .foregroundColor(Color(hex: widget.textColorHex))
                    
                    // Value progress bar
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
        }
        .padding(.horizontal, isSimulator ? 8 : 12)
        .padding(.vertical, isSimulator ? 5 : 6)
        .background(Color(hex: widget.backgroundColorHex).opacity(0.15))
        .cornerRadius(6)
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
                        .frame(width: isSimulator ? 30 : 40, height: isSimulator ? 20 : 30)
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
    
    public var body: some View {
        let anki = state.ankiState
        
        HStack(spacing: 8) {
            if !anki.isConnected {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.stack.fill.badge.person.crop")
                        .font(.system(size: isSimulator ? 11 : 13))
                    Text("Anki Offline")
                        .font(.system(size: isSimulator ? 11 : 13, weight: .medium))
                    Button("Connect") {
                        anki.checkConnection()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: isSimulator ? 9 : 11))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: widget.backgroundColorHex))
                    .cornerRadius(4)
                }
            } else {
                // Sync status indicator/button
                HStack(alignment: .center, spacing: 4) {
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
                    
                    if anki.isSyncing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                    }
                }
                
                if anki.currentCard == nil {
                    Text("Anki: Select Deck")
                        .font(.system(size: isSimulator ? widget.fontSize - 1 : widget.fontSize, weight: .medium))
                } else if !anki.isShowingAnswer {
                    (
                        Text("Q: ")
                            .font(.system(size: isSimulator ? widget.fontSize - 1 : widget.fontSize, weight: .medium))
                        + parseBoldTags(in: anki.questionPreview, defaultColor: Color(hex: widget.textColorHex), boldColor: Color(hex: widget.ankiBoldColorHex), fontSize: isSimulator ? widget.fontSize - 1 : widget.fontSize)
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: isSimulator ? widget.ankiTextMaxWidth * 0.48 : widget.ankiTextMaxWidth, alignment: .leading)
                    
                    Button(action: {
                        anki.revealAnswer()
                    }) {
                        Text("Reveal ▶")
                            .font(.system(size: isSimulator ? widget.fontSize - 2 : widget.fontSize - 1, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: widget.backgroundColorHex))
                            .foregroundColor(Color(hex: widget.textColorHex))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                } else {
                    (
                        Text("A: ")
                            .font(.system(size: isSimulator ? widget.fontSize - 1 : widget.fontSize, weight: .medium))
                        + parseBoldTags(in: anki.answerPreview, defaultColor: Color(hex: widget.textColorHex), boldColor: Color(hex: widget.ankiBoldColorHex), fontSize: isSimulator ? widget.fontSize - 1 : widget.fontSize)
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: isSimulator ? widget.ankiTextMaxWidth * 0.48 : widget.ankiTextMaxWidth, alignment: .leading)
                    
                    HStack(spacing: 4) {
                        let count = anki.currentCard?.buttonCount ?? 4
                        let buttons = getRatingButtons(for: widget, buttonCount: count)
                        
                        ForEach(buttons, id: \.rating) { btn in
                            Button(action: {
                                anki.submitRating(ease: btn.rating)
                            }) {
                                Text(btn.title)
                                    .font(.system(size: isSimulator ? widget.fontSize - 3 : widget.fontSize - 1, weight: .bold))
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
            }
        }
        .padding(.horizontal, isSimulator ? 8 : 12)
        .padding(.vertical, isSimulator ? 5 : 6)
        .background(Color(hex: widget.backgroundColorHex).opacity(0.15))
        .cornerRadius(6)
    }
    
    private func parseBoldTags(in text: String, defaultColor: Color, boldColor: Color, fontSize: CGFloat) -> Text {
        var parts: [Text] = []
        let components = text.components(separatedBy: "<b>")
        for (index, component) in components.enumerated() {
            if index == 0 {
                parts.append(Text(component).foregroundColor(defaultColor).font(.system(size: fontSize)))
            } else {
                let subParts = component.components(separatedBy: "</b>")
                if subParts.count > 1 {
                    parts.append(Text(subParts[0]).bold().foregroundColor(boldColor).font(.system(size: fontSize)))
                    let regularText = subParts.dropFirst().joined(separator: "</b>")
                    parts.append(Text(regularText).foregroundColor(defaultColor).font(.system(size: fontSize)))
                } else {
                    parts.append(Text("<b>" + component).foregroundColor(defaultColor).font(.system(size: fontSize)))
                }
            }
        }
        return parts.reduce(Text("")) { $0 + $1 }
    }
    
    private func getRatingButtons(for widget: TouchBarWidget, buttonCount: Int) -> [(title: String, rating: Int, color: Color)] {
        var result: [(title: String, rating: Int, color: Color)] = []
        
        // Anki ease ratings: 1=Again, 2=Hard, 3=Good, 4=Easy
        if buttonCount == 2 {
            if widget.ankiShowAgain {
                result.append((title: "Again", rating: 1, color: .red))
            }
            if widget.ankiShowGood {
                result.append((title: "Good", rating: 3, color: .green))
            }
        } else if buttonCount == 3 {
            if widget.ankiShowAgain {
                result.append((title: "Again", rating: 1, color: .red))
            }
            if widget.ankiShowGood {
                result.append((title: "Good", rating: 3, color: .green))
            }
            if widget.ankiShowEasy {
                result.append((title: "Easy", rating: 4, color: .blue))
            }
        } else {
            if widget.ankiShowAgain {
                result.append((title: "Again", rating: 1, color: .red))
            }
            if widget.ankiShowHard {
                result.append((title: "Hard", rating: 2, color: .orange))
            }
            if widget.ankiShowGood {
                result.append((title: "Good", rating: 3, color: .green))
            }
            if widget.ankiShowEasy {
                result.append((title: "Easy", rating: 4, color: .blue))
            }
        }
        
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
            Image(systemName: "speaker.fill")
                .font(.system(size: isSimulator ? widget.fontSize - 2 : widget.fontSize))
                .foregroundColor(Color(hex: widget.textColorHex))
            
            Slider(value: $volume, in: 0...100, onEditingChanged: { _ in
                setSystemVolume(Int(volume))
            })
            .frame(width: isSimulator ? widget.volumeSliderWidth * 0.6 : widget.volumeSliderWidth)
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: isSimulator ? widget.fontSize - 2 : widget.fontSize))
                .foregroundColor(Color(hex: widget.textColorHex))
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
