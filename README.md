# Plex-HDR-Fix: PLEX HDR Fix
### 🚀 Precision Color Management: Take Control Back from Windows

By default, **Plex Desktop performs no internal tone mapping.** It relies entirely on the OS (Windows/macOS) or your monitor's hardware to handle the signal. This "passive" approach often fails:
- **On SDR Screens**: You get a washed-out, grey image because the OS can't map HDR colors properly.
- **On HDR Screens**: It relies on generic system handling, often resulting in inaccurate brightness peaks, crushed highlights, or loss of fine detail.

This configuration suite fixes Plex by implementing an **active mpv pipeline** using the modern **`gpu-next`** renderer.

---

## 🌟 Why use this config?

1. **Active Control**: Stop relying on Windows' mediocre conversion. This config performs high-quality mapping internally for superior color accuracy.
2. **Bit-Perfect HDR**: Match mpv's output peak **exactly** to your calibrated profile to prevent quality-degrading secondary conversions by the OS.
3. **Advanced SDR-to-HDR**: Uses **Inverse Tone Mapping** to make standard SDR content look vibrant and dynamic on HDR displays.
4. **Optimized HDR-to-SDR**: Fine-tuned profiles for various algorithms (Spline, BT.2446a, etc.) ensure HDR movies look perfect on standard monitors.
5. **No Extra Downloads**: Leverages high-end shaders already included in the Plex package (SSim/Krig) to eliminate blur.

---

## 🛠️ Installation & Configuration

### 1. Locate your Plex mpv directory
- **Windows**: `%LOCALAPPDATA%\Plex\`
- **macOS**: `~/Library/Application Support/Plex/`

### 2. Copy Config Files
Place the `mpv.conf` and `input.conf` from this repository into the root of the Plex directory identified above.

### 3. Setup Your Output Mode (SDR vs HDR)
The config must know if your monitor is currently in SDR or HDR mode. Open `mpv.conf` and edit the following line:

*   **For SDR Monitors (Default)**:
    `target-colorspace-hint=no`
*   **For HDR Monitors**:
    `target-colorspace-hint=yes` *(Note: Windows HDR must also be toggled "On" in System Settings).*

> **Tip**: You can also toggle this instantly during playback by pressing **`Shift + T`**.

---

## ⌨️ Hotkeys (Full Key Operations)

| Function | Increase (**Shift**) | Decrease (**Alt**) | Reset (**Alt + Shift**) | Info |
| :--- | :--- | :--- | :--- | :--- |
| **Tone Mapping** | `M` | `Alt + m` | `Alt + M` (Reset to Auto) | `m` |
| **Target Peak** | `P` | `Alt + p` | `Alt + P` (Reset to Auto) | `p` |
| **TM Parameter** | `N` | `Alt + n` | `Alt + N` (Reset to Default) | `n` |
| **Saturation** | `S` | `Alt + s` | `Alt + S` (Reset to 0) | `s` |
| **Compute Peak** | `C` | `Alt + c` | `Alt + C` (Reset to Auto) | `c` |
| **Output Mode** | `T` (Toggle SDR/HDR) | - | `Alt + T` (Force SDR) | `t` |
| **Rendering Mode**| `R` (Toggle Custom/Plex) | - | - | `r` |
| **Interpolation** | `I` (Toggle On/Off) | - | - | `i` |
| **System Info** | `d` (Stats Overlay) | - | - | `v` (Video Params) |

---

## 💡 Calibration Tip
**For HDR Monitors**: 
1. Run the [Windows HDR Calibration Tool](https://apps.microsoft.com).
2. Note your **Peak Brightness** (e.g., 400 nits).
3. In `mpv.conf`, set `target-peak` in `[HDR-HDR-Default]` and `[SDR-HDR-Default]` to **exactly** that value.
4. Use the **`P`** (Shift+p) / **`Alt+p`** keys during playback if you need to fine-tune it on the fly!

---

## 💡 Troubleshooting
*   **Performance**: If the video stutters, your GPU might be struggling with `gpu-next`. Try commenting out the `glsl-shaders` lines in `mpv.conf`.
*   **HDR Output**: If colors look wrong, ensure your monitor is actually in HDR mode in Windows settings before toggling **`Shift + T`**.

