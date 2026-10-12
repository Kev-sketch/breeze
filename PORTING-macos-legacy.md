# PORTING-macos-legacy.md — Breeze on macOS (universal: Intel + Apple Silicon, floor macOS 13)

> Legacy-OS port produced with the `legacy-os-port` skill. This file is the port's memory: it lets a
> future session pick up the work without re-discovering anything.

> **CORRECTION (2026-10-12).** An earlier revision of this port lowered the deployment floor to
> macOS 13.0. That was **wrong and broke the build**: a CI run on the macOS 26 runner failed with
> **607 availability errors across 85 files**, because the codebase uses macOS **14** APIs unguarded
> — `onChange(of:initial:_:)` (414×), `symbolEffect` (30×), `contentTransition(.replace)` (22×),
> `SCScreenshotManager`/`captureImage` (24×), `CADisplayLink` (14×), `keyframeAnimator` /
> `SpringKeyframe` / `CubicKeyframe`, `onKeyPress(_:action:)`, `NSApplication.activate(from:options:)`,
> and more. **The floor is macOS 14.0 (Sonoma)** — a hard requirement of the code. The earlier
> "SMAppService is the youngest API (13.0)" analysis was incomplete; it missed these.
>
> **ADDENDUM (2026-10-12, branch `port/macos13`).** The floor is moving to **macOS 13.0 (Ventura)**
> after all — via explicit Ventura fallbacks (`Sources/Breeze/Support/BackDeployCompat.swift`,
> `CompatDisplayLink.swift`, `ScreenCaptureCompat.swift`) instead of the naive floor-lowering that
> failed above. `Package.swift`, `build.sh` and `Info.plist` now declare 13.0; this doc's older
> "floor is 14.0" statements are historical.

## 1. Summary

- **Upstream:** https://github.com/vorssaint/vorssaint-utils
- **Port target:** a **universal binary (arm64 + x86_64)** so the app runs natively on **both Apple
  Silicon and Intel Macs**. Deployment floor: **macOS 13.0 (Ventura)** via explicit fallbacks
  (see the ADDENDUM above and §5.1).
- **Status:** the port builds a universal binary; the full app build is verified by CI on the
  `macos-26` GitHub runner (see `.github/workflows/breeze-release.yml`).
- **What is verified, and how:**
  - `build.sh` passes `zsh -n` (syntax OK).
  - The universal compile + `lipo -create` path was exercised against the local SDK: a throwaway
    Swift program compiled for both `arm64` and `x86_64` merged into a fat Mach-O (`x86_64 arm64`)
    that ran on this Intel host.
  - CI (macos-26) builds the app and packages the DMG.

## 2. Environment facts (do not re-discover)

Properties of the build machine used for this port.

| Fact | Value |
|---|---|
| OS version | macOS 13.7.8 (Ventura, Build 22H730) |
| IDE present? | Command Line Tools only — **no Xcode.app** |
| SDKs available | MacOSX12.1, 12.3, 12, 13, 13.1, 13.3 (newest usable: **13.3**) |
| Compiler version | Apple Swift 5.8.1, `x86_64-apple-darwin22.6.0` |
| Package manager state | SwiftPM present; `xcrun --sdk macosx --show-sdk-platform-path` fails (CLT-only quirk, non-fatal). Upstream is built via `build.sh` driving `swiftc` directly, not SwiftPM, so this does not block the build. |
| Missing IDE-only tools | `actool`/`ibtool` (asset catalogs) — absent; adaptive icon falls back to `AppIcon.icns` (cosmetic, already handled by upstream). |
| Signing identity | none → ad-hoc (`codesign --sign -`) is sufficient to run locally; not notarizable. |
| Hardware notes | MacBookPro16,2, Quad-Core Intel Core i7 (x86_64). The host is Intel, so it runs the x86_64 slice of any universal binary natively. |

**Why the full app could not be built here:** upstream's `build.sh` pins `PINNED_SDK=.../MacOSX26.sdk`
and the code references macOS 26 / 27 symbols (behind `#available`, but the symbols must still exist
in the SDK to compile). This machine's newest SDK is 13.3 and its toolchain is Swift 5.8.1. A complete
build therefore requires a machine with the **macOS 26 SDK + Xcode 26 / Swift 5.9+** (or newer).

## 3. Build configuration changes

