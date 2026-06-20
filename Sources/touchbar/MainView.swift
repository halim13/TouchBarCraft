import SwiftUI
import AppKit

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
                            ForEach(state.widgets.filter { !$0.isHidden && !$0.hideFromTouchBar }) { widget in
                                widgetSimulatorView(for: widget, state: state)
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
                            Button("NHK Easy News") { state.addWidget(.nhkNews) }
                            Button("Dock") { state.addWidget(.dock) }
                            Button("App Launcher") { state.addWidget(.appLauncher) }
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
                                        Text(widget.type.rawValue + (widget.isHidden ? " (Hidden)" : ""))
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
                                        
                                        // Hide/Show toggle button
                                        Button(action: {
                                            state.widgets[index].isHidden.toggle()
                                            state.saveConfig()
                                            StatusItemManager.shared.rebuildMenu()
                                        }) {
                                            Image(systemName: widget.isHidden ? "eye.slash" : "eye")
                                                .font(.system(size: 9))
                                                .foregroundColor(widget.isHidden ? .orange.opacity(0.8) : .gray.opacity(0.6))
                                                .frame(width: 14, height: 14)
                                        }
                                        .buttonStyle(.plain)
                                        .help(widget.isHidden ? "Show widget" : "Hide widget")
                                        
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
                                .opacity(widget.isHidden ? 0.45 : 1.0)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    state.selectedWidgetID = widget.id
                                }
                                .onDrag { NSItemProvider(object: String(index) as NSString) }
                                .onDrop(of: [.text], delegate: ReorderDropDelegate(item: index) { from, to in
                                    var list = state.widgets
                                    let item = list.remove(at: from)
                                    list.insert(item, at: to > from ? to - 1 : to)
                                    state.widgets = list
                                    state.saveConfig()
                                })
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
                        if widget.type != .dock && widget.type != .appLauncher {
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
                        }
                        
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
                        
                            // Swipe Gestures Card
                            SwipeConfigurationView(state: state)
                                .padding(14)
                                .background(Color.white.opacity(0.03))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
                            
                            // Global Shortcuts Card
                            GlobalShortcutsCard()
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

}

// MARK: - Global Shortcuts Card

private struct GlobalShortcutsCard: View {
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Global Shortcuts")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.orange)
            
            Text("Set global hotkeys for app-wide actions. Requires Accessibility permission.")
                .font(.system(size: 9))
                .foregroundColor(.gray)
                .italic()
            
            HStack(spacing: 8) {
                Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(accessibilityGranted ? .green : .red)
                    .font(.system(size: 10))
                Text(accessibilityGranted ? "Accessibility: Active" : "Accessibility: Not Active — try toggling it off/on in System Settings")
                    .font(.system(size: 9))
                    .foregroundColor(accessibilityGranted ? .green : .red)
                if !accessibilityGranted {
                    Button("Re-check") {
                            accessibilityGranted = AXIsProcessTrusted()
                            if !accessibilityGranted {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                            }
                        }
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
                }
            }
            
            VStack(spacing: 4) {
                HotkeyRecorderRow(action: .openSettings)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
}

extension MainView {
    
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

    @ViewBuilder
    private func widgetSimulatorView(for widget: TouchBarWidget, state: AppState) -> some View {
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
        case .nhkNews:
            WidgetNHKNewsView(widget: widget, state: state, isSimulator: true)
        case .dock:
            WidgetDockView(widget: widget, state: state, isSimulator: true)
        case .appLauncher:
            WidgetAppLauncherView(widget: widget, state: state, isSimulator: true)
        }
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
    
    @State private var touchBarExpanded: Bool = true
    @State private var overlayExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ── Connection & Deck ──────────────────────────────────────
            groupHeader(icon: "antenna.radiowaves.left.and.right", title: "Connection & Deck", color: .blue)

