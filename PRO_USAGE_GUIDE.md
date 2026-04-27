# 💎 ProPlayer Elite: The Master Experience Guide

Welcome to the definitive media experience for macOS. ProPlayer Elite is tuned for high-fidelity rendering. This guide helps you master the "Elite" features of the v13.0 engine.

---

## 🚀 Extreme Rendering Tiers

The v13.0 engine introduces two new tiers beyond standard 4K:

### 1. 🌌 Ultra 5K (Edge Directed)
*   **Best for**: 1080p and 1440p content on Studio Displays or 5K iMacs.
*   **Kernel**: Uses **EASU** (Edge Adaptive Spatial Upsampling). Unlike standard scaling, it detects contrast edges and applies directional interpolation to keep lines razor-sharp without "ringing" artifacts.

### 2. 🛰️ Extreme 8K (EASU + RCAS)
*   **Best for**: High-bitrate 4K content being upscaled for large format displays or 8K setups.
*   **Pipeline**: Combines EASU with **RCAS** (Robust Contrast Adaptive Sharpening). It restores high-frequency textures (skin, fabric, grain) based on local contrast analysis.
*   **⚠️ Thermal Note**: On fanless devices (MacBook Air M1/M2), using 8K tier while on battery may lead to thermal throttling. Plug in for the best 120fps experience.

---

## 🎬 Cinematic Post-Processing

Our Metal pipeline includes a suite of "Non-Destructive" filters:

- **ACES Filmic Tone Mapping**: Automatically converts HDR10/Dolby Vision metadata to your display's SDR capability. It provides a natural "log" roll-off in highlights, avoiding the "burnt" look of standard players.
- **Film Grain Synthesis**: Adds 35mm stochastically generated grain. Why? Modern digital video can look "plasticky" due to heavy compression. Film grain restores the organic motion that separates home video from cinema.
- **Temporal Noise Reduction (TNR)**: If you notice "blocks" in dark scenes of low-quality files, enable TNR. It uses the previous frame to average out compression noise without losing edge detail.

---

## ⌨️ Elite Keyboard Protocol

Master these shortcuts for a keyboard-driven workflow:

| Action | Shortcut |
| :--- | :--- |
| **Play / Pause** | `Space` / `K` |
| **Fullscreen (Native Space)** | `F` / `Double Click` |
| **Seek Forward/Back** | `Right` / `Left` (5s) or `L` / `J` (10s) |
| **Big Seek (30s)** | `Shift + Right` / `Shift + Left` |
| **Volume Control** | `Up` / `Down` |
| **Cycle Speed** | `[` (Slower) / `]` (Faster) |
| **Cycle Aspect Ratio** | `A` (Fit, Fill, Zoom) |
| **Toggle Mute** | `M` |
| **Screenshot (Native PNG)** | `S` |
| **Video Metadata Overlay** | `Cmd + I` |

---

## 📁 Native macOS Integration

- **Drag & Drop**: Drag any file or folder directly into the player to start instant playback.
- **Immersive Windows**: The player window is "Edge-to-Edge". Use the standard macOS traffic lights (Green button) for a seamless FullScreen Space that hides the Apple Menu bar completely.

---

## 🛠️ Troubleshooting

### "App is damaged and can't be opened"
If you receive this error after downloading the DMG from GitHub, macOS Gatekeeper is blocking the app because it lacks a paid Apple Developer signature. It is **not** actually damaged.

**Solution:**
1. Move the app to your **Applications** folder.
2. Open **Terminal** and run:
   ```bash
   sudo xattr -cr "/Applications/Elysium Vanguard Pro Player 8K.app"
   ```
3. Enter your Mac password. You can now launch the app normally.

---

*ProPlayer Elite v13.0 - Designed for those who see the difference.*
