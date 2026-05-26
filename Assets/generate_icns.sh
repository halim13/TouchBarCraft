#!/bin/bash
set -e

# Path to the source high-res icon PNG
SOURCE_PNG="AppIcon.png"

if [ ! -f "$SOURCE_PNG" ]; then
    echo "Error: $SOURCE_PNG not found!"
    exit 1
fi

echo "Creating AppIcon.iconset..."
mkdir -p AppIcon.iconset

# Generate the various sizes required for macOS .icns files
sips -z 16 16     -s format png "$SOURCE_PNG" --out AppIcon.iconset/icon_16x16.png
sips -z 32 32     -s format png "$SOURCE_PNG" --out AppIcon.iconset/icon_16x16@2x.png
sips -z 32 32     -s format png "$SOURCE_PNG" --out AppIcon.iconset/icon_32x32.png
sips -z 64 64     -s format png "$SOURCE_PNG" --out AppIcon.iconset/icon_32x32@2x.png
sips -z 128 128   -s format png "$SOURCE_PNG" --out AppIcon.iconset/icon_128x128.png
sips -z 256 256   -s format png "$SOURCE_PNG" --out AppIcon.iconset/icon_128x128@2x.png
sips -z 256 256   -s format png "$SOURCE_PNG" --out AppIcon.iconset/icon_256x256.png
sips -z 512 512   -s format png "$SOURCE_PNG" --out AppIcon.iconset/icon_256x256@2x.png
sips -z 512 512   -s format png "$SOURCE_PNG" --out AppIcon.iconset/icon_512x512.png
sips -z 1024 1024 -s format png "$SOURCE_PNG" --out AppIcon.iconset/icon_512x512@2x.png

echo "Compiling to AppIcon.icns..."
iconutil -c icns AppIcon.iconset

echo "Cleaning up temporary iconset directory..."
rm -rf AppIcon.iconset

echo "AppIcon.icns generated successfully!"
