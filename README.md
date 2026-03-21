# Plex-HDR-Fix: PLEX HDR Fix
### 🚀 Precision Color Management: Take Control Back from Windows

By default, **Plex Desktop performs no internal tone mapping.** It relies entirely on the OS (Windows/macOS) or your monitor's hardware to handle the signal. This "passive" approach often fails:
- **On SDR Screens**: You get a washed-out, grey image because the OS can't map HDR colors properly.
- **On HDR Screens**: It relies on generic system handling, often resulting in inaccurate brightness peaks, crushed highlights, or loss of fine detail.

This configuration suite fixes Plex by implementing an **active mpv pipeline** using the modern **`gpu-next`** renderer:
- **Active Control**: Stop relying on Windows' mediocre conversion. This config performs high-quality mapping internally for superior color accuracy.
- **Bit-Perfect HDR**: Match mpv's output peak **exactly** to your calibrated profile to prevent quality-degrading secondary conversions by the OS.
- **Advanced SDR-to-HDR**: Uses **Inverse Tone Mapping** to make standard SDR content look vibrant and dynamic on HDR displays.
- **Optimized HDR-to-SDR**: Fine-tuned profiles for various algorithms (Spline, BT.2446a, etc.) ensure HDR movies look perfect on standard monitors.
- **No Extra Downloads**: Leverages high-end shaders already included in the Plex package (SSim/Krig) to eliminate blur.

---
## ✨ Features

| Feature | Description |
|---------|-------------|
| **Tone Mapping Control** | Real-time switching of algorithms for various HDR contents including BT.2446a, BT.2390, ST2094-40/10, Spline, Mobius, Reinhard, Hable |
| **Dynamic HDR Analysis** | Target Peak Compute with scene-based peak detection (99.9th percentile) with contrast recovery |
| **Target Peak Control** | Real-time target peak brightness cycling (100-450 nits + auto) for various HDR content |
| **Saturation Control** | Real-time adjustment (-100 to +100) with algorithm-specific presets |
| **Aspect Ratio Control** | Support cropping, zooming and panscan of widecreen content for full 16:9, 1.9:1 display |
| **RIFE AI Interpolation** | 3 RIFE models via VapourSynth filters: Action (400), Cinema (406), Realistic (410) and pre-downscalers for various GPU power  |
| **Interpolation Profiles** | 8 automatic profiles for different display refresh rates, 48Hz, 60 Hz and above, against 24, 48, and 60 fps content |
| **Auto Refresh Rate** | 48Hz for 24fps content, fullscreen triggers Refresh Rate switch, back to original Hz after 5 min during playback in windowed |
| **Subtitle Scaling** | Automatic adjustment of ASS substitles for cropped/zoomed content |
| **Smart Padding** | Automatic pixel alignment (4px width, 2px height) for better scaling and hardware decoding |
| **Dot-to-Dot Scaling** | Disables upscaling when difference <10 pixels, e.g. 1918 or 3836 width, when fullscreen playback |
| **Upscaling** | ewa_lanczossharp, mitchell, spline36 with zero anti-ringing |
| **Shaders** | KrigBilateral (edge-preserving), SSimSuperRes (detail enhancement), SSimDownscaler |
| **Debanding** | 2-iteration debanding with configured threshold, range, and grain for high quality content |
| **Dithering** | Fruit (8-bit) for SDR display and error diffusion (10-bit) for HDR display |
| **Audio Downmix** | Improve downmix of 7.1, 5.1 and 2.0 for stereo output |
| **Monitoring** | Standard MPV Dashboard and Tone Mapping Graph |

---

## 🛠️ Installation & Configuration

