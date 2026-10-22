#!/bin/bash
set -euo pipefail
TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$TOOLS/../../.." && pwd)"
OUT="$ROOT/build-local/freetype-ios"
mkdir -p "$OUT"
FRAMEWORK="$OUT/freetype2.framework/freetype2"
STATIC="$OUT/libfreetype2.a"
VENDORED="$ROOT/Pods/freetype2/freetype/libfreetype.a"
if [[ ! -f "$VENDORED" && ! -f "$FRAMEWORK" && ! -f "$STATIC" ]]; then
    xcodebuild -project "$ROOT/Pods/Pods.xcodeproj" -target freetype2 \
        -configuration Release -sdk iphoneos -arch arm64 \
        IPHONEOS_DEPLOYMENT_TARGET=12.0 CODE_SIGNING_ALLOWED=NO \
        CONFIGURATION_BUILD_DIR="$OUT" build > "$ROOT/build-local/freetype-build.log" 2>&1 || {
        tail -80 "$ROOT/build-local/freetype-build.log" >&2
        exit 1
    }
fi
if [[ -f "$VENDORED" ]]; then
    BINARY="$VENDORED"
    ln -sfn "$VENDORED" "$OUT/libfreetype.a"
elif [[ -f "$FRAMEWORK" ]]; then
    BINARY="$FRAMEWORK"
    ln -sfn "$FRAMEWORK" "$OUT/libfreetype.dylib"
elif [[ -f "$STATIC" ]]; then
    BINARY="$STATIC"
    ln -sfn "$STATIC" "$OUT/libfreetype.a"
else
    echo 'The freetype2 CocoaPod produced no supported iOS library' >&2
    exit 1
fi
ARCHS="$(xcrun lipo -archs "$BINARY")"
[[ " $ARCHS " == *" arm64 "* ]] || {
    echo "FreeType has wrong architecture: $ARCHS" >&2
    exit 1
}
printf '%s\n' "$OUT"
