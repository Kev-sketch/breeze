#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

# Builds Breeze, assembles the .app bundle, signs it and (with --install)
# installs it into /Applications.
#
# The bundle is staged in a temporary directory outside ~/Documents: folders synced
# by File Provider gain xattrs (com.apple.provenance etc.) that invalidate codesign.
set -euo pipefail
cd "$(dirname "$0")"

# The icon catalog and the bundle are staged in temp dirs; sweep both however
# the script ends.
ICON_TMP=""
STAGE_TMP=""

cleanup() {
    [[ -n "$ICON_TMP" ]] && rm -rf "$ICON_TMP"
    [[ -n "$STAGE_TMP" ]] && rm -rf "$STAGE_TMP"
    return 0
}
trap cleanup EXIT
# zsh runs the EXIT trap when the script is hung up, but not when it is
# interrupted or terminated; route those through exit so a Ctrl-C partway
# into the build sweeps like any other ending.
trap 'exit 1' INT TERM HUP

# Flags: --dev builds the local-only "Breeze (Developer)" variant (its own
# bundle id, so it coexists with the official app); --install puts it in /Applications.
DEV=0
INSTALL=0
TEST=0
TEST_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --dev)     DEV=1 ;;
        --install) INSTALL=1 ;;
        --test)    TEST=1 ;;
        --test-suite=*) TEST=1; TEST_ARGS+=("--suite=${arg#*=}") ;;
        --list-tests) TEST=1; TEST_ARGS+=(--list) ;;
    esac
done

if (( DEV )); then
    APP_NAME="Breeze (Developer)"
    EXECUTABLE="BreezeDeveloper"
    APP_BUNDLE_ID="com.kevsketch.breeze.utils.dev"
    BUILD_VARIANT_FLAGS=(-D BREEZE_DEVELOPMENT)
    APP_OPTIMIZATION_FLAGS=(-Onone)
    BUILD_CONFIGURATION="debug"
else
    APP_NAME="Breeze"
    EXECUTABLE="Breeze"
    APP_BUNDLE_ID="com.kevsketch.breeze.utils"
    BUILD_VARIANT_FLAGS=()
    APP_OPTIMIZATION_FLAGS=(-O)
    BUILD_CONFIGURATION="release"
fi
FAN_HELPER_ID="$APP_BUNDLE_ID.fan-control"
# Now Playing is read through /usr/bin/perl loading this library; see
# Sources/NowPlayingAdapter. Staged under Contents/Frameworks, signed on its own.
NOW_PLAYING_ADAPTER_ID="$APP_BUNDLE_ID.now-playing"
NOW_PLAYING_ADAPTER="libBreezeNowPlaying.dylib"
# --- Universal binary support: Apple Silicon (arm64) + Intel (x86_64) ---
# Upstream built arm64 only. This port produces a universal (fat) binary so the
# app runs natively on both Apple Silicon and Intel Macs. The deployment floor is
# macOS 14.0: the codebase uses 607 macOS-14 APIs unguarded (onChange(of:initial:_:),
# symbolEffect, contentTransition(.replace), SCScreenshotManager, CADisplayLink,
# keyframeAnimator, …) across 85 files, so 14.0 is a hard requirement.
# See PORTING-macos-legacy.md.
MACOS_DEPLOYMENT_TARGET=14.0
ARCHS=(arm64 x86_64)
NATIVE_TARGET="$(uname -m)-apple-macosx${MACOS_DEPLOYMENT_TARGET}"
TARGET="arm64-apple-macosx${MACOS_DEPLOYMENT_TARGET}"
ENTITLEMENTS="Resources/Breeze.entitlements"
LEGACY_IDENTITY="Breeze Signing"

developer_id_identity() {
    security find-identity -v -p codesigning 2>/dev/null \
        | grep 'Developer ID Application' \
        | head -1 \
        | sed -E 's/.*"(.*)".*/\1/' || true
}

# A find-identity listing also names certificates codesign then rejects (an
# expired one fails the build with errSecInternalComponent), and -v excludes
# every self-signed one; ask codesign itself with a throwaway copy of /bin/echo.
legacy_identity_installed() {
    local probe signed=1
    # A locked keychain still lists its identities but cannot sign with them,
    # and this one is locked after every reboot; unlock it before asking.
    security unlock-keychain -p breeze-signing \
        "$HOME/Library/Keychains/breeze-signing.keychain-db" 2>/dev/null || true
    probe="$(mktemp)"
    cp /bin/echo "$probe"
    /usr/bin/codesign --force --strip-disallowed-xattrs --sign "$LEGACY_IDENTITY" "$probe" \
        >/dev/null 2>&1 && signed=0
    rm -f "$probe"
    return $signed
}

# Any build that lands in /Applications needs a stable signature, not just the
# Developer one: macOS ties Accessibility and Screen Recording grants to the
# exact binary hash, so an ad-hoc rebuild orphans them while System Settings
# keeps showing them as granted, and no new prompt ever appears. A plain
# --install strands them under the released bundle id, on the app the user
# actually relies on. When no identity is installed, create the stable local one
# up front instead of falling through to ad-hoc — setup-signing.sh is free,
# offline and idempotent. Gating on the install rather than the variant keeps
# this off CI, where neither ci.yml nor release.yml passes --install.
if (( DEV || INSTALL )) && [[ -z "$(developer_id_identity)" ]] \
    && ! legacy_identity_installed; then
    echo "▸ No signing identity installed; creating the stable local one…"
    if ! ./Tools/setup-signing.sh; then
        echo "  ⚠ Tools/setup-signing.sh failed; signing ad-hoc instead." >&2
        echo "    Accessibility and Screen Recording grants will not survive rebuilds:" >&2
        echo "    System Settings will show them as granted while the app is not trusted." >&2
        echo "    After fixing the identity, clear the stale grant once with:" >&2
        echo "      tccutil reset Accessibility $APP_BUNDLE_ID" >&2
    fi
fi

codesign_with_timestamp_retry() {
    local attempt
    for attempt in 1 2 3; do
        if /usr/bin/codesign "$@"; then
            return 0
        fi
        if (( attempt < 3 )); then
            echo "  Developer ID signing failed; retrying ($((attempt + 1))/3)"
            sleep "$attempt"
        fi
    done
    return 1
}

write_swift_output_file_map() {
    local output_file="$1"
    local object_dir="$2"
    shift 2
    local source artifact

    {
        print -r -- "{"
        print -r -- "  \"\": {"
        print -r -- "    \"swift-dependencies\": \"$object_dir/master.swiftdeps\""
        print -r -- "  }"
        for source in "$@"; do
            artifact="${source//\//__}"
            artifact="${artifact%.swift}"
            print -r -- ","
            print -r -- "  \"$source\": {"
            print -r -- "    \"object\": \"$object_dir/$artifact.o\","
            print -r -- "    \"swift-dependencies\": \"$object_dir/$artifact.swiftdeps\""
            print -r -- "  }"
        done
        print -r -- "}"
    } > "$output_file"
}

