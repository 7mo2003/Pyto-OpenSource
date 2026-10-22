#!/bin/bash
set -e

cd "$(dirname "${BASH_SOURCE[0]}")"

source environment.sh

python3 -m pip install 'pybind11==2.7.1' 'pythran==0.9.12'
# Run in a separate interpreter: SciPy requires Pythran to be unimported when
# its setup.py patches distutils' base class for the Fortran-aware build.
python3 check-scipy-build-ext.py

export LDFLAGS="$LDFLAGS -L$(pwd) -L$(pwd)/../numpy/build/temp.iphoneos-arm64-3.10"

# numpy.distutils only probes conventional lib*.dylib/lib*.a names. The
# downloaded iOS dependencies are framework binaries instead, so expose those
# exact arm64-device binaries through a temporary, non-host link directory.
# Do not use /usr/local/lib, Homebrew, or Accelerate: those are host libraries.
OPENBLAS_FRAMEWORK="$(cd ../../OpenBlas/openblas.framework && pwd)"
LAPACK_FRAMEWORK="$(cd ../../SciPy/scipy-deps.framework && pwd)"
SCIPY_LINK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pyto-scipy-libs.XXXXXX")"
cleanup_scipy_links() {
    rm -rf "$SCIPY_LINK_DIR"
    rm -f ../scipy/site.cfg
}
trap cleanup_scipy_links EXIT

[ -f "$OPENBLAS_FRAMEWORK/openblas" ] || {
    echo "Missing iOS OpenBLAS framework binary: $OPENBLAS_FRAMEWORK/openblas" >&2
    exit 2
}
[ -f "$LAPACK_FRAMEWORK/lapack" ] || {
    echo "Missing iOS LAPACK framework binary: $LAPACK_FRAMEWORK/lapack" >&2
    exit 2
}
ln -s "$OPENBLAS_FRAMEWORK/openblas" "$SCIPY_LINK_DIR/libopenblas.dylib"
ln -s "$LAPACK_FRAMEWORK/lapack" "$SCIPY_LINK_DIR/liblapack.dylib"

# Force the historical NumPy/SciPy resolver to these framework-backed names.
# site.cfg is temporary and is removed even when setup.py fails.
cat > ../scipy/site.cfg <<EOF
[openblas]
libraries = openblas
library_dirs = $SCIPY_LINK_DIR

[lapack]
libraries = lapack
library_dirs = $SCIPY_LINK_DIR
EOF
export NPY_BLAS_ORDER=openblas
export NPY_LAPACK_ORDER=lapack

if ! [ -d fortran-ios ]; then
curl -L https://github.com/ColdGrub1384/fortran-ios/releases/download/v2.3/fortran-ios-macos-$(uname -m).zip -o fortran-ios.zip
unzip fortran-ios.zip
rm -rf __MACOSX
rm -rf fortran-ios.zip
fi

# Actions has no TTY. The release script's `docker exec -it` is otherwise
# rejected before the compiler container can start; retain stdin forwarding.
[ -f fortran-ios/bin/flang.sh ] || {
    echo "Missing bundled fortran-ios flang.sh" >&2
    exit 2
}
sed -i.bak 's/docker exec -it/docker exec -i/g' fortran-ios/bin/flang.sh
rm -f fortran-ios/bin/flang.sh.bak

# fortran-ios v2.3's flang.sh invokes Docker for every Fortran source. Fail
# clearly rather than silently falling back to a host compiler or producing a
# non-iOS object file.
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "SciPy requires a reachable Docker daemon: bundled fortran-ios v2.3 flang.sh runs flang in a Docker container" >&2
    exit 2
fi

rm -f fortran-ios/bin/gfortran
cp gfortran fortran-ios/bin

cd ../scipy

rm -f scipy/ndimage/src/ni_morphology.c
cp ../tools/ni_morphology.c scipy/ndimage/src/

git submodule update --init

python3 setup.py bdist --force
yes | cp -f scipy/misc/*.dat build/lib*/scipy/misc
python3 ../tools/make_frameworks.py scipy SciPy ios_flang_runtime scipy-deps
../tools/copy-scripts.sh build/lib*/* ../../../site-packages/scipy