            HStack {
                Text("Status:")
                    .font(.system(size: 11))
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
                VStack(alignment: .leading, spacing: 6) {
                    Picker("Deck:", selection: Binding(
                        get: { state.widgets[index].ankiDeckName },
                        set: { deck in
                            let oldDeck = state.widgets[index].ankiDeckName
                            let overlayConfig = AnkiFloatingOverlayManager.shared.config
                            if !oldDeck.isEmpty {
                                var existing = state.widgets[index].ankiDeckSettings[oldDeck] ?? AnkiDeckSettings(questionField: "", answerField: "", audioField: "")
                                existing.questionField = state.widgets[index].ankiQuestionField
                                existing.answerField = state.widgets[index].ankiAnswerField
                                existing.audioField = state.widgets[index].ankiAudioField
                                existing.touchBarAudioField = state.widgets[index].ankiTouchBarAudioField
                                existing.extraQuestionField = state.widgets[index].ankiExtraQuestionField
                                existing.extraAnswerField = state.widgets[index].ankiExtraAnswerField
                                existing.overlayQuestionField = overlayConfig.questionField
                                existing.overlayAnswerField = overlayConfig.answerField
                                existing.overlayAudioField = overlayConfig.audioField
                                existing.overlayExtraQuestionField = overlayConfig.extraQuestionField
                                existing.overlayExtraAnswerField = overlayConfig.extraAnswerField
                                existing.overlayBoldColorHex = overlayConfig.boldColorHex
                                state.widgets[index].ankiDeckSettings[oldDeck] = existing
                            }
                            state.widgets[index].ankiDeckName = deck
                            if !deck.isEmpty {
                                if let saved = state.widgets[index].ankiDeckSettings[deck] {
                                    state.widgets[index].ankiQuestionField = saved.questionField
                                    state.widgets[index].ankiAnswerField = saved.answerField
                                    state.widgets[index].ankiAudioField = saved.audioField
                                    state.widgets[index].ankiTouchBarAudioField = saved.touchBarAudioField
                                    state.widgets[index].ankiExtraQuestionField = saved.extraQuestionField
                                    state.widgets[index].ankiExtraAnswerField = saved.extraAnswerField
                                    var overlayCfg = overlayConfig
                                    overlayCfg.questionField = saved.overlayQuestionField
                                    overlayCfg.answerField = saved.overlayAnswerField
                                    overlayCfg.audioField = saved.overlayAudioField
                                    overlayCfg.extraQuestionField = saved.overlayExtraQuestionField
                                    overlayCfg.extraAnswerField = saved.overlayExtraAnswerField
                                    overlayCfg.boldColorHex = saved.overlayBoldColorHex
                                    AnkiFloatingOverlayManager.shared.config = overlayCfg
                                } else {
                                    state.widgets[index].ankiQuestionField = ""
                                    state.widgets[index].ankiAnswerField = ""
                                    state.widgets[index].ankiAudioField = ""
                                    state.widgets[index].ankiTouchBarAudioField = ""
                                    state.widgets[index].ankiExtraQuestionField = ""
                                    state.widgets[index].ankiExtraAnswerField = ""
                                    var overlayCfg = overlayConfig
                                    overlayCfg.questionField = ""
                                    overlayCfg.answerField = ""
                                    overlayCfg.audioField = ""
                                    overlayCfg.extraQuestionField = ""
                                    overlayCfg.extraAnswerField = ""
                                    overlayCfg.boldColorHex = ""
                                    AnkiFloatingOverlayManager.shared.config = overlayCfg
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
                    .onAppear { state.ankiState.fetchDecks() }

                    HStack(spacing: 8) {
                        Button("Refresh Decks") { state.ankiState.fetchDecks() }
                            .buttonStyle(.bordered).controlSize(.small)
                        Button("Sync AnkiWeb") { state.ankiState.syncDecks() }
                            .buttonStyle(.borderedProminent).tint(.blue).controlSize(.small)
                    }
                }
            }

            Divider()

            // ── Touch Bar Settings ─────────────────────────────────────
            DisclosureGroup(isExpanded: $touchBarExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    // Card Fields
                    VStack(alignment: .leading, spacing: 8) {
                        groupSubHeader("Card Fields")

                        ankiFieldRow("Question:", text: Binding(
                            get: { state.widgets[index].ankiQuestionField },
                            set: { val in
                                state.widgets[index].ankiQuestionField = val
                                saveFieldToDeckSettings { $0.questionField = val }
                                Task { await state.ankiState.loadCurrentCard() }
                            }
                        ))

                        ankiFieldRow("Answer:", text: Binding(
                            get: { state.widgets[index].ankiAnswerField },
                            set: { val in
                                state.widgets[index].ankiAnswerField = val
                                saveFieldToDeckSettings { $0.answerField = val }
                                Task { await state.ankiState.loadCurrentCard() }
                            }
                        ))

                        ankiFieldRow("Audio (Play btn):", text: Binding(
                            get: { state.widgets[index].ankiAudioField },
                            set: { val in
                                state.widgets[index].ankiAudioField = val
                                saveFieldToDeckSettings { $0.audioField = val }
                                Task { await state.ankiState.loadCurrentCard() }
                            }
                        ))

                        ankiFieldRow("TB Tap Audio:", text: Binding(
                            get: { state.widgets[index].ankiTouchBarAudioField },
                            set: { val in
                                state.widgets[index].ankiTouchBarAudioField = val
                                saveFieldToDeckSettings { $0.touchBarAudioField = val }
                                Task { await state.ankiState.loadCurrentCard() }
                            }
                        ))

                        Text("Audio Field → Play/Stop button. TB Tap Audio → played when tapping answer on physical Touch Bar.")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                            .italic()
                    }

                    Divider()

                    // Text & Colors
                    VStack(alignment: .leading, spacing: 8) {
                        groupSubHeader("Text & Colors")

                        HStack(spacing: 8) {
                            Text("Max Text Width:")
                                .font(.system(size: 11))
                                .frame(width: 95, alignment: .leading)
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
                            Text("px").font(.system(size: 11)).foregroundColor(.gray)
                        }

                        HStack(spacing: 8) {
                            Text("Bold Color:")
                                .font(.system(size: 11))
                                .frame(width: 95, alignment: .leading)
                            TextField("#HEX", text: Binding(
                                get: { widget.ankiBoldColorHex },
                                set: { state.widgets[index].ankiBoldColorHex = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: widget.ankiBoldColorHex) },
                                set: { color in if let h = color.toHex() { state.widgets[index].ankiBoldColorHex = h; state.saveConfig(); state.ankiState.refreshTouchBar() } }
                            ))
                        }

                        HStack(spacing: 8) {
                            Text("Horizontal Scroll:")
                                .font(.system(size: 11))
                                .frame(width: 95, alignment: .leading)
                            Picker("", selection: Binding(
                                get: { widget.ankiScrollMode },
                                set: { state.widgets[index].ankiScrollMode = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                            )) {
                                ForEach(AnkiScrollMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)
                            .font(.system(size: 11))
                        }
                    }

                    Divider()

                    // Answer Buttons
                    VStack(alignment: .leading, spacing: 8) {
                        groupSubHeader("Answer Buttons")

                        VStack(alignment: .leading, spacing: 6) {
                            Toggle("Again (1)", isOn: Binding(
                                get: { widget.ankiShowAgain },
                                set: { state.widgets[index].ankiShowAgain = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                            ))
                            Toggle("Hard (2)", isOn: Binding(
                                get: { widget.ankiShowHard },
                                set: { state.widgets[index].ankiShowHard = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                            ))
                            Toggle("Good (3)", isOn: Binding(
                                get: { widget.ankiShowGood },
                                set: { state.widgets[index].ankiShowGood = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                            ))
                            Toggle("Easy (4)", isOn: Binding(
                                get: { widget.ankiShowEasy },
                                set: { state.widgets[index].ankiShowEasy = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                            ))
                        }
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11))

                        Divider()

                        ratingColorRow(label: "Again:", hex: widget.ankiAgainColorHex) { state.widgets[index].ankiAgainColorHex = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                        ratingColorRow(label: "Hard:", hex: widget.ankiHardColorHex) { state.widgets[index].ankiHardColorHex = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                        ratingColorRow(label: "Good:", hex: widget.ankiGoodColorHex) { state.widgets[index].ankiGoodColorHex = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                        ratingColorRow(label: "Easy:", hex: widget.ankiEasyColorHex) { state.widgets[index].ankiEasyColorHex = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }

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

                    // Furigana
                    VStack(alignment: .leading, spacing: 8) {
                        groupSubHeader("Furigana")

                        Toggle("Combine Furigana (私[わたし] → 私 with わたし above)", isOn: Binding(
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
                                Text("Font Size:")
                                    .font(.system(size: 11))
                                    .frame(width: 95, alignment: .leading)
                                TextField("0 = auto", text: Binding(
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
                                .frame(width: 70)
                                Text("pt").font(.system(size: 10)).foregroundColor(.gray)
                            }

                            HStack(spacing: 8) {
                                Text("V Offset:")
                                    .font(.system(size: 11))
                                    .frame(width: 95, alignment: .leading)
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
                                .frame(width: 70)
                                Text("pt").font(.system(size: 10)).foregroundColor(.gray)
                            }

                            HStack(spacing: 8) {
                                Text("Seg Offset:")
                                    .font(.system(size: 11))
                                    .frame(width: 95, alignment: .leading)
                                TextField("0", text: Binding(
                                    get: { String(format: "%.0f", widget.ankiFuriganaSegmentOffset) },
                                    set: { val in
                                        if let num = Double(val.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                            state.widgets[index].ankiFuriganaSegmentOffset = num
                                            state.saveConfig()
                                            state.ankiState.refreshTouchBar()
                                        }
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)
                                Text("pt").font(.system(size: 10)).foregroundColor(.gray)
                            }

                            HStack(spacing: 8) {
                                Text("Text Offset:")
                                    .font(.system(size: 11))
                                    .frame(width: 95, alignment: .leading)
                                TextField("0", text: Binding(
                                    get: { String(format: "%.0f", widget.ankiNonFuriganaSegmentOffset) },
                                    set: { val in
                                        if let num = Double(val.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                            state.widgets[index].ankiNonFuriganaSegmentOffset = num
                                            state.saveConfig()
                                            state.ankiState.refreshTouchBar()
                                        }
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)
                                Text("pt").font(.system(size: 10)).foregroundColor(.gray)
                            }

                            HStack(spacing: 8) {
                                Button("Reset Size") {
                                    state.widgets[index].ankiFuriganaFontSize = 0
                                    state.saveConfig()
                                    state.ankiState.refreshTouchBar()
                                }
                                .font(.system(size: 9))
                                .foregroundColor(widget.ankiFuriganaFontSize == 0 ? .gray : .orange)
                                .buttonStyle(.plain)
                                .disabled(widget.ankiFuriganaFontSize == 0)

                                Button("Reset V Offset") {
                                    state.widgets[index].ankiFuriganaVerticalOffset = 0
                                    state.saveConfig()
                                    state.ankiState.refreshTouchBar()
                                }
                                .font(.system(size: 9))
                                .foregroundColor(widget.ankiFuriganaVerticalOffset == 0 ? .gray : .orange)
                                .buttonStyle(.plain)
                                .disabled(widget.ankiFuriganaVerticalOffset == 0)
                            }
                        } else {
                            HStack(spacing: 8) {
                                Text("Text Offset:")
                                    .font(.system(size: 11))
                                    .frame(width: 95, alignment: .leading)
                                TextField("0", text: Binding(
                                    get: { String(format: "%.0f", widget.ankiNonFuriganaSegmentOffset) },
                                    set: { val in
                                        if let num = Double(val.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                            state.widgets[index].ankiNonFuriganaSegmentOffset = num
                                            state.saveConfig()
                                            state.ankiState.refreshTouchBar()
                                        }
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)
                                Text("pt").font(.system(size: 10)).foregroundColor(.gray)
                            }
                        }
                    }

                    Divider()

                    // Extra Fields (Touch Bar)
                    VStack(alignment: .leading, spacing: 8) {
                        groupSubHeader("Extra Fields")
                        Text("Extra text displayed below the main content on the Touch Bar. Combine multiple fields with commas (e.g. Word, Reading).")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                            .italic()

                        HStack(spacing: 8) {
                            Text("Extra Question:")
                                .font(.system(size: 11))
                                .frame(width: 95, alignment: .leading)
                            TextField("e.g. ExtraFront", text: Binding(
                                get: { state.widgets[index].ankiExtraQuestionField },
                                set: { state.widgets[index].ankiExtraQuestionField = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                        }

                        HStack(spacing: 8) {
                            Text("Extra Answer:")
                                .font(.system(size: 11))
                                .frame(width: 95, alignment: .leading)
                            TextField("e.g. ExtraBack", text: Binding(
                                get: { state.widgets[index].ankiExtraAnswerField },
                                set: { state.widgets[index].ankiExtraAnswerField = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11))
                        }

                        Toggle("Show extra field on tap / hotkey", isOn: Binding(
                            get: { state.widgets[index].ankiTapShowsExtra },
                            set: { state.widgets[index].ankiTapShowsExtra = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                        ))
                        .toggleStyle(.checkbox).font(.system(size: 11))
                    }

                    Divider()

                    // Misc
                    VStack(alignment: .leading, spacing: 8) {
                        groupSubHeader("Other")

                        Toggle("Show remaining cards (New/Learn/Review)", isOn: Binding(
                            get: { widget.ankiShowRemainingCounts },
                            set: { state.widgets[index].ankiShowRemainingCounts = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                        ))
                        .toggleStyle(.checkbox).font(.system(size: 11))

                        Toggle("Move rating buttons to left side", isOn: Binding(
                            get: { isMediaOnLeft },
                            set: { val in
                                isMediaOnLeft = val
                                let c: AnyClass? = NSClassFromString("touchbar.TouchBarPresenter")
                                (c as? NSObject.Type)?.perform(NSSelectorFromString("refreshTouchBar"))
                            }
                        ))
                        .toggleStyle(.checkbox).font(.system(size: 11))

                        Toggle("Only play audio after answer revealed", isOn: Binding(
                            get: { state.widgets[index].ankiAudioOnlyOnAnswer },
                            set: { state.widgets[index].ankiAudioOnlyOnAnswer = $0; state.saveConfig() }
                        ))
                        .toggleStyle(.checkbox).font(.system(size: 11))

                        Toggle("Mute Anki Audio", isOn: Binding(
                            get: { state.ankiState.isMuted },
                            set: { _ in state.ankiState.toggleMute(); state.saveConfig(); StatusItemManager.shared.refreshMuteState() }
                        ))
                        .toggleStyle(.checkbox).font(.system(size: 11))

                        Toggle("Show next review duration on rating buttons (e.g. 30d, 35m)", isOn: Binding(
                            get: { state.widgets[index].ankiShowButtonsInterval },
                            set: { state.widgets[index].ankiShowButtonsInterval = $0; state.saveConfig(); state.ankiState.refreshTouchBar() }
                        ))
                        .toggleStyle(.checkbox).font(.system(size: 11))
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "menubar.rectangle").font(.system(size: 12)).foregroundColor(.purple)
                    Text("Touch Bar Settings").font(.system(size: 12, weight: .bold)).foregroundColor(.primary)
                }
            }

            Divider()

            // ── Floating Overlay ───────────────────────────────────────
            DisclosureGroup(isExpanded: $overlayExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    // Enable/Disable Floating Overlay
                    Toggle("Enable Floating Overlay", isOn: Binding(
                        get: { AnkiFloatingOverlayManager.shared.config.isEnabled },
                        set: { val in
                            var config = AnkiFloatingOverlayManager.shared.config
                            config.isEnabled = val
                            AnkiFloatingOverlayManager.shared.config = config
                        }
                    ))
                    .toggleStyle(.switch)
                    .font(.system(size: 12, weight: .medium))

                    // Overlay Card Fields (independent from Touch Bar)
                    VStack(alignment: .leading, spacing: 8) {
                        groupSubHeader("Overlay Card Fields")
                        Text("Set custom fields for the floating overlay. Leave empty to use the same fields as the Touch Bar.")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                            .italic()

                        ankiFieldRow("Question:", text: Binding(
                            get: { AnkiFloatingOverlayManager.shared.config.questionField },
                            set: { var c = AnkiFloatingOverlayManager.shared.config; c.questionField = $0; AnkiFloatingOverlayManager.shared.config = c; saveOverlayToDeckSettings(); AnkiFloatingOverlayManager.shared.refreshOverlay() }
                        ))

                        ankiFieldRow("Answer:", text: Binding(
                            get: { AnkiFloatingOverlayManager.shared.config.answerField },
                            set: { var c = AnkiFloatingOverlayManager.shared.config; c.answerField = $0; AnkiFloatingOverlayManager.shared.config = c; saveOverlayToDeckSettings(); AnkiFloatingOverlayManager.shared.refreshOverlay() }
                        ))

                        ankiFieldRow("Audio:", text: Binding(
                            get: { AnkiFloatingOverlayManager.shared.config.audioField },
                            set: { var c = AnkiFloatingOverlayManager.shared.config; c.audioField = $0; AnkiFloatingOverlayManager.shared.config = c; saveOverlayToDeckSettings(); AnkiFloatingOverlayManager.shared.refreshOverlay() }
                        ))
                    }

                    Divider()

                    // Extra Fields
                    VStack(alignment: .leading, spacing: 8) {
                        groupSubHeader("Extra Fields")

                        ankiFieldRow("Extra Question:", text: Binding(
                            get: { AnkiFloatingOverlayManager.shared.config.extraQuestionField },
                            set: { var c = AnkiFloatingOverlayManager.shared.config; c.extraQuestionField = $0; AnkiFloatingOverlayManager.shared.config = c; saveOverlayToDeckSettings(); AnkiFloatingOverlayManager.shared.refreshOverlay() }
                        ))

                        Toggle("Show extra question only on answer phase", isOn: Binding(
                            get: { AnkiFloatingOverlayManager.shared.config.extraQuestionOnlyOnAnswer },
                            set: { var c = AnkiFloatingOverlayManager.shared.config; c.extraQuestionOnlyOnAnswer = $0; AnkiFloatingOverlayManager.shared.config = c; saveOverlayToDeckSettings(); AnkiFloatingOverlayManager.shared.refreshOverlay() }
                        ))
                        .toggleStyle(.checkbox).font(.system(size: 11))

                        ankiFieldRow("Extra Answer:", text: Binding(
                            get: { AnkiFloatingOverlayManager.shared.config.extraAnswerField },
                            set: { var c = AnkiFloatingOverlayManager.shared.config; c.extraAnswerField = $0; AnkiFloatingOverlayManager.shared.config = c; saveOverlayToDeckSettings(); AnkiFloatingOverlayManager.shared.refreshOverlay() }
                        ))

                        HStack(spacing: 8) {
                            Text("Text Color:")
                                .font(.system(size: 11))
                                .frame(width: 95, alignment: .leading)
                            TextField("#HEX", text: Binding(
                                get: { AnkiFloatingOverlayManager.shared.config.extraFieldColorHex },
                                set: { var c = AnkiFloatingOverlayManager.shared.config; c.extraFieldColorHex = $0; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: AnkiFloatingOverlayManager.shared.config.extraFieldColorHex) },
                                set: { color in if let h = color.toHex() { var c = AnkiFloatingOverlayManager.shared.config; c.extraFieldColorHex = h; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() } }
                            ))
                        }

                        HStack(spacing: 8) {
                            Text("Font Size:")
                                .font(.system(size: 11))
                                .frame(width: 95, alignment: .leading)
                            Slider(value: Binding(
                                get: { AnkiFloatingOverlayManager.shared.config.extraFieldFontSize },
                                set: { var c = AnkiFloatingOverlayManager.shared.config; c.extraFieldFontSize = $0; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() }
                            ), in: 0...28, step: 1)
                            Text(AnkiFloatingOverlayManager.shared.config.extraFieldFontSize > 0 ? "\(Int(AnkiFloatingOverlayManager.shared.config.extraFieldFontSize))pt" : "Auto")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.gray)
                                .frame(width: 40)
                        }
                    }

                    Divider()

                    // Card Templates
                    VStack(alignment: .leading, spacing: 8) {
                        groupSubHeader("Card Templates")
                        Text("Use Anki-style card templates to render question/answer with full HTML/CSS support. Import templates from the current card's note type to get started, then edit them freely without affecting Anki.")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                            .italic()

                        Toggle("Use Card Template", isOn: Binding(
                            get: { AnkiFloatingOverlayManager.shared.config.useCardTemplate },
                            set: { val in
                                var c = AnkiFloatingOverlayManager.shared.config
                                c.useCardTemplate = val
                                AnkiFloatingOverlayManager.shared.config = c
                                AnkiFloatingOverlayManager.shared.refreshOverlay()
                            }
                        ))
                        .toggleStyle(.switch)
                        .font(.system(size: 11))

                        HStack(spacing: 8) {
                            Button("Import Templates from Current Card") {
                                importCardTemplates()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .controlSize(.small)
                            .disabled(!state.ankiState.isConnected || state.ankiState.selectedDeck.isEmpty)

                            if hasCardTemplates() {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 14))
                                Text("Templates imported")
                                    .font(.system(size: 9))
                                    .foregroundColor(.green)
                            }
                        }

                        if hasCardTemplates() {
                            templateEditor("Front Template", text: Binding(
                                get: { currentDeckFrontTemplate },
                                set: { saveTemplateField(keyPath: \.frontTemplate, value: $0) }
                            ))
                            templateEditor("Back Template", text: Binding(
                                get: { currentDeckBackTemplate },
                                set: { saveTemplateField(keyPath: \.backTemplate, value: $0) }
                            ))
                            templateEditor("CSS Styling", text: Binding(
                                get: { currentDeckTemplateCss },
                                set: { saveTemplateField(keyPath: \.templateCss, value: $0) }
                            ))
                        }
                    }

                    Divider()

                    // Appearance
                    VStack(alignment: .leading, spacing: 8) {
                        groupSubHeader("Appearance")

                        HStack(spacing: 8) {
                            Text("Font Size:")
                                .font(.system(size: 11))
                                .frame(width: 95, alignment: .leading)
                            Slider(value: Binding(
                                get: { AnkiFloatingOverlayManager.shared.config.fontSize },
                                set: { var c = AnkiFloatingOverlayManager.shared.config; c.fontSize = $0; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() }
                            ), in: 10...32, step: 1)
                            Text("\(Int(AnkiFloatingOverlayManager.shared.config.fontSize))pt")
                                .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                                .frame(width: 35)
                        }

                        HStack(spacing: 8) {
                            Text("Furigana Font:")
                                .font(.system(size: 11))
                                .frame(width: 95, alignment: .leading)
                            Slider(value: Binding(
                                get: { AnkiFloatingOverlayManager.shared.config.overlayFuriganaFontSize },
                                set: { var c = AnkiFloatingOverlayManager.shared.config; c.overlayFuriganaFontSize = $0; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() }
                            ), in: 0...20, step: 1)
                            Text(AnkiFloatingOverlayManager.shared.config.overlayFuriganaFontSize > 0 ? "\(Int(AnkiFloatingOverlayManager.shared.config.overlayFuriganaFontSize))pt" : "Auto")
                                .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                                .frame(width: 40)
                        }

                        HStack(spacing: 8) {
                            Text("Window Opacity:")
                                .font(.system(size: 11))
                                .frame(width: 95, alignment: .leading)
                            Slider(value: Binding(
                                get: { AnkiFloatingOverlayManager.shared.config.windowOpacity },
                                set: { var c = AnkiFloatingOverlayManager.shared.config; c.windowOpacity = $0; AnkiFloatingOverlayManager.shared.config = c }
                            ), in: 0.1...1.0, step: 0.05)
                            Text("\(Int(AnkiFloatingOverlayManager.shared.config.windowOpacity * 100))%")
                                .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                                .frame(width: 35)
                        }

                        HStack(spacing: 8) {
                            Text("Text Opacity:")
                                .font(.system(size: 11))
                                .frame(width: 95, alignment: .leading)
                            Slider(value: Binding(
                                get: { AnkiFloatingOverlayManager.shared.config.textOpacity },
                                set: { var c = AnkiFloatingOverlayManager.shared.config; c.textOpacity = $0; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() }
                            ), in: 0.1...1.0, step: 0.05)
                            Text("\(Int(AnkiFloatingOverlayManager.shared.config.textOpacity * 100))%")
                                .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                                .frame(width: 35)
                        }

                        HStack(spacing: 8) {
                            Text("Text Color:")
                                .font(.system(size: 11))
                                .frame(width: 95, alignment: .leading)
                            TextField("#HEX", text: Binding(
                                get: { AnkiFloatingOverlayManager.shared.config.textColorHex },
                                set: { var c = AnkiFloatingOverlayManager.shared.config; c.textColorHex = $0; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() }
                            ))
                            .textFieldStyle(.roundedBorder).frame(width: 80)
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: AnkiFloatingOverlayManager.shared.config.textColorHex) },
                                set: { color in if let h = color.toHex() { var c = AnkiFloatingOverlayManager.shared.config; c.textColorHex = h; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() } }
                            ))
                        }

                        HStack(spacing: 8) {
                            Text("Bg Color:")
                                .font(.system(size: 11))
                                .frame(width: 95, alignment: .leading)
                            TextField("#HEX", text: Binding(
                                get: { AnkiFloatingOverlayManager.shared.config.backgroundColorHex },
                                set: { var c = AnkiFloatingOverlayManager.shared.config; c.backgroundColorHex = $0; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() }
                            ))
                            .textFieldStyle(.roundedBorder).frame(width: 80)
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: AnkiFloatingOverlayManager.shared.config.backgroundColorHex) },
                                set: { color in if let h = color.toHex() { var c = AnkiFloatingOverlayManager.shared.config; c.backgroundColorHex = h; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() } }
                            ))
                        }

                        HStack(spacing: 8) {
                            Text("Q Preview Color:")
                                .font(.system(size: 11))
                                .frame(width: 95, alignment: .leading)
                            TextField("#HEX", text: Binding(
                                get: { AnkiFloatingOverlayManager.shared.config.questionAnswerColorHex },
                                set: { var c = AnkiFloatingOverlayManager.shared.config; c.questionAnswerColorHex = $0; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() }
                            ))
                            .textFieldStyle(.roundedBorder).frame(width: 80)
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: AnkiFloatingOverlayManager.shared.config.questionAnswerColorHex) },
                                set: { color in if let h = color.toHex() { var c = AnkiFloatingOverlayManager.shared.config; c.questionAnswerColorHex = h; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() } }
                            ))
                        }

                        HStack(spacing: 8) {
                            Text("Bold Color:")
                                .font(.system(size: 11))
                                .frame(width: 95, alignment: .leading)
                            TextField("#HEX", text: Binding(
                                get: { AnkiFloatingOverlayManager.shared.config.boldColorHex },
                                set: { var c = AnkiFloatingOverlayManager.shared.config; c.boldColorHex = $0; AnkiFloatingOverlayManager.shared.config = c; saveOverlayToDeckSettings(); AnkiFloatingOverlayManager.shared.refreshOverlay() }
                            ))
                            .textFieldStyle(.roundedBorder).frame(width: 80)
                            ColorPicker("", selection: Binding(
                                get: { Color(hex: AnkiFloatingOverlayManager.shared.config.boldColorHex.isEmpty ? "#FFD60A" : AnkiFloatingOverlayManager.shared.config.boldColorHex) },
                                set: { color in if let h = color.toHex() { var c = AnkiFloatingOverlayManager.shared.config; c.boldColorHex = h; AnkiFloatingOverlayManager.shared.config = c; saveOverlayToDeckSettings(); AnkiFloatingOverlayManager.shared.refreshOverlay() } }
                            ))
                        }
                    }

                    Divider()

                    // Controls
                    VStack(alignment: .leading, spacing: 8) {
                        groupSubHeader("Controls")

                        Toggle("Rating Buttons", isOn: Binding(
                            get: { AnkiFloatingOverlayManager.shared.config.showRatingButtons },
                            set: { var c = AnkiFloatingOverlayManager.shared.config; c.showRatingButtons = $0; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() }
                        ))
                        Toggle("Audio Button", isOn: Binding(
                            get: { AnkiFloatingOverlayManager.shared.config.showAudioButton },
                            set: { var c = AnkiFloatingOverlayManager.shared.config; c.showAudioButton = $0; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() }
                        ))
                        Toggle("Sync Button", isOn: Binding(
                            get: { AnkiFloatingOverlayManager.shared.config.showSyncButton },
                            set: { var c = AnkiFloatingOverlayManager.shared.config; c.showSyncButton = $0; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() }
                        ))
                        Toggle("Reveal Button", isOn: Binding(
                            get: { AnkiFloatingOverlayManager.shared.config.showRevealButton },
                            set: { var c = AnkiFloatingOverlayManager.shared.config; c.showRevealButton = $0; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() }
                        ))
                        Toggle("Header (Deck Name & Counter)", isOn: Binding(
                            get: { AnkiFloatingOverlayManager.shared.config.showHeader },
                            set: { var c = AnkiFloatingOverlayManager.shared.config; c.showHeader = $0; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() }
                        ))
                        if AnkiFloatingOverlayManager.shared.config.showHeader {
                            Toggle("Swap deck name & counter position", isOn: Binding(
                                get: { AnkiFloatingOverlayManager.shared.config.swapHeaderDeckAndCounts },
                                set: { var c = AnkiFloatingOverlayManager.shared.config; c.swapHeaderDeckAndCounts = $0; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() }
                            ))
                            .toggleStyle(.checkbox).font(.system(size: 10)).padding(.leading, 16)
                        }
                        if !AnkiFloatingOverlayManager.shared.config.showHeader {
                            Toggle("Counts only (without header)", isOn: Binding(
                                get: { AnkiFloatingOverlayManager.shared.config.showCounts },
                                set: { var c = AnkiFloatingOverlayManager.shared.config; c.showCounts = $0; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() }
                            ))
                            .toggleStyle(.checkbox).font(.system(size: 10)).padding(.leading, 16)
                        }
                        Toggle("Hide Title Bar (focus mode)", isOn: Binding(
                            get: { AnkiFloatingOverlayManager.shared.config.hideTitleBar },
                            set: { var c = AnkiFloatingOverlayManager.shared.config; c.hideTitleBar = $0; AnkiFloatingOverlayManager.shared.config = c }
                        ))
                        Toggle("Show next review duration on rating buttons", isOn: Binding(
                            get: { AnkiFloatingOverlayManager.shared.config.showButtonsInterval },
                            set: { var c = AnkiFloatingOverlayManager.shared.config; c.showButtonsInterval = $0; AnkiFloatingOverlayManager.shared.config = c; AnkiFloatingOverlayManager.shared.refreshOverlay() }
                        ))
                    }
                    .toggleStyle(.checkbox).font(.system(size: 11))

                    Divider()

                    HStack(spacing: 8) {
                        Button(action: { AnkiFloatingOverlayManager.shared.show() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "eye.fill").font(.system(size: 10))
                                Text("Show Overlay").font(.system(size: 10))
                            }
                            .padding(.vertical, 5).padding(.horizontal, 10)
                            .background(Color.teal.opacity(0.2)).foregroundColor(.teal).cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: { AnkiFloatingOverlayManager.shared.hide() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "eye.slash.fill").font(.system(size: 10))
                                Text("Hide").font(.system(size: 10))
                            }
                            .padding(.vertical, 5).padding(.horizontal, 10)
                            .background(Color.red.opacity(0.2)).foregroundColor(.red).cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "rectangle.3.group.fill").font(.system(size: 12)).foregroundColor(.teal)
                    Text("Floating Overlay").font(.system(size: 12, weight: .bold)).foregroundColor(.primary)
                }
            }

            Divider()

            // ── Widget ─────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "paintbrush").font(.system(size: 12)).foregroundColor(.orange)
                    Text("Widget").font(.system(size: 12, weight: .bold))
                }

                HStack(spacing: 8) {
                    Text("Custom Width:")
                        .font(.system(size: 11))
                        .frame(width: 95, alignment: .leading)
                    TextField("0 = auto", text: Binding(
                        get: { String(Int(widget.customWidth)) },
                        set: { val in
                            if let num = Double(val.filter { $0.isNumber }) {
                                state.widgets[index].customWidth = num
                                state.saveConfig()
                            }
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    Text("px").font(.system(size: 11)).foregroundColor(.gray)
                }

                Toggle("Hide from Touch Bar (keep keyboard & overlay)", isOn: Binding(
                    get: { widget.hideFromTouchBar },
                    set: { state.widgets[index].hideFromTouchBar = $0; state.saveConfig() }
                ))
                .toggleStyle(.switch).font(.system(size: 11))
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "chart.bar").font(.system(size: 12)).foregroundColor(.gray)
                    Text("Session Stats").font(.system(size: 12, weight: .bold))
                }
                HStack {
                    Text("Cards Reviewed:")
                    Spacer()
                    Text("\(state.ankiState.cardsReviewed)").fontWeight(.bold)
                }
                HStack {
                    Text("Time Elapsed:")
                    Spacer()
                    Text(state.ankiState.sessionDuration).fontWeight(.bold)
                }
            }
            .font(.system(size: 11)).foregroundColor(.gray)

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
                    ForEach(AnkiHotkeyAction.allCases.filter { $0 != .toggleNHKFloatingWindow && $0 != .openSettings }, id: \.rawValue) { action in
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
        }
    }

    // MARK: - Helpers

    private func groupHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12)).foregroundColor(color)
            Text(title).font(.system(size: 12, weight: .bold))
        }
    }

    private func groupSubHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.gray)
    }

