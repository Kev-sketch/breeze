// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

// macOS 13 back-deployment shim for `CADisplayLink`.
//
// macOS 14 moved the per-frame callback onto `NSView.displayLink(target:selector:)`
// returning a `CADisplayLink`. macOS 13 has no `CADisplayLink`; this wraps a
// `CVDisplayLink` behind the same small API surface the app uses
// (`preferredFrameRateRange`, `add(to:forMode:)`, `invalidate()`,
// `timestamp`, `targetTimestamp`, `duration`).

import AppKit
import CoreVideo
import QuartzCore

final class CompatDisplayLink: NSObject {
    private weak var view: NSView?
    private weak var screen: NSScreen?
    private weak var target: AnyObject?
    private let selector: Selector

    private var caLink: AnyObject?          // CADisplayLink on macOS 14+
    private var cvLink: CVDisplayLink?      // CVDisplayLink on macOS 13
    private var running = false

    private(set) var timestamp: CFTimeInterval = 0
    private(set) var duration: CFTimeInterval = 1.0 / 60.0
    var targetTimestamp: CFTimeInterval { timestamp + duration }

    private var rate = CAFrameRateRange(minimum: 15, maximum: 60, preferred: 60)
    var preferredFrameRateRange: CAFrameRateRange {
        get { rate }
        set { rate = newValue }
    }

    init(view: NSView, target: AnyObject, selector: Selector) {
        self.view = view
        self.target = target
        self.selector = selector
    }

    init(screen: NSScreen, target: AnyObject, selector: Selector) {
        self.screen = screen
        self.target = target
        self.selector = selector
    }

    func add(to runLoop: RunLoop, forMode mode: RunLoop.Mode) {
        guard !running else { return }
        running = true

        if #available(macOS 14.0, *) {
            let ca: CADisplayLink?
            if let view {
                ca = view.displayLink(target: self, selector: #selector(caFire(_:)))
            } else if let screen {
                ca = screen.displayLink(target: self, selector: #selector(caFire(_:)))
            } else {
                ca = nil
            }
            if let ca {
                ca.preferredFrameRateRange = rate
                ca.add(to: runLoop, forMode: mode)
                caLink = ca
                return
            }
        }

        var link: CVDisplayLink?
        if let screen,
           let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            CVDisplayLinkCreateWithCGDisplay(CGDirectDisplayID(number.uint32Value), &link)
        } else {
            CVDisplayLinkCreateWithActiveCGDisplays(&link)
        }
        guard let link else { return }
        CVDisplayLinkSetOutputHandler(link) { [weak self] _, _, _, _, _ in
            DispatchQueue.main.async { self?.cvFire() }
            return kCVReturnSuccess
        }
        CVDisplayLinkStart(link)
        cvLink = link
    }

    func invalidate() {
        running = false
        if #available(macOS 14.0, *) {
            (caLink as? CADisplayLink)?.invalidate()
        }
        caLink = nil
        if let cvLink { CVDisplayLinkStop(cvLink) }
        cvLink = nil
    }

    @available(macOS 14.0, *)
    @objc private func caFire(_ link: CADisplayLink) {
        timestamp = link.timestamp
        duration = link.duration
        _ = target?.perform(selector, with: self)
    }

    private func cvFire() {
        let now = CACurrentMediaTime()
        duration = max(now - timestamp, 1.0 / 120.0)
        timestamp = now
        _ = target?.perform(selector, with: self)
    }
}

extension NSView {
    /// `NSView.displayLink(target:selector:)` on macOS 14; a `CVDisplayLink`-backed
    /// equivalent on macOS 13.
    func compatDisplayLink(target: AnyObject, selector: Selector) -> CompatDisplayLink {
        CompatDisplayLink(view: self, target: target, selector: selector)
    }
}

extension NSScreen {
    /// `NSScreen.displayLink(target:selector:)` on macOS 14; a `CVDisplayLink`-backed
    /// equivalent on macOS 13.
    func compatDisplayLink(target: AnyObject, selector: Selector) -> CompatDisplayLink {
        CompatDisplayLink(screen: self, target: target, selector: selector)
    }
}
