#!/bin/bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

python3 -m pip install 'Cython==0.29.37'
source environment.sh

SDKROOT="$(xcrun --sdk iphoneos --show-sdk-path)"
CC="$(xcrun --sdk iphoneos -f clang)"
AR="$(xcrun --sdk iphoneos -f ar)"
RANLIB="$(xcrun --sdk iphoneos -f ranlib)"
work="$(mktemp -d "${TMPDIR:-/tmp}/pyto-libyaml.XXXXXX")"
trap 'rm -rf "$work"' EXIT
curl -fsSL --retry 2 https://pyyaml.org/download/libyaml/yaml-0.2.5.tar.gz | tar -xz -C "$work"
cd "$work/yaml-0.2.5"
mkdir -p ios-objects
for src in src/api.c src/dumper.c src/emitter.c src/loader.c src/parser.c src/reader.c src/scanner.c src/writer.c; do
  "$CC" -arch arm64 -isysroot "$SDKROOT" -miphoneos-version-min=12.1 -fPIC \
    -DYAML_VERSION_MAJOR=0 -DYAML_VERSION_MINOR=2 -DYAML_VERSION_PATCH=5 \
    '-DYAML_VERSION_STRING="0.2.5"' \
    -Iinclude -Isrc -c "$src" -o "ios-objects/$(basename "${src%.c}").o"
done
"$AR" rcs libyaml.a ios-objects/*.o
"$RANLIB" libyaml.a
yaml_root="$PWD"

cd -
cd ../pyyaml
export CFLAGS="${CFLAGS:-} -arch arm64 -isysroot $SDKROOT -I$yaml_root/include"
export LDFLAGS="${LDFLAGS:-} -arch arm64 -isysroot $SDKROOT -L$yaml_root"
python3 setup.py --with-libyaml bdist
python3 ../tools/make_frameworks.py pyyaml PyYaml
rm -rf ../../../site-packages/yaml
rm -rf ../../../site-packages/_yaml
cp -r build/lib*/yaml ../../../site-packages
cp -r build/lib*/_yaml ../../../site-packages
