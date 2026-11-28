#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
check_dir="$(mktemp -d "${TMPDIR:-/tmp}/redbit-recovery.XXXXXX")"
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 \
  AppleApp/Sources/PlaybackSession/PlaybackRecoveryPolicy.swift \
  AppleApp/Sources/PlaybackSession/RedBitAutomationStatus.swift \
  AppleApp/Sources/PlaybackSession/RedBitToolContract.swift \
  scripts/stream-recovery-verify/check.swift -o "$check_dir/check"
"$check_dir/check"
