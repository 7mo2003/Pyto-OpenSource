#!/bin/bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
FREETYPE_LIBDIR="$(bash ensure-ios-freetype.sh)"

pushd ../../../

xcodebuild ARCHS=arm64 ONLY_ACTIVE_ARCH=NO -scheme libpng -sdk iphoneos build SYMROOT=Extensions/Dependencies/tools/build_pillow
xcodebuild ARCHS=arm64 ONLY_ACTIVE_ARCH=NO -scheme libjpeg -sdk iphoneos build SYMROOT=Extensions/Dependencies/tools/build_pillow

popd

pushd build_pillow/*

mv libjpeg.framework/libjpeg ../../libjpeg.dylib
mv libpng.framework/libpng ../../libpng.dylib

popd

source environment.sh

SDKROOT="$(xcrun --sdk iphoneos --show-sdk-path)"
ZLIB_SDK_INCLUDE="$SDKROOT/usr/include"
ZLIB_SDK_LIBRARY="$SDKROOT/usr/lib/libz.tbd"
[[ -f "$ZLIB_SDK_INCLUDE/zlib.h" ]] || {
    echo "The iOS SDK is missing zlib.h: $ZLIB_SDK_INCLUDE/zlib.h" >&2
    exit 1
}
[[ -f "$ZLIB_SDK_LIBRARY" ]] || {
    echo "The iOS SDK is missing libz.tbd: $ZLIB_SDK_LIBRARY" >&2
    exit 1
}

# The pinned Pillow setup.py asks the compiler for libz.dylib when ZLIB_ROOT is
# set. Legacy setuptools does not reliably treat the SDK's libz.tbd as a
# candidate, so provide that SDK file under the expected name in a temporary
# root. No host/Homebrew zlib path is added or searched.
ZLIB_ROOT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pyto-pillow-zlib.XXXXXX")"
trap 'rm -rf "$ZLIB_ROOT_DIR"' EXIT
mkdir -p "$ZLIB_ROOT_DIR/lib"
ln -s "$ZLIB_SDK_INCLUDE" "$ZLIB_ROOT_DIR/include"
ln -s "$ZLIB_SDK_LIBRARY" "$ZLIB_ROOT_DIR/lib/libz.dylib"
export ZLIB_ROOT="$ZLIB_ROOT_DIR"
export CFLAGS="${CFLAGS:-} -arch arm64 -isysroot $SDKROOT -I$ZLIB_SDK_INCLUDE -I../../../libjpeg -I../../../libpng -I../../../freetype2-ios/include -I../../../Pods/freetype2/freetype/Classes"
export CPPFLAGS="${CPPFLAGS:-} -arch arm64 -isysroot $SDKROOT -I$ZLIB_SDK_INCLUDE"
export LDFLAGS="${LDFLAGS:-} -arch arm64 -isysroot $SDKROOT -L$ZLIB_ROOT_DIR/lib -L$FREETYPE_LIBDIR -L../tools"

cd ../pillow
python3 setup.py build_ext --disable-tiff --disable-jpeg200 --disable-lcms --disable-imagequant --disable-xcb --disable-platform-guessing --enable-jpeg --enable-zlib --enable-freetype
python3 setup.py egg_info
cp -r src/PIL/* build/lib*/PIL/
python3 ../tools/make_frameworks.py Pillow PIL
rm -rf ../../../site-packages/PIL
cp -r build/lib*/* ../../../site-packages/
find ../../../site-packages/ -name "*.so" -delete

cd ../tools

rm -rf build_pillow
rm -f libjpeg.dylib
rm -f libpng.dylib
