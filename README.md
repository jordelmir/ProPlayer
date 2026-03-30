# ProPlayer Elite 
**The Ultimate Native Video Playback Engine for macOS Apple Silicon**

![Platform](https://img.shields.io/badge/Platform-macOS_14.0+-black?logo=apple)
![Architecture](https://img.shields.io/badge/Architecture-Apple_Silicon_M1%2BM2%2BM3-blue)
![Swift](https://img.shields.io/badge/Swift-6.0_Strict_Concurrency-orange)
![Engine](https://img.shields.io/badge/Engine-Metal_%2B_AVFoundation-purple)

**ProPlayer Elite** is a professional-grade, zero-latency video player architected from the ground up for macOS. Bypassing standard limitations, it leverages a custom **Metal GPU Pipeline (v13.0)** directly attached to AVFoundation's pixel buffers to deliver Hollywood-studio rendering quality, real-time upscaling, and post-processing historically reserved for high-end color grading suites.

---

## 🚀 The Metal v13.0 Pipeline

Unlike standard players (VLC, QuickTime) that rely on `AVPlayerLayer` or simple OpenGL/Bilinear upscaling, ProPlayer intercepts raw `CVPixelBuffer` frames via `CVMetalTextureCache` and processes them through a custom fragment shader architecture executing in nanoseconds on Apple Silicon GPU cores.

### Studio-Grade Processing Features
*   **FSR 1.0 Approximate Upscaling (5K & 8K):** Edge Adaptive Spatial Upsampling (EASU) with Robust Contrast Adaptive Sharpening (RCAS) math forces ultra-crisp edges on compressed or low-resolution video (720p/1080p).
*   **Lanczos-3 Kernel:** Pure mathematical 6-tap sinc-windowed upscaling for pristine 4K rendering.
*   **ACES Filmic Tone Mapping:** Real-time HDR-to-SDR conversion using the Academy Color Encoding System. Preserves highlights and wide-color gamut without blowing out the sky.
*   **Temporal Noise Reduction (TNR):** Double-buffered frame fusion. Analyzes inter-frame Luma gradients to eliminate compression artifacts and static grain without introducing motion ghosting.
*   **Cinematic Film Grain Synthesis:** Procedural 35mm stochastic noise generation (luma-adaptive) to mask banding and emulate projection.
*   **Color Temperature Control:** Real-time Kelvin approximation offset (2500K - 10000K).

---

## ⚡️ Zero-Latency & Hardened Concurrency

*   **Swift 6 Strict Actor-Isolation:** 100% Data-Race free. `PlayerEngine` runs purely isolated memory access via `@MainActor` UI synchronization and background `Task` detachments.
*   **Auto-Play Intent Queueing:** The video playback intention is buffered the exact millisecond the user clicks a file, initiating playback the microsecond the AVAsset reports `readyToPlay`.
*   **Zero Memory Leaks:** ARC-enforced memory management with aggressive `CVPixelBuffer` and `CVMetalTexture` lifecycle flushing. Tested under 4K+ HDR load on M1.

---

## 🖥️ System Architecture

| Layer | Technology | Responsibility |
| :--- | :--- | :--- |
| **Presentation** | SwiftUI `WindowGroup` | Glassmorphism UI, Context Menus, Library Layouts |
| **Orchestration** | `PlayerViewModel` | MVVM bridging, Input handling (Shortcuts, Gestures) |
| **Decoding** | `AVFoundation` | Hardware-accelerated decoding (H.264, HEVC, ProRes) |
| **GPU Rasterization** | `MetalKit` (`MTKView`) | 60/120Hz display link, V-Sync, Viewport handling |
| **Post-Processing** | Custom MSL (`Shaders.metal`) | EASU, Lanczos, Tone Mapping, TNR, Pixel shading |

---

## 🛠 Compilation & Deployment

The project is structured efficiently around Swift Package Manager (SPM) and standard shell automation.

```bash
# Compile Release Build & Package as ZIP (Creates macOS executable bundle)
chmod +x build_elite_v11.sh
./build_elite_v11.sh
```

### Security & Environment (`.env` & `.gitignore`)
This repository has been audited for zero secrets leakage. The `.gitignore` is completely locked down, protecting:
*   `.env` and `.env.*` files (Development vectors)
*   `.p8`, `.cert`, `.mobileprovision` (Apple Code Signing credentials)
*   DerivedData, `.build/`, `.app`, and `.zip` artifacts (Compilation clutter)

If you plan to connect remote telemetry (Sentry, Crashlytics) or Firebase/Supabase in the future, clone `.env.example` as `.env` locally.

---
*Architected and developed with an obsession for performance. "Top World Standard".*