| Area | Upstream | This port |
|---|---|---|
| Architecture | `arm64` only (`TARGET="arm64-apple-macosx14.0"`) | **universal `arm64` + `x86_64`** via a `build_universal` helper that compiles each arch and merges with `lipo -create` |
| Deployment target | macOS 14.0 | **macOS 13.0** (Ventura fallbacks in `Sources/Breeze/Support/`; see §5.1) |
| Test target | `arm64` (would not run on Intel) | native host arch (`NATIVE_TARGET="$(uname -m)-apple-macosx${MACOS_DEPLOYMENT_TARGET}"`) so tests run on either architecture |
| Toolchain / language level | `swift-tools-version:5.9` | unchanged (the 26-SDK host supplies Swift ≥ 5.9) |
| Dependencies | none external (SPM); two C system-library shims (`HIDEventSystem`, `VMStatisticsCompat`) | unchanged |

## 4. Blocker inventory

### 4.1 — Upstream shipped Apple Silicon only (Intel absent)
- **File:** `build.sh:65` (was `TARGET="arm64-apple-macosx14.0"`), and the three product `swiftc` steps.
- **Symptom:** the published/branched build produced an `arm64`-only binary; it would not launch on
  Intel Macs ("You can't open the application because it is not supported on this type of Mac").
- **Root cause:** the target triple hard-coded a single architecture; no `x86_64` slice was ever built.
- **Fix:** introduced `ARCHS=(arm64 x86_64)`, a `build_universal()` helper, and routed the app, fan
  helper, and Now Playing adapter through it; the bundle now copies universal binaries.
- **Verified:** standalone compile + `lipo -create` produced a fat `x86_64 arm64` binary that runs.
- **Upstream?** introduced by the port.

### 4.2 — Deployment floor is macOS 14.0 (a hard requirement)
- **File:** `Package.swift`, `build.sh`, and 85 source files.
- **Symptom:** a CI build with the floor at 13.0 failed with 607 availability errors.
- **Root cause:** the codebase uses macOS **14** APIs unguarded throughout — `onChange(of:initial:_:)`
  (414×), `symbolEffect` (30×), `contentTransition(.replace)` (22×), `SCScreenshotManager`/
  `captureImage` (24×), `CADisplayLink` (14×), `keyframeAnimator`/`SpringKeyframe`/`CubicKeyframe`,
  `onKeyPress(_:action:)`, `NSApplication.activate(from:options:)`, and more. Lowering the floor to
  13.0 (an earlier mistake in this port) cannot compile against them.