    private func ankiFieldRow(_ label: String, text: Binding<String>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .frame(width: 95, alignment: .leading)
            TextField("", text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
        }
    }

    private func saveFieldToDeckSettings(_ update: (inout AnkiDeckSettings) -> Void) {
        let deck = state.widgets[index].ankiDeckName
        if !deck.isEmpty {
            var settings = state.widgets[index].ankiDeckSettings[deck] ?? AnkiDeckSettings(
                questionField: state.widgets[index].ankiQuestionField,
                answerField: state.widgets[index].ankiAnswerField,
                audioField: state.widgets[index].ankiAudioField
            )
            update(&settings)
            state.widgets[index].ankiDeckSettings[deck] = settings
        }
        state.saveConfig()
    }

    private func saveOverlayToDeckSettings() {
        let deck = state.widgets[index].ankiDeckName
        if !deck.isEmpty {
            let overlayConfig = AnkiFloatingOverlayManager.shared.config
            var settings = state.widgets[index].ankiDeckSettings[deck] ?? AnkiDeckSettings(
                questionField: state.widgets[index].ankiQuestionField,
                answerField: state.widgets[index].ankiAnswerField,
                audioField: state.widgets[index].ankiAudioField
            )
            settings.overlayQuestionField = overlayConfig.questionField
            settings.overlayAnswerField = overlayConfig.answerField
            settings.overlayAudioField = overlayConfig.audioField
            settings.overlayExtraQuestionField = overlayConfig.extraQuestionField
            settings.overlayExtraAnswerField = overlayConfig.extraAnswerField
            settings.overlayBoldColorHex = overlayConfig.boldColorHex
            state.widgets[index].ankiDeckSettings[deck] = settings
        }
        state.saveConfig()
    }

