import SwiftUI

public struct MainView: View {
    @Bindable var state: AppState
    
    // Curated premium color presets
    private let colorPresets = [
        ("#8B5CF6", "Purple"),
        ("#3B82F6", "Blue"),
        ("#10B981", "Emerald"),
        ("#EF4444", "Red"),
        ("#EC4899", "Pink"),
        ("#F59E0B", "Amber"),
        ("#06B6D4", "Cyan"),
        ("#1E1E24", "Space Gray")
    ]
    
    // Curated premium SF Symbol presets
    private let symbolPresets = [
        "sparkles", "clock", "calendar", "terminal.fill", "cpu", "memorychip",
        "music.note", "speaker.wave.3.fill", "moon.stars.fill", "pawprint.fill",
        "gamecontroller.fill", "battery.100", "house.fill", "gearshape.fill",
        "bell.fill", "envelope.fill"
    ]
    
    // Curated sound presets
    private let soundPresets = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse",
        "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"
    ]
    
    public init(state: AppState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Branding Section
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .teal, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("TouchBarCraft")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("MacBook Pro M2 Touch Bar Customizer")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Status Pills
                HStack(spacing: 8) {
                    StatusPill(icon: "cpu", text: String(format: "CPU: %.0f%%", state.cpuUsage), color: .emerald)
                    StatusPill(icon: "memorychip", text: String(format: "RAM: %.0f%%", state.ramUsage), color: .amber)
                    StatusPill(icon: "battery.75", text: String(format: "BAT: %d%%", state.batteryLevel), color: .cyan)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.15))
            
            Divider()
            
            // 🎹 Virtual Touch Bar Simulator
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("🎹 TOUCH BAR SIMULATOR (CLICK WIDGETS TO TEST)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Active App Layout")
                        .font(.system(size: 9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(4)
                }
                .padding(.horizontal, 20)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(state.widgets) { widget in
                            Group {
                                switch widget.type {
                                case .label:
                                    WidgetLabelView(widget: widget, state: state, isSimulator: true)
                                case .button:
                                    WidgetButtonView(widget: widget, state: state, isSimulator: true)
                                case .systemMonitor:
                                    WidgetSystemMonitorView(widget: widget, state: state, isSimulator: true)
                                case .media:
                                    WidgetMediaView(widget: widget, state: state, isSimulator: true)
                                case .animation:
                                    WidgetAnimationView(widget: widget, state: state, isSimulator: true)
                                case .anki:
                                    WidgetAnkiView(widget: widget, state: state, isSimulator: true)
                                }
                            }
                            .shadow(color: Color(hex: widget.backgroundColorHex).opacity(0.3), radius: 4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(state.selectedWidgetID == widget.id ? Color.purple : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                state.selectedWidgetID = widget.id
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.black)
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
            }
            .padding(.vertical, 16)
            .background(Color.black.opacity(0.05))
            
            Divider()
            
            // Sidebar List + Properties Editor
            HStack(spacing: 0) {
                // Left Column: Widget Sidebar
                VStack(spacing: 0) {
                    HStack {
                        Text("Active Widgets")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        
                        // Add widget menu button
                        Menu {
                            Button("Text Label") { state.addWidget(.label) }
                            Button("Button (Action)") { state.addWidget(.button) }
                            Button("System Monitor") { state.addWidget(.systemMonitor) }
                            Button("Media Controls") { state.addWidget(.media) }
                            Button("Animation Presets") { state.addWidget(.animation) }
                            Button("Anki Review") { state.addWidget(.anki) }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.purple)
                        }
                        .menuStyle(.borderlessButton)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    
                    if state.widgets.isEmpty {
                        VStack(spacing: 8) {
                            Text("No widgets active.")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            
                            Button("Load Defaults") {
                                state.loadDefaultWidgets()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .controlSize(.small)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(Array(state.widgets.enumerated()), id: \.element.id) { index, widget in
                                HStack(spacing: 8) {
                                    Image(systemName: widget.iconName)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: widget.backgroundColorHex))
                                        .frame(width: 16)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(widget.title.isEmpty ? "Untitled" : widget.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text(widget.type.rawValue)
                                            .font(.system(size: 9))
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    // Move buttons
                                    HStack(spacing: 4) {
                                        Button(action: {
                                            moveUp(index: index)
                                        }) {
                                            Image(systemName: "chevron.up")
                                                .font(.system(size: 8))
                                                .foregroundColor(index == 0 ? .gray : .white)
                                        }
                                        .disabled(index == 0)
                                        .buttonStyle(.plain)
                                        
                                        Button(action: {
                                            moveDown(index: index)
                                        }) {
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 8))
                                                .foregroundColor(index == state.widgets.count - 1 ? .gray : .white)
                                        }
                                        .disabled(index == state.widgets.count - 1)
                                        .buttonStyle(.plain)
                                        
                                        Button(action: {
                                            state.deleteWidget(id: widget.id)
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 10))
                                                .foregroundColor(.red.opacity(0.8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(state.selectedWidgetID == widget.id ? Color.purple.opacity(0.15) : Color.clear)
                                .cornerRadius(6)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    state.selectedWidgetID = widget.id
                                }
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6))
                            }
                        }
                        .listStyle(.plain)
                    }
                }
                .frame(width: 250)
                .background(Color.black.opacity(0.1))
                
                Divider()
                
                // Right Column: Widget Configuration Details Editor
                ScrollView {
                    if let selectedID = state.selectedWidgetID,
                       let index = state.widgets.firstIndex(where: { $0.id == selectedID }) {
                        let widget = state.widgets[index]
                        
                        VStack(alignment: .leading, spacing: 18) {
                            Text("🔧 WIDGET CONFIGURATION")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            
                            // Section 1: General Properties Card
                            VStack(alignment: .leading, spacing: 12) {
                                Text("General properties")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.purple)
                                
                                HStack(spacing: 8) {
                                    Text("Display Text:")
                                        .font(.system(size: 11))
                                        .frame(width: 80, alignment: .leading)
                                    TextField("Widget label/title", text: Binding(
                                        get: { widget.title },
                                        set: { state.widgets[index].title = $0; state.saveConfig() }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                }
                                
                                HStack(spacing: 8) {
                                    Text("Icon Name:")
                                        .font(.system(size: 11))
                                        .frame(width: 80, alignment: .leading)
                                    TextField("SF Symbol name", text: Binding(
                                        get: { widget.iconName },
                                        set: { state.widgets[index].iconName = $0; state.saveConfig() }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    
                                    Image(systemName: widget.iconName)
                                        .font(.system(size: 14))
                                        .frame(width: 20, height: 20)
                                        .background(Color.black.opacity(0.2))
                                        .cornerRadius(4)
                                }
                                
                                // SF Symbol Presets Selection
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Select preset icon:")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                    
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                                        ForEach(symbolPresets, id: \.self) { symbol in
                                            Button(action: {
                                                state.widgets[index].iconName = symbol
                                                state.saveConfig()
                                            }) {
                                                Image(systemName: symbol)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(widget.iconName == symbol ? .purple : .white)
                                                    .frame(width: 24, height: 24)
                                                    .background(Color.white.opacity(0.08))
                                                    .cornerRadius(4)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
                            
                            // Section 2: Colors Card
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Aesthetic customization")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.teal)
                                
                                HStack(spacing: 8) {
                                    Text("Background HEX:")
                                        .font(.system(size: 11))
                                        .frame(width: 100, alignment: .leading)
                                    TextField("#HEX (Bg)", text: Binding(
                                        get: { widget.backgroundColorHex },
                                        set: { state.widgets[index].backgroundColorHex = $0; state.saveConfig() }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    
                                    ColorPicker("", selection: Binding(
                                        get: { Color(hex: widget.backgroundColorHex) },
                                        set: { color in
                                            if let hexString = color.toHex() {
                                                state.widgets[index].backgroundColorHex = hexString
                                                state.saveConfig()
                                            }
                                        }
                                    ))
                                }
                                
                                HStack(spacing: 8) {
                                    Text("Text HEX:")
                                        .font(.system(size: 11))
                                        .frame(width: 100, alignment: .leading)
                                    TextField("#HEX (Text)", text: Binding(
                                        get: { widget.textColorHex },
                                        set: { state.widgets[index].textColorHex = $0; state.saveConfig() }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    
                                    ColorPicker("", selection: Binding(
                                        get: { Color(hex: widget.textColorHex) },
                                        set: { color in
                                            if let hexString = color.toHex() {
                                                state.widgets[index].textColorHex = hexString
                                                state.saveConfig()
                                            }
                                        }
                                    ))
                                }
                                
                                // Color Presets Grid
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Curated preset colors:")
                                        .font(.system(size: 10))
                                        .foregroundColor(.gray)
                                    
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                                        ForEach(colorPresets, id: \.0) { hex, label in
                                            Button(action: {
                                                state.widgets[index].backgroundColorHex = hex
                                                state.saveConfig()
                                            }) {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color(hex: hex))
                                                    .frame(height: 20)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 4)
                                                            .stroke(widget.backgroundColorHex.lowercased() == hex.lowercased() ? Color.white : Color.clear, lineWidth: 1.5)
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                            .help(label)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
                            
                            // Section 3: Widget-Type-Specific Options
                            VStack(alignment: .leading, spacing: 12) {
                                Text("\(widget.type.rawValue) Options")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.pink)
                                
                                switch widget.type {
                                case .label:
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("💡 Placeholder Guide:")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.purple)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            PlaceholderTip(code: "{time}", desc: "Local 24h Clock (e.g. 14:35:02)")
                                            PlaceholderTip(code: "{date}", desc: "Current Calendar Date (e.g. Mon, 25 May)")
                                            PlaceholderTip(code: "{cpu}", desc: "Live active CPU percentage")
                                            PlaceholderTip(code: "{ram}", desc: "Physical RAM utilization percentage")
                                            PlaceholderTip(code: "{battery}", desc: "MacBook battery charge percentage")
                                        }
                                    }
                                    
                                case .button:
                                    VStack(alignment: .leading, spacing: 10) {
                                        Picker("Button Action:", selection: Binding(
                                            get: { widget.actionType },
                                            set: { state.widgets[index].actionType = $0; state.saveConfig() }
                                        )) {
                                            ForEach(ActionType.allCases, id: \.self) { type in
                                                Text(type.rawValue).tag(type)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        
                                        if widget.actionType == .shellCommand {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Shell command to run:")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.gray)
                                                
                                                TextEditor(text: Binding(
                                                    get: { widget.actionValue },
                                                    set: { state.widgets[index].actionValue = $0; state.saveConfig() }
                                                ))
                                                .font(.system(size: 10, design: .monospaced))
                                                .frame(height: 50)
                                                .padding(4)
                                                .background(Color.black.opacity(0.3))
                                                .cornerRadius(4)
                                                
                                                Text("e.g. 'open -a Safari', 'say Done', or a path to a script")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.gray)
                                            }
                                        } else if widget.actionType == .playSound {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Sound Effect Name:")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.gray)
                                                
                                                Picker("Select Sound", selection: Binding(
                                                    get: { soundPresets.contains(widget.actionValue) ? widget.actionValue : "Glass" },
                                                    set: { state.widgets[index].actionValue = $0; state.saveConfig() }
                                                )) {
                                                    ForEach(soundPresets, id: \.self) { sound in
                                                        Text(sound).tag(sound)
                                                    }
                                                }
                                                .pickerStyle(.menu)
                                                
                                                Button("🎵 Test Sound Now") {
                                                    NSSound(named: widget.actionValue)?.play()
                                                }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                                .padding(.top, 4)
                                            }
                                        } else {
                                            Text("No additional arguments needed.")
                                                .font(.system(size: 10))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                case .systemMonitor:
                                    Picker("System Resource:", selection: Binding(
                                        get: { widget.monitorType },
                                        set: { state.widgets[index].monitorType = $0; state.saveConfig() }
                                    )) {
                                        ForEach(MonitorType.allCases, id: \.self) { monitor in
                                            Text(monitor.rawValue).tag(monitor)
                                        }
                                    }
                                    .pickerStyle(.radioGroup)
                                    
                                case .media:
                                    Text("Fully automatic system widget. Renders interactive Backward, Play/Pause, and Forward keys that communicate directly with Apple Music, Spotify, or default macOS media listeners.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                        .lineSpacing(4)
                                    
                                case .animation:
                                    VStack(alignment: .leading, spacing: 10) {
                                        Picker("Animation Preset:", selection: Binding(
                                            get: { widget.animationType },
                                            set: { state.widgets[index].animationType = $0; state.saveConfig() }
                                        )) {
                                            ForEach(AnimationPreset.allCases, id: \.self) { anim in
                                                Text(anim.rawValue).tag(anim)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text("Frame Interval Speed:")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.gray)
                                                Spacer()
                                                Text(String(format: "%.2fs", widget.animationSpeed))
                                                    .font(.system(size: 10, design: .monospaced))
                                                    .foregroundColor(.white)
                                            }
                                            
                                            Slider(value: Binding(
                                                get: { widget.animationSpeed },
                                                set: { state.widgets[index].animationSpeed = $0; state.saveConfig() }
                                            ), in: 0.05...1.0, step: 0.05)
                                        }
                                    }
                                case .anki:
                                    AnkiConfigView(widget: widget, index: index, state: state)
                                }
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
                            
                            Spacer()
                        }
                        .padding(20)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 28))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("Select a widget in the sidebar or simulator to configure properties.")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .background(Color(red: 18/255, green: 18/255, blue: 20/255)) // Obsidan Gray
    }
    
    // Sidebar move helpers
    private func moveUp(index: Int) {
        guard index > 0 else { return }
        state.widgets.swapAt(index, index - 1)
        state.saveConfig()
    }
    
    private func moveDown(index: Int) {
        guard index < state.widgets.count - 1 else { return }
        state.widgets.swapAt(index, index + 1)
        state.saveConfig()
    }
}

// MARK: - Extra Subviews & Helpers

private struct StatusPill: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 9, design: .monospaced))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct PlaceholderTip: View {
    let code: String
    let desc: String
    
    var body: some View {
        HStack(spacing: 6) {
            Text(code)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.purple)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.15))
                .cornerRadius(4)
            
            Text(desc)
                .font(.system(size: 9))
                .foregroundColor(.gray)
        }
    }
}

// Color Hex exporter helper
private extension Color {
    func toHex() -> String? {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return nil }
        let r = Int(rgbColor.redComponent * 255.0)
        let g = Int(rgbColor.greenComponent * 255.0)
        let b = Int(rgbColor.blueComponent * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// Extra color definitions
private extension Color {
    static let emerald = Color(red: 16/255, green: 185/255, blue: 129/255)
    static let amber = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let cyan = Color(red: 6/255, green: 182/255, blue: 212/255)
}

struct AnkiConfigView: View {
    let widget: TouchBarWidget
    let index: Int
    let state: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Connection Status:")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                if state.ankiState.isConnected {
                    Text("Connected")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                } else {
                    Text("Disconnected")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                }
            }
            
            if !state.ankiState.isConnected {
                Text("Ensure Anki is open and AnkiConnect add-on is installed.")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                
                Button("Reconnect") {
                    state.ankiState.checkConnection()
                    state.ankiState.fetchDecks()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                // Deck Selection
                VStack(alignment: .leading, spacing: 6) {
                    Text("Deck Selection")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    Picker("Deck Name:", selection: Binding(
                        get: { widget.ankiDeckName },
                        set: { deck in
                            state.widgets[index].ankiDeckName = deck
                            state.saveConfig()
                            state.ankiState.startReview(deck: deck)
                        }
                    )) {
                        Text("Select a deck...").tag("")
                        ForEach(state.ankiState.deckNames, id: \.self) { deck in
                            Text(deck).tag(deck)
                        }
                    }
                    .pickerStyle(.menu)
                    .onAppear {
                        state.ankiState.fetchDecks()
                    }
                    
                    HStack(spacing: 8) {
                        Button("🔄 Refresh Decks") {
                            state.ankiState.fetchDecks()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("📤 Sync AnkiWeb") {
                            state.ankiState.syncDecks()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .controlSize(.small)
                    }
                }
                
                Divider()
                
                // Custom Fields mapping
                VStack(alignment: .leading, spacing: 8) {
                    Text("Card Fields Mapping")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    HStack {
                        Text("Question Field:")
                            .font(.system(size: 11))
                            .frame(width: 95, alignment: .leading)
                        TextField("e.g. Front", text: Binding(
                            get: { widget.ankiQuestionField },
                            set: { val in
                                state.widgets[index].ankiQuestionField = val
                                state.saveConfig()
                                Task {
                                    await state.ankiState.loadCurrentCard()
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                    }
                    
                    HStack {
                        Text("Answer Field:")
                            .font(.system(size: 11))
                            .frame(width: 95, alignment: .leading)
                        TextField("e.g. Back", text: Binding(
                            get: { widget.ankiAnswerField },
                            set: { val in
                                state.widgets[index].ankiAnswerField = val
                                state.saveConfig()
                                Task {
                                    await state.ankiState.loadCurrentCard()
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                    }
                    
                    Text("Falls back to standard 'Front'/'Back' if fields aren't found on the card.")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .italic()
                }
                
                Divider()
                
                // Selectable Answers/Buttons
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enabled Touch Bar Answer Buttons")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Again (1)", isOn: Binding(
                            get: { widget.ankiShowAgain },
                            set: { val in
                                state.widgets[index].ankiShowAgain = val
                                state.saveConfig()
                                state.ankiState.refreshTouchBar()
                            }
                        ))
                        .toggleStyle(.checkbox)
                        
                        Toggle("Hard (2)", isOn: Binding(
                            get: { widget.ankiShowHard },
                            set: { val in
                                state.widgets[index].ankiShowHard = val
                                state.saveConfig()
                                state.ankiState.refreshTouchBar()
                            }
                        ))
                        .toggleStyle(.checkbox)
                        
                        Toggle("Good (3)", isOn: Binding(
                            get: { widget.ankiShowGood },
                            set: { val in
                                state.widgets[index].ankiShowGood = val
                                state.saveConfig()
                                state.ankiState.refreshTouchBar()
                            }
                        ))
                        .toggleStyle(.checkbox)
                        
                        Toggle("Easy (4)", isOn: Binding(
                            get: { widget.ankiShowEasy },
                            set: { val in
                                state.widgets[index].ankiShowEasy = val
                                state.saveConfig()
                                state.ankiState.refreshTouchBar()
                            }
                        ))
                        .toggleStyle(.checkbox)
                    }
                    .font(.system(size: 11))
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review Stats:")
                        .font(.system(size: 11, weight: .bold))
                    HStack {
                        Text("Cards Reviewed:")
                        Spacer()
                        Text("\(state.ankiState.cardsReviewed)")
                            .fontWeight(.bold)
                    }
                    HStack {
                        Text("Time Elapsed:")
                        Spacer()
                        Text(state.ankiState.sessionDuration)
                            .fontWeight(.bold)
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(.gray)
            }
        }
    }
}
