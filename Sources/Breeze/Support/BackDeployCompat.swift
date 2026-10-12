// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

// macOS 13 back-deployment shims.
//
// The app targets macOS 14 and uses several macOS-14-only SwiftUI APIs
// unguarded. This file provides pre-14 equivalents so the same source builds and
// runs on macOS 13. Call sites were renamed mechanically (e.g. `.onChange(of:)`
// -> `.onChangeCompat(of:)`); the shim supplies the behaviour on both OSes.

import SwiftUI

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
