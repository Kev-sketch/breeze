# PORTING-macos-legacy.md — Breeze on macOS (universal: Intel + Apple Silicon, floor macOS 13)

> Legacy-OS port produced with the `legacy-os-port` skill. This file is the port's memory: it lets a
> future session pick up the work without re-discovering anything.

## 1. Summary

- **Upstream:** https://github.com/Kev-sketch/breeze @ `upstream-main` (grafted tag on `port/macos-universal`)
- **Port target:** a **universal binary (arm64 + x86_64)** so the app runs natively on **both Apple
  Silicon and Intel Macs**; deployment floor lowered from **macOS 14.0 → macOS 13.0 (Ventura)**.
- **Status:** build configuration changed and the **universal build mechanism is verified** at the
  toolchain level. The **full app build is NOT verified on this host** — see §2/§4 for why (upstream
  pins the macOS 26 SDK + Swift 5.9, which this machine does not have).
- **What is verified, and how:**
  - `build.sh` passes `zsh -n` (syntax OK).
  - The universal compile + `lipo -create` path was exercised end-to-end against the local SDK:
    a throwaway Swift program was compiled for both `arm64` and `x86_64` and merged into a single fat
    Mach-O reported by `lipo -info` as `x86_64 arm64`, and it executed on this Intel host.
  - `Package.swift` deployment floor changed `.macOS(.v14)` → `.macOS(.v13)`.

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
| Deployment target | macOS 14.0 | **macOS 13.0** (`MACOS_DEPLOYMENT_TARGET=13.0`, `Package.swift` `.macOS(.v13)`) |
| Test target | `arm64` (would not run on Intel) | native host arch (`NATIVE_TARGET="$(uname -m)-apple-macosx13.0"`) so tests run on either architecture |
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

### 4.2 — Deployment floor was 14.0; real floor is 13.0
- **File:** `Package.swift`, `build.sh`.
- **Symptom:** blocked installation/launch on macOS 13.
- **Root cause:** the only **unguarded** modern API the app depends on is `SMAppService`
  (login-item / fan-control daemon registration), used in `LaunchAtLogin.swift`,
  `FanControlService.swift`, `GeneralSettings.swift`, `Uninstaller.swift`, `SelfUninstall.swift`.
  `SMAppService` requires **macOS 13.0**. All newer APIs (14.4, 15, 26, 27) are already behind
  `#available` guards, so they do not raise the floor.
- **Fix:** set floor to 13.0 in both `build.sh` and `Package.swift`.
- **Verified:** by source audit (37 `#available` guards; the single unguarded modern symbol set is
  `SMAppService`). A full availability typecheck on a 26-SDK host is still recommended to confirm no
  other unguarded ≥13 API exists.
- **Upstream?** partially upstream (they chose 14 conservatively); lowered by the port.

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

Not yet populated. Runtime verification requires:
1. A machine with the macOS 26 SDK + Xcode 26 / Swift 5.9+, and
2. Testing on actual **macOS 13 (Intel and Apple Silicon)** hardware to exercise the lowered floor and
   the universal slices. No runtime bugs have been observed because the full app has not yet been built
   on a suitable host.

## 6. Verification

- `zsh -n build.sh` → syntax OK.
- Universal mechanism: standalone `swiftc` (arm64 + x86_64) + `lipo -create` → fat `x86_64 arm64`
  Mach-O that runs on this Intel host. (Artefact: `/tmp/univtest/vt_universal`.)
- `Package.swift` floor → `.macOS(.v13)`.
- **Pending on a 26-SDK host:** full `./build.sh` compile/typecheck; running the universal `.app` on
  macOS 13 Intel and macOS 13/14 Apple Silicon; exercising menu-bar features, the fan-control daemon
  (`SMAppService` registration on 13+), and the Now Playing adapter.

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