    private func hasCardTemplates() -> Bool {
        let deck = state.widgets[index].ankiDeckName
        guard !deck.isEmpty else { return false }
        guard let settings = state.widgets[index].ankiDeckSettings[deck] else { return false }
        return !settings.frontTemplate.isEmpty || !settings.backTemplate.isEmpty
    }

    @State private var importInProgress: Bool = false
    private func importCardTemplates() {
        guard !importInProgress else { return }
        importInProgress = true
        Task {
            do {
                // Fetch fresh card data from Anki to get modelName
                let ankiCard = try? await AnkiConnectClient.shared.getCurrentCard(
                    questionField: state.widgets[index].ankiQuestionField,
                    answerField: state.widgets[index].ankiAnswerField,
                    audioField: state.widgets[index].ankiAudioField,
                    touchBarAudioField: state.widgets[index].ankiTouchBarAudioField
                )
                guard let card = ankiCard, !card.modelName.isEmpty else {
                    print("Import cancelled: no card available or model name is empty")
                    importInProgress = false
                    return
                }
                print("Importing templates for model: \(card.modelName)")
                let (frontTemplate, backTemplate) = try await AnkiConnectClient.shared.modelTemplates(modelName: card.modelName)
                let css = try await AnkiConnectClient.shared.modelStyling(modelName: card.modelName)
                print("Got templates: front=\(frontTemplate.count)chars, back=\(backTemplate.count)chars, css=\(css.count)chars")

                let deck = state.widgets[index].ankiDeckName
                guard !deck.isEmpty else {
                    print("Import cancelled: no deck selected")
                    importInProgress = false
                    return
                }
                var widget = state.widgets[index]
                var settings = widget.ankiDeckSettings[deck] ?? AnkiDeckSettings(
                    questionField: widget.ankiQuestionField,
                    answerField: widget.ankiAnswerField,
                    audioField: widget.ankiAudioField
                )
                settings.frontTemplate = frontTemplate
                settings.backTemplate = backTemplate
                settings.templateCss = css
                widget.ankiDeckSettings[deck] = settings
                state.widgets[index] = widget
                state.saveConfig()
                print("Templates saved for deck: \(deck)")

                var overlayCfg = AnkiFloatingOverlayManager.shared.config
                overlayCfg.useCardTemplate = true
                AnkiFloatingOverlayManager.shared.config = overlayCfg
                AnkiFloatingOverlayManager.shared.refreshOverlay()
                print("Template import complete")
            } catch {
                print("Failed to import card templates: \(error)")
            }
            importInProgress = false
        }
    }

