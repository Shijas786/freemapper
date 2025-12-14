# AuroraMapper - Xcode Setup Guide

## Current Status
The project builds successfully via Swift Package Manager, but Xcode shows indexing warnings.

## Solution: Create Proper Xcode Project

Since you're building a macOS app (not a command-line tool), you should use an Xcode project instead of just a Swift Package.

### Option 1: Create New Xcode Project (Recommended)

1. **Open Xcode**
2. **File → New → Project**
3. Choose **macOS → App**
4. Settings:
   - Product Name: `AuroraMapper`
   - Team: Your team
   - Organization Identifier: `com.auromapper`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Click **Next** and save to a new folder

5. **Copy Source Files:**
   ```bash
   # From terminal
   cp -r /Users/shijas/freemapper/AuroraMapper/Sources/* [NEW_PROJECT]/AuroraMapper/
   ```

6. **Add Metal File:**
   - Right-click project in Xcode
   - Add Files to "AuroraMapper"
   - Select `Shaders.metal`

### Option 2: Run from Command Line (Quick Test)

The app builds fine from terminal:

```bash
cd /Users/shijas/freemapper/AuroraMapper
swift build
swift run AuroraMapper
```

### Option 3: Generate Xcode Project from Package

```bash
cd /Users/shijas/freemapper/AuroraMapper
swift package generate-xcodeproj
open AuroraMapper.xcodeproj
```

Then in Xcode:
1. Select the **AuroraMapper** target
2. Go to **Signing & Capabilities**
3. Enable **Automatically manage signing**
4. Select your team

## Why These Warnings Appear

Swift Packages are designed for libraries, not full macOS apps. macOS apps need:
- Bundle identifier
- Info.plist
- Proper code signing
- App sandbox entitlements

The warnings you see are Xcode trying to index a package as if it were an app.

## Recommended Action

**Use Option 3** (generate Xcode project) - it's the fastest way to get a proper app bundle while keeping your existing code structure.
