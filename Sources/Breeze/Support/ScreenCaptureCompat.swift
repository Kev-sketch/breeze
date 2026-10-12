// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

// macOS 13 back-deployment shim for one-shot screen capture.
//
// macOS 14 added `SCScreenshotManager.captureImage(contentFilter:configuration:)`.
// macOS 13 ships ScreenCaptureKit but not `SCScreenshotManager`, so this falls
// back to the CoreGraphics window/display capture — deprecated on macOS 14 but
// still functional on macOS 13.

import ScreenCaptureKit
import CoreGraphics

enum ScreenCaptureCompat {
    /// One-shot capture. Uses `SCScreenshotManager` on macOS 14+, and the
    /// CoreGraphics capture on macOS 13. Pass the display or window the filter
    /// was built from; the macOS 13 path needs it because `SCContentFilter` does
    /// not expose it.
    static func captureImage(filter: SCContentFilter,
                             displayID: CGDirectDisplayID?,
                             windowID: CGWindowID?,
                             configuration: SCStreamConfiguration) async -> CGImage? {
        if #available(macOS 14.0, *) {
            return try? await SCScreenshotManager.captureImage(contentFilter: filter,
                                                               configuration: configuration)
        }
        if let windowID {
            return CGWindowListCreateImage(.null, .optionIncludingWindow, windowID,
                                           [.boundsIgnoreFraming, .bestResolution])
        }
        if let displayID {
            return CGDisplayCreateImage(displayID)
        }
        return nil
    }
}
