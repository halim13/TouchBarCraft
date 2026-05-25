#!/bin/bash
set -e

echo "🚀 Building TouchBarCraft in Release mode..."
swift build -c release

echo "📁 Creating TouchBarCraft.app bundle..."
APP_DIR="TouchBarCraft.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "⚙️ Copying executable..."
cp .build/release/touchbar "$MACOS_DIR/TouchBarCraft"

echo "📝 Creating Info.plist..."
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TouchBarCraft</string>
    <key>CFBundleIdentifier</key>
    <string>com.halim13.TouchBarCraft</string>
    <key>CFBundleName</key>
    <string>TouchBarCraft</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <string>NO</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ App bundle created successfully: $(pwd)/$APP_DIR"
echo ""
echo "🎉 To run TouchBarCraft in the background without terminal:"
echo "   1. Double click on $(pwd)/TouchBarCraft.app in Finder"
echo "   2. You can move TouchBarCraft.app to your Applications folder so SMAppService can register it properly."
echo ""