finalize_installed_bundle_after_child() {
    local bundle="$1"
    local helper="$bundle/Contents/Library/LaunchServices/$FAN_HELPER_ID"
    local adapter="$bundle/Contents/Frameworks/$NOW_PLAYING_ADAPTER"
    local devid
    devid="$(developer_id_identity)"

    echo "▸ Finalizing installed signature…"
    sleep 3
    if [[ -n "$devid" ]]; then
        [[ -f "$helper" ]] && codesign_with_timestamp_retry --force --strip-disallowed-xattrs \
            --options runtime --timestamp --identifier "$FAN_HELPER_ID" --sign "$devid" "$helper"
        [[ -f "$adapter" ]] && codesign_with_timestamp_retry --force --strip-disallowed-xattrs \
            --options runtime --timestamp --identifier "$NOW_PLAYING_ADAPTER_ID" --sign "$devid" "$adapter"
        codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
            --entitlements "$ENTITLEMENTS" --sign "$devid" "$bundle"
    elif legacy_identity_installed; then
        [[ -f "$helper" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
            --identifier "$FAN_HELPER_ID" --sign "$LEGACY_IDENTITY" "$helper"
        [[ -f "$adapter" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
            --identifier "$NOW_PLAYING_ADAPTER_ID" --sign "$LEGACY_IDENTITY" "$adapter"
        /usr/bin/codesign --force --strip-disallowed-xattrs --sign "$LEGACY_IDENTITY" "$bundle"
    else
        [[ -f "$helper" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
            --identifier "$FAN_HELPER_ID" --sign - "$helper"
        [[ -f "$adapter" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
            --identifier "$NOW_PLAYING_ADAPTER_ID" --sign - "$adapter"
        /usr/bin/codesign --force --strip-disallowed-xattrs --sign - "$bundle"
    fi
    [[ -f "$helper" ]] && /usr/bin/codesign --verify --strict "$helper"
    [[ -f "$adapter" ]] && /usr/bin/codesign --verify --strict "$adapter"
    /usr/bin/codesign --verify --deep --strict "$bundle"
    echo "✓ Signature ready: $bundle"
}

if (( INSTALL && ! TEST )) && [[ "${BREEZE_INSTALL_CHILD:-0}" != "1" ]]; then
    BREEZE_INSTALL_CHILD=1 "$0" "$@"
    child_status=$?
    if (( child_status != 0 )); then
        exit "$child_status"
    fi
    finalize_installed_bundle_after_child "/Applications/$APP_NAME.app"
    exit 0
fi

# Prefer the macOS 26 SDK when present: the 27 SDK turns SwiftUI property wrappers
# into macros (SwiftUIMacros plugin) that the Command Line Tools cannot load yet.
PINNED_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    SDK="$(xcrun --show-sdk-path)"
elif [[ -d "$PINNED_SDK" ]]; then
    SDK="$PINNED_SDK"
else
    SDK="$(xcrun --show-sdk-path)"
fi
SDK_COMPAT_FLAGS=()
VM_STATISTICS_COMPAT_FLAGS=(-I Sources/VMStatisticsCompat)
HID_EVENT_SYSTEM_FLAGS=(-I Sources/HIDEventSystem)
if [[ "$SDK" == "$PINNED_SDK" ]]; then
    # Swift 6.4 can read the SDK 26 interfaces when given their compiler version.
    SDK_COMPAT_FLAGS=(-Xfrontend -interface-compiler-version -Xfrontend 6.3.2)
fi

# Build one product as a universal binary by compiling each architecture
# separately and merging the slices with lipo. Pass the swiftc flags EXCEPT
# -target / -sdk / -o (this function supplies those).
build_universal() {
    local out="$1"; shift
    local arch arch_out per_arch=()
    for arch in "${ARCHS[@]}"; do
        arch_out="build/arch/${arch}/$(basename "$out")"
        mkdir -p "$(dirname "$arch_out")"
        swiftc -target "${arch}-apple-macosx${MACOS_DEPLOYMENT_TARGET}" -sdk "$SDK" \
            "${SDK_COMPAT_FLAGS[@]}" "$@" -o "$arch_out" || return $?
        per_arch+=("$arch_out")
    done
    lipo -create -output "$out" "${per_arch[@]}"
}

# The defaults migrations under test need a real UserDefaults suite, and every
# suite leaves an empty plist in ~/Library/Preferences. The tests already clear
# the domains, but cfprefsd writes the emptied file back out around the time the
# process that owned it exits, so only a caller that outlives the run can remove
# them. `PreferenceNamespaceTests` scans every compiled Swift test file against
# these namespaces, which keeps this sweep complete without a second list.
discard_test_preferences() {
    local preferences="${1:-$HOME/Library/Preferences}" name attempt
    local survivors=0 quiet_passes=0
    # cfprefsd can recreate an emptied domain after the first removal. Require
    # two quiet checks, but keep a hard limit so persistent failures still fail CI.
    for attempt in {1..10}; do
        for name in "breeze.tests." "com.kevsketch.breeze.tests."; do
            rm -f "$preferences"/$name*.plist(N)
        done
        rm -f "$preferences/metrics-tests.plist"
        sleep 0.2
        survivors=$(find "$preferences" -maxdepth 1 \
            \( -name "breeze.tests.*.plist" -o -name "com.kevsketch.breeze.tests.*.plist" \
               -o -name "metrics-tests.plist" \) 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$survivors" == "0" ]]; then
            quiet_passes=$((quiet_passes + 1))
            if (( quiet_passes == 2 )); then return 0; fi
        else
            quiet_passes=0
        fi
    done
    echo "✗ test preferences did not settle in $preferences ($survivors remaining)" >&2
    return 1
}

# Standalone automated tests: pure contracts plus isolated disk, subprocess,
# keyboard-data and media fixtures. No application windows or device capture.
if (( TEST )); then
    python3 Tests/generate_sources.py
    TEST_OBJECT_DIR="build/objects/tests"
    mkdir -p "$TEST_OBJECT_DIR"
    TEST_SOURCES=(
        Sources/Breeze/Services/Media/MediaSupport.swift
        Sources/Breeze/Core/QuitProtectionSupport.swift
        Sources/Breeze/Core/QuitProtectionStrings.swift
        Sources/Breeze/Core/Defaults.swift
        Sources/Breeze/Core/NotchStrings.swift
        Sources/Breeze/Core/NotchTourStrings.swift
        Sources/Breeze/Core/NotchEditorStrings.swift
        Sources/Breeze/UI/Settings/NotchSettingsTabRow.swift
        Sources/Breeze/Core/NotchActivityStrings.swift
        Sources/Breeze/Services/Notch/NotchTimerSupport.swift
        Sources/Breeze/Services/Notch/NotchTimerAlert.swift
        Sources/Breeze/UI/Notch/NotchIslandAlert.swift
        Sources/Breeze/Services/Notch/NotchAccessorySupport.swift
        Sources/Breeze/Services/QuickTools/CameraPreviewSupport.swift
        Sources/Breeze/Core/NotchMusicExtrasStrings.swift
        Sources/Breeze/Services/Notch/NotchLyricsSupport.swift
        Sources/Breeze/Services/Notch/NotchQueueSupport.swift
        Sources/Breeze/Services/Notch/NotchPreferredPlayer.swift
        Sources/Breeze/Core/NotchFilesStrings.swift
        Sources/Breeze/Core/NotchWatchStrings.swift
        Sources/Breeze/Services/Notch/NotchWatchSupport.swift
        Sources/Breeze/Core/NotchMascotStrings.swift
        Sources/Breeze/Services/Notch/NotchMascotSupport.swift
        Sources/Breeze/Services/CommandBar/CommandBarDropletMotion.swift
        Sources/Breeze/Services/Notch/NotchFileToolsSupport.swift
        Sources/Breeze/Services/Notch/NotchDownloadSupport.swift
        Sources/Breeze/Services/Notch/NotchDownloadProgressObserver.swift
        Sources/Breeze/Core/NotchCalendarStrings.swift
        Sources/Breeze/Core/NotchNotificationStrings.swift
        Sources/Breeze/Core/NotchGestureStrings.swift
        Sources/Breeze/Core/NotchAgentStrings.swift
        Sources/Breeze/Services/Notch/NotchAgentSupport.swift
        Sources/Breeze/Core/NotchLockScreenStrings.swift
        Sources/Breeze/Services/Notch/NotchLockScreenSupport.swift
        Sources/Breeze/Services/AgentUsage/AgentUsageModels.swift
        Sources/Breeze/Services/AgentUsage/AgentPricing.swift
        Sources/Breeze/Services/AgentUsage/AgentLogObject.swift
        Sources/Breeze/Services/AgentUsage/AgentLogParser.swift
        Sources/Breeze/Services/AgentUsage/AgentUsageSummary.swift
        Sources/Breeze/Services/AgentUsage/AgentUsageStore.swift
        Sources/Breeze/Services/AgentUsage/AgentUsageArchive.swift
        Sources/Breeze/Services/AgentUsage/AgentClaudeAppUsage.swift
        Sources/Breeze/Services/AgentUsage/AgentCodexServer.swift
        Sources/Breeze/Services/AgentUsage/AgentOpenCodeReader.swift
        Sources/Breeze/Services/Notch/NotchGestureSupport.swift
        Sources/Breeze/Services/Notch/NotchSectionPaging.swift
        Sources/Breeze/Services/Notch/NotchSliderEditing.swift
        Sources/Breeze/Services/Notch/NotchNotificationSupport.swift
        Sources/Breeze/Services/Notch/NotchNotificationReaderCore.swift
        Sources/Breeze/Services/Notch/NotchCalendarSupport.swift
        Sources/Breeze/Services/Notch/NotchKeepAwakeSupport.swift
        Sources/Breeze/Services/Notch/NotchSupport.swift
        Sources/Breeze/Services/Notch/NotchAudioLevelSupport.swift
        Sources/Breeze/Services/Notch/NotchVolumeKeyGate.swift
        Sources/Breeze/Services/Notch/NotchMusicSupport.swift
        Sources/Breeze/UI/Notch/NotchDecorativeClock.swift
        Sources/Breeze/UI/Notch/NotchEqualizerBars.swift
        Sources/Breeze/UI/Notch/NotchScrollEdgeFade.swift
        Sources/Breeze/UI/Notch/NotchAgentAnimationView.swift
        Sources/Breeze/UI/WindowVisibilityReader.swift
        Sources/Breeze/Services/Notch/NotchMusicAutomationSupport.swift
        Sources/Breeze/Services/Notch/NotchMusicAutomation.swift
        Sources/Breeze/Services/Notch/NotchPlaybackSource.swift
        Sources/Breeze/Services/Notch/NotchPlaybackCommand.swift
        Sources/Breeze/Services/Notch/NotchMusicCommandWriter.swift
        Sources/Breeze/Core/FeatureCatalog.swift
        Sources/Breeze/Core/FeaturePresets.swift
        Sources/Breeze/Core/FeatureHubStrings.swift
        Sources/Breeze/Core/ShortcutSettingsStrings.swift
        Sources/Breeze/Core/SettingsBackupSupport.swift
        Sources/Breeze/Core/BackupStrings.swift
        Sources/Breeze/Core/SnippetStrings.swift
        Sources/Breeze/Core/AlertSoundStrings.swift
        Sources/Breeze/Core/BrightnessStrings.swift
        Sources/Breeze/Core/MediaImageStrings.swift
        Sources/Breeze/Core/QuickToggleStrings.swift
        Sources/Breeze/Core/ScreenshotStrings.swift
        Sources/Breeze/Core/RecentCaptureStrings.swift
        Sources/Breeze/Core/RecorderStrings.swift
        Sources/Breeze/Core/RecorderShareStrings.swift
        Sources/Breeze/Core/CameraPreviewStrings.swift
        Sources/Breeze/Core/WallpaperStrings.swift
        Sources/Breeze/Services/Wallpaper/WallpaperSupport.swift
        Sources/Breeze/Core/ScratchpadStrings.swift
        Sources/Breeze/Core/FinderRenameStrings.swift
        Sources/Breeze/Core/CommandBarStrings.swift
        Sources/Breeze/Core/FeedbackStrings.swift
        Sources/Breeze/Core/RadialMenuStrings.swift
        Sources/Breeze/Core/MenuBarAppearanceStrings.swift
        Sources/Breeze/Core/AppAppearance.swift
        Sources/Breeze/Core/AppearanceStrings.swift
        Sources/Breeze/Core/GeneralSettingsStrings.swift
        Sources/Breeze/Core/SettingsPageStrings.swift
        Sources/Breeze/Core/BatteryTimeStrings.swift
        Sources/Breeze/Core/CPUCoreStrings.swift
        Sources/Breeze/Core/MonitorLayoutStrings.swift
        Sources/Breeze/Core/KeepAwakeStrings.swift
        Sources/Breeze/Core/BluetoothSleepStrings.swift
        Sources/Breeze/Core/PermissionGuideStrings.swift
        Sources/Breeze/Core/FanControlStrings.swift
        Sources/Breeze/Core/ConnectedDevicesStrings.swift
        Sources/Breeze/Services/FanControl/FanControlSupport.swift
        Sources/Breeze/Services/FanControl/FanControlResumeSupport.swift
        Sources/Breeze/Services/Snippets/TextSnippetSupport.swift
        Sources/Breeze/Services/RadialMenu/RadialMenuSupport.swift
        Sources/Breeze/Services/QuickTools/ScratchpadSupport.swift
        Sources/Breeze/Services/QuickTools/ScratchpadStore.swift
        Sources/Breeze/Services/KillProcess/KillProcessSupport.swift
        Sources/Breeze/Services/Recorder/RecorderSupport.swift
        Sources/Breeze/Services/Recorder/RecorderSampleTiming.swift
        Sources/Breeze/Services/Recorder/RecorderWriter.swift
        Sources/Breeze/Services/Recorder/RecorderCaptureEngine.swift
        Sources/Breeze/Core/RecorderExportStrings.swift
        Sources/Breeze/Services/Recorder/RecorderComposer.swift
        Sources/Breeze/Services/Recorder/RecorderComposerPlan.swift
        Sources/Breeze/Services/Recorder/RecorderCursorSprite.swift
        Sources/Breeze/Services/Recorder/RecorderTextRenderer.swift
        Sources/Breeze/Services/Recorder/RecorderImageRenderer.swift
        Sources/Breeze/Services/Recorder/RecorderExporter.swift
        Sources/Breeze/Services/Recorder/RecorderGIFClipboard.swift
        Sources/Breeze/Services/Recorder/RecorderComposition.swift
        Sources/Breeze/Services/Recorder/RecordingSharingSupport.swift
        Sources/Breeze/Services/PrivateFileStore.swift
        Sources/Breeze/Services/Recorder/RecorderTakeStore.swift
        Sources/Breeze/Services/Recorder/RecorderPresetImageStore.swift
        Sources/Breeze/Services/Recorder/RecorderMotion.swift
        Sources/Breeze/Services/Recorder/RecorderPointerTrack.swift
        Sources/Breeze/Services/Recorder/RecorderTypingTrack.swift
        Sources/Breeze/Services/Recorder/RecorderTimeline.swift
        Sources/Breeze/Services/Recorder/RecorderTextOverlay.swift
        Sources/Breeze/Services/Recorder/RecorderImageOverlay.swift
        Sources/Breeze/Services/Recorder/RecorderBlurRegion.swift
        Sources/Breeze/Services/Recorder/RecorderEditDocument.swift
        Sources/Breeze/Core/AppInfo.swift
        Sources/Breeze/Core/GlobalShortcut.swift
        Sources/Breeze/Core/SymbolicHotKeys.swift
        Sources/Breeze/Services/SystemShortcutTakeoverSupport.swift
        Sources/Breeze/Core/Localization.swift
        Sources/Breeze/Core/Localizations/Strings+*.swift
        Sources/Breeze/Core/FeatureStrings.swift
        Sources/Breeze/Core/KillProcessStrings.swift
        Sources/Breeze/Core/PortManagerStrings.swift
        Sources/Breeze/Core/WhatsAppDownloadStrings.swift
        Sources/Breeze/Core/WhatsAppOrganizerStrings.swift
        Sources/Breeze/Core/ReleaseNotes.swift
        Sources/Breeze/Core/URLCleaning.swift
        Sources/Breeze/Services/GeneralPasteboardAccess.swift
        Sources/Breeze/Services/Clipboard/ClipboardHistoryWrite.swift
        Sources/Breeze/Services/Audio/AirPlayRouteManager.swift
        Sources/Breeze/Services/Audio/MixerRoutingSupport.swift
        Sources/Breeze/Services/Audio/MusicLaunchSupport.swift
        Sources/Breeze/Services/Bluetooth/BluetoothSleepSupport.swift
        Sources/Breeze/UI/MenuPanel/MixerPercentNativeTextField.swift
        Sources/Breeze/UI/MenuPanel/MixerAppDragSource.swift
        Sources/Breeze/Services/Audio/BoostLimiter.swift
        Sources/Breeze/Services/Audio/MixerRender.swift
        Sources/Breeze/Services/Audio/PreciseVolumeRollerSupport.swift
        Sources/Breeze/Services/DockPreview/DockPreviewSupport.swift
        Sources/Breeze/Services/DockPreview/DockAutohideHold.swift
        Sources/Breeze/Services/SpacesOrder/SpacesOrderHold.swift
        Sources/Breeze/Services/Homebrew/HomebrewSupport.swift
        Sources/Breeze/Services/Homebrew/HomebrewEnvironment.swift
        Sources/Breeze/Services/AppUpdates/AppUpdatesSupport.swift
        Sources/Breeze/Services/AppUpdates/AppUpdateFeedSupport.swift
        Sources/Breeze/Core/AppUpdateStrings.swift
        Sources/Breeze/Core/DiskImageInstallerStrings.swift
        Sources/Breeze/Services/DiskImageInstaller/DiskImageInstallerSupport.swift
        Sources/Breeze/UI/NonModalAlert.swift
        Sources/Breeze/Services/Clipboard/ClipboardHistorySupport.swift
        Sources/Breeze/Core/ColorValue.swift
        Sources/Breeze/Services/Clipboard/ClipboardAutoClearSupport.swift
        Sources/Breeze/Services/AutoQuit/AutoQuitSupport.swift
        Sources/Breeze/Services/Shelf/ShelfSupport.swift
        Sources/Breeze/Services/Shelf/ShelfFilePromiseTransfer.swift
        Sources/Breeze/Core/ShelfPromiseDeliveryStrings.swift
        Sources/Breeze/Services/Finder/FinderRenameSupport.swift
        Sources/Breeze/Services/Update/UpdateInstallerSupport.swift
        Sources/Breeze/Services/Update/UpdateServiceSupport.swift
        Sources/Breeze/Services/InstalledApps.swift
        Sources/Breeze/Services/LaunchAtLoginSupport.swift
        Sources/Breeze/UI/Settings/SettingsSearchSupport.swift
        Sources/Breeze/UI/Settings/SettingsSidebarSupport.swift
        Sources/Breeze/UI/Settings/FeatureVisibilitySupport.swift
        Sources/Breeze/UI/Settings/SettingsWindow.swift
        Sources/Breeze/Core/SettingsNavigationStrings.swift
        Sources/Breeze/App/MenuBarSpacingSupport.swift
        Sources/Breeze/App/MenuBarAllowanceSupport.swift
        Sources/Breeze/App/ReopenRequestSupport.swift
        Sources/Breeze/App/StatusItemAnchorSupport.swift
        Sources/Breeze/Services/DockClick/DockClickSupport.swift
        Sources/Breeze/Services/Finder/CutPasteProgressSupport.swift
        Sources/Breeze/Services/Finder/CutPastePrivilegeSupport.swift
        Sources/Breeze/Services/Finder/FinderPasteImageSupport.swift
        Sources/Breeze/Services/MiddleClick/MiddleClickSupport.swift
        Sources/Breeze/Services/MouseNavigation/MouseNavigationSupport.swift
        Sources/Breeze/Services/MouseNavigation/MouseNavigationKeys.swift
        Sources/Breeze/Services/MouseButtons/MouseButtonShortcutSupport.swift
        Sources/Breeze/Services/MouseButtons/MouseSpacesGestureSupport.swift
        Sources/Breeze/Services/MouseClickDebounce/MouseClickDebounceSupport.swift
        Sources/Breeze/Services/MouseExceptions/MouseAppExceptionSupport.swift
        Sources/Breeze/Services/MouseExceptions/MouseAppExceptions.swift
        Sources/Breeze/Services/WindowServerSupport.swift
        Sources/Breeze/Services/WindowMaximizerSupport.swift
        Sources/Breeze/Core/MouseButtonStrings.swift
        Sources/Breeze/Core/MouseClickDebounceStrings.swift
        Sources/Breeze/Core/MouseExceptionStrings.swift
        Sources/Breeze/Core/ClipboardIgnoredAppsStrings.swift
        Sources/Breeze/Core/WindowLayoutIgnoredAppsStrings.swift
        Sources/Breeze/Services/WindowLayout/WindowLayoutIgnoredApps.swift
        Sources/Breeze/Core/WindowPreviewExclusionStrings.swift
        Sources/Breeze/Core/WindowMaximizerExclusionStrings.swift
        Sources/Breeze/Core/DiskExclusionStrings.swift
        Sources/Breeze/Core/SwitcherAppRulesStrings.swift
        Sources/Breeze/Services/QuickTools/QuickToolsSupport.swift
        Sources/Breeze/Services/CommandBar/CommandBarSupport.swift
        Sources/Breeze/Services/CommandBar/CommandBarPreferences.swift
        Sources/Breeze/Services/CommandBar/CommandBarMath.swift
        Sources/Breeze/Services/CommandBar/CommandBarUnits.swift
        Sources/Breeze/Services/CommandBar/CommandBarColors.swift
        Sources/Breeze/Services/CommandBar/CommandBarEmoji.swift
        Sources/Breeze/Services/CommandBar/CommandBarLinks.swift
        Sources/Breeze/Services/CommandBar/CommandBarDates.swift
        Sources/Breeze/Services/CommandBar/CommandBarRowShortcuts.swift
        Sources/Breeze/Services/CommandBar/CommandBarSystemSettingsSupport.swift
        Sources/Breeze/Services/CommandBar/CommandBarFileSearchSupport.swift
        Sources/Breeze/Services/CommandBar/CommandBarQueryMemory.swift
        Sources/Breeze/Services/SpotlightNamesSupport.swift
        Sources/Breeze/Services/QuickTools/MicMuteSupport.swift
        Sources/Breeze/Services/QuickTools/QuickTogglesSupport.swift
        Sources/Breeze/Services/QuickTools/ScreenshotCapturePolicy.swift
        Sources/Breeze/Services/QuickTools/ScreenshotSupport.swift
        Sources/Breeze/UI/Settings/ScreenCaptureToolPicker.swift
        Sources/Breeze/UI/Settings/MonitorToken.swift
        Sources/Breeze/Services/QuickTools/ScreenshotRenderer.swift
        Sources/Breeze/Services/QuickTools/RecentCaptureStore.swift
        Sources/Breeze/Services/QuickTools/ScreenshotSharingSupport.swift
        Sources/Breeze/Services/QuickTools/WindowActivationPolicy.swift
        Sources/Breeze/Services/KeyboardDebounce/KeyboardDebounceSupport.swift
        Sources/Breeze/Services/SuperKey/SuperKeySupport.swift
        Sources/Breeze/Services/SuperKey/SuperKeyMappingGuard.swift
        Sources/Breeze/Core/SuperKeyStrings.swift
        Sources/Breeze/Core/InputSourceSelection.swift
        Sources/Breeze/Services/SessionActivity.swift
        Sources/Breeze/Services/SessionActivitySupport.swift
        Sources/Breeze/Services/EventTimestamp.swift
        Sources/Breeze/Services/OwnKeyEvent.swift
        Sources/Breeze/Services/ScrollWheelSupport.swift
        Sources/Breeze/Services/HorizontalWheelScrolling.swift
        Sources/Breeze/Services/SmoothScrollSupport.swift
        Sources/Breeze/Services/MouseAcceleration/MouseAccelerationSupport.swift
        Sources/Breeze/Services/FocusFollowsMouse/FocusFollowsMouseSupport.swift
        Sources/Breeze/Services/AssistiveKeyboard.swift
        Sources/Breeze/Services/Switcher/SwitcherModels.swift
        Sources/Breeze/Services/Switcher/WindowServerCaptureQueue.swift
        Sources/Breeze/Services/Switcher/SwitcherSupport.swift
        Sources/Breeze/Services/Switcher/SpaceHopSupport.swift
        Sources/Breeze/Services/Switcher/WindowUseOrder.swift
        Sources/Breeze/Services/Metrics/MetricFormat.swift
        Sources/Breeze/Services/Metrics/VMStatisticsDecoder.swift
        Sources/Breeze/Services/KeepAwakeAutomationSupport.swift
        Sources/Breeze/Services/SudoersSupport.swift
        Sources/Breeze/Services/Metrics/BatteryTimeSupport.swift
        Sources/Breeze/Services/Metrics/BatteryPowerSupport.swift
        Sources/Breeze/Services/BoundedProcessRunner.swift
        Sources/Breeze/Services/DetachedProcess.swift
        Sources/Breeze/Services/ShellSupport.swift
        Sources/Breeze/Services/PortManager/PortManagerSupport.swift
        Sources/Breeze/Services/Metrics/NetworkProcessSupport.swift
        Sources/Breeze/Services/Metrics/NetworkSampler.swift
        Sources/Breeze/Services/Metrics/NetworkAddressService.swift
        Sources/Breeze/Services/Metrics/SpeedTest.swift
        Sources/Breeze/Services/Metrics/PeripheralBatterySampler.swift
        Sources/Breeze/Services/Metrics/PeripheralBatterySupport.swift
        Sources/Breeze/Services/Metrics/DiskSupport.swift
        Sources/Breeze/Services/Metrics/MonitorSamplingPolicy.swift
        Sources/Breeze/Services/Metrics/USBDeviceSampler.swift
        Sources/Breeze/Services/Metrics/CPUCoreSampler.swift
        Sources/Breeze/Services/Metrics/MaxCapacityProbe.swift
        Sources/Breeze/Services/Metrics/TemperatureSensorSelector.swift
        Sources/Breeze/Services/Metrics/SustainedAlertGate.swift
        Sources/Breeze/Services/WindowLayout/WindowLayoutSupport.swift
        Sources/Breeze/Services/WindowLayout/WindowGestureSupport.swift
        Sources/Breeze/Core/WindowDirectionalStrings.swift
        Sources/Breeze/Core/PointerDisplayStrings.swift
        Sources/Breeze/Core/GraphScaleStrings.swift
        Sources/Breeze/Core/NotchLowBatteryStrings.swift
        Sources/Breeze/Services/CleaningMode/CleaningUnlockCounter.swift
        Sources/Breeze/Services/CleaningMode/CleaningMouseReleaseGate.swift
        Sources/Breeze/Services/Display/ExtraBrightnessSupport.swift
        Sources/Breeze/Services/Display/BrightnessSupport.swift
        Sources/Breeze/Services/Display/LidDimmingSupport.swift
        Sources/Breeze/Services/Cleaner/CleanerSupport.swift
        Sources/Breeze/Services/Cleaner/CleanerPolicy.swift
        Sources/Breeze/Services/Cleaner/CleanerSchedule.swift
        Sources/Breeze/Services/Uninstall/UninstallerSupport.swift
        Sources/Breeze/Services/ManagedDownloads/WhatsAppDownloadSupport.swift
        Sources/Breeze/Core/SecureInputSupport.swift
        Tests/*.swift
        build/generated-tests/*.swift
    )
    TEST_OUTPUT_FILE_MAP="$TEST_OBJECT_DIR/output-file-map.json"
    write_swift_output_file_map "$TEST_OUTPUT_FILE_MAP" "$TEST_OBJECT_DIR" "${TEST_SOURCES[@]}"
    echo "▸ Building & running tests against $(basename "$SDK")…"
    swiftc -Onone -incremental -enable-batch-mode -j "$(sysctl -n hw.logicalcpu)" \
        -module-name BreezeTests -output-file-map "$TEST_OUTPUT_FILE_MAP" \
        -target "$NATIVE_TARGET" -sdk "$SDK" "${SDK_COMPAT_FLAGS[@]}" \
        "${VM_STATISTICS_COMPAT_FLAGS[@]}" "${TEST_SOURCES[@]}" -o build/metrics-tests
    test_status=0
    ./build/metrics-tests "${TEST_ARGS[@]}" || test_status=$?
    if (( ${#TEST_ARGS} == 0 )); then
        ./Tests/PreferenceCleanupTests.sh || test_status=1
        ./Tests/UninstallSpacesTests.sh || test_status=1
        ./Tests/DeveloperInstallIsolationTests.sh || test_status=1
    fi
    discard_test_preferences || test_status=1
    exit $test_status
fi

echo "▸ Compiling ($BUILD_CONFIGURATION) against $(basename "$SDK")…"
APP_SOURCES=(Sources/Breeze/**/*.swift)
if (( ! DEV )); then
    # A release starts from an empty build directory, so nothing an earlier
    # build left behind (an old icon catalog, a staged bundle) can reach it.
    # Only the compiler's incremental records stay: they rebuild whatever
    # changed since, and a fresh checkout has none.
    find build -mindepth 1 -maxdepth 1 ! -name objects -exec rm -rf {} + 2>/dev/null || true
fi
mkdir -p build
# Without -j the driver compiles one file at a time, and without batch mode
# each file's compiler parses the whole module again: a clean release took a
# quarter of an hour. Batches share that work and run on every core, and the
# optimization stays per file, as before.
# Built as a universal binary (arm64 + x86_64) so it runs on both Apple Silicon
# and Intel Macs. Each architecture compiles into its own object directory under
# build/arch/<arch>/; the app's per-file incremental output-file-map is not used
# on the universal path (each arch is a fresh, complete compile).
build_universal "build/$EXECUTABLE" \
    "${APP_OPTIMIZATION_FLAGS[@]}" -enable-batch-mode -j "$(sysctl -n hw.logicalcpu)" \
    "${VM_STATISTICS_COMPAT_FLAGS[@]}" "${HID_EVENT_SYSTEM_FLAGS[@]}" \
    "${BUILD_VARIANT_FLAGS[@]}" \
    "${APP_SOURCES[@]}"

echo "▸ Compiling protected fan helper…"
build_universal "build/$FAN_HELPER_ID" \
    -O "${BUILD_VARIANT_FLAGS[@]}" \
    Sources/Breeze/Services/FanControl/FanControlSupport.swift \
    Sources/Breeze/Services/FanControl/FanControlXPC.swift \
    Sources/Breeze/Services/SystemMonitor/SMCClient.swift \
    Sources/Breeze/Services/Metrics/TemperatureSensorSelector.swift \
    Sources/Breeze/Services/FanControl/FanControlHardware.swift \
    Sources/FanControlHelper/main.swift
"build/$FAN_HELPER_ID" --selftest

echo "▸ Compiling Now Playing adapter…"
build_universal "build/$NOW_PLAYING_ADAPTER" \
    -O -emit-library -module-name BreezeNowPlaying \
    Sources/NowPlayingAdapter/NowPlayingAdapter.swift \
    Sources/NowPlayingAdapter/NowPlayingQueue.swift \
    Sources/NowPlayingAdapter/NowPlayingSelection.swift \
    Sources/Breeze/Services/Notch/NotchPlaybackSource.swift \
    Sources/Breeze/Services/Notch/NotchPlaybackCommand.swift

echo "▸ Generating app icon…"
swift Tools/MakeIcon.swift build/AppIcon.iconset
xattr -c -r build/AppIcon.iconset build/AppIcon.icns build/MenuBarIcon.png build/MenuBarIcon@2x.png build/BrandMark.png 2>/dev/null || true
ACTOOL_BIN="$(xcrun --find actool 2>/dev/null || true)"
ICON_TMP="$(mktemp -d)"
ADAPTIVE_SKIP=""
if [[ -z "$ACTOOL_BIN" ]]; then
    ADAPTIVE_SKIP="actool not found (adaptive icons need Xcode 26+)"
else
    echo "▸ Compiling adaptive icon catalog…"
    # actool crashes on File Provider-synced paths, so compile a local copy.
    ditto "Resources/Brand/AppIcon.icon" "$ICON_TMP/AppIcon.icon"
    # Xcode 27 beta actool requires the --compile target directory to already exist.
    mkdir -p "$ICON_TMP/catalog"
    if "$ACTOOL_BIN" "$ICON_TMP/AppIcon.icon" \
            --compile "$ICON_TMP/catalog" \
            --app-icon AppIcon \
            --platform macosx \
            --target-device mac \
            --minimum-deployment-target 14.0 \
            --enable-on-demand-resources NO \
            --output-partial-info-plist "$ICON_TMP/partial-info.plist" \
            >"$ICON_TMP/actool.log" 2>&1 && [[ -s "$ICON_TMP/catalog/Assets.car" ]]; then
        mv "$ICON_TMP/catalog/Assets.car" build/Assets.car
    else
        ADAPTIVE_SKIP="actool could not compile the catalog"
    fi
fi
if [[ -n "$ADAPTIVE_SKIP" ]]; then
    cp "$ICON_TMP/actool.log" build/actool-failure.log 2>/dev/null || true
    echo "  adaptive icon skipped: $ADAPTIVE_SKIP (Dock falls back to AppIcon.icns)"
fi
echo "▸ Assembling and signing bundle…"
STAGE_TMP="$(mktemp -d)"
STAGE="$STAGE_TMP/$APP_NAME.app"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources" \
    "$STAGE/Contents/Library/LaunchDaemons" "$STAGE/Contents/Library/LaunchServices"
cp "build/$EXECUTABLE" "$STAGE/Contents/MacOS/$EXECUTABLE"
cp "build/$FAN_HELPER_ID" "$STAGE/Contents/Library/LaunchServices/$FAN_HELPER_ID"
mkdir -p "$STAGE/Contents/Frameworks"
cp "build/$NOW_PLAYING_ADAPTER" "$STAGE/Contents/Frameworks/$NOW_PLAYING_ADAPTER"
cp Resources/now-playing.pl "$STAGE/Contents/Resources/now-playing.pl"
cp Resources/agent-prices.json "$STAGE/Contents/Resources/agent-prices.json"
cp Resources/com.kevsketch.breeze.utils.fan-control.plist \
    "$STAGE/Contents/Library/LaunchDaemons/$FAN_HELPER_ID.plist"
cp Resources/Info.plist "$STAGE/Contents/Info.plist"
cp CHANGELOG.md "$STAGE/Contents/Resources/CHANGELOG.md"
for lproj in Resources/*.lproj(N); do
    cp -R "$lproj" "$STAGE/Contents/Resources/"
done
if (( DEV )); then
    # A distinct identity so the Developer build installs and runs next to the
    # official app, with its own permissions, preferences and login item.
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $APP_BUNDLE_ID" "$STAGE/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$STAGE/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $APP_NAME" "$STAGE/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $EXECUTABLE" "$STAGE/Contents/Info.plist"
    FAN_PLIST="$STAGE/Contents/Library/LaunchDaemons/$FAN_HELPER_ID.plist"
    /usr/libexec/PlistBuddy -c "Set :Label $FAN_HELPER_ID" "$FAN_PLIST"
    /usr/libexec/PlistBuddy -c "Set :BundleProgram Contents/Library/LaunchServices/$FAN_HELPER_ID" "$FAN_PLIST"
    /usr/libexec/PlistBuddy -c "Delete :MachServices:com.kevsketch.breeze.utils.fan-control" "$FAN_PLIST"
    /usr/libexec/PlistBuddy -c "Add :MachServices:$FAN_HELPER_ID bool true" "$FAN_PLIST"
    # Stamp the source commit + build time so the running dev app shows (in About)
    # exactly which code it was compiled from. Lets you verify it matches HEAD before
    # testing, instead of unknowingly running a stale build. Dev-only; never shipped.
    SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
    [[ -n "$(git status --porcelain 2>/dev/null)" ]] && SHA="$SHA-dirty"
    /usr/libexec/PlistBuddy -c "Add :BreezeBuildCommit string '$SHA · $(date '+%Y-%m-%d %H:%M')'" "$STAGE/Contents/Info.plist"
    echo "  stamped dev build: $SHA"
fi
FAN_HELPER_VERSION="$(
    export LC_ALL=C
    /usr/bin/shasum -a 256 \
        "$STAGE/Contents/Library/LaunchServices/$FAN_HELPER_ID" \
        "$STAGE/Contents/Library/LaunchDaemons/$FAN_HELPER_ID.plist" \
        | /usr/bin/awk '{print $1}' | /usr/bin/shasum -a 256 \
        | /usr/bin/awk '{print $1}'
)"
/usr/libexec/PlistBuddy -c "Add :BreezeFanControlHelperVersion string '$FAN_HELPER_VERSION'" \
    "$STAGE/Contents/Info.plist"
printf 'APPL????' > "$STAGE/Contents/PkgInfo"
cp build/AppIcon.icns "$STAGE/Contents/Resources/AppIcon.icns"
cp build/MenuBarIcon.png build/MenuBarIcon@2x.png build/BrandMark.png "$STAGE/Contents/Resources/"
if [[ -f build/Assets.car ]]; then
    cp build/Assets.car "$STAGE/Contents/Resources/Assets.car"
fi
if [[ -d Resources/Gifs ]]; then
    mkdir -p "$STAGE/Contents/Resources/Gifs"
    cp Resources/Gifs/*.gif "$STAGE/Contents/Resources/Gifs/"
fi
if ! cmp -s Resources/Gifs/highlights-notch.gif "$STAGE/Contents/Resources/Gifs/highlights-notch.gif"; then
    echo "Dynamic Island tour GIF is missing or differs from the bundled copy" >&2
    exit 1
fi
if [[ -d Resources/Images ]]; then
    mkdir -p "$STAGE/Contents/Resources/Images"
    cp Resources/Images/* "$STAGE/Contents/Resources/Images/"
fi
xattr -c -r "$STAGE" 2>/dev/null || true

# Signing, in order of preference:
#   1. Developer ID Application — the real, Apple-issued identity used for
#      notarized releases. Signed with the hardened runtime (required for
#      notarization), the app's entitlements and a secure timestamp. Gives a
#      stable, team-based designated requirement, so permissions persist across
#      updates AND Gatekeeper shows no "unverified developer" warning.
#   2. "Breeze Signing" — the legacy stable self-signed identity, kept
#      as a fallback so contributors without a Developer ID still get a constant
#      designated requirement across their local builds.
#   3. Ad-hoc — fresh clone with no identity at all.
DEVID="$(developer_id_identity)"
codesign_app() {
    local target="$1"
    if [[ -n "$DEVID" ]]; then
        codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
            --entitlements "$ENTITLEMENTS" --sign "$DEVID" "$target"
    elif legacy_identity_installed; then
        codesign --force --strip-disallowed-xattrs --sign "$LEGACY_IDENTITY" "$target"
    else
        codesign --force --strip-disallowed-xattrs --sign - "$target"
    fi
}

codesign_fan_helper() {
    local target="$1"
    if [[ -n "$DEVID" ]]; then
        codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
            --identifier "$FAN_HELPER_ID" --sign "$DEVID" "$target"
    elif legacy_identity_installed; then
        codesign --force --strip-disallowed-xattrs --identifier "$FAN_HELPER_ID" \
            --sign "$LEGACY_IDENTITY" "$target"
    else
        codesign --force --strip-disallowed-xattrs --identifier "$FAN_HELPER_ID" --sign - "$target"
    fi
}

codesign_now_playing_adapter() {
    local target="$1"
    if [[ -n "$DEVID" ]]; then
        codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
            --identifier "$NOW_PLAYING_ADAPTER_ID" --sign "$DEVID" "$target"
    elif legacy_identity_installed; then
        codesign --force --strip-disallowed-xattrs --identifier "$NOW_PLAYING_ADAPTER_ID" \
            --sign "$LEGACY_IDENTITY" "$target"
    else
        codesign --force --strip-disallowed-xattrs --identifier "$NOW_PLAYING_ADAPTER_ID" --sign - "$target"
    fi
}

sign_bundle() {
    local bundle="$1"
    local executable="$bundle/Contents/MacOS/$EXECUTABLE"
    local helper="$bundle/Contents/Library/LaunchServices/$FAN_HELPER_ID"
    local adapter="$bundle/Contents/Frameworks/$NOW_PLAYING_ADAPTER"

    if [[ -n "$DEVID" ]]; then
        echo "  signing with Developer ID (hardened runtime): $DEVID"
    elif legacy_identity_installed; then
        echo "  signing with legacy self-signed identity: $LEGACY_IDENTITY"
    else
        echo "  signing ad-hoc (no identity installed — run Tools/setup-signing.sh)"
    fi
    [[ -f "$helper" ]] && codesign_fan_helper "$helper"
    [[ -f "$adapter" ]] && codesign_now_playing_adapter "$adapter"
    codesign_app "$bundle"

    # If local filesystem metadata invalidates the first signature, sign once
    # more. The installed Developer bundle is signed again after the final copy.
    if ! codesign --verify --deep --strict "$bundle" >/dev/null 2>&1; then
        echo "  re-signing after filesystem metadata settled"
        xattr -c -r "$bundle" 2>/dev/null || true
        [[ -f "$helper" ]] && codesign_fan_helper "$helper"
        [[ -f "$adapter" ]] && codesign_now_playing_adapter "$adapter"
        codesign_app "$bundle"
    fi
    [[ -f "$executable" ]] && codesign --verify --strict "$executable"
    [[ -f "$helper" ]] && codesign --verify --strict "$helper"
    [[ -f "$adapter" ]] && codesign --verify --strict "$adapter"
    codesign --verify --deep --strict "$bundle"
}

sign_installed_bundle() {
    local bundle="$1"
    wait_for_install_metadata "$bundle"
    sign_bundle "$bundle"
}

sign_bundle "$STAGE"

process_is_running() {
    local proc="$1"
    if (( ${#proc} > 15 )); then
        pgrep -f "/Contents/MacOS/$proc" >/dev/null 2>&1
    else
        pgrep -x "$proc" >/dev/null 2>&1
    fi
}

stop_process() {
    local proc="$1"
    if (( ${#proc} > 15 )); then
        pkill -f "/Contents/MacOS/$proc" 2>/dev/null || true
    else
        pkill -x "$proc" 2>/dev/null || true
    fi
    for _ in {1..50}; do
        if ! process_is_running "$proc"; then
            return 0
        fi
        sleep 0.1
    done
    echo "✗ $proc is still running — quit it and retry" >&2
    return 1
}

wait_for_install_metadata() {
    local bundle="$1"
    local missing
    for _ in {1..50}; do
        missing=0
        while IFS= read -r file; do
            if ! xattr -p com.apple.provenance "$file" >/dev/null 2>&1; then
                missing=1
                break
            fi
        done < <(find "$bundle/Contents" -type f ! -path "*/_CodeSignature/*")
        if (( missing == 0 )); then
            return 0
        fi
        sleep 0.1
    done
}

# Installed development builds only need the copy in /Applications. Retaining
# another app in each checkout pollutes application search with stale builds.
if (( DEV )); then
    for old_bundle in "build/stage/$APP_NAME.app" "build/stage.noindex/$APP_NAME.app"; do
        if [[ -d "$old_bundle" ]]; then
            /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
                -u "$PWD/$old_bundle" >/dev/null 2>&1 || true
            rm -rf "$old_bundle"
        fi
    done
fi

if (( !DEV || !INSTALL )); then
    STAGE_DIRECTORY="build/stage"
    (( DEV )) && STAGE_DIRECTORY="build/stage.noindex"
    mkdir -p "$STAGE_DIRECTORY"
    BUILD_STAGE="$STAGE_DIRECTORY/$APP_NAME.app"
    rm -rf "$BUILD_STAGE"
    ditto --noextattr --noqtn "$STAGE" "$BUILD_STAGE"
    xattr -c -r "$BUILD_STAGE" 2>/dev/null || true
    if ! codesign --verify --deep --strict "$BUILD_STAGE" >/dev/null 2>&1; then
        if xattr -lr "$BUILD_STAGE" 2>/dev/null | grep -Eq 'com\.apple\.(FinderInfo|ResourceFork|provenance|fileprovider)'; then
            echo "  staging copy has local filesystem metadata; temp bundle was verified"
        else
            codesign --verify --deep --strict "$BUILD_STAGE"
        fi
    fi
    echo "✓ Bundle ready: $BUILD_STAGE"
fi

if (( INSTALL )); then
    echo "▸ Installing into /Applications…"
    stop_process "$EXECUTABLE"
    # Only an official install replaces the pre-rename official apps. The
    # Developer variant must coexist with them just as it does with Breeze.
    if (( ! DEV )); then
        for legacy in "Breeze:Breeze" "Breeze Utils:BreezeUtils"; do
            name="${legacy%%:*}"; proc="${legacy##*:}"
            if [[ -d "/Applications/$name.app" ]]; then
                stop_process "$proc"
                rm -rf "/Applications/$name.app"
                echo "  (legacy $name.app removed)"
            fi
        done
    fi
    INSTALL_DEST="/Applications/$APP_NAME.app"
    rm -rf "$INSTALL_DEST"
    ditto --noextattr --noqtn "$STAGE" "$INSTALL_DEST"
    sign_installed_bundle "$INSTALL_DEST"
    echo "✓ Installed: $INSTALL_DEST"
fi
