// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

// macOS 13 back-deployment shims.
//
// The app targets macOS 14 and uses several macOS-14-only SwiftUI APIs
// unguarded. This file provides pre-14 equivalents (or graceful no-ops) so the
// same source builds and runs on macOS 13. Call sites were renamed mechanically
// (e.g. `.onChange(of:)` -> `.onChangeCompat(of:)`); the shim supplies the
// behaviour on both OSes.

import SwiftUI
import AppKit
import EventKit

// MARK: - onChange(of:initial:_:)  (macOS 14)

/// Back-deploys `onChange(of:initial:_:)` (macOS 14+) to macOS 13.
///
/// The 14 API gives the closure both the old and new value (or nothing). On 13
/// only `onChange(of:perform:)` exists, which passes the new value alone, so this
/// modifier tracks the previous value itself to keep the two-argument closures
/// working. `initial` is honoured with an `onAppear` call, matching the 14
/// semantics.
struct OnChangeCompatModifier<V: Equatable>: ViewModifier {
    let value: V
    let initial: Bool
    let action: (V, V) -> Void
    @State private var previous: V?

    func body(content: Content) -> some View {
        content
            .onAppear {
                if initial { action(value, value) }
                previous = value
            }
            .onChange(of: value) { newValue in
                let old = previous ?? newValue
                action(old, newValue)
                previous = newValue
            }
    }
}

extension View {
    /// Two-argument form: `onChange(of:initial:_:) { old, new in … }`.
    func onChangeCompat<V: Equatable>(of value: V, initial: Bool = false,
                                      _ action: @escaping (V, V) -> Void) -> some View {
        modifier(OnChangeCompatModifier(value: value, initial: initial, action: action))
    }

    /// Zero-argument form: `onChange(of:initial:_:) { … }`.
    func onChangeCompat<V: Equatable>(of value: V, initial: Bool = false,
                                      _ action: @escaping () -> Void) -> some View {
        modifier(OnChangeCompatModifier(value: value, initial: initial,
                                        action: { _, _ in action() }))
    }
}

// MARK: - contentTransition(.symbolEffect(.replace))  (macOS 14)

extension View {
    /// `.contentTransitionSymbolReplaceCompat()` needs macOS 14; fall back to
    /// a cross-fade on macOS 13.
    @ViewBuilder
    func contentTransitionSymbolReplaceCompat() -> some View {
        if #available(macOS 14.0, *) {
            contentTransition(.symbolEffect(.replace))
        } else {
            contentTransition(.opacity)
        }
    }
}

// MARK: - symbolEffect  (macOS 14)

extension View {
    @ViewBuilder
    func symbolBounceCompat<V: Equatable>(value: V) -> some View {
        if #available(macOS 14.0, *) {
            symbolEffect(.bounce, value: value)
        } else {
            self
        }
    }

    @ViewBuilder
    func symbolBounceCompat<V: Equatable>(speed: Double, value: V) -> some View {
        if #available(macOS 14.0, *) {
            symbolEffect(.bounce, options: .speed(speed), value: value)
        } else {
            self
        }
    }

    @ViewBuilder
    func symbolVariableColorCompat(reversing: Bool, isActive: Bool) -> some View {
        if #available(macOS 14.0, *) {
            if reversing {
                symbolEffect(.variableColor.iterative.reversing, options: .repeating, isActive: isActive)
            } else {
                symbolEffect(.variableColor.iterative, options: .repeating, isActive: isActive)
            }
        } else {
            self
        }
    }
}

// MARK: - onKeyPress(_:action:)  (macOS 14)

extension View {
    /// Keyboard stepping is unavailable before macOS 14; the view still renders,
    /// it just does not react to the key.
    @ViewBuilder
    func onKeyPressCompat(_ key: KeyEquivalent, _ action: @escaping () -> Void) -> some View {
        if #available(macOS 14.0, *) {
            onKeyPress(key) { action(); return .handled }
        } else {
            self
        }
    }
}

// MARK: - focusable(interactions:) / focusEffectDisabled  (macOS 14)

extension View {
    @ViewBuilder
    func focusableEditCompat() -> some View {
        if #available(macOS 14.0, *) {
            focusable(interactions: .edit)
        } else {
            focusable()
        }
    }

    @ViewBuilder
    func focusEffectDisabledCompat() -> some View {
        if #available(macOS 14.0, *) {
            focusEffectDisabled()
        } else {
            self
        }
    }
}

// MARK: - NSRunningApplication.activateCompat(from:options:)  (macOS 14)

extension NSRunningApplication {
    /// macOS 14 added cooperative `activate(from:options:)`; macOS 13 only has
    /// the older `activate(ignoringOtherApps:)`.
    @discardableResult
    func activateCompat(from source: NSRunningApplication,
                        options: NSApplication.ActivationOptions = []) -> Bool {
        if #available(macOS 14.0, *) {
            return activate(from: source, options: options)
        }
        activate(ignoringOtherApps: true)
        return true
    }
}

// MARK: - EventKit authorization  (macOS 14)

extension EKAuthorizationStatus {
    /// macOS 14 split `.authorized` into `.fullAccess` / `.writeOnly`.
    var compatFullAccess: Bool {
        if #available(macOS 14.0, *) { return self == .fullAccess }
        return self == .authorized
    }

    var compatWriteOnly: Bool {
        if #available(macOS 14.0, *) { return self == .writeOnly }
        return false
    }

    /// Statuses that mean "the user has answered": granted, denied, restricted.
    static var compatSettledValues: [EKAuthorizationStatus] {
        if #available(macOS 14.0, *) { return [.fullAccess, .denied, .restricted] }
        return [.authorized, .denied, .restricted]
    }
}

// MARK: - ContentUnavailableView  (macOS 14)

/// Stand-in for `ContentUnavailableView` on macOS 13.
struct ContentUnavailableCompat: View {
    let title: String
    let systemImage: String
    var message: String = ""

    var body: some View {
        if #available(macOS 14.0, *) {
            ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
        } else {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.secondary)
                Text(title).font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
