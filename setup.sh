#!/bin/bash

# Do not enable pipefail: upstream uses `yes | cp`, where yes exits via SIGPIPE.
set -e

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Pyto's original Xcode project requires macOS with full Xcode; xtool cannot build this workspace." >&2
    exit 2
fi
for tool in xcodebuild xcrun brew pod python3.10; do
    command -v "$tool" >/dev/null 2>&1 || { echo "Missing required tool: $tool" >&2; exit 2; }
done
xcrun --sdk iphoneos --show-sdk-path >/dev/null || exit 2

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
cd "$DIR"

# Keep nested pip installs from silently upgrading the historical toolchain.
export PIP_CONSTRAINT="$DIR/build-constraints.txt"

# Restore pinned source dependencies before any dependency-specific directory work.
git submodule update --init --recursive
# Treat HTTP errors as download failures instead of unpacking error pages.
curl() { command curl --fail --show-error "$@"; }

python3 -m pip install 'setuptools<60' 'Cython<3'
python3 -m pip install 'numpy<1.24'
python3 -m pip install jinja2
python3 -m pip install wheel
python3 -m pip install 'sphinx<6' 'sphinx-rtd-theme<2' Pillow
python3 -m pip install pbxproj
brew install zlib

# Python

curl -L https://github.com/ColdGrub1384/Python-Apple-support/releases/download/3.10/Python-3.10-iOS-support.b1.tar.gz -o Python-3.10-iOS-support.b1.tar.gz
mkdir -p python-apple-support
cd python-apple-support

tar -xzvf ../Python-3.10-iOS-support.b1.tar.gz || exit 1
rm ../Python-3.10-iOS-support.b1.tar.gz

cp OpenSSL/libOpenSSL.a ../
cp OpenSSL/libOpenSSL.a ../python3_ios/Python3_ios/libOpenSSL.a
cp libFFI/libFFI.a ../python3_ios/Python3_ios/
cp BZip2/libbzip2.a ../python3_ios/Python3_ios/libbz2.a
cp XZ/libxz.a ../python3_ios/Python3_ios/liblzma.a
cp Python/libPython.a ../python3_ios/Python3_ios/libPython3.10.a
mkdir -p ../site-packages/python3.10
cp -R Python/Resources/lib/python3.10/. ../site-packages/python3.10/

cd ../
rm -rf python-apple-support

# ios_system

pushd Extensions/Dependencies/ios_system

curl -L -O https://github.com/holzschu/ios_system/releases/download/v3.0.0/awk.xcframework.zip
curl -L -O https://github.com/holzschu/ios_system/releases/download/v3.0.0/curl_ios.xcframework.zip
curl -L -O https://github.com/holzschu/ios_system/releases/download/v3.0.0/files.xcframework.zip
curl -L -O https://github.com/holzschu/ios_system/releases/download/v3.0.0/shell.xcframework.zip
curl -L -O https://github.com/holzschu/network_ios/releases/download/v0.2/network_ios.xcframework.zip
curl -L -O https://github.com/holzschu/ios_system/releases/download/v3.0.0/tar.xcframework.zip
curl -L -O https://github.com/holzschu/ios_system/releases/download/v3.0.0/text.xcframework.zip
for archive in ./*.zip; do
    unzip -o "$archive" -d .
done
rm *.zip
popd

pushd Extensions/Dependencies/libssh2
curl -L -O https://github.com/Frugghi/SwiftSH/raw/master/libssh2/libssh2.a
popd

# OpenCV

rm -rf opencv2.framework
curl -L -O https://github.com/ColdGrub1384/OpenCV-Contrib-iOS/releases/download/4.3.0/opencv2.framework.zip
unzip -o opencv2.framework.zip
rm -rf opencv2.framework.zip
rm -rf __MACOSX

# OpenBlas and everything Fortran related

curl -L https://github.com/ColdGrub1384/lapack-ios/releases/download/v1.4/lapack-ios.zip -o lapack-ios.zip
mkdir -p Extensions/SciPy/
unzip -o lapack-ios.zip
yes | cp -rf lapack-ios/openblas.framework Extensions/OpenBlas
cp -r lapack-ios/lapack.framework Extensions/SciPy
yes | cp -rf lapack-ios/ios_flang_runtime.framework Extensions/SciPy
rm -rf Extensions/SciPy/scipy-deps.framework
mv Extensions/SciPy/lapack.framework Extensions/SciPy/scipy-deps.framework
rm -rf __MACOSX
rm -rf lapack-ios

# Cocoapods and submodules

pod install

# CFFI

cd Extensions/Dependencies
curl https://files.pythonhosted.org/packages/cb/ae/380e33d621ae301770358eb11a896a34c34f30db188847a561e8e39ee866/cffi-1.14.3.tar.gz --output cffi.tar.gz
tar -xzvf cffi.tar.gz
rm cffi.tar.gz
rm -rf cffi
mv cffi* cffi

cd ../../

# Documentation

cd documentations
curl -L https://docs.python.org/3.10/archives/python-3.10.0-docs-html.zip -o Python.zip
unzip -o Python.zip
rm Python.zip
cd ../

# Build package metadata and native modules before documentation reads them.
cd site-packages
./install.sh
cd ../

cd docs
make html
cd ../
