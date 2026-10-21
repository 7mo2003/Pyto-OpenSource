#!/bin/bash
# Build helper for the original Pyto Xcode workspace. No signing credentials used.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
MODE="${1:-check}"
case "$MODE" in check|prepare|build) ;; *) echo "Usage: $0 [check|prepare|build]" >&2; exit 64 ;; esac

if [[ "$(uname -s)" != Darwin ]]; then
    echo "BLOCKED: This is the original Xcode/CocoaPods project, not a SwiftPM app."
    echo "A Mac with full Xcode is required. Linux Swift/xtool is not a substitute for this workspace."
    exit 2
fi
for tool in xcodebuild xcrun python3.10 brew pod git curl unzip; do
    command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool" >&2; exit 2; }
done
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-path
python3.10 --version
[[ -f Pyto.xcworkspace/contents.xcworkspacedata && -f Pyto.xcodeproj/project.pbxproj ]] || { echo "Incomplete source checkout" >&2; exit 2; }
if [[ "$MODE" == check ]]; then
    echo "Host prerequisites found. This does NOT establish that dependencies or the app compile."
    exit 0
fi
if [[ "$MODE" == prepare ]]; then
    [[ -d .git ]] || { echo "Use the Git checkout so pinned submodules can be restored." >&2; exit 2; }
    git submodule sync --recursive
    git submodule update --init --recursive
    python3.10 -m venv .venv-build
    source .venv-build/bin/activate
    python3 -m pip install --upgrade pip
    # The upstream script performs network downloads and dependency compilation.
    # It remains historical upstream code; review errors rather than treating exit 0 as a successful app build.
    bash ./setup.sh 2>&1 | tee setup-build.log
    exit 0
fi
[[ -f Pods/Manifest.lock ]] || { echo "Run '$0 prepare' first. CocoaPods dependencies are absent." >&2; exit 2; }
OUT="$ROOT/build-local"
mkdir -p "$OUT"
xcodebuild -workspace Pyto.xcworkspace -scheme Pyto -configuration Release \
    -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath "$OUT/DerivedData" \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) PYTO_OPEN_SOURCE' \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= build \
    2>&1 | tee "$OUT/xcodebuild.log"
APP="$OUT/DerivedData/Build/Products/Release-iphoneos/Pyto.app"
[[ -f "$APP/Info.plist" ]] || { echo "Pyto.app was not produced." >&2; exit 1; }
STAGE="$(mktemp -d "$OUT/package.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/Payload"
ditto "$APP" "$STAGE/Payload/Pyto.app"
(cd "$STAGE" && /usr/bin/zip -q -r -y "$OUT/Pyto-source-build-unsigned.ipa" Payload)
echo "Created: $OUT/Pyto-source-build-unsigned.ipa"
echo "Unsigned: this is not installable on a normal iPhone until properly signed and provisioned."
echo "A successful build alone does not establish runtime equivalence with the supplied IPA."
