#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint
#
# Shared helper for the local Breeze signing keychain password.
#
# Replaces a hardcoded shared literal with a per-installation random password
# (persisted at $HOME/.breeze-signing.pass, mode 0600) so the keychain cannot
# be opened by anything that guesses the old shared string. This file is the
# single source of truth for both build.sh and Tools/setup-signing.sh; delete
# the persisted file to force a fresh keychain on the next setup-signing.sh
# run. The script remains idempotent: re-runs return the same password until
# the file is removed.

# Path to the persisted random password. Kept under $HOME (per-user) and 0600.
BREEZE_KC_PASS_FILE="${BREEZE_KC_PASS_FILE:-${HOME}/.breeze-signing.pass}"

# Echo the keychain password, generating + persisting a random one on first
# use. Writes a 24-byte hex string (no trailing newline) under umask 077 so the
# file is created 0600.
breeze_kc_pass() {
    if [[ -r "$BREEZE_KC_PASS_FILE" ]]; then
        cat "$BREEZE_KC_PASS_FILE"
        return
    fi
    local pass
    if ! pass="$(openssl rand -hex 24 2>/dev/null)" || [[ -z "$pass" ]]; then
        print -u2 -- "breeze_kc_pass: openssl rand failed; cannot create random keychain password"
        return 1
    fi
    umask 077
    if ! print -rn -- "$pass" > "$BREEZE_KC_PASS_FILE"; then
        print -u2 -- "breeze_kc_pass: cannot write $BREEZE_KC_PASS_FILE"
        return 1
    fi
    print -rn -- "$pass"
}