    // MARK: - Template Editor Helpers

    private var currentDeckFrontTemplate: String {
        let deck = state.widgets[index].ankiDeckName
        return state.widgets[index].ankiDeckSettings[deck]?.frontTemplate ?? ""
    }

    private var currentDeckBackTemplate: String {
        let deck = state.widgets[index].ankiDeckName
        return state.widgets[index].ankiDeckSettings[deck]?.backTemplate ?? ""
    }

    private var currentDeckTemplateCss: String {
        let deck = state.widgets[index].ankiDeckName
        return state.widgets[index].ankiDeckSettings[deck]?.templateCss ?? ""
    }

    private func saveTemplateField(keyPath: WritableKeyPath<AnkiDeckSettings, String>, value: String) {
        let deck = state.widgets[index].ankiDeckName
        guard !deck.isEmpty else { return }
        var widget = state.widgets[index]
        var settings = widget.ankiDeckSettings[deck] ?? AnkiDeckSettings(
            questionField: widget.ankiQuestionField,
            answerField: widget.ankiAnswerField,
            audioField: widget.ankiAudioField
        )
        settings[keyPath: keyPath] = value
        widget.ankiDeckSettings[deck] = settings
        state.widgets[index] = widget
        state.saveConfig()
        AnkiFloatingOverlayManager.shared.refreshOverlay()
    }

