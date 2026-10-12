// swift-tools-version:5.9
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import PackageDescription

let package = Package(
    name: "Breeze",
    // Floor is macOS 13.0 (Ventura). The macOS-14 APIs used across the codebase
    // (onChange(of:initial:_:), symbolEffect, SCScreenshotManager, CADisplayLink,
    // keyframeAnimator, …) are covered by Ventura fallbacks in
    // Sources/Breeze/Support/BackDeployCompat.swift, CompatDisplayLink.swift and
    // ScreenCaptureCompat.swift. See PORTING-macos-legacy.md.
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
            name: "Breeze",
            dependencies: ["VMStatisticsCompat", "HIDEventSystem"],
            path: "Sources/Breeze"
        )
    ]
)
