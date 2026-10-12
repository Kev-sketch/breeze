// swift-tools-version:5.9
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import PackageDescription

let package = Package(
    name: "Breeze",
    // Floor is macOS 14.0 (unchanged from upstream). A CI build at 13.0 failed
    // with 607 availability errors: the code uses macOS-14 APIs unguarded
    // (onChange(of:initial:_:), symbolEffect, SCScreenshotManager, CADisplayLink,
    // keyframeAnimator, …) across 85 files. See PORTING-macos-legacy.md.
    platforms: [.macOS(.v14)],
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
            name: "Breeze",
            dependencies: ["VMStatisticsCompat", "HIDEventSystem"],
            path: "Sources/Breeze"
        )
    ]
)
