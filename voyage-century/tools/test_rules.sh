#!/usr/bin/env bash
# Baut und testet die Kampfregeln (unreal/.../Source/VCRules) ohne Unreal Engine.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/unreal/VoyageCentury/Source/VCRules/Tests"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT
cmake -S "$SRC" -B "$BUILD" -DCMAKE_BUILD_TYPE=Debug >/dev/null
cmake --build "$BUILD" -j >/dev/null
"$BUILD/vc_rules_tests"