### 1. Locate your Plex mpv directory
- **Windows**: `%LOCALAPPDATA%\Plex\`
- **macOS**: `~/Library/Application Support/Plex/`

### 2. Copy Config Files
Place the `mpv.conf`, `input.conf` and `scripts\Plex-HDR-Fix.lua` from this repository into the root of the Plex directory identified above.

#### 2.1 Automatic Display Refresh Rate Switching
If your monitor frequence supports multipliers of 24 Hz, you can copy `scripts\Plex-Hz-Fix.lua` and configure TARGET_WIDTH, MOVIE_HZ and DESKTOP_HZ in the script to switch the monitor Hz in fullscreen playback. Additional steps:
- ⚠️You need to download the `ChangeScreenResolution.exe` from https://tools.taubenkorb.at/change-screen-resolution/ and place the file under the script directory.
- ⚠️You likely need to add a custom resolution in display profile (e.g. in Nivida control panel) for 48Hz refresh rate.

#### 2.2 RIFE (Real-Time Intermediate Flow Estimation) Interpolation
You can copy `scripts\Plex-VapourSynth*` files in the scripts directory. This integrates to VapourSynth with vs-mlrt plugin that already installed in your machines. Otherwise, you can follow the web sites how to install:
- https://github.com/AmusementClub/vs-mlrt
- https://github.com/vapoursynth/vapoursynth

### 3. Setup Your Output Mode (SDR vs HDR)
The config must know if your monitor is currently in SDR or HDR mode. Open `mpv.conf` and edit the following line:

*   **For SDR Output (Default)**:
    `target-colorspace-hint=no`
*   **For HDR Output**:
    `target-colorspace-hint=yes` *(Note: Windows HDR must also be toggled "On" in System Settings).*

> **Tip**: You can also toggle this instantly during playback by pressing **`Shift + T`**.

For SDR Monitor, the installation process is bascially done except you need different Target Peak from default (170).
For HDR Monitor, pls go ahead to next step to configure the proper Target Peak (if other than default of 400).

### 4. Calibrate Your Target Peak (The Secret to Contrast)
To prevent Windows from interfering with the image, you must align the `target-peak` in `mpv.conf`:

*   **For SDR Output (HDR-to-SDR)**:
    - Locate the **`[HDR-SDR-Default]`** section.
    - Default is set to **`target-peak=170`**. 
    - **Why?** Standard 203 nits can look dull; **170** provides a much **punchier image with deeper contrast** on standard SDR displays.

*   **For HDR Output (Native HDR & SDR-to-HDR Upscaling)**:
    - Locate **BOTH** the **`[HDR-HDR-Default]`** and **`[SDR-HDR-Default]`** sections.
    - Set `target-peak` in both sections to **exactly match** your Windows HDR Calibration value (e.g., 400, 600, or 1000).
    - **Why?** This ensures both native HDR and upscaled SDR (Inverse Tone Mapping) align perfectly with your monitor's hardware, preventing Windows from double-processing the signal.
    - ⚠️ **CRITICAL**: **DO NOT set this to `auto`.** If set to auto, mpv will skip the internal tone mapping engine and passthrough the signal to the OS, which defeats the purpose of this custom configuration and calibration.
---

## 📊 Real-time Monitoring (Dashboard)
*   Pressing `d` triggers the MPV dashboard, allowing you to monitor video information, peak brightness, and renderer status & processing time.
*   Pressing 'g' triggers tone mapping graph.

### Dashboard - Main Page
![Plex Dashboard](dashboard-1.png)

### Dashboard - 2nd Page
![Plex Dashboard](dashboard-2.png)

### Tone Mappping Graph
![Plex Dashboard](dashboard-3.png)
---

## ⌨️ Hotkeys (Full Key Operations)

| Function | Increase (**Shift**) | Decrease (**Alt**) | Reset (**Alt + Shift**) | Info |
| :--- | :--- | :--- | :--- | :--- |
| **Tone Mapping** | `M` | `Alt + m` | `Alt + M` (Reset to Auto) | `m` |
| **Target Peak** | `P` | `Alt + p` | `Alt + P` (Reset to Auto) | `p` |
| **TM Parameter** | `N` | `Alt + n` | `Alt + N` (Reset to Default) | `n` |
| **Saturation** | `S` | `Alt + s` | `Alt + S` (Reset to 0) | `s` |
| **Compute Peak** | `C` | `Alt + c` | `Alt + C` (Reset to Auto) | `c` |
| **Output Mode** | `T` (SDR/HDR) | - | `Alt + T` (Force SDR) | `t` |
| **Rendering Mode**| `R` (Custom/MPV) | - | - | `r` |
| **Interpolation** | `I` (On/Off) | - | - | `i` |
| **Panscan & Zoom** | `H` (Off/Panscan) | `Alt + h` (Off/Zoom) | `Alt + H` (Reset to Off) | `h` |
| **Filter (Cropping)** | `F` (Off/16:9/0.8x/W=1.9xH) | - | `Alt + F` (Reset to Off) | `f` |
| **Unscale Mode** | `W` (Off/On/downscale-big) | - | - | `w` |
| **RIFE Interpolation** | `E` (Enable/Disable) | `Alt + e` (Action/Cinema/Realistic) | `Alt + E` (Downscaler: 1080p/2K/4K) | `e` |
| **Automatic Display Hz** | `Q` (Enable/Disable) | - | - | `q` |
| **Video Params** | - | - | - | `v` |
| **Tone Mapping Graph** | - | - | - | `g` |
| **System Info** | - | - | - | `d` |

---

## 💡 Troubleshooting
*   **Performance**: If the video stutters, your GPU might be struggling with `gpu-next`. Try commenting out the `glsl-shaders` lines in `mpv.conf`.
*   **HDR Output**: If colors look wrong, ensure your monitor is actually in HDR mode in Windows settings before toggling **`Shift + T`**.

---

## ⚠️ Disclaimer & Community Feedback
- **Tested Environment**: This configuration has been primarily developed and tested on **Windows 11** with SDR displays.
- **Mac Users**: While the paths are provided (`~/Library/Application Support/Plex/`), the behavior of `vo=gpu-next` on macOS (Metal API) may vary. 
- **HDR Monitors**: Since I am using an SDR display, the HDR-to-HDR profiles rely on standard MPV math and user-reported nit values.

**Have a Mac or HDR screen?** If you test this config, please share your results in the **Issues** tab! Your feedback helps make this config better for everyone.
