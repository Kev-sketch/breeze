# Pre-launch report — vorssaint-utils (port branch `port/macos-universal`)

Date: 2026-10-11 · Reviewer: automated pre-launch review · Repo: local clone of
`github.com/vorssaint/vorssaint-utils`, branch `port/macos-universal`

## Verdict at a glance

| Area | Result | Blockers |
|---|---|---|
| 1. Code review | ✅ Pass (1 cleanup applied) | 0 |
| 2. Security audit | ✅ Pass with notes | 0 |
| 3. Port configuration | ⚠️ Statically verified; full build unverified here | 1 (verification) |
| 4. Setup & files | ✅ Pass with notes | 0 |
| 5. GitHub publication | ❌ **Not published** | **1 (blocking)** |

**Launch is NOT ready.** One hard blocker (not published) and one verification blocker (no
end-to-end build on a suitable toolchain) must be cleared first.

---

## Area 1 — Code review

**Port diff reviewed** (`build.sh`, `Package.swift`, `README.md`, `PORTING-macos-legacy.md`,
`FEATURE-HARDWARE-COMPAT.md`):

- ✅ `build_universal()` is a small, well-scoped helper: it compiles each arch separately and merges
  with `lipo -create`. App, fan helper, and Now Playing adapter are all routed through it; the test
  target builds for the native host arch. Variable wiring is correct (`MACOS_DEPLOYMENT_TARGET`,
  `ARCHS`, `NATIVE_TARGET`, `TARGET` all defined at the top and used consistently).
- 🔧 **Fixed during review:** the port had left dead code — the app's `APP_OBJECT_DIR` /
  `APP_OUTPUT_FILE_MAP` / `write_swift_output_file_map` setup was no longer consumed once the app
  moved to the per-arch universal path. Removed; `build.sh` re-passes `zsh -n`. (The shared function
  is still used by the test target — correctly untouched.)
- ⚠️ **Note (performance):** the universal app build drops `-incremental`, so every build recompiles
  all sources for both arches. Correct, but slower than upstream's incremental single-arch build.
- ✅ README badge and "What you need" updated to reflect universal + macOS 13; a clear port note links
  to the porting doc. Attribution and GPL-3.0 header comments preserved.

**Broader repo (spot-checked):** 961 tracked files, ~859 Swift; modular `Services/`/`UI/`/`Core/`
layout, no obvious dead code beyond the item above. `CHANGELOG.md` is 252 KB (intentional history).

## Area 2 — Security audit

**No committed secrets.** A tracked-file scan for private keys, API keys, tokens, and passwords
returned only GitHub Actions `${{ secrets.* }}` references (correct) and false positives (a UUID
variable named `token`; localization strings mentioning "token/password").

**Positives**
- ✅ `.gitignore` excludes signing material (`*.p12`, `*.pem`, `*.p8`, `*.key`, `*.keychain-db`) and
  build artifacts (`build/`, `dist/`, `*.dmg`).
- ✅ Entitlements (`Resources/Vorssaint.entitlements`) are minimal hardened-runtime resource grants
  (Apple Events, camera, audio input, calendars); app is not sandboxed — expected for this class of
  app.
- ✅ CI hygiene: `actions/checkout` pinned to a commit SHA, `persist-credentials: false`, and
  least-privilege `permissions:` (`contents: read`).
- ✅ `issue-fix-status.yml` uses the risky `pull_request_target` trigger **safely**: it performs **no
  checkout**, reads the PR body via the API into a file, and only greps it — no untrusted code runs.
- ✅ Privileged fan daemon registered via `SMAppService` with its own Mach service and a plist that
  runs a signed helper (no shell). Helper runs a `--selftest` at build time.
- ✅ Sudoers rule is tightly scoped: `#<uid> ALL=(root) NOPASSWD: /usr/bin/pmset disablesleep 1,
  /usr/bin/pmset disablesleep 0` — a **uid** (not a username, so no injection) and only the two
  `pmset` invocations needed for lid-closed keep-awake.
- ✅ The Now Playing `now-playing.pl` adapter validates its mode against a whitelist and only loads
  the app-bundled library path.

**Notes / low-risk items**
- ⚠️ **Hardcoded keychain password** `vorssaint-signing` appears in `build.sh:91` and
  `Tools/setup-signing.sh:26`, and the keychain is set to never auto-lock. This protects a *locally
  generated self-signed* identity, not a real secret, so severity is low — but consider prompting for
  a password or generating a random one for the local keychain.
- ℹ️ Outbound network surface is limited and visible: update checks (GitHub API/releases), the
  `agent-prices.json` feed from `raw.githubusercontent.com`, and `vorssaint.com` links. No inbound
  listeners. A privacy doc exists (`docs/PRIVACY.md`).