- **Fix:** keep the floor at **macOS 14.0** (upstream's choice was correct).
- **Verified:** CI run `38246266910` on the `macos-26` runner produced the 607-error list at floor 13.
- **Upstream?** upstream. To reach macOS 13 or below, every one of these sites must be guarded or
  rewritten with a macOS-13 fallback — and several (`SCScreenshotManager`, `CADisplayLink`,
  `symbolEffect`, `keyframeAnimator`) have **no** direct macOS-13 equivalent, so features would degrade.
  That is a large, separate port, not a build-config change.

### 4.3 — Upstream requires the macOS 26 SDK + Swift 5.9 (environment limitation)
- **File:** `build.sh:199` (`PINNED_SDK=".../MacOSX26.sdk"`); `Package.swift:1` (`swift-tools-version:5.9`).
- **Symptom:** on this host the code will not compile (no 26 SDK; Swift 5.8.1 < 5.9).
- **Root cause:** forward-looking use of macOS 26/27 symbols and the pinned SDK.
- **Fix:** none required for the port; the universal/floor changes are correct for a 26-SDK host. To
  build/verify, use a machine with Xcode 26 (or newer) Command Line Tools.
- **Verified:** documented; not buildable on the porting host.
- **Upstream?** upstream.

### 4.4 — "macOS 10.0 onward" is categorically impossible for this codebase
This is the honest boundary of the request. A SwiftUI app **cannot** run on macOS 10.0–10.14:

- **SwiftUI requires macOS 10.15 (Catalina).** 205 of the app's Swift files `import SwiftUI`.
  SwiftUI did not exist before 10.15, so there is no path to run this UI on 10.0–10.14.
- **Swift itself requires macOS 10.10 (Yosemite, 2014) at runtime.** There is no Swift compiler,
  runtime, or ABI on macOS 10.0–10.9; any Swift binary (even without SwiftUI) cannot execute there.
- **macOS 10.0–10.3 (Cheetah/Puma/Jaguar) are PowerPC-only.** They cannot execute `x86_64` (Intel)
  or `arm64` (Apple Silicon) binaries at all, and predate Swift by ~13 years.
- **Conclusion:** reaching 10.0–10.14 would require a from-scratch rewrite in Objective-C / AppKit
  (and Carbon/Classic for 10.0–10.3 on PowerPC) — a different project, not a port. This port does
  **not** attempt that. The realistic, reachable envelope for this codebase is **macOS 13 → current**.

> Note on SDK availability: even with every historical SDK in hand, the SwiftUI floor (10.15) cannot be
> crossed for this code. Older SDKs (≤ macOS 11) are no longer shipped by Apple and would themselves
> have to be recovered from legacy Xcode releases; they do not change the SwiftUI/Swift language floor.

## 5. Post-port fixes (found by running it)

### 5.1 — `onGeometryChange` Ventura fallback (static triage, 2026-10-12)
- **Last unguarded macOS-14 family.** A repo-wide sweep showed every other family from §4.2
  already converted to the `Support/` shims (`onChangeCompat`, `symbol*Compat`,
  `contentTransitionSymbolReplaceCompat`, `onKeyPressCompat`, `activateCompat`, `CompatDisplayLink`,
  `ScreenCaptureCompat`, …) or guarded inline (`keyframeAnimator` in `NotchMusicStrip.swift`).
- **Fix:** `onGeometryChangeCompat(for:_:action:)` in `BackDeployCompat.swift` — a layout-neutral
  background `GeometryReader` firing on appear + on change; 6 sites converted in `NotchSectionsView`,
  `NotchView` (×2), `SwitcherView` (×2), `MediaWorkspaceView`. No-op on 14+ (original call runs).
- **Exonerated by isolated `swiftc -typecheck` probes against the 13.1/13.3 SDKs** (each API alone,
  target `x86_64-apple-macosx13.0`): `.numericText()` (13.0), `.onExitCommand`, `.dropDestination`,
  `TextField axis:`, `.defaultAppStorage`, `navigationSplitViewColumnWidth`, `symbolRenderingMode`,
  `ImageRenderer`, `PasteButton` — all 13.x-native, left untouched. `scrollTarget`/`writeOnly` hits are
  local names; `scrollBounceBehavior` appears in comments only (its AppKit fallback predates it).
- **Verified here:** `swiftc -parse` on all 5 touched files; fallback-branch harness typechecks clean
  on the 13.1 and 13.3 SDKs. **Still pending:** full `./build.sh` on a 26-SDK host (the `#available`
  14-branches cannot typecheck against the 13.x SDKs on this host).

Runtime verification requires:
1. A machine with the macOS 26 SDK + Xcode 26 / Swift 5.9+, and
2. Testing on actual **macOS 13 (Intel and Apple Silicon)** hardware to exercise the lowered floor and
   the universal slices. No runtime bugs have been observed because the full app has not yet been built
   on a suitable host.

## 6. Verification

- `zsh -n build.sh` → syntax OK.
- Universal mechanism: standalone `swiftc` (arm64 + x86_64) + `lipo -create` → fat `x86_64 arm64`
  Mach-O that runs on this Intel host. (Artefact: `/tmp/univtest/vt_universal`.)
- `Package.swift` floor → `.macOS(.v13)`; floor-13 CI build green
  ([Port macOS 13 build #38264344727](https://github.com/Kev-sketch/breeze/actions/runs/38264344727)).
- **Pending:** running the universal `.app` on macOS 13 Intel and macOS 13/14 Apple Silicon;
  exercising menu-bar features, the fan-control daemon (`SMAppService` registration on 13+),
  and the Now Playing adapter.

## 7. How to build

1. On a Mac with **Xcode 26 (or newer) Command Line Tools** (provides the macOS 26 SDK + Swift 5.9+).
2. `./build.sh --dev` → compiles the universal `Breeze (Developer)` variant into a `.app` bundle.
   (`./build.sh --dev --install` installs and launches it.)
3. Confirm the slices: `lipo -info build/Breeze` → `x86_64 arm64`.
4. To validate the lowered floor, build and run on a macOS 13 machine (Intel and Apple Silicon).

## 8. How to publish

- Fork remotes: `origin` → your fork, `upstream` → `https://github.com/Kev-sketch/breeze`
  (kept read-only; never push to it).
- Branch: `port/macos-universal`; fork-point tag: `upstream-main`.
- Tag releases `<upstream-version>-macos-universal`.
- Attach the built universal `.dmg` to a release so users don't have to build it.
- Keep upstream's GPL-3.0-or-later license and attribution; per `TRADEMARKS.md`, give the fork its own
  bundle identity (the `--dev` variant already uses `com.kevsketch.breeze.utils.dev`). Drop upstream's release
  pipelines that depend on upstream's signing secrets.

## 9. Known limitations

- **Ad-hoc signed / not notarized** on this host → fine for local use; not Gatekeeper-clean for download.
- **Adaptive icon catalog** needs Xcode 26's `actool` and is skipped on CLT builds (falls back to
  `AppIcon.icns`) — cosmetic only.
- **macOS 10.0–10.14 are unreachable** for this SwiftUI codebase (see §4.4). The port envelope is
  macOS 13 → current, universal (Intel + Apple Silicon).
- Full end-to-end runtime verification is pending a 26-SDK host and macOS 13 hardware (see §5).
