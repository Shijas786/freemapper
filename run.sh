#!/bin/bash

# AuroraMapper Launch Script
# This script suppresses harmless Xcode console warnings

echo "🚀 Launching AuroraMapper..."
echo ""

cd "$(dirname "$0")/AuroraMapper"

# Set bundle identifier environment variable
export CFBundleIdentifier="com.auromapper.app"
export PRODUCT_BUNDLE_IDENTIFIER="com.auromapper.app"

# Build and run
swift build

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo "🎨 Starting AuroraMapper..."
    echo ""
    
    # Run the app (suppress the specific warnings)
    swift run AuroraMapper 2>&1 | grep -v "Cannot index window tabs" | grep -v "Unable to obtain a task name port"
else
    echo "❌ Build failed!"
    exit 1
fi
