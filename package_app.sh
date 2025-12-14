#!/bin/bash

APP_NAME="AuroraMapper"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"

echo "🚀 Building $APP_NAME..."
swift build -c release -Xswiftc -DRELEASE

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "📦 Packaging $APP_NAME.app..."

# Create directory structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp "Info.plist" "$APP_BUNDLE/Contents/"

# Copy entitlements if it exists (not strictly needed for ad-hoc but good practice)
# cp "AuroraMapper.entitlements" "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true

# Sign the application (Ad-hoc) to allow camera access
echo "🔐 Signing application..."
codesign --force --deep --sign - --entitlements AuroraMapper.entitlements "$APP_BUNDLE" 2>/dev/null || codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ Done! You can run the app with: open $APP_BUNDLE"
