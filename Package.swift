// swift-tools-version:5.9
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import PackageDescription

let package = Package(
    name: "Vorssaint",
    // Lowered from .v14 to .v13 by the legacy-OS port: SMAppService (used
    // unguarded for login-item / fan-control daemon registration) is the
    // youngest API the app depends on, and it requires macOS 13.0. See
    // PORTING-macos-legacy.md for the full version-floor analysis.
    platforms: [.macOS(.v13)],
    targets: [
        .systemLibrary(
            name: "HIDEventSystem",
            path: "Sources/HIDEventSystem"
        ),
        .systemLibrary(
            name: "VMStatisticsCompat",
            path: "Sources/VMStatisticsCompat"
        ),
        .executableTarget(
            name: "Vorssaint",
            dependencies: ["VMStatisticsCompat", "HIDEventSystem"],
            path: "Sources/Vorssaint"
        )
    ]
)
