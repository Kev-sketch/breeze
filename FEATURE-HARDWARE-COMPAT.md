# Feature hardware/design compatibility — vorssaint-utils on THIS laptop

Target machine for this audit (identified during the legacy-OS port recon):

| Property | Value |
|---|---|
| Model | **MacBookPro16,2** — 13-inch MacBook Pro (2020, four Thunderbolt 3 ports) |
| CPU | Intel Core i7 (quad-core, x86_64) |
| GPU | **Intel Iris Plus Graphics (integrated only — no discrete GPU)** |
| Display | 13.3″ Retina, **no XDR**, **no ProMotion/120 Hz**, **no display notch**, 60 Hz |
| Camera | 720p FaceTime HD (built in) |
| Cooling | **One fan** (active), SMC present (Intel/T2) |
| Input | **Touch Bar present** (2020 Intel), Force Touch trackpad |
| OS | **macOS 13.7.8 (Ventura)** |
| Architecture | Intel — runs the `x86_64` slice of the now-universal binary |

How to read a verdict:
- ✅ **Compatible** — works on this laptop as designed.
- ⚠️ **Degraded / simulated** — runs, but a sub-feature or its realism depends on hardware this
  laptop lacks; it falls back.
- ❌ **Unavailable** — a hard requirement (display type, OS version, GPU class) is absent, so the
  feature or sub-feature is disabled here.

---

## Hard incompatibilities with this laptop

### ❌ Extra brightness (XDR HDR headroom) — `Sources/Vorssaint/Services/Display/ExtraBrightnessService.swift`
- **Dependency:** a built-in **XDR display with EDR (extended dynamic range) headroom**. The class
  comment states it "pushes the built-in XDR display past its regular maximum brightness by using the
  panel's HDR headroom," and its availability probe is literally *"a built-in display with EDR headroom
  exists."*
- **Incompatibility:** this 2020 13″ panel is **not XDR** and exposes no EDR headroom, so the feature's
  `isAvailable` returns false. The slider is inert here. (Only the 2021+ 14″/16″ MacBook Pro and
  Pro Display XDR qualify.)
- **Fix:** none for this hardware; it is a genuine panel capability gap.

### ⚠️ Dynamic Island / Notch — `Sources/Vorssaint/Services/Notch/`, `Sources/Vorssaint/UI/Notch/`
- **Dependency:** a **physical display notch / camera cutout** (2021+ 14″/16″ MacBook Pro, MacBook Air
  M2+). `NotchSupport.swift` (lines 112–119) describes the silhouette options and notes *"a physical
  camera always keeps the cutout it covers."* The default silhouette is `capsule` — a pill floating in
  the menu bar.
- **Incompatibility:** this laptop has **no physical notch**. The feature still works, but only in
  **simulated** mode (a drawn capsule/cutout over the menu bar), not wrapped around real hardware. It is
  cosmetic-only realism loss, not a functional break.
- **Secondary incompatibility:** the macOS 26 **Liquid Glass** rendering of the island/windows is gated
  by `LiquidGlassSupport.isSupported` (`Sources/Vorssaint/Core/LiquidGlassSupport.swift:13` — true only
  on macOS 26+). On 13.7.8 the glass styling is disabled; the non-glass island renders.

### ❌ Liquid Glass visuals (macOS 26) — `Sources/Vorssaint/Core/LiquidGlassSupport.swift`
- **Dependency:** **macOS 26 or later** native Liquid Glass. `isSupported` returns false below 26.
- **Incompatibility:** this laptop runs **13.7.8**, so every Liquid Glass surface (notch island, window
  backgrounds, etc.) renders in the pre-26 flat style. Graceful fallback; not a crash.

### ⚠️ Discrete-GPU reading in System Monitor — `Sources/Vorssaint/Services/SystemMonitor/`
- **Dependency:** a **discrete GPU** thermal/power sensor (the SMC `gpu` key set in
  `FanControlHardware.swift:35-36` is the thermal analogue).
- **Incompatibility:** this laptop has **integrated graphics only**. A discrete-GPU tile/temperature is
  expected to read **N/A** — a hardware limit, not a port defect (same class of gap as the skill's
  "GPU sensor N/A → hardware limit" example). The integrated-GPU and CPU readings remain valid.

### ⚠️ macOS 14.4 / 15 / 26 / 27 enhancements — across the UI
- **Dependency:** the 37 `#available` guards in the codebase (14.4 ×10, 15 ×2/1, 26 ×~20, 27 ×4).
- **Incompatibility:** on **13.7.8** every one of these newer branches is inactive and the app uses the
  older fallback path. This is expected and safe, but specific visual/behavioral polish that shipped for
  14.4+ (and the 26/27 Liquid Glass + adaptive search field) will **not** appear on this laptop.

