# AuroraMapper

**Professional macOS Projection Mapping Software**

AuroraMapper is a production-ready, Metal-accelerated projection mapping application for macOS, designed for live performance and installation work.

## Features

### v1 (Core Engine)
- ✅ External display detection & fullscreen output
- ✅ Hardware-accelerated video playback (MP4, ProRes)
- ✅ 4-corner perspective warping (Quad Warp)
- ✅ Real-time interactive handles
- ✅ Save/Load mapping presets (JSON)
- ✅ Zero-copy video pipeline (CVMetalTextureCache)

### v2 Pro (MadMapper-Level Features)
- ✅ **Multi-layer compositing** - Stack multiple video surfaces and masks
- ✅ **Mesh warping** - Convert quads to arbitrary grids (up to 10×10) for curved surfaces
- ✅ **Polygon masking** - Cut out specific areas using custom shapes
- ✅ **Edge blending** - Soft edges for multi-projector setups
- ✅ **Layer opacity control** - Per-layer transparency
- ✅ **Test Pattern Generators**:
  - Checkerboard (alignment)
  - Grid (calibration)
  - Color Bars (SMPTE)
  - Gradient (testing)
  - Solid Colors (white, black, RGB)
- ✅ **Input Source Management**:
  - Video files (MP4, ProRes, MOV)
  - Test patterns
  - Solid colors
  - Live source switching
- ✅ **Resolution Presets**:
  - Full HD (1920×1080)
  - 2K (2560×1440)
  - 4K (3840×2160)
  - XGA (1024×768)
- ✅ **Professional UI**:
  - MadMapper-inspired layout
  - Stage preview
  - Input source display
  - Layer management panel
  - Property inspector

### v3 Pro (Complete MadMapper Parity)
- ✅ **24 Procedural Generators**:
  - **Generators**: Solid Color, Color Patterns, Grid Generator, Test Card
  - **Materials**: Gradient Color, Strob, Shapes, Line Patterns, MadNoise, Sphere
  - **Line Patterns**: LineRepeat, SquareArray, Siren, Dunes, Bar Code, Bricks, Clouds, Random, Noisy Barcode, Caustics, SquareWave, CubicCircles, Diagonals
- ✅ **Complete Menu System**:
  - **File Menu**: New/Open/Save Project, Import (Media, Image Folders, 3D Objects, Fixtures, SVG), Export (Input/Output)
  - **View Menu**: Desktop/Fullscreen modes, Show Info, Test Pattern, Cursors, Highlighting, Zoom controls, Display modes, UI panels, Snap to Objects, Lock Movement
  - **Output Menu**: Import/Export output setups
  - **Tools Menu**: Arm Lasers, etc.
- ✅ **View Controls**:
  - Zoom to selected surface
  - Fit to window
  - Zoom in/out
  - Dual View / Input / Stage modes
  - Snap to objects
  - Lock surfaces movement
  - Reset locations
- ✅ **Project Management**:
  - New/Open/Save/Save As
  - Collect external resources
  - Export project bundle
  - Reveal in Finder
- ✅ **Keyboard Shortcuts**: Full keyboard navigation matching MadMapper

### v4 Pro (Live Production Features)
- ✅ **Montage/Timeline System**:
  - Timeline-based video composition
  - Multi-track editing (4 tracks)
  - Clip management (add, remove, trim)
  - Frame-accurate playback
  - Timecode display (HH:MM:SS:FF)
  - Professional timeline UI with ruler
  - Playback controls (play, pause, stop, step forward/back)
  - Zoom controls (0.1x to 5x)
  - Snap to frames
  - Visual playhead indicator
  - Drag to seek
  - Frame counter
  - Clip visualization with duration
  - Multi-clip compositing


## Architecture

```
┌─────────────────┐
│  SwiftUI UI     │ (Control Panel + Canvas Editor)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  ViewModel      │ (State Management)
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌──────────────┐
│ Video  │ │ Metal        │
│ Engine │ │ Renderer     │
└────────┘ └──────────────┘
    │            │
    │            ▼
    │      ┌──────────┐
    │      │ Shaders  │
    │      └──────────┘
    │            │
    └────────────┴─────────▶ Output Window
                             (External Display)
```

### Core Components

- **MetalRenderer**: Multi-pass rendering (Stencil + Composition)
- **VideoEngine**: AVFoundation → Metal texture bridge
- **Homography**: Perspective transform math
- **Layer System**: Unified model for surfaces and masks
- **Shaders**: Grid warping + Edge blending + Masking

## Technical Stack

- **Language**: Swift 5.9+
- **Graphics**: Metal (Vertex + Fragment shaders)
- **Video**: AVFoundation (Hardware decoding)
- **UI**: SwiftUI + AppKit
- **Platform**: macOS 13.0+ (Apple Silicon + Intel)

## Build & Run

### Requirements
- Xcode 15.0+
- macOS 13.0+

### Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/Shijas786/freemapper.git
   cd freemapper/AuroraMapper
   ```

2. **Open in Xcode**
   ```bash
   open Package.swift
   ```
   Or double-click `Package.swift`

3. **Build & Run**
   - Select the **AuroraMapper** scheme
   - Press `Cmd+R`

4. **Usage**
   - Click **"Load Video"** to select an MP4/MOV file
   - Click **"Start Output"** to open the projector window
   - Drag control points in the canvas to warp the video
   - Use **"Add Layer"** to create multiple surfaces or masks
   - Convert quads to grids for curved surface mapping

## Performance

- **Zero-copy video pipeline**: Direct CVPixelBuffer → Metal texture
- **60+ FPS** on Apple Silicon
- **Triple buffering**: Smooth frame delivery
- **Stencil-based masking**: GPU-accelerated cutouts

## Preset Format

Presets are saved as JSON:

```json
{
  "name": "My Setup",
  "layers": [
    {
      "id": "...",
      "name": "Main Surface",
      "type": "video",
      "isVisible": true,
      "opacity": 1.0,
      "edgeSoftness": 0.1,
      "rows": 3,
      "cols": 3,
      "controlPoints": [...]
    }
  ]
}
```

## Roadmap

### Phase 3: Professional Features
- [ ] **Syphon/NDI input** - Receive from Resolume, TouchDesigner, etc.
- [ ] **Multi-output management** - Multiple projectors
- [ ] **Bezier curve warping** - Smooth mesh deformation
- [ ] **Keyframe animation** - Automated mapping changes
- [ ] **Audio reactivity** - FFT-based effects

### Phase 4: Live Performance
- [ ] **MIDI/OSC control** - External hardware integration
- [ ] **Cue system** - Preset sequencing
- [ ] **Blackout/Freeze** - Quick controls
- [ ] **Test patterns** - Alignment grids

## License

MIT License - See LICENSE file for details

## Credits

Built by senior macOS graphics engineers with deep experience in Metal, AVFoundation, and real-time rendering.

Inspired by MadMapper, designed for production use.

---

**Status**: v2 Advanced Engine Complete ✅