    @ViewBuilder
    private func templateEditor(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
            TextEditor(text: text)
                .font(.system(size: 9, design: .monospaced))
                .frame(height: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
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
        case .nhkNews:
            NHKNewsConfigView(widget: widget, index: index, state: state)
        case .dock:
            DockOptionsView(widget: widget, index: index, state: state)
        case .appLauncher:
            AppLauncherConfigView(widget: widget, index: index, state: state)
        }
    }
}

// MARK: - NHK News Easy Config View

struct NHKNewsConfigView: View {
    let widget: TouchBarWidget
    let index: Int
    let state: AppState

    @AppStorage("NHKF_translationEnabled") private var translationEnabled = false
    @AppStorage("NHKF_translationTargetLanguage") private var translationTargetLanguage = "en"
    @AppStorage("NHKF_translationShowMode") private var translationShowModeRaw = NHKTranslationShowMode.toggle.rawValue
    @AppStorage("NHKF_translationColorHex") private var translationColorHex = "#40E0D0"
    
    var body: some View {
        let nhk = state.nhkNewsState
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Status:")
                    .font(.system(size: 11, weight: .bold))
                Spacer()
                if nhk.isLoading {
                    Text("Loading...")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue).cornerRadius(4)
                } else if !nhk.errorMessage.isEmpty {
                    Text("Error")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red).cornerRadius(4)
                } else if !nhk.articles.isEmpty {
                    Text("\(nhk.articles.count) articles")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green).cornerRadius(4)
                } else {
                    Text("Idle")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray).cornerRadius(4)
                }
            }
            
            if let lastUpdated = nhk.lastUpdated {
                HStack {
                    Text("Last Updated:")
                        .font(.system(size: 10)).foregroundColor(.gray)
                    Spacer()
                    Text(lastUpdated, style: .relative)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            
            Toggle("Hide from Touch Bar (keep keyboard & floating window)", isOn: Binding(
                get: { widget.hideFromTouchBar },
                set: { state.widgets[index].hideFromTouchBar = $0; state.saveConfig() }
            ))
            .toggleStyle(.switch)
            .font(.system(size: 11))

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Furigana")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)

                HStack(spacing: 8) {
                    Text("Font Size:")
                        .font(.system(size: 11))
                        .frame(width: 100, alignment: .leading)
                    Slider(value: Binding(
                        get: { widget.nhkFuriganaFontSize == 0 ? 5 : widget.nhkFuriganaFontSize },
                        set: { state.widgets[index].nhkFuriganaFontSize = $0; state.saveConfig() }
                    ), in: 4...12, step: 0.5)
                    Text(widget.nhkFuriganaFontSize > 0
                         ? String(format: "%.1fpt", widget.nhkFuriganaFontSize)
                         : "Auto")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                        .frame(width: 40, alignment: .trailing)
                }
                Button("Reset Auto") {
                    state.widgets[index].nhkFuriganaFontSize = 0
                    state.saveConfig()
                }
                .buttonStyle(.plain)
                .font(.system(size: 9))
                .foregroundColor(.orange)
                .disabled(widget.nhkFuriganaFontSize == 0)

                HStack(spacing: 8) {
                    Text("Color:")
                        .font(.system(size: 11))
                        .frame(width: 100, alignment: .leading)
                    TextField("#HEX", text: Binding(
                        get: { widget.nhkFuriganaColorHex },
                        set: { state.widgets[index].nhkFuriganaColorHex = $0; state.saveConfig() }
                    ))
                    .textFieldStyle(.roundedBorder)
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: widget.nhkFuriganaColorHex) },
                        set: { color in
                            if let hex = color.toHex() {
                                state.widgets[index].nhkFuriganaColorHex = hex
                                state.saveConfig()
                            }
                        }
                    ))
                }

                Toggle("Navigation buttons on left side", isOn: Binding(
                    get: { widget.nhkNavOnLeft },
                    set: { state.widgets[index].nhkNavOnLeft = $0; state.saveConfig() }
                ))
                .font(.system(size: 11))
                .toggleStyle(.switch)

                Toggle("Floating Window", isOn: Binding(
                    get: { NHKFloatingWindowManager.shared.isEnabled },
                    set: { newVal in
                        NHKFloatingWindowManager.shared.isEnabled = newVal
                        if !newVal {
                            NHKFloatingWindowManager.shared.hide()
                        } else {
                            NHKFloatingWindowManager.shared.show()
                        }
                    }
                ))
                .font(.system(size: 11))
                .toggleStyle(.switch)

                HStack(spacing: 8) {
                    Text("Max Width:")
                        .font(.system(size: 11))
                        .frame(width: 100, alignment: .leading)
                    TextField("0 = auto", text: Binding(
                        get: { widget.customWidth > 0 ? String(Int(widget.customWidth)) : "" },
                        set: { val in
                            state.widgets[index].customWidth = Double(val) ?? 0
                            state.saveConfig()
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    Stepper("", value: Binding(
                        get: { widget.customWidth },
                        set: { state.widgets[index].customWidth = $0; state.saveConfig() }
                    ), in: 0...500, step: 10)
                    .labelsHidden()
                }

                Text("Floating Window Settings")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.teal)
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    Text("Font Size:")
                        .font(.system(size: 11))
                        .frame(width: 100, alignment: .leading)
                    Slider(value: Binding(
                        get: { NHKFloatingWindowManager.shared.fontSize },
                        set: { NHKFloatingWindowManager.shared.fontSize = $0; NHKFloatingWindowManager.shared.refreshContent() }
                    ), in: 10...36, step: 1)
                    Text("\(Int(NHKFloatingWindowManager.shared.fontSize))px")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                        .frame(width: 40, alignment: .trailing)
                }

                HStack(spacing: 8) {
                    Text("Text Color:")
                        .font(.system(size: 11))
                        .frame(width: 100, alignment: .leading)
                    TextField("#HEX", text: Binding(
                        get: { NHKFloatingWindowManager.shared.textColorHex },
                        set: { NHKFloatingWindowManager.shared.textColorHex = $0; NHKFloatingWindowManager.shared.refreshContent() }
                    ))
                    .textFieldStyle(.roundedBorder)
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: NHKFloatingWindowManager.shared.textColorHex) },
                        set: { color in
                            if let hex = color.toHex() {
                                NHKFloatingWindowManager.shared.textColorHex = hex
                                NHKFloatingWindowManager.shared.refreshContent()
                            }
                        }
                    ))
                }

                HStack(spacing: 8) {
                    Text("Furi Size:")
                        .font(.system(size: 11))
                        .frame(width: 100, alignment: .leading)
                    Slider(value: Binding(
                        get: { NHKFloatingWindowManager.shared.furiganaFontSize },
                        set: { NHKFloatingWindowManager.shared.furiganaFontSize = $0; NHKFloatingWindowManager.shared.refreshContent() }
                    ), in: 0...20, step: 1)
                    Text(NHKFloatingWindowManager.shared.furiganaFontSize > 0 ? "\(Int(NHKFloatingWindowManager.shared.furiganaFontSize))px" : "Auto")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.gray)
                        .frame(width: 40, alignment: .trailing)
                }
                Button("Reset Auto") {
                    NHKFloatingWindowManager.shared.furiganaFontSize = 0
                    NHKFloatingWindowManager.shared.refreshContent()
                }
                .buttonStyle(.plain)
                .font(.system(size: 9))
                .foregroundColor(.orange)
                .disabled(NHKFloatingWindowManager.shared.furiganaFontSize == 0)

                HStack(spacing: 8) {
                    Text("Furi Color:")
                        .font(.system(size: 11))
                        .frame(width: 100, alignment: .leading)
                    TextField("#HEX", text: Binding(
                        get: { NHKFloatingWindowManager.shared.furiganaColorHex },
                        set: { NHKFloatingWindowManager.shared.furiganaColorHex = $0; NHKFloatingWindowManager.shared.refreshContent() }
                    ))
                    .textFieldStyle(.roundedBorder)
                    ColorPicker("", selection: Binding(
                        get: { Color(hex: NHKFloatingWindowManager.shared.furiganaColorHex) },
                        set: { color in
                            if let hex = color.toHex() {
                                NHKFloatingWindowManager.shared.furiganaColorHex = hex
                                NHKFloatingWindowManager.shared.refreshContent()
                            }
                        }
                    ))
                }
            }

            Divider()

            // MARK: - Translation Settings
            VStack(alignment: .leading, spacing: 8) {
                Text("Translation")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.teal)

                Toggle("Enable Translation", isOn: $translationEnabled)
                    .toggleStyle(.switch)
                    .font(.system(size: 11))
                    .onChange(of: translationEnabled) { _, _ in
                        if !translationEnabled {
                            translationShowModeRaw = NHKTranslationShowMode.toggle.rawValue
                        }
                        NHKFloatingWindowManager.shared.refreshContent()
                    }

                if translationEnabled {
                    HStack(spacing: 8) {
                        Text("Target Language:")
                            .font(.system(size: 11))
                            .frame(width: 110, alignment: .leading)

                        Picker("", selection: $translationTargetLanguage) {
                            ForEach(TranslationLanguage.supported.filter { $0.id != "ja" }) { lang in
                                HStack {
                                    Text(lang.nativeName)
                                    Text("(\(lang.displayName))")
                                        .foregroundColor(.gray)
                                }.tag(lang.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                        .onChange(of: translationTargetLanguage) { _, _ in
                            NHKFloatingWindowManager.shared.refreshContent()
                        }
                    }

                    Picker("Show Translation:", selection: Binding(
                        get: { NHKTranslationShowMode(rawValue: translationShowModeRaw) ?? .toggle },
                        set: { translationShowModeRaw = $0.rawValue }
                    )) {
                        ForEach(NHKTranslationShowMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .font(.system(size: 10))
                    .onChange(of: translationShowModeRaw) { _, _ in
                        NHKFloatingWindowManager.shared.refreshContent()
                    }

                    HStack(spacing: 8) {
                        Text("Translation Color:")
                            .font(.system(size: 11))
                            .frame(width: 110, alignment: .leading)

                        TextField("#HEX", text: $translationColorHex)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 90)
                            .onChange(of: translationColorHex) { _, _ in
                                NHKFloatingWindowManager.shared.refreshContent()
                            }

                        ColorPicker("", selection: Binding(
                            get: { Color(hex: translationColorHex) },
                            set: { color in
                                if let hex = color.toHex() {
                                    translationColorHex = hex
                                    NHKFloatingWindowManager.shared.refreshContent()
                                }
                            }
                        ))
                    }

                    Text("'Toggle' adds a button to toggle translation. 'Always' shows translation automatically.")
                        .font(.system(size: 9))
                        .foregroundColor(.gray)
                        .italic()
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.03))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.05), lineWidth: 1))

            Divider()

            // MARK: - NHK Keyboard Shortcut
            VStack(alignment: .leading, spacing: 8) {
                Text("Keyboard Shortcut")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)

                Text("Set a global hotkey to toggle the NHK floating window even when TouchBarCraft is in the background.")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
                    .italic()

                HotkeyRecorderRow(action: .toggleNHKFloatingWindow)
            }

            Divider()

            if let article = nhk.currentArticle {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Article")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.gray)
                    Text(article.title)
                        .font(.system(size: 11)).foregroundColor(.white).lineLimit(3)
                    if !article.description.isEmpty {
                        Text(article.description)
                            .font(.system(size: 10)).foregroundColor(.gray).lineLimit(2)
                    }
                    HStack {
                        Text("Article \(nhk.currentArticleIndex + 1) of \(nhk.articles.count)")
                            .font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                        Spacer()
                        if !article.contentChunks.isEmpty {
                            Text("\(article.contentChunks.count) chunks")
                                .font(.system(size: 9, design: .monospaced)).foregroundColor(.teal)
                        }
                    }
                }
                Divider()
            }
            
            HStack(spacing: 8) {
                Button(action: { Task { await nhk.fetchArticles() } }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh News")
                    }.padding(.vertical, 6).padding(.horizontal, 12)
                    .background(Color.red.opacity(0.2))
                    .foregroundColor(.red).cornerRadius(6)
                }.buttonStyle(.plain)
                
                Button(action: { nhk.nextArticle() }) {
                    HStack {
                        Image(systemName: "forward.fill")
                        Text("Next")
                    }.padding(.vertical, 6).padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue).cornerRadius(6)
                }.buttonStyle(.plain)
            }
            
            if nhk.mode == .reading {
                Divider()
                Text("Reading Mode")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(.teal)
                HStack(spacing: 8) {
                    Button(action: { nhk.previousChunk() }) {
                        Label("Prev", systemImage: "chevron.left").font(.system(size: 10))
                    }.buttonStyle(.bordered).controlSize(.small)
                    if nhk.hasChunks {
                        Text(nhk.chunkProgress)
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                    }
                    Button(action: { nhk.nextChunk() }) {
                        Label("Next", systemImage: "chevron.right").font(.system(size: 10))
                    }.buttonStyle(.bordered).controlSize(.small)
                    Button(action: { nhk.returnToList() }) {
                        Label("List", systemImage: "list.bullet").font(.system(size: 10))
                    }.buttonStyle(.bordered).controlSize(.small)
                }
            } else if nhk.currentArticle != nil {
                Button(action: { nhk.startReading() }) {
                    Label("Start Reading", systemImage: "book.fill").font(.system(size: 11))
                }.buttonStyle(.borderedProminent).tint(.red).controlSize(.small)
            }
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

    @State private var editorText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(title, selection: $actionType) {
                ForEach(ActionType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: actionType) { _ in
                editorText = actionValue
            }

            if actionType == .shellCommand || actionType == .appleScript {
                VStack(alignment: .leading, spacing: 4) {
                    Text(actionType == .shellCommand ? "Shell command to run:" : "AppleScript to run:")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)

                    TextEditor(text: $editorText)
                        .focused($isFocused)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(height: 50)
                        .padding(4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(4)
                        .onChange(of: isFocused) { focused in
                            if !focused {
                                actionValue = editorText
                            }
                        }

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
        .onAppear {
            editorText = actionValue
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

// MARK: - Swipe Gesture Configuration

struct SwipeConfigurationView: View {
    let state: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
                Text("Swipe Gestures")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.orange)
            }
            
            Text("Configure separate swipe actions for 2-finger and 3-finger gestures on the Touch Bar.")
                .font(.system(size: 10))
                .foregroundColor(.gray)
            
            fingerSection(title: "2 Fingers", 
                          leftBinding: Binding(get: { state.swipe2LeftActionType }, set: { state.swipe2LeftActionType = $0; refreshTouchBar() }),
                          rightBinding: Binding(get: { state.swipe2RightActionType }, set: { state.swipe2RightActionType = $0; refreshTouchBar() }))
            
            Divider()
            
            fingerSection(title: "3 Fingers",
                          leftBinding: Binding(get: { state.swipe3LeftActionType }, set: { state.swipe3LeftActionType = $0; refreshTouchBar() }),
                          rightBinding: Binding(get: { state.swipe3RightActionType }, set: { state.swipe3RightActionType = $0; refreshTouchBar() }))
            
            Text("Horizontal swipe must exceed 30pt threshold. Settings are stored in UserDefaults and apply to all widgets.")
                .font(.system(size: 9))
                .foregroundColor(.gray)
                .italic()
        }
    }
    
    private func fingerSection(title: String, leftBinding: Binding<ActionType>, rightBinding: Binding<ActionType>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
            Picker("Swipe Left:", selection: leftBinding) {
                ForEach(ActionType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)
            Picker("Swipe Right:", selection: rightBinding) {
                ForEach(ActionType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.menu)
        }
        .font(.system(size: 11))
    }
    
    private func refreshTouchBar() {
        let presenterClass: AnyClass? = NSClassFromString("touchbar.TouchBarPresenter")
        let refreshSelector = NSSelectorFromString("refreshTouchBar")
        if let presenter = presenterClass as? NSObject.Type {
            presenter.perform(refreshSelector)
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

// MARK: - Dock Widget Config View

struct DockOptionsView: View {
    let widget: TouchBarWidget
    let index: Int
    let state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Custom Width:")
                    .font(.system(size: 11))
                    .frame(width: 100, alignment: .leading)
                TextField("0 = auto", text: Binding(
                    get: { widget.customWidth > 0 ? String(Int(widget.customWidth)) : "" },
                    set: { val in
                        state.widgets[index].customWidth = Double(val) ?? 0
                        state.saveConfig()
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                Stepper("", value: Binding(
                    get: { widget.customWidth },
                    set: { state.widgets[index].customWidth = $0; state.saveConfig() }
                ), in: 0...500, step: 10)
                .labelsHidden()
            }
        }
    }
}

// MARK: - App Launcher Widget Config View

struct AppLauncherConfigView: View {
    let widget: TouchBarWidget
    let index: Int
    let state: AppState

    var body: some View {
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Custom Width:")
                    .font(.system(size: 11))
                    .frame(width: 100, alignment: .leading)
                TextField("0 = auto", text: Binding(
                    get: { widget.customWidth > 0 ? String(Int(widget.customWidth)) : "" },
                    set: { val in
                        state.widgets[index].customWidth = Double(val) ?? 0
                        state.saveConfig()
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                Stepper("", value: Binding(
                    get: { widget.customWidth },
                    set: { state.widgets[index].customWidth = $0; state.saveConfig() }
                ), in: 0...500, step: 10)
                .labelsHidden()
            }

            Text("Applications")
                .font(.system(size: 11, weight: .semibold))

            if !widget.appLauncherApps.isEmpty {
                List {
                    ForEach(Array(widget.appLauncherApps.enumerated()), id: \.element) { i, bid in
                        let app: (bundleID: String, url: URL?, name: String) = {
                            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                                return (bid, url, FileManager.default.displayName(atPath: url.path))
                            }
                            return (bid, nil, bid)
                        }()
                        HStack(spacing: 6) {
                            if let url = app.url {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                    .resizable()
                                    .frame(width: 18, height: 18)
                                Text(app.name)
                                    .font(.system(size: 11))
                            } else {
                                Text(app.bundleID)
                                    .font(.system(size: 10))
                                    .foregroundColor(.red)
                            }
                            Spacer()
                            Button("Remove") {
                                state.widgets[index].appLauncherApps.remove(at: i)
                                state.saveConfig()
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.red)
                            .font(.system(size: 10))
                        }
                        .onDrag { NSItemProvider(object: String(i) as NSString) }
                        .onDrop(of: [.text], delegate: ReorderDropDelegate(item: i) { from, to in
                            let item = state.widgets[index].appLauncherApps.remove(at: from)
                            state.widgets[index].appLauncherApps.insert(item, at: to > from ? to - 1 : to)
                            state.saveConfig()
                        })
                    }
                    .onDelete { sources in
                        for source in sources.sorted(by: >) {
                            state.widgets[index].appLauncherApps.remove(at: source)
                        }
                        state.saveConfig()
                    }
                }
                .listStyle(.plain)
                .frame(height: min(CGFloat(widget.appLauncherApps.count) * 30, 200))
            }

            Button("Add from Running Apps") {
                let runningApps = NSWorkspace.shared.runningApplications
                    .filter { $0.activationPolicy == .regular }
                    .compactMap { $0.bundleIdentifier }
                for bid in runningApps {
                    if !state.widgets[index].appLauncherApps.contains(bid) {
                        state.widgets[index].appLauncherApps.append(bid)
                    }
                }
                state.saveConfig()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            Button("Browse…") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = true
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                panel.allowedFileTypes = ["app"]
                guard panel.runModal() == .OK else { return }
                for url in panel.urls {
                    guard let bundle = Bundle(url: url),
                          let bundleID = bundle.bundleIdentifier else { continue }
                    if !state.widgets[index].appLauncherApps.contains(bundleID) {
                        state.widgets[index].appLauncherApps.append(bundleID)
                    }
                }
                state.saveConfig()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

            if !state.widgets[index].appLauncherApps.isEmpty {
                Button("Remove All", role: .destructive) {
                    state.widgets[index].appLauncherApps.removeAll()
                    state.saveConfig()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.red)
            }
        }
    }
}

// MARK: - Drag-Drop Reordering Delegate

struct ReorderDropDelegate: DropDelegate {
    let item: Int
    let onMove: (Int, Int) -> Void

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [.text]).first else {
            return false
        }
        provider.loadObject(ofClass: NSString.self) { str, _ in
            guard let str = str as? String, let from = Int(str) else { return }
            DispatchQueue.main.async {
                self.onMove(from, self.item)
            }
        }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.text])
    }
}