---

## Full per-feature matrix

### Sound — ✅ compatible
Volume mixer, per-app output, output switcher, mic tools, Music-app blocker. All software; no hardware
dependency beyond a working audio device (present). Music-app blocker needs Accessibility (permission,
not hardware).

### Know what your Mac is doing
- System monitor — ✅ (CPU, memory, battery, network, temps all valid) except ⚠️ **discrete-GPU tile → N/A** (integrated only).
- **Fan Control (beta) — ✅ compatible.** This laptop **has a fan** and an Intel SMC; the feature drives
  SMC keys (`FanControlHardware.swift` via `SMCClient`). Note: later fanless Macs (e.g. MacBook Air)
  would have *no* fan to control — the opposite direction. ✅ here.
- Menu bar readouts — ✅.
- Network / speed test — ✅.
- Alerts — ✅.

### Windows and the Dock — ✅ compatible
App switcher (live previews need Screen Recording permission), window layout/snap, Dock preview, Dock
clicks, green-button maximize, fixed Spaces order, quit-on-close, quit/close protection. All software;
multi-display moves work via Thunderbolt 3. No hardware blocker.

### Keyboard and mouse — ✅ compatible
Text snippets, smooth scrolling, pointer acceleration, linear scrolling, focus-follows-mouse, scroll
direction, side buttons, mouse-button shortcuts, middle click, click filter, key debounce, Super key,
shortcut management. All CGEvent/IOKit input taps; work on Intel. No Touch Bar dependency.

### Clipboard, files and links — ✅ compatible
Clipboard history, auto-clear, paste-plain, Shelf, Finder shortcuts (⌘X/⌘V, F2 rename), Clean URL, disk
image installer. Software; work on Intel.

### Everyday tools
- **Dynamic Island — ⚠️ simulated** (see above; no physical notch; Liquid Glass needs 26).
- AI agents — ✅ (reads Claude/Codex/Copilot logs; no hardware dependency).
- Command Bar, Quick panel, Quick toggles, Radial menu, Scratchpad, Cleaning Mode — ✅.

### Capture and create — ✅ compatible
Screen capture, screenshot annotate, screen recording (needs Screen Recording + Mic), camera preview
(720p FaceTime camera present ✅), copy-text-from-screen (offline OCR), color picker, local media tools.
No hardware blocker.

### App management — ✅ compatible
App updates, Cleaner, messaging downloads, Uninstaller, Homebrew manager (needs Homebrew), Port manager
(needs `lsof`/`Kill Process`). Software.

### Energy and display
- Keep awake (incl. lid-closed/clamshell) — ✅ (Intel clamshell mode supported).
- **Displays / brightness — ✅ for hardware brightness, half/quarter brightness steps, and software
  extra-dimming** (built-in Retina supports brightness control). ❌ **Extra brightness (XDR)** sub-feature
  is unavailable (no XDR panel — see above).
- Bluetooth on sleep — ✅ (Bluetooth present).

### Misc / cross-cutting
- **Touch Bar — present on THIS model, absent on 2021+, but the app does NOT use it** (no `NSTouchBar`
  references in the source). Noted for completeness: a design element this laptop has that later
  iterations dropped; irrelevant to compatibility.
- Login-item / fan daemon registration via `SMAppService` — ✅ requires macOS 13.0 (the port floor);
  satisfied by 13.7.8.

---

## Verification status & caveats

- **Statically confirmed** (from source): Extra brightness XDR requirement, Liquid Glass macOS 26 gate,
  Notch simulated-mode fallback, no Touch Bar usage, SMC-based Fan Control.
- **Not yet runtime-verified:** the app has not been built/run on this host (upstream pins the macOS 26
  SDK + Swift 5.9; this machine has SDK 13.3 + Swift 5.8.1). The GPU-tile **N/A** and the general
  Intel runtime behavior should be confirmed once the port is built on a 26-SDK host and exercised on
  actual macOS 13 Intel hardware (the port's Phase 6).
- **Bottom line:** of the ~12 feature groups, only **Extra brightness (XDR)** is hard-disabled, while
  **Dynamic Island/Notch** and **Liquid Glass** are simulated/degraded (no notch hardware; OS < 26), and
  the **discrete-GPU monitor tile** is N/A (integrated graphics only). Everything else is compatible
  with this 2020 Intel MacBook Pro.
