#!/bin/bash
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"
source environment.sh

# Installing host CFFI registers its setuptools cffi_modules build hook.
python3 -m pip install 'cffi==1.15.1' setuptools_rust
brew install openssl
if [[ -f "$HOME/.cargo/env" ]]; then
    source "$HOME/.cargo/env"
fi
[[ -x "$HOME/.cargo/bin/cargo" ]] || { echo 'Rust/Cargo is required' >&2; exit 2; }
export PATH="$(pwd):$PATH"
rustup target add aarch64-apple-ios
# cargo-lipo is not used: this script builds only arm64 and extracts its archive.

export CFLAGS="$CFLAGS -I'$(pwd)' -I'$(pwd)'/../../../python3_ios -I'$(pwd)'/../../../OpenSSL"
export LDFLAGS="$LDFLAGS -L'$(pwd)'/../../../python3_ios/Python3_ios -lOpenSSL"
export PYO3_CROSS_LIB_DIR="$(cd ../../../python3_ios/Python3_ios && pwd)"
export PYO3_CROSS_PYTHON_VERSION=3.10
export PYO3_CROSS=1

cd ../cryptography
cp ../tools/cryptography-setup.py setup.py
python3 setup.py bdist
shopt -s nullglob
bindings=(build/lib*/cryptography/hazmat/bindings)
[[ ${#bindings[@]} -eq 1 ]] || { echo 'Expected exactly one cryptography build output' >&2; exit 1; }
BINDINGS="$(cd "${bindings[0]}" && pwd)"
openssl_modules=("$BINDINGS"/_openssl*.so)
[[ ${#openssl_modules[@]} -ge 1 ]] || { echo 'CFFI OpenSSL extension was not built' >&2; exit 1; }
cp ../tools/Cargo.toml src/rust/Cargo.toml
pushd src/rust
cargo build --target aarch64-apple-ios
mkdir -p objects
pushd objects
python3 ../../../../tools/extract_objects.py ../target/aarch64-apple-ios/debug/libcryptography_rust.a
xcrun --sdk iphoneos clang -shared -arch arm64 -undefined dynamic_lookup -o _rust.abi3.so ./*.o
mv _rust.abi3.so "$BINDINGS/"
popd
rm -rf objects
popd
python3 ../tools/make_frameworks.py cryptography Cryptography
../tools/copy-scripts.sh build/lib*/cryptography ../../../site-packages/cryptography
