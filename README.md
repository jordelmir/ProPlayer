# Elysium Vanguard Pro Player 8K

> **v14.0 — Production Release**  
> The ultimate GPU-accelerated video player for macOS, engineered for professionals demanding zero-compromise 8K playback.

---

## ✨ Features

### 🎬 Studio-Grade Metal Rendering Engine
- **Lanczos-3 Upscaling** — True 16-tap bicubic-spline approximation for 4K/5K/8K resolution
- **EASU/RCAS Pipeline** — Edge-Adaptive Spatial Upsampling with Robust Contrast Adaptive Sharpening
- **ACES Filmic Tone Mapping** — HDR-to-SDR without clipping or color crushing
- **Temporal Noise Reduction (TNR)** — Adaptive double-buffering to eliminate noise on static frames
- **35mm Film Grain Synthesis** — Procedural, luminance-adaptive grain for cinematic warmth
- **Color Temperature Control** — Real-time Kelvin adjustment (2500K–10000K)
- **Sub-pixel Dither** — Eliminates banding artifacts at all bit depths

### 🖥️ Immersive macOS Experience
- **Native Fullscreen** — True macOS Spaces integration via `.fullScreenPrimary`
- **Zero-Copy CVMetalTextureCache** — Hardware-pinned GPU frames, no CPU copies
- **CVDisplayLink VSync** — Hardware-locked frame pacing for 0-stutter playback
- **Smart Fill** — Intelligent aspect ratio management with max 15% stretch tolerance
- **Ambient Mode** — Dynamic Gaussian blur background for cinematic letterboxing
- **Picture-in-Picture** — Native macOS PiP support

### 🎛️ Professional Controls
- **7-Tier Super Resolution**: Off → 2K → 4K → Ultra AI → 5K → 8K → Anime Adaptive
- **A-B Looping** for precision editing workflows
- **Custom Zoom & Pan** with gesture support
- **Keyboard-Driven** — Full playback control without touching the mouse
- **Smart Playlist Management** with drag-and-drop, sorting, and filtering

### 🔒 Privacy First
- **Zero Telemetry** — No analytics, no tracking, no external network calls
- **Offline-First** — Works 100% without internet
- **macOS Sandbox Ready** — Respects Apple's security model

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────────┐
│            ProPlayerEliteApp (SwiftUI)        │
│  ┌─────────────┐  ┌────────────────────────┐ │
│  │ LibraryView  │  │     PlayerView         │ │
│  │ (Grid/List)  │  │ ┌──────────────────┐   │ │
│  │              │  │ │  MetalPlayerView  │   │ │
│  └─────────────┘  │ │  (MTKView bridge) │   │ │
│                    │ └──────────────────┘   │ │
│                    │  ControlsOverlay       │ │
│                    │  TimelineView          │ │
│                    │  OSD + VideoInfo       │ │
│                    └────────────────────────┘ │
├──────────────────────────────────────────────┤
│           ProPlayerEngine (Library)           │
│  ┌───────────────┐  ┌──────────────────────┐ │
│  │  PlayerEngine  │  │  MetalVideoRenderer  │ │
│  │  (FSM + Core)  │  │  (Shaders.metal)     │ │
│  │  PlayerCore    │  │  VideoFrameExtractor  │ │
│  │  PlayerDriver  │  │  VideoDisplayLink     │ │
│  │  AssetValidator│  │  VideoGeometryEngine  │ │
│  └───────────────┘  └──────────────────────┘ │
└──────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Build & Install

```bash
# Clone the repository
git clone git@github.com:jordelmir/ElysiumVanguard8K.git
cd ElysiumVanguard8K

# Build and install to /Applications (one command)
sh build_evp8k.sh
```

The build script will:
1. Deep clean the build cache
2. Compile a Release-optimized binary
3. Assemble a native `.app` bundle
4. Install to `/Applications`
5. Register with macOS Launch Services

### Launch

```bash
# From terminal
open "/Applications/Elysium Vanguard Pro Player 8K.app"

# Or find it in Finder → Applications → Elysium Vanguard Pro Player 8K
```

---

## ⌨️ Keyboard Shortcuts

| Action | Shortcut |
|---|---|
| Play / Pause | `Space` |
| Seek Forward 5s | `→` |
| Seek Backward 5s | `←` |
| Seek Forward 30s | `Shift + →` |
| Seek Backward 30s | `Shift + ←` |
| Volume Up | `↑` |
| Volume Down | `↓` |
| Mute | `M` |
| Fullscreen | `F` |
| Cycle Screen Mode | `A` |
| Screenshot | `S` |
| Video Info | `⌘ + I` |
| Speed Up | `]` |
| Speed Down | `[` |
| Open File | `⌘ + O` |

---

## 🔧 Requirements

- **macOS** 12.0+ (Monterey or later)
- **Apple Silicon** (M1/M2/M3) or Intel Mac with Metal GPU
- **Swift** 5.9+
- **Xcode** 15+ (for building)

---

## 📊 Supported Formats

MP4, M4V, MOV, AVI, MKV, WMV, FLV, WebM, MPG, MPEG, 3GP, TS, MTS, M2TS, VOB, OGV

Codec support: H.264/AVC, H.265/HEVC, AV1, VP9, ProRes, MPEG-4  
Audio: AAC, Dolby Digital, Apple Lossless, FLAC, Opus

---

## 📜 License

Copyright © 2026 Jordelmir. All rights reserved.

---

*Engineered with ⚡ by the Elysium Vanguard team. Built for professionals who demand the absolute best.*
