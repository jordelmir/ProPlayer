# 💎 Elysium Vanguard Pro Player 8K
### *The Definitive 8K Media Engine for macOS*

![Platform: macOS](https://img.shields.io/badge/Platform-macOS%2012.0+-black?style=for-the-badge&logo=apple)
![Architecture: Apple Silicon](https://img.shields.io/badge/Architecture-Apple%20Silicon-blue?style=for-the-badge&logo=apple)
![Swift: 6.0](https://img.shields.io/badge/Swift-6.0-orange?style=for-the-badge&logo=swift)
![Metal: Enabled](https://img.shields.io/badge/Metal-Hardware%20Accelerated-brightgreen?style=for-the-badge)

**Elysium Vanguard Pro Player 8K** is a studio-grade media playback environment engineered for the 1% of professionals who demand zero-compromise performance. Built from the ground up on **Metal**, it delivers hardware-locked 8K playback with a zero-leak memory architecture.

---

## ⚡ Engineering Excellence

### 🔱 The 8K Metal Pipeline
Elysium doesn't just "play" video; it reconstructs it. Our custom rendering pipeline leverages:
- **Zero-Copy CVMetalTextureCache**: Bypasses the CPU entirely, pinning hardware frames directly to GPU memory.
- **Temporal Noise Reduction (TNR)**: Leverages double-buffering to eliminate compression artifacts without sacrificing detail.
- ** Lanczos-3 Adaptive Upscaling**: Real-time 16-tap spatial reconstruction for breathtaking clarity on Retina and Pro Display XDR panels.

### 🛡️ Zero-Leak Memory Architecture
Engineered to solve the "30GB RAM" trap common in high-bitrate players:
- **Concurrency Throttling**: Metadata extraction is capped at 8-16 parallel threads to maintain a stable memory footprint.
- **Proactive GCD/ARC Management**: Explicit `autoreleasepool` boundaries and `CVMetalTextureCacheFlush` calls ensure media buffers are reclaimed instantly.
- **Isolated State Machine**: A pure-FSM (Finite State Machine) player core ensures deterministic state transitions and zero "zombie" playback items.

---

## ✨ Features

- **Professional Waveform**: Real-time periodic spectrum visualizer for deep audio analysis.
- **Smart Metadata Engine**: Automated identification via MusicBrainz/AcoustID with Batch Tag editing.
- **Synced Lyrics Protocol**: Real-time LRC parsing with per-line precision scrolling.
- **A-B Loop & Frame Step**: Frame-accurate navigation for precision editing workflows.
- **Ambient Lighting Mode**: Dynamic Gaussian glow that extends the cinematic experience beyond the letterbox.

---

## 🚀 Deployment

### Native Installation
For the fastest experience, build and install natively to your Applications folder:

```bash
sh build_evp8k.sh
```

### Download DMG
Ready-to-use distribution images are available under [Releases](https://github.com/jordelmir/ElysiumVanguard8K/releases).

---

## ⌨️ Professional Controls

| Action | Mapping |
|:---|:---|
| **Toggle Play/Pause** | `Space` |
| **Seek (Fine/Coarse)** | `← / →` or `Shift + ← / →` |
| **Super Resolution Tier** | `1` - `7` |
| **Screenshot (lossless)** | `S` |
| **Toggle Lyrics View** | `L` |
| **A-B Loop Toggle** | `B` |

---

## 🏗 Build System & Environment

- **Renderer**: Metal Swift + Custom Kernels
- **Audio Engine**: AVFoundation Stack
- **Project Structure**: SPM-First (Swift Package Manager)
- **CI/CD**: GitHub Actions Automated DMG Release

---

### 📜 Technical Support & License
Copyright © 2026 **Jordelmir**. All rights reserved.  
*Engineered with 💎 by the Elysium Vanguard team. Precision above all.*
