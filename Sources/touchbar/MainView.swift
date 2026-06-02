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
                
                GeometryReader { geometry in
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
                                    case .volumeSlider:
                                        WidgetVolumeSliderView(widget: widget, state: state, isSimulator: true)
                                    case .brightnessButtons:
                                        WidgetBrightnessButtonsView(widget: widget, state: state, isSimulator: true)
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
                            
                            if !state.widgets.isEmpty {
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(minWidth: geometry.size.width, alignment: .leading)
                    }
                }                
                .frame(height: 40)
            }
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.05))
            .padding(.vertical, 16)
            
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
                            Button("Volume Slider") { state.addWidget(.volumeSlider) }
                            Button("Brightness Controls") { state.addWidget(.brightnessButtons) }
                            Divider()
                            Button("Paste Widget from JSON") {
                                let pasteboard = NSPasteboard.general
                                if let json = pasteboard.string(forType: .string) {
                                    let success = state.pasteWidgetFromJSON(json)
                                    if !success {
                                        print("Failed to paste widget — clipboard doesn't contain valid widget JSON")
                                    }
                                }
                            }
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
                                    
                                    // Action buttons
                                    HStack(spacing: 4) {
                                        // Copy JSON to clipboard
                                        Button(action: {
                                            let json = state.copyWidgetAsJSON(widget)
                                            if !json.isEmpty {
                                                let pasteboard = NSPasteboard.general
                                                pasteboard.clearContents()
                                                pasteboard.setString(json, forType: .string)
                                            }
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 9))
                                                .foregroundColor(.teal.opacity(0.8))
                                                .frame(width: 14, height: 14)
                                        }
                                        .buttonStyle(.plain)
                                        .help("Copy widget as JSON")
                                        
                                        let isFirst = index == 0
                                        Button(action: {
                                            withAnimation { moveUp(index: index) }
                                        }) {
                                            Image(systemName: "chevron.up")
                                                .font(.system(size: 9))
                                                .foregroundColor(isFirst ? .gray : .white)
                                                .frame(width: 14, height: 14)
                                        }
                                        .disabled(isFirst)
                                        .buttonStyle(.plain)
                                        
                                        let isLast = index == state.widgets.count - 1
                                        Button(action: {
                                            withAnimation { moveDown(index: index) }
                                        }) {
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 9))
                                                .foregroundColor(isLast ? .gray : .white)
                                                .frame(width: 14, height: 14)
                                        }
                                        .disabled(isLast)
                                        .buttonStyle(.plain)
                                        
                                        Button(action: {
                                            state.deleteWidget(id: widget.id)
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 10))
                                                .foregroundColor(.red.opacity(0.8))
                                                .frame(width: 14, height: 14)
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
                    
                    Divider()
                    
                    Button(action: {
                        state.selectedWidgetID = nil
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 12))
                            Text("App Settings & Autostart")
                                .font(.system(size: 11, weight: .bold))
                            Spacer()
                            if state.selectedWidgetID == nil {
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .contentShape(Rectangle())
                        .foregroundColor(state.selectedWidgetID == nil ? .purple : .white)
                        .background(state.selectedWidgetID == nil ? Color.purple.opacity(0.12) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 250)
                .background(Color.black.opacity(0.1))
                
                Divider()
                
                // Right Column: Widget Configuration Details Editor
                ScrollView {
                    if let selectedID = state.selectedWidgetID,
                       let index = state.widgets.firstIndex(where: { $0.id == selectedID }) {
                        let widget = state.widgets[index]
                        let isVolumeSlider = widget.type == .volumeSlider
                        let bgHexLabel = isVolumeSlider ? "Slider HEX:" : "Background HEX:"
                        let bgHexPlaceholder = isVolumeSlider ? "#HEX (Slider)" : "#HEX (Bg)"
                        
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
                                    Text(bgHexLabel)
                                        .font(.system(size: 11))
                                        .frame(width: 100, alignment: .leading)
                                    TextField(bgHexPlaceholder, text: Binding(
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
                                
                                 if !isVolumeSlider {
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
                                     
                                     HStack(spacing: 8) {
                                         Text("Font Size:")
                                             .font(.system(size: 11))
                                             .frame(width: 100, alignment: .leading)
                                         
                                         Slider(value: Binding(
                                             get: { widget.fontSize },
                                             set: { state.widgets[index].fontSize = $0; state.saveConfig() }
                                         ), in: 8...20, step: 1)
                                         
                                         Text("\(Int(widget.fontSize))px")
                                             .font(.system(size: 10, design: .monospaced))
                                             .foregroundColor(.gray)
                                             .frame(width: 35, alignment: .trailing)
                                     }
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
                                
                                WidgetOptionsView(widget: widget, index: index, state: state)
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
                            
                            Spacer()
                        }
                        .padding(20)
                    } else {
                        VStack(alignment: .leading, spacing: 18) {
                            Text("⚙️ APP PREFERENCES & RUNNING")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            
                            // Autostart Card
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Autostart / Launch at Login")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.purple)
                                
                                Text("Automate starting TouchBarCraft when you log in or restart your MacBook.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                    .lineLimit(nil)
                                
                                Toggle("Start TouchBarCraft automatically at Login", isOn: Binding(
                                    get: { state.isLaunchAtLoginEnabled },
                                    set: { state.isLaunchAtLoginEnabled = $0 }
                                ))
                                .toggleStyle(.checkbox)
                                .font(.system(size: 11))
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
                            
                            // Background Running Mode Info Card
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Running in Background & Tray")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.teal)
                                
                                Text("TouchBarCraft is designed to stay alive in the background and control strip tray even when you close the main dashboard window.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                    .lineLimit(nil)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.emerald)
                                            .font(.system(size: 11))
                                        Text("Closing the window will hide the UI but keeps the Touch Bar active.")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white)
                                    }
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.emerald)
                                            .font(.system(size: 11))
                                        Text("Click the Dock icon or status bar tray icon to bring back this window.")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white)
                                    }
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.emerald)
                                            .font(.system(size: 11))
                                        Text("No terminal or 'swift run' needed when using the packaged application!")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
                            
                            // JSON Presets Card
                            VStack(alignment: .leading, spacing: 12) {
                                Text("JSON Preset Export / Import")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.teal)
                                
                                Text("Export all widgets as JSON to share with others or backup. Import overwrites the current layout.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                                    .lineLimit(nil)
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        let json = state.copyAllWidgetsAsJSON()
                                        if !json.isEmpty {
                                            let pasteboard = NSPasteboard.general
                                            pasteboard.clearContents()
                                            pasteboard.setString(json, forType: .string)
                                            print("Copied \(state.widgets.count) widget(s) as JSON to clipboard")
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "doc.on.clipboard")
                                            Text("Copy All as JSON")
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(Color.teal.opacity(0.2))
                                        .foregroundColor(.teal)
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: {
                                        let pasteboard = NSPasteboard.general
                                        if let json = pasteboard.string(forType: .string) {
                                            let success = state.replaceAllWidgetsFromJSON(json)
                                            if success {
                                                print("Imported widgets from clipboard successfully")
                                            } else {
                                                print("Failed to import — clipboard doesn't contain valid widgets JSON")
                                            }
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "clipboard")
                                            Text("Import from Clipboard")
                                        }
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 12)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
                            
                            // Manual Actions Card
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Manual Diagnostics")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.pink)
                                
                                Button(action: {
                                    let presenterClass: AnyClass? = NSClassFromString("touchbar.TouchBarPresenter")
                                    let refreshSelector = NSSelectorFromString("refreshTouchBar")
                                    if let presenter = presenterClass as? NSObject.Type {
                                        presenter.perform(refreshSelector)
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Force Re-present System Touch Bar")
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Color.pink.opacity(0.2))
                                    .foregroundColor(.pink)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
                        }
                        .padding(20)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 720, minHeight: 480)
        .background(Color(red: 18/255, green: 18/255, blue: 20/255))
        
    }
    
    private func moveUp(index: Int) {
        guard index > 0 else { return }
        var list = state.widgets
        list.swapAt(index, index - 1)
        state.widgets = list
        state.saveConfig()
    }
    
    private func moveDown(index: Int) {
        guard index < state.widgets.count - 1 else { return }
        var list = state.widgets
        list.swapAt(index, index + 1)
        state.widgets = list
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
    @AppStorage("AnkiTouchBar.isMediaOnLeft") private var isMediaOnLeft: Bool = false
    
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
                        get: { state.widgets[index].ankiDeckName },
                        set: { deck in
                            // Save current field values for the old deck before switching
                            let oldDeck = state.widgets[index].ankiDeckName
                            if !oldDeck.isEmpty {
                                state.widgets[index].ankiDeckSettings[oldDeck] = AnkiDeckSettings(
                                    questionField: state.widgets[index].ankiQuestionField,
                                    answerField: state.widgets[index].ankiAnswerField,
                                    audioField: state.widgets[index].ankiAudioField,
                                    touchBarAudioField: state.widgets[index].ankiTouchBarAudioField
                                )
                            }
                            state.widgets[index].ankiDeckName = deck
                            // Restore saved settings for the newly selected deck
                            if !deck.isEmpty {
                                if let saved = state.widgets[index].ankiDeckSettings[deck] {
                                    state.widgets[index].ankiQuestionField = saved.questionField
                                    state.widgets[index].ankiAnswerField = saved.answerField
                                    state.widgets[index].ankiAudioField = saved.audioField
                                    state.widgets[index].ankiTouchBarAudioField = saved.touchBarAudioField
                                }
                            }
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
                            get: { state.widgets[index].ankiQuestionField },
                            set: { val in
                                state.widgets[index].ankiQuestionField = val
                                let deck = state.widgets[index].ankiDeckName
                                if !deck.isEmpty {
                                    var settings = state.widgets[index].ankiDeckSettings[deck] ?? AnkiDeckSettings(
                                        questionField: val,
                                        answerField: state.widgets[index].ankiAnswerField,
                                        audioField: state.widgets[index].ankiAudioField
                                    )
                                    settings.questionField = val
                                    state.widgets[index].ankiDeckSettings[deck] = settings
                                }
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
                            get: { state.widgets[index].ankiAnswerField },
                            set: { val in
                                state.widgets[index].ankiAnswerField = val
                                let deck = state.widgets[index].ankiDeckName
                                if !deck.isEmpty {
                                    var settings = state.widgets[index].ankiDeckSettings[deck] ?? AnkiDeckSettings(
                                        questionField: state.widgets[index].ankiQuestionField,
                                        answerField: val,
                                        audioField: state.widgets[index].ankiAudioField
                                    )
                                    settings.answerField = val
                                    state.widgets[index].ankiDeckSettings[deck] = settings
                                }
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
                        Text("Audio Field:")
                            .font(.system(size: 11))
                            .frame(width: 95, alignment: .leading)
                        TextField("e.g. Audio", text: Binding(
                            get: { state.widgets[index].ankiAudioField },
                            set: { val in
                                state.widgets[index].ankiAudioField = val
                                let deck = state.widgets[index].ankiDeckName
                                if !deck.isEmpty {
                                    var settings = state.widgets[index].ankiDeckSettings[deck] ?? AnkiDeckSettings(
                                        questionField: state.widgets[index].ankiQuestionField,
                                        answerField: state.widgets[index].ankiAnswerField,
                                        audioField: val
                                    )
                                    settings.audioField = val
                                    state.widgets[index].ankiDeckSettings[deck] = settings
                                }
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
                        Text("Touch Bar Audio:")
                            .font(.system(size: 11))
                            .frame(width: 95, alignment: .leading)
                        TextField("e.g. Audio", text: Binding(
                            get: { state.widgets[index].ankiTouchBarAudioField },
                            set: { val in
                                state.widgets[index].ankiTouchBarAudioField = val
                                let deck = state.widgets[index].ankiDeckName
                                if !deck.isEmpty {
                                    var settings = state.widgets[index].ankiDeckSettings[deck] ?? AnkiDeckSettings(
                                        questionField: state.widgets[index].ankiQuestionField,
                                        answerField: state.widgets[index].ankiAnswerField,
                                        audioField: state.widgets[index].ankiAudioField
                                    )
                                    settings.touchBarAudioField = val
                                    state.widgets[index].ankiDeckSettings[deck] = settings
                                }
                                state.saveConfig()
                                Task {
                                    await state.ankiState.loadCurrentCard()
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                    }
                    
                    Text("Audio Field: used by Play/Stop button. Touch Bar Audio: played when tapping the answer text on the physical Touch Bar.")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .italic()
                }
                
                Divider()
                
                // Custom Width & Aesthetic Setting
                VStack(alignment: .leading, spacing: 8) {
                    Text("Widget Custom Width & Aesthetics")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 8) {
                        Text("Max Text Width:")
                            .font(.system(size: 11))
                            .frame(width: 105, alignment: .leading)
                        
                        TextField("", text: Binding(
                            get: { String(Int(widget.ankiTextMaxWidth)) },
                            set: { val in
                                if let num = Double(val.filter { $0.isNumber }) {
                                    state.widgets[index].ankiTextMaxWidth = num
                                    state.saveConfig()
                                    state.ankiState.refreshTouchBar()
                                }
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        
                        Text("px")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    
                    HStack(spacing: 8) {
                        Text("Bold Custom Color:")
                            .font(.system(size: 11))
                            .frame(width: 105, alignment: .leading)
                        
                        TextField("#HEX", text: Binding(
                            get: { widget.ankiBoldColorHex },
                            set: { val in
                                state.widgets[index].ankiBoldColorHex = val
                                state.saveConfig()
                                state.ankiState.refreshTouchBar()
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        
                        ColorPicker("", selection: Binding(
                            get: { Color(hex: widget.ankiBoldColorHex) },
                            set: { color in
                                if let hexString = color.toHex() {
                                    state.widgets[index].ankiBoldColorHex = hexString
                                    state.saveConfig()
                                    state.ankiState.refreshTouchBar()
                                }
                            }
                        ))
                    }
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
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rating Button Custom Colors")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    ratingColorRow(label: "Again Color:", hex: widget.ankiAgainColorHex) { state.widgets[index].ankiAgainColorHex = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                    ratingColorRow(label: "Hard Color:", hex: widget.ankiHardColorHex) { state.widgets[index].ankiHardColorHex = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                    ratingColorRow(label: "Good Color:", hex: widget.ankiGoodColorHex) { state.widgets[index].ankiGoodColorHex = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                    ratingColorRow(label: "Easy Color:", hex: widget.ankiEasyColorHex) { state.widgets[index].ankiEasyColorHex = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                    
                    Button(action: {
                        state.widgets[index].ankiAgainColorHex = "#E53333"
                        state.widgets[index].ankiHardColorHex = "#E58019"
                        state.widgets[index].ankiGoodColorHex = "#19B24C"
                        state.widgets[index].ankiEasyColorHex = "#3380E5"
                        state.saveConfig()
                        state.ankiState.refreshTouchBar()
                    }) {
                        Text("Reset to Default Colors")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Remaining Cards Display")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    Toggle("Show Remaining Cards Status (New, Learn, Review)", isOn: Binding(
                        get: { widget.ankiShowRemainingCounts },
                        set: { val in
                            state.widgets[index].ankiShowRemainingCounts = val
                            state.saveConfig()
                            state.ankiState.refreshTouchBar()
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Furigana Display")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    Toggle("Combine Furigana (e.g. 私[わたし] → 私 with わたし above)", isOn: Binding(
                        get: { widget.ankiCombineFurigana },
                        set: { val in
                            state.widgets[index].ankiCombineFurigana = val
                            state.saveConfig()
                            state.ankiState.refreshTouchBar()
                            StatusItemManager.shared.refreshFuriganaState()
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    
                    if widget.ankiCombineFurigana {
                        HStack(spacing: 8) {
                            Text("Furigana Font Size:")
                                .font(.system(size: 11))
                                .frame(width: 120, alignment: .leading)
                            
                            TextField("0", text: Binding(
                                get: { widget.ankiFuriganaFontSize == 0 ? "0" : String(format: "%.0f", widget.ankiFuriganaFontSize) },
                                set: { val in
                                    if let num = Double(val.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                        state.widgets[index].ankiFuriganaFontSize = max(0, num)
                                        state.saveConfig()
                                        state.ankiState.refreshTouchBar()
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            
                            Text("pt (0 = auto)")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        
                        HStack(spacing: 8) {
                            Text("Furigana Offset:")
                                .font(.system(size: 11))
                                .frame(width: 120, alignment: .leading)
                            
                            TextField("0", text: Binding(
                                get: { String(format: "%.0f", widget.ankiFuriganaVerticalOffset) },
                                set: { val in
                                    if let num = Double(val.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                        state.widgets[index].ankiFuriganaVerticalOffset = num
                                        state.saveConfig()
                                        state.ankiState.refreshTouchBar()
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            
                            Text("pt")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        
                        HStack(spacing: 8) {
                            Text("Text Offset:")
                                .font(.system(size: 11))
                                .frame(width: 120, alignment: .leading)
                            
                            TextField("0", text: Binding(
                                get: { String(format: "%.0f", widget.ankiFuriganaTextOffset) },
                                set: { val in
                                    if let num = Double(val.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                        state.widgets[index].ankiFuriganaTextOffset = max(0, num)
                                        state.saveConfig()
                                        state.ankiState.refreshTouchBar()
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            
                            Text("pt")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        
                        HStack(spacing: 8) {
                            Button(action: {
                                state.widgets[index].ankiFuriganaFontSize = 0
                                state.saveConfig()
                                state.ankiState.refreshTouchBar()
                            }) {
                                Text("Reset Font Size")
                                    .font(.system(size: 9))
                                    .foregroundColor(widget.ankiFuriganaFontSize == 0 ? .gray : .orange)
                            }
                            .buttonStyle(.plain)
                            .disabled(widget.ankiFuriganaFontSize == 0)
                            
                            Button(action: {
                                state.widgets[index].ankiFuriganaVerticalOffset = 0
                                state.saveConfig()
                                state.ankiState.refreshTouchBar()
                            }) {
                                Text("Reset Furi Offset")
                                    .font(.system(size: 9))
                                    .foregroundColor(widget.ankiFuriganaVerticalOffset == 0 ? .gray : .orange)
                            }
                            .buttonStyle(.plain)
                            .disabled(widget.ankiFuriganaVerticalOffset == 0)
                            
                            Button(action: {
                                state.widgets[index].ankiFuriganaTextOffset = 0
                                state.saveConfig()
                                state.ankiState.refreshTouchBar()
                            }) {
                                Text("Reset Text Offset")
                                    .font(.system(size: 9))
                                    .foregroundColor(widget.ankiFuriganaTextOffset == 0 ? .gray : .orange)
                            }
                            .buttonStyle(.plain)
                            .disabled(widget.ankiFuriganaTextOffset == 0)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text("Answer Text Offset:")
                                .font(.system(size: 11))
                                .frame(width: 120, alignment: .leading)
                            
                            TextField("0", text: Binding(
                                get: { String(format: "%.0f", widget.ankiAnswerTextOffset) },
                                set: { val in
                                    if let num = Double(val.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                        state.widgets[index].ankiAnswerTextOffset = num
                                        state.saveConfig()
                                        state.ankiState.refreshTouchBar()
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            
                            Text("pt")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Text("When enabled, Japanese furigana readings in brackets will be displayed above the kanji text.")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .italic()
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Touch Bar Layout Toggle")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    Toggle("Move media controls (Rating/Audio/Reveal) to the left side", isOn: Binding(
                        get: { isMediaOnLeft },
                        set: { val in
                            isMediaOnLeft = val
                            let presenterClass: AnyClass? = NSClassFromString("touchbar.TouchBarPresenter")
                            let refreshSelector = NSSelectorFromString("refreshTouchBar")
                            if let presenter = presenterClass as? NSObject.Type {
                                presenter.perform(refreshSelector)
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    
                    Text("When enabled: media controls appear on the left, Sync on the right. Default: Sync on left, media controls on right.")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .italic()
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Audio Mute Toggle")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    Toggle("Mute Anki Audio", isOn: Binding(
                        get: { state.ankiState.isMuted },
                        set: { _ in
                            state.ankiState.toggleMute()
                            state.saveConfig()
                            StatusItemManager.shared.refreshMuteState()
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    
                    Text("When muted, audio playback from Anki cards (both Play/Stop button and Touch Bar tap) will be suppressed.")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .italic()
                    
                    Divider()
                    
                    Text("Audio Play Restrictions")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    Toggle("Only play audio after answer is revealed", isOn: Binding(
                        get: { state.widgets[index].ankiAudioOnlyOnAnswer },
                        set: { val in
                            state.widgets[index].ankiAudioOnlyOnAnswer = val
                            state.saveConfig()
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    
                    Text("When enabled, audio (Play/Stop button and Touch Bar audio) will not play until you reveal the answer first. Prevents hearing the answer audio while still on the question.")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .italic()
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text Display")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    Toggle("Trim long text with trailing ellipsis (...)", isOn: Binding(
                        get: { widget.ankiTrimText },
                        set: { val in
                            state.widgets[index].ankiTrimText = val
                            state.saveConfig()
                            state.ankiState.refreshTouchBar()
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    
                    Text("When enabled, text that exceeds the available width will be cut off with an ellipsis (…). When disabled, text is shown as-is without any trimming.")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .italic()
                }
                
                Divider()
                
                // MARK: - Floating Overlay (Alternatif Touch Bar Fisik)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "rectangle.3.group.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.teal)
                        Text("Floating Overlay — Alternatif Touch Bar Fisik")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.teal)
                    }
                    
                    Text("Jika Touch Bar fisik tidak berfungsi/rusak, aktifkan overlay jendela mengambang yang menampilkan konten kartu Anki di layar.")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .italic()
                    
                    Toggle("Aktifkan Floating Overlay", isOn: Binding(
                        get: { AnkiFloatingOverlayManager.shared.config.isEnabled },
                        set: { val in
                            var config = AnkiFloatingOverlayManager.shared.config
                            config.isEnabled = val
                            AnkiFloatingOverlayManager.shared.config = config
                            if val {
                                AnkiFloatingOverlayManager.shared.show()
                            } else {
                                AnkiFloatingOverlayManager.shared.hide()
                            }
                        }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    
                    if AnkiFloatingOverlayManager.shared.config.isEnabled {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 10) {
                            // Font Size
                            HStack(spacing: 8) {
                                Text("Ukuran Font:")
                                    .font(.system(size: 11))
                                    .frame(width: 100, alignment: .leading)
                                
                                Slider(value: Binding(
                                    get: { AnkiFloatingOverlayManager.shared.config.fontSize },
                                    set: { val in
                                        var config = AnkiFloatingOverlayManager.shared.config
                                        config.fontSize = val
                                        AnkiFloatingOverlayManager.shared.config = config
                                        AnkiFloatingOverlayManager.shared.refreshOverlay()
                                    }
                                ), in: 10...32, step: 1)
                                
                                Text("\(Int(AnkiFloatingOverlayManager.shared.config.fontSize))pt")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .frame(width: 35, alignment: .trailing)
                            }
                            
                            // Furigana Font Size
                            HStack(spacing: 8) {
                                Text("Font Furigana:")
                                    .font(.system(size: 11))
                                    .frame(width: 100, alignment: .leading)
                                
                                Slider(value: Binding(
                                    get: { AnkiFloatingOverlayManager.shared.config.overlayFuriganaFontSize },
                                    set: { val in
                                        var config = AnkiFloatingOverlayManager.shared.config
                                        config.overlayFuriganaFontSize = val
                                        AnkiFloatingOverlayManager.shared.config = config
                                        AnkiFloatingOverlayManager.shared.refreshOverlay()
                                    }
                                ), in: 0...20, step: 1)
                                
                                Text(AnkiFloatingOverlayManager.shared.config.overlayFuriganaFontSize > 0 ? "\(Int(AnkiFloatingOverlayManager.shared.config.overlayFuriganaFontSize))pt" : "Auto")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .frame(width: 40, alignment: .trailing)
                            }
                            
                            Divider()
                            
                            // Window Transparency
                            HStack(spacing: 8) {
                                Text("Transp. Jendela:")
                                    .font(.system(size: 11))
                                    .frame(width: 100, alignment: .leading)
                                
                                Slider(value: Binding(
                                    get: { AnkiFloatingOverlayManager.shared.config.windowOpacity },
                                    set: { val in
                                        var config = AnkiFloatingOverlayManager.shared.config
                                        config.windowOpacity = val
                                        AnkiFloatingOverlayManager.shared.config = config
                                    }
                                ), in: 0.1...1.0, step: 0.05)
                                
                                Text("\(Int(AnkiFloatingOverlayManager.shared.config.windowOpacity * 100))%")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .frame(width: 35, alignment: .trailing)
                            }
                            
                            // Text Transparency
                            HStack(spacing: 8) {
                                Text("Transp. Teks:")
                                    .font(.system(size: 11))
                                    .frame(width: 100, alignment: .leading)
                                
                                Slider(value: Binding(
                                    get: { AnkiFloatingOverlayManager.shared.config.textOpacity },
                                    set: { val in
                                        var config = AnkiFloatingOverlayManager.shared.config
                                        config.textOpacity = val
                                        AnkiFloatingOverlayManager.shared.config = config
                                        AnkiFloatingOverlayManager.shared.refreshOverlay()
                                    }
                                ), in: 0.1...1.0, step: 0.05)
                                
                                Text("\(Int(AnkiFloatingOverlayManager.shared.config.textOpacity * 100))%")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .frame(width: 35, alignment: .trailing)
                            }
                            
                            // Window Width
                            HStack(spacing: 8) {
                                Text("Lebar Jendela:")
                                    .font(.system(size: 11))
                                    .frame(width: 100, alignment: .leading)
                                
                                Slider(value: Binding(
                                    get: { AnkiFloatingOverlayManager.shared.config.windowWidth },
                                    set: { val in
                                        var config = AnkiFloatingOverlayManager.shared.config
                                        config.windowWidth = val
                                        AnkiFloatingOverlayManager.shared.config = config
                                    }
                                ), in: 200...2000, step: 10)
                                
                                Text("\(Int(AnkiFloatingOverlayManager.shared.config.windowWidth))px")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .frame(width: 45, alignment: .trailing)
                            }
                            
                            // Window Height
                            HStack(spacing: 8) {
                                Text("Tinggi Jendela:")
                                    .font(.system(size: 11))
                                    .frame(width: 100, alignment: .leading)
                                
                                Slider(value: Binding(
                                    get: { AnkiFloatingOverlayManager.shared.config.windowHeight },
                                    set: { val in
                                        var config = AnkiFloatingOverlayManager.shared.config
                                        config.windowHeight = val
                                        AnkiFloatingOverlayManager.shared.config = config
                                    }
                                ), in: 150...1200, step: 10)
                                
                                Text("\(Int(AnkiFloatingOverlayManager.shared.config.windowHeight))px")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .frame(width: 45, alignment: .trailing)
                            }
                            
                            Divider()
                            
                            // Text Color
                            HStack(spacing: 8) {
                                Text("Warna Teks:")
                                    .font(.system(size: 11))
                                    .frame(width: 100, alignment: .leading)
                                
                                TextField("#HEX", text: Binding(
                                    get: { AnkiFloatingOverlayManager.shared.config.textColorHex },
                                    set: { val in
                                        var config = AnkiFloatingOverlayManager.shared.config
                                        config.textColorHex = val
                                        AnkiFloatingOverlayManager.shared.config = config
                                        AnkiFloatingOverlayManager.shared.refreshOverlay()
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)
                                
                                ColorPicker("", selection: Binding(
                                    get: { Color(hex: AnkiFloatingOverlayManager.shared.config.textColorHex) },
                                    set: { color in
                                        if let hexString = color.toHex() {
                                            var config = AnkiFloatingOverlayManager.shared.config
                                            config.textColorHex = hexString
                                            AnkiFloatingOverlayManager.shared.config = config
                                            AnkiFloatingOverlayManager.shared.refreshOverlay()
                                        }
                                    }
                                ))
                            }
                            
                            // Background Color
                            HStack(spacing: 8) {
                                Text("Warna Background:")
                                    .font(.system(size: 11))
                                    .frame(width: 100, alignment: .leading)
                                
                                TextField("#HEX", text: Binding(
                                    get: { AnkiFloatingOverlayManager.shared.config.backgroundColorHex },
                                    set: { val in
                                        var config = AnkiFloatingOverlayManager.shared.config
                                        config.backgroundColorHex = val
                                        AnkiFloatingOverlayManager.shared.config = config
                                        AnkiFloatingOverlayManager.shared.refreshOverlay()
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)
                                
                                ColorPicker("", selection: Binding(
                                    get: { Color(hex: AnkiFloatingOverlayManager.shared.config.backgroundColorHex) },
                                    set: { color in
                                        if let hexString = color.toHex() {
                                            var config = AnkiFloatingOverlayManager.shared.config
                                            config.backgroundColorHex = hexString
                                            AnkiFloatingOverlayManager.shared.config = config
                                            AnkiFloatingOverlayManager.shared.refreshOverlay()
                                        }
                                    }
                                ))
                            }
                            
                            // Question Answer Color
                            HStack(spacing: 8) {
                                Text("Warna Preview Soal:")
                                    .font(.system(size: 11))
                                    .frame(width: 100, alignment: .leading)
                                
                                TextField("#HEX", text: Binding(
                                    get: { AnkiFloatingOverlayManager.shared.config.questionAnswerColorHex },
                                    set: { val in
                                        var config = AnkiFloatingOverlayManager.shared.config
                                        config.questionAnswerColorHex = val
                                        AnkiFloatingOverlayManager.shared.config = config
                                        AnkiFloatingOverlayManager.shared.refreshOverlay()
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 90)
                                
                                ColorPicker("", selection: Binding(
                                    get: { Color(hex: AnkiFloatingOverlayManager.shared.config.questionAnswerColorHex) },
                                    set: { color in
                                        if let hexString = color.toHex() {
                                            var config = AnkiFloatingOverlayManager.shared.config
                                            config.questionAnswerColorHex = hexString
                                            AnkiFloatingOverlayManager.shared.config = config
                                            AnkiFloatingOverlayManager.shared.refreshOverlay()
                                        }
                                    }
                                ))
                            }
                            
                            Text("Warna Preview Soal mengubah warna teks pertanyaan yang muncul di layar jawaban (sebelumnya abu-abu).")
                                .font(.system(size: 9))
                                .foregroundColor(.gray)
                                .italic()
                            
                            Divider()
                            
                            // Show/Hide Toggles
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Kontrol yang Ditampilkan:")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.gray)
                                
                                Toggle("Tombol Rating (Again/Hard/Good/Easy)", isOn: Binding(
                                    get: { AnkiFloatingOverlayManager.shared.config.showRatingButtons },
                                    set: { val in
                                        var config = AnkiFloatingOverlayManager.shared.config
                                        config.showRatingButtons = val
                                        AnkiFloatingOverlayManager.shared.config = config
                                        AnkiFloatingOverlayManager.shared.refreshOverlay()
                                    }
                                ))
                                .toggleStyle(.checkbox)
                                
                                Toggle("Tombol Audio (Play/Stop)", isOn: Binding(
                                    get: { AnkiFloatingOverlayManager.shared.config.showAudioButton },
                                    set: { val in
                                        var config = AnkiFloatingOverlayManager.shared.config
                                        config.showAudioButton = val
                                        AnkiFloatingOverlayManager.shared.config = config
                                        AnkiFloatingOverlayManager.shared.refreshOverlay()
                                    }
                                ))
                                .toggleStyle(.checkbox)
                                
                                Toggle("Tombol Sinkronisasi (Sync)", isOn: Binding(
                                    get: { AnkiFloatingOverlayManager.shared.config.showSyncButton },
                                    set: { val in
                                        var config = AnkiFloatingOverlayManager.shared.config
                                        config.showSyncButton = val
                                        AnkiFloatingOverlayManager.shared.config = config
                                        AnkiFloatingOverlayManager.shared.refreshOverlay()
                                    }
                                ))
                                .toggleStyle(.checkbox)
                                
                                Toggle("Tombol Tampilkan Jawaban", isOn: Binding(
                                    get: { AnkiFloatingOverlayManager.shared.config.showRevealButton },
                                    set: { val in
                                        var config = AnkiFloatingOverlayManager.shared.config
                                        config.showRevealButton = val
                                        AnkiFloatingOverlayManager.shared.config = config
                                        AnkiFloatingOverlayManager.shared.refreshOverlay()
                                    }
                                ))
                                .toggleStyle(.checkbox)
                                
                                Toggle("Header (Judul Deck & Counter)", isOn: Binding(
                                    get: { AnkiFloatingOverlayManager.shared.config.showHeader },
                                    set: { val in
                                        var config = AnkiFloatingOverlayManager.shared.config
                                        config.showHeader = val
                                        AnkiFloatingOverlayManager.shared.config = config
                                        AnkiFloatingOverlayManager.shared.refreshOverlay()
                                    }
                                ))
                                .toggleStyle(.checkbox)
                                
                                if !AnkiFloatingOverlayManager.shared.config.showHeader {
                                    Toggle("Counter Saja (N/L/R) — tanpa header", isOn: Binding(
                                        get: { AnkiFloatingOverlayManager.shared.config.showCounts },
                                        set: { val in
                                            var config = AnkiFloatingOverlayManager.shared.config
                                            config.showCounts = val
                                            AnkiFloatingOverlayManager.shared.config = config
                                            AnkiFloatingOverlayManager.shared.refreshOverlay()
                                        }
                                    ))
                                    .toggleStyle(.checkbox)
                                    .font(.system(size: 10))
                                }
                            }
                            .font(.system(size: 11))
                            
                            Divider()
                            
                            // Focus Mode
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Mode Fokus:")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.gray)
                                
                                Toggle("Sembunyikan Title Bar & Tombol Tutup", isOn: Binding(
                                    get: { AnkiFloatingOverlayManager.shared.config.hideTitleBar },
                                    set: { val in
                                        var config = AnkiFloatingOverlayManager.shared.config
                                        config.hideTitleBar = val
                                        AnkiFloatingOverlayManager.shared.config = config
                                    }
                                ))
                                .toggleStyle(.checkbox)
                                .font(.system(size: 11))
                                
                                Text("Menyembunyikan title bar dan tombol tutup (X) agar tampilan lebih fokus. Geser jendela dengan cara drag area konten.")
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
                                    .italic()
                                    .lineLimit(nil)
                            }
                            
                            Divider()
                            
                            // Test buttons
                            HStack(spacing: 8) {
                                Button(action: {
                                    if AnkiFloatingOverlayManager.shared.config.isEnabled {
                                        AnkiFloatingOverlayManager.shared.show()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "eye.fill")
                                            .font(.system(size: 10))
                                        Text("Tampilkan Overlay")
                                            .font(.system(size: 10))
                                    }
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 10)
                                    .background(Color.teal.opacity(0.2))
                                    .foregroundColor(.teal)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    AnkiFloatingOverlayManager.shared.hide()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "eye.slash.fill")
                                            .font(.system(size: 10))
                                        Text("Sembunyikan")
                                            .font(.system(size: 10))
                                    }
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 10)
                                    .background(Color.red.opacity(0.2))
                                    .foregroundColor(.red)
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Divider()
                
                // MARK: - Global Keyboard Shortcuts
                VStack(alignment: .leading, spacing: 8) {
                    Text("Global Keyboard Shortcuts")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    Text("Set global hotkeys that work even when TouchBarCraft is in the background. Requires Accessibility permission (already requested on first launch).")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .italic()
                    
                    VStack(spacing: 4) {
                        ForEach(AnkiHotkeyAction.allCases, id: \.rawValue) { action in
                            HotkeyRecorderRow(action: action)
                        }
                    }
                }
                
                Divider()
                
                // MARK: - Game Controller Support
                VStack(alignment: .leading, spacing: 8) {
                    Text("Game Controller / Joystick Support (EXPERIMENTAL)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text(GameControllerManager.shared.controllerStatusString)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(GameControllerManager.shared.hasConnectedController ? .green : .gray)
                    }
                    
                    Toggle("Enable Game Controller Support", isOn: Binding(
                        get: { GameControllerManager.shared.isEnabled },
                        set: { GameControllerManager.shared.isEnabled = $0 }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    
                    Toggle("Gaming Mode (disable controller while playing games)", isOn: Binding(
                        get: { GameControllerManager.shared.isGamingMode },
                        set: { GameControllerManager.shared.isGamingMode = $0 }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .disabled(!GameControllerManager.shared.isEnabled)
                    
                    if GameControllerManager.shared.isEnabled && !GameControllerManager.shared.isGamingMode {
                        Text("✓ Controller input active — buttons are mapped to Anki actions")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                    } else if GameControllerManager.shared.isGamingMode {
                        Text("⚠ Gaming mode ON — controller input for Anki is disabled")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    } else {
                        Text("Controller support is disabled")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                    
                    // Custom button mapping
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Custom Button Mapping:")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                        
                        Text("Assign each controller button to an Anki action. Defaults are used if not customized.")
                            .font(.system(size: 8))
                            .foregroundColor(.gray.opacity(0.7))
                            .italic()
                        
                        ForEach(GameControllerButton.allCases, id: \.rawValue) { button in
                            ControllerMappingRow(button: button)
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(6)
                    
                    Text("Connect a PS4, PS5, Xbox, or MFi controller via Bluetooth or USB. Supports most standard gamepads out of the box.")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .italic()
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
    
    @ViewBuilder
    private func ratingColorRow(label: String, hex: String, onChange: @escaping (String) -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .frame(width: 120, alignment: .leading)
            
            TextField("#HEX", text: Binding(
                get: { hex },
                set: { onChange($0) }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 100)
            
            ColorPicker("", selection: Binding(
                get: { Color(hex: hex) },
                set: { color in
                    if let hexString = color.toHex() {
                        onChange(hexString)
                    }
                }
            ))
        }
    }
}

// MARK: - Widget Specific Options Subviews

struct WidgetOptionsView: View {
    let widget: TouchBarWidget
    let index: Int
    let state: AppState
    
    private let soundPresets = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse",
        "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink"
    ]
    
    var body: some View {
        switch widget.type {
        case .label:
            LabelOptionsView(widget: widget, index: index, state: state, soundPresets: soundPresets)
        case .button:
            ButtonOptionsView(widget: widget, index: index, state: state, soundPresets: soundPresets)
        case .systemMonitor:
            SystemMonitorOptionsView(widget: widget, index: index, state: state, soundPresets: soundPresets)
        case .media:
            Text("Fully automatic system widget. Renders interactive Backward, Play/Pause, and Forward keys that communicate directly with Apple Music, Spotify, or default macOS media listeners.")
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .lineSpacing(4)
        case .animation:
            AnimationOptionsView(widget: widget, index: index, state: state, soundPresets: soundPresets)
        case .anki:
            AnkiConfigView(widget: widget, index: index, state: state)
        case .volumeSlider:
            VolumeSliderOptionsView(widget: widget, index: index, state: state)
        case .brightnessButtons:
            BrightnessOptionsView(widget: widget, index: index, state: state)
        }
    }
}

struct LabelOptionsView: View {
    let widget: TouchBarWidget
    let index: Int
    let state: AppState
    let soundPresets: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Show Seconds in {time}", isOn: Binding(
                get: { widget.showSeconds },
                set: { state.widgets[index].showSeconds = $0; state.saveConfig() }
            ))
            .toggleStyle(.checkbox)
            .font(.system(size: 11))
            
            Divider()
            
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
            
            Divider()
            ActionConfigurationView(
                title: "On Tap Action:",
                actionType: Binding(
                    get: { widget.actionType },
                    set: { state.widgets[index].actionType = $0; state.saveConfig() }
                ),
                actionValue: Binding(
                    get: { widget.actionValue },
                    set: { state.widgets[index].actionValue = $0; state.saveConfig() }
                ),
                soundPresets: soundPresets
            )
            Divider()
            ActionConfigurationView(
                title: "On Long Press Action:",
                actionType: Binding(
                    get: { widget.longPressActionType },
                    set: { state.widgets[index].longPressActionType = $0; state.saveConfig() }
                ),
                actionValue: Binding(
                    get: { widget.longPressActionValue },
                    set: { state.widgets[index].longPressActionValue = $0; state.saveConfig() }
                ),
                soundPresets: soundPresets
            )
        }
    }
}

struct ButtonOptionsView: View {
    let widget: TouchBarWidget
    let index: Int
    let state: AppState
    let soundPresets: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Show Seconds in {time}", isOn: Binding(
                get: { widget.showSeconds },
                set: { state.widgets[index].showSeconds = $0; state.saveConfig() }
            ))
            .toggleStyle(.checkbox)
            .font(.system(size: 11))
            ActionConfigurationView(
                title: "Button Action:",
                actionType: Binding(
                    get: { widget.actionType },
                    set: { state.widgets[index].actionType = $0; state.saveConfig() }
                ),
                actionValue: Binding(
                    get: { widget.actionValue },
                    set: { state.widgets[index].actionValue = $0; state.saveConfig() }
                ),
                soundPresets: soundPresets
            )
            Divider()
            ActionConfigurationView(
                title: "Long Press Action:",
                actionType: Binding(
                    get: { widget.longPressActionType },
                    set: { state.widgets[index].longPressActionType = $0; state.saveConfig() }
                ),
                actionValue: Binding(
                    get: { widget.longPressActionValue },
                    set: { state.widgets[index].longPressActionValue = $0; state.saveConfig() }
                ),
                soundPresets: soundPresets
            )
        }
    }
}

struct ActionConfigurationView: View {
    let title: String
    @Binding var actionType: ActionType
    @Binding var actionValue: String
    let soundPresets: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(title, selection: $actionType) {
                ForEach(ActionType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)
            
            if actionType == .shellCommand || actionType == .appleScript {
                VStack(alignment: .leading, spacing: 4) {
                    Text(actionType == .shellCommand ? "Shell command to run:" : "AppleScript to run:")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    
                    TextEditor(text: $actionValue)
                    .font(.system(size: 10, design: .monospaced))
                    .frame(height: 50)
                    .padding(4)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(4)
                    
                    Text(actionType == .shellCommand ? "e.g. 'open -a Safari', 'say Done', or a path to a script" : "e.g. 'tell application \"System Events\" to key code 25 using {command down, shift down}'")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                }
            } else if actionType == .playSound {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sound Effect Name:")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    
                    Picker("Select Sound", selection: Binding(
                        get: { soundPresets.contains(actionValue) ? actionValue : "Glass" },
                        set: { actionValue = $0 }
                    )) {
                        ForEach(soundPresets, id: \.self) { sound in
                            Text(sound).tag(sound)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Button("🎵 Test Sound Now") {
                        NSSound(named: actionValue)?.play()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 4)
                }
            } else if actionType != .none {
                Text("No additional arguments needed.")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
    }
}

struct SystemMonitorOptionsView: View {
    let widget: TouchBarWidget
    let index: Int
    let state: AppState
    let soundPresets: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("System Resource:", selection: Binding(
                get: { widget.monitorType },
                set: { state.widgets[index].monitorType = $0; state.saveConfig() }
            )) {
                ForEach(MonitorType.allCases, id: \.self) { monitor in
                    Text(monitor.rawValue).tag(monitor)
                }
            }
            .pickerStyle(.radioGroup)
            
            if widget.monitorType == .battery {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Display Mode:", selection: Binding(
                        get: { widget.batteryDisplayType },
                        set: { state.widgets[index].batteryDisplayType = $0; state.saveConfig() }
                    )) {
                        ForEach(BatteryDisplayType.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    if widget.batteryDisplayType == .textOnly {
                        Text("Shows only the battery percentage (e.g. 50%). If the battery level drops below the Low Battery Limit, the text color will automatically turn red.")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                            .lineSpacing(3)
                        
                        HStack(spacing: 8) {
                            Text("Low Battery Limit:")
                                .font(.system(size: 11))
                                .frame(width: 140, alignment: .leading)
                            
                            TextField("", text: Binding(
                                get: { String(widget.batteryLowThreshold) },
                                set: { val in
                                    if let num = Int(val.filter { $0.isNumber }) {
                                        state.widgets[index].batteryLowThreshold = num
                                        state.saveConfig()
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            
                            Text("% (Default 20%)")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Battery Icon & Animation Customization")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                            
                            // Low threshold setting
                            HStack(spacing: 8) {
                                Text("Low Battery Limit:")
                                    .font(.system(size: 11))
                                    .frame(width: 140, alignment: .leading)
                                
                                TextField("", text: Binding(
                                    get: { String(widget.batteryLowThreshold) },
                                    set: { val in
                                        if let num = Int(val.filter { $0.isNumber }) {
                                            state.widgets[index].batteryLowThreshold = num
                                            state.saveConfig()
                                        }
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                
                                Text("% (Default 20%)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            
                            // Full threshold setting
                            HStack(spacing: 8) {
                                Text("Full Battery Limit:")
                                    .font(.system(size: 11))
                                    .frame(width: 140, alignment: .leading)
                                
                                TextField("", text: Binding(
                                    get: { String(widget.batteryFullThreshold) },
                                    set: { val in
                                        if let num = Int(val.filter { $0.isNumber }) {
                                            state.widgets[index].batteryFullThreshold = num
                                            state.saveConfig()
                                        }
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                                
                                Text("% (Default 85%)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            
                            Divider()
                                .padding(.vertical, 2)
                            
                            // Custom Charging Icon
                            customFileRow(label: "⚡️ Charging Icon/Animation:", path: widget.batteryChargingIcon) { path in
                                state.widgets[index].batteryChargingIcon = path
                                state.saveConfig()
                            }
                            
                            // Custom Normal Icon
                            customFileRow(label: "🔋 Not Charging (Normal) Icon/Animation:", path: widget.batteryNormalIcon) { path in
                                state.widgets[index].batteryNormalIcon = path
                                state.saveConfig()
                            }
                            
                            // Custom Low Icon
                            customFileRow(label: "⚠️ Low Battery Icon/Animation (≤ 20%):", path: widget.batteryLowIcon) { path in
                                state.widgets[index].batteryLowIcon = path
                                state.saveConfig()
                            }
                            
                            // Custom Full Icon
                            customFileRow(label: "✅ Full Battery Icon/Animation (≥ 85%):", path: widget.batteryFullIcon) { path in
                                state.widgets[index].batteryFullIcon = path
                                state.saveConfig()
                            }
                        }
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            HStack(spacing: 8) {
                Text("Custom Width:")
                    .font(.system(size: 11))
                    .frame(width: 140, alignment: .leading)
                
                TextField("0", text: Binding(
                    get: { String(Int(widget.customWidth)) },
                    set: { val in
                        if let num = Double(val.filter { $0.isNumber }) {
                            state.widgets[index].customWidth = num
                            state.saveConfig()
                            state.ankiState.refreshTouchBar()
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                
                Text("px (0 for auto)")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            
            Divider()
            ActionConfigurationView(
                title: "On Tap Action:",
                actionType: Binding(
                    get: { widget.actionType },
                    set: { state.widgets[index].actionType = $0; state.saveConfig() }
                ),
                actionValue: Binding(
                    get: { widget.actionValue },
                    set: { state.widgets[index].actionValue = $0; state.saveConfig() }
                ),
                soundPresets: soundPresets
            )
            Divider()
            ActionConfigurationView(
                title: "On Long Press Action:",
                actionType: Binding(
                    get: { widget.longPressActionType },
                    set: { state.widgets[index].longPressActionType = $0; state.saveConfig() }
                ),
                actionValue: Binding(
                    get: { widget.longPressActionValue },
                    set: { state.widgets[index].longPressActionValue = $0; state.saveConfig() }
                ),
                soundPresets: soundPresets
            )
        }
    }
    
    private func customFileRow(label: String, path: String, onSelect: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
            
            HStack(spacing: 8) {
                TextField("Path to static image or .gif file", text: Binding(
                    get: { path },
                    set: { onSelect($0) }
                ))
                .textFieldStyle(.roundedBorder)
                
                Button("Browse...") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.canChooseFiles = true
                    panel.allowedContentTypes = [.image, .gif]
                    
                    if panel.runModal() == .OK {
                        if let selectPath = panel.url?.path {
                            onSelect(selectPath)
                        }
                    }
                }
                
                if !path.isEmpty {
                    Button("Clear") {
                        onSelect("")
                    }
                }
            }
        }
    }
}

struct AnimationOptionsView: View {
    let widget: TouchBarWidget
    let index: Int
    let state: AppState
    let soundPresets: [String]
    
    var body: some View {
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Custom GIF File Path:")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                
                HStack(spacing: 8) {
                    TextField("Absolute path to .gif file", text: Binding(
                        get: { widget.customGifPath },
                        set: { state.widgets[index].customGifPath = $0; state.saveConfig() }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    
                    Button("Select File...") {
                        selectGifFile()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                if !widget.customGifPath.isEmpty {
                    Button("Clear Custom GIF") {
                        state.widgets[index].customGifPath = ""
                        state.saveConfig()
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                }
            }
            
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
            
            Divider()
                .padding(.vertical, 4)
            
            HStack(spacing: 8) {
                Text("Custom Width:")
                    .font(.system(size: 11))
                    .frame(width: 140, alignment: .leading)
                
                TextField("0", text: Binding(
                    get: { String(Int(widget.customWidth)) },
                    set: { val in
                        if let num = Double(val.filter { $0.isNumber }) {
                            state.widgets[index].customWidth = num
                            state.saveConfig()
                            state.ankiState.refreshTouchBar()
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                
                Text("px (0 for auto)")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            
            Divider()
            ActionConfigurationView(
                title: "On Tap Action:",
                actionType: Binding(
                    get: { widget.actionType },
                    set: { state.widgets[index].actionType = $0; state.saveConfig() }
                ),
                actionValue: Binding(
                    get: { widget.actionValue },
                    set: { state.widgets[index].actionValue = $0; state.saveConfig() }
                ),
                soundPresets: soundPresets
            )
            Divider()
            ActionConfigurationView(
                title: "On Long Press Action:",
                actionType: Binding(
                    get: { widget.longPressActionType },
                    set: { state.widgets[index].longPressActionType = $0; state.saveConfig() }
                ),
                actionValue: Binding(
                    get: { widget.longPressActionValue },
                    set: { state.widgets[index].longPressActionValue = $0; state.saveConfig() }
                ),
                soundPresets: soundPresets
            )
        }
    }
    
    private func selectGifFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.gif]
        
        if panel.runModal() == .OK {
            if let path = panel.url?.path {
                state.widgets[index].customGifPath = path
                state.saveConfig()
            }
        }
    }
}

struct VolumeSliderOptionsView: View {
    let widget: TouchBarWidget
    let index: Int
    let state: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Configures the volume slider width.")
                .font(.system(size: 11))
                .foregroundColor(.gray)
            
            HStack(spacing: 8) {
                Text("Slider Width:")
                    .font(.system(size: 11))
                    .frame(width: 90, alignment: .leading)
                
                TextField("", text: Binding(
                    get: { String(Int(widget.volumeSliderWidth)) },
                    set: { val in
                        if let num = Double(val.filter { $0.isNumber }) {
                            state.widgets[index].volumeSliderWidth = num
                            state.saveConfig()
                            state.ankiState.refreshTouchBar()
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                
                Text("px")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            
            Toggle("Show Volume Icons", isOn: Binding(
                get: { widget.volumeShowIcon },
                set: { val in
                    state.widgets[index].volumeShowIcon = val
                    state.saveConfig()
                    state.ankiState.refreshTouchBar()
                }
            ))
            .toggleStyle(.checkbox)
            .font(.system(size: 11))
        }
    }
}

struct BrightnessOptionsView: View {
    let widget: TouchBarWidget
    let index: Int
    let state: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Configures the brightness button size.")
                .font(.system(size: 11))
                .foregroundColor(.gray)
            
            HStack(spacing: 8) {
                Text("Button Width:")
                    .font(.system(size: 11))
                    .frame(width: 90, alignment: .leading)
                
                TextField("", text: Binding(
                    get: { String(Int(widget.brightnessButtonSize)) },
                    set: { val in
                        if let num = Double(val.filter { $0.isNumber }) {
                            state.widgets[index].brightnessButtonSize = num
                            state.saveConfig()
                            state.ankiState.refreshTouchBar()
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                
                Text("px")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Global Hotkey Recorder Views
// MARK: - Game Controller Mapping Row

struct ControllerMappingRow: View {
    let button: GameControllerButton
    @State private var selectedAction: AnkiHotkeyAction? = nil
    
    private var defaultActionName: String {
        GameControllerManager.defaultAction(for: button)?.displayName ?? "—"
    }
    
    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: button.iconName)
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                    .frame(width: 16)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(button.rawValue)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Text("Default: " + defaultActionName)
                        .font(.system(size: 8))
                        .foregroundColor(.gray.opacity(0.6))
                }
            }
            .frame(width: 110, alignment: .leading)
            
            Image(systemName: "arrow.right")
                .font(.system(size: 8))
                .foregroundColor(.gray)
            
            Picker("", selection: Binding(
                get: { selectedAction?.rawValue ?? -1 },
                set: { newRawValue in
                    let action = newRawValue >= 0 ? AnkiHotkeyAction(rawValue: newRawValue) : nil
                    selectedAction = action
                    GameControllerManager.shared.setMapping(for: button, action: action)
                }
            )) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 9))
                    Text("Default: " + defaultActionName)
                        .font(.system(size: 10))
                }.tag(-1)
                ForEach(AnkiHotkeyAction.allCases, id: \.rawValue) { action in
                    HStack(spacing: 4) {
                        Image(systemName: action.iconName)
                            .font(.system(size: 9))
                        Text(action.displayName)
                            .font(.system(size: 10))
                    }.tag(action.rawValue)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 130)
        }
        .padding(.vertical, 2)
        .onAppear {
            selectedAction = GameControllerManager.shared.loadedAction(for: button)
        }
    }
}


struct HotkeyRecorderRow: View {
    let action: AnkiHotkeyAction
    @State private var isRecording = false
    @State private var eventMonitor: Any?
    @State private var cachedBinding: HotkeyBinding = .empty

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: action.iconName)
                .font(.system(size: 10))
                .foregroundColor(.purple)
                .frame(width: 16)

            Text(action.displayName)
                .font(.system(size: 10))
                .foregroundColor(.white)
                .frame(width: 100, alignment: .leading)

            Spacer()

            Button(action: {
                if isRecording {
                    cancelRecording()
                } else {
                    startRecording()
                }
            }) {
                Text(displayString)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(isRecording ? .white : .purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isRecording ? Color.red.opacity(0.6) : Color.purple.opacity(0.15))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isRecording ? Color.red : Color.purple.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help(isRecording ? "Press a key combination..." : "Click to record")

            if cachedBinding.isValid {
                Toggle("", isOn: Binding(
                    get: { cachedBinding.isEnabled },
                    set: { newVal in
                        if newVal {
                            let binding = cachedBinding
                            GlobalHotkeyManager.shared.setBinding(HotkeyBinding(keyCode: binding.keyCode, modifiers: binding.modifiers, isEnabled: true), for: action)
                        } else {
                            GlobalHotkeyManager.shared.toggleEnabled(for: action)
                        }
                        syncBinding()
                    }
                ))
                .toggleStyle(.checkbox)
                .controlSize(.small)

                Button(action: {
                    cancelRecording()
                    GlobalHotkeyManager.shared.clearBinding(for: action)
                    syncBinding()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Clear shortcut")
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 6)
        .background(isRecording ? Color.red.opacity(0.08) : Color.clear)
        .cornerRadius(4)
        .onAppear { syncBinding() }
        .onDisappear { cancelRecording() }
    }

    private var displayString: String {
        if isRecording {
            return "Press keys..."
        }
        return cachedBinding.isValid ? cachedBinding.displayString : "Set"
    }

    private func syncBinding() {
        cachedBinding = GlobalHotkeyManager.shared.binding(for: action)
    }

    private func startRecording() {
        cancelRecording()
        isRecording = true

        let monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [self] event in
            guard self.isRecording else { return event }

            let keyCode = Int(event.keyCode)

            let isModifierOnly: Bool = {
                switch keyCode {
                case 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E:
                    return true
                default:
                    return false
                }
            }()

            if isModifierOnly {
                return nil
            }

            let flags = event.modifierFlags
            let hasModifier = flags.contains(.command) ||
                               flags.contains(.shift) ||
                               flags.contains(.option) ||
                               flags.contains(.control)

            if hasModifier {
                let binding = GlobalHotkeyManager.binding(from: event)
                GlobalHotkeyManager.shared.setBinding(binding, for: self.action)
                self.cancelRecording()
                self.syncBinding()
            }

            return nil
        }
        eventMonitor = monitor
    }

    private func cancelRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