- ⚠️ `release.yml` consumes upstream-only secrets (`SIGNING_CERT_P12`, `NOTARY_*`). A fork must never
  attempt to reuse upstream's signing identity — see Area 5.

## Area 3 — Port configuration

- ✅ `zsh -n build.sh` → syntax OK (after the cleanup in Area 1).
- ✅ Universal mechanism **proven on this host**: a representative Swift program compiled for `arm64`
  and `x86_64` and merged with `lipo -create` yields a fat Mach-O (`x86_64 arm64`) that runs on this
  Intel machine.
- ✅ `Package.swift` floor lowered to `.macOS(.v13)` (rationale: unguarded `SMAppService` = 13.0);
  `swift-tools-version:5.9` unchanged.
- ⚠️ **Verification blocker:** upstream pins the **macOS 26 SDK** and requires **Swift 5.9+**; this
  host has SDK 13.3 / Swift 5.8.1, so the full app **cannot be built or run here**. The port config is
  statically verified only. Validate by building on a macOS 26-SDK host (the CI `macos-26` runner).
- ⚠️ **Verify on CI:** the `ci.yml` "compatibility" job builds on `macos-15` with SDK **15.2** and
  Swift 6.0.3. Code that references macOS 26/27 symbols may fail to compile against the 15.2 SDK — run
  that job to confirm it still passes with the universal build.

## Area 4 — Setup soundness & file correctness

- ✅ No build artifacts committed (`build/`, `dist/`, `*.dmg`, `.app/` — none tracked).
- ✅ Required asset present: `Resources/Gifs/highlights-notch.gif` (3.3 MB) — `build.sh` hard-fails
  without it.
- ✅ License (`LICENSE`, GPL-3.0-or-later) and `TRADEMARKS.md`/`SECURITY.md`/`SUPPORT.md` preserved.
- ✅ The two new port documents are intended additions.
- ⚠️ **Repo bloat:** `docs/demo.gif` is **30.5 MB**, plus `ReleaseAssets/vorssaint-3.1.4-showcase-1.mp4`
  (2.6 MB) and several multi-MB GIFs. Not blocking, but heavy for clones; consider Git LFS or hosting
  demo media in Releases.

## Area 5 — GitHub publication  ❌ BLOCKER

- Authenticated account: **`Kev-sketch`**.
- Remotes in this clone: **only `upstream`** → `vorssaint/vorssaint-utils` (read-only). **There is no
  `origin` remote.**
- Working tree: the port changes are **uncommitted** (`Package.swift`, `README.md`, `build.sh` modified;
  `PORTING-macos-legacy.md`, `FEATURE-HARDWARE-COMPAT.md`, `PRELAUNCH-REPORT.md` untracked).
- Repos under the account: `Kev-sketch/CoolMyMac-macOS13-Port` and `Kev-sketch/desktop-tutorial` —
  **no repository for this project.**

**Conclusion: the project is NOT published to GitHub under your repository.** This must be resolved
before launch.

---

## Blocking issues (must resolve before launch)

1. **Publish to GitHub.** No `origin`, no repo, nothing committed. Required steps:
   - `git add -A && git commit` the port changes (needs a git identity for the commit).
   - Create the repo under `Kev-sketch` and add it as `origin` (keep `upstream` read-only).
   - Push the branch (and `main`/tags as desired).
   - **Decision needed:** repository name and visibility (public vs private).
2. **Produce and verify a real build.** Build on a macOS 26-SDK host (or the CI `macos-26` runner) and
   run the universal `.app` on macOS 13 Intel **and** Apple Silicon. `lipo -info build/Vorssaint`
   should read `x86_64 arm64`.
3. **Fork release pipeline.** `release.yml` is hard-gated to `github.repository ==
   'vorssaint/vorssaint-utils'` and actor `vorssaint`, and needs upstream secrets. In the fork it will
   never run. To ship signed/notarized releases you must edit the workflow and supply your own
   Developer ID + notary credentials — or distribute local builds (ad-hoc signed).

## Non-blocking issues (recommended)

- Confirm the `ci.yml` compatibility job (SDK 15.2) still compiles the macOS-26-guarded code.
- Trim repo size (30 MB `docs/demo.gif`, committed `.mp4`).
- Consider removing the hardcoded local-keychain password / enabling auto-lock.
- Note the slower non-incremental universal build; acceptable, documented.

## Pre-launch checklist

- [ ] Commit the port and create `origin` under `Kev-sketch` (name/visibility decided)
- [ ] Push branch + tags; keep `upstream` untouched
- [ ] Build on macOS 26 SDK; verify `lipo -info` shows `x86_64 arm64`
- [ ] Run on macOS 13 Intel and Apple Silicon; exercise menu-bar + fan-control (SMAppService) + Now Playing
- [ ] Decide distribution: edit `release.yml` with own certs, or ship ad-hoc local builds
- [ ] (Optional) LFS/Releases for large media; harden local keychain password
