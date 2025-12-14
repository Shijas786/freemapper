#!/bin/bash

# Ensure the app is packaged first
./package_app.sh

if [ $? -ne 0 ]; then
    echo "❌ Packaging failed. Aborting run."
    exit 1
fi

echo "🚀 Running AuroraMapper from Bundle..."
echo "Logs will appear below:"
echo "----------------------------------------"

# Run the executable inside the bundle directly to see logs in console
./AuroraMapper.app/Contents/MacOS/AuroraMapper
