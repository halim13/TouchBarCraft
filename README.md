# 💻 TouchBarCraft

<p align="center">
  <img src="Assets/AppIcon.png" alt="TouchBarCraft Logo" width="128" height="128">
</p>

<p align="center">
  <strong>Craft and customize your macOS Touch Bar with modern, dynamic widgets.</strong>
</p>

---

**TouchBarCraft** is a lightweight, high-performance utility written in Swift and SwiftUI that allows you to take full control of your macOS Touch Bar. It overrides the default system Control Strip with custom, interactive widgets configured directly from a modern GUI.

## ✨ Features

- **Global Touch Bar Override**: Fully replaces the native macOS Touch Bar system-wide.
- **System Tray Menu Bar Item**: Quick access to controls and settings right from your macOS Menu Bar.
- **Launch at Login (Autostart)**: Uses Apple's modern `SMAppService` API to launch at startup seamlessly.
- **Custom JSON Configuration**: Widgets are dynamically saved and loaded from `~/.touchbarcraft.json`.

---

## 🛠 Available Widgets

| Widget Type | Description |
| :--- | :--- |
| **🏷 Label** | Dynamic text output supporting placeholders like `{time}` and `{date}`. |
| **⚡️ Button** | Custom action buttons that can execute shell commands, play sounds, toggle Dark Mode, or sleep/lock the screen. |
| **📊 System Monitor** | Real-time monitoring of CPU usage, RAM usage, and battery/charging status. |
| **🎵 Media Controller** | Media control widget supporting play/pause status and current playback. |
| **🐈 Animation** | Add custom pets (like an animated cat) and control frame speed on your Touch Bar. |
| **🗂 Anki Integration** | Syncs with `AnkiConnect` to track your daily review deck progress and card due counts. |
| **🔊 Volume Slider** | Adjust system audio volume using a native Touch Bar slider control. |
| **🔆 Brightness Buttons** | Quickly increase or decrease screen brightness. |

---

## ⚙️ How to Build and Run

### Prerequisites
- macOS 14.0 or newer
- Swift 5.9+ / Xcode Command Line Tools

### 1. Build the App
Run the provided build script to compile the application and package it into a standard macOS `.app` bundle:
```bash
chmod +x build_app.sh
./build_app.sh
```

This compiles `TouchBarCraft` in release mode and bundles it into `TouchBarCraft.app` in your project root.

### 2. Run the App
- Double-click **`TouchBarCraft.app`** in Finder to launch it.
- **Recommendation**: Move `TouchBarCraft.app` to your `/Applications` directory to allow macOS to register it for the *Launch at Login* service properly.

---

## 🔧 JSON Configuration (`~/.touchbarcraft.json`)

Your custom layout is stored in a clean JSON format. An example structure:

```json
[
  {
    "type": "label",
    "title": "👋 TouchBarCraft!",
    "iconName": "sparkles",
    "backgroundColorHex": "#8B5CF6",
    "textColorHex": "#FFFFFF"
  },
  {
    "type": "systemMonitor",
    "title": "CPU",
    "iconName": "cpu",
    "backgroundColorHex": "#10B981",
    "monitorType": "cpu"
  }
]
```

---

## 📝 License
This project is open-source. Feel free to customize and craft your own widgets!
