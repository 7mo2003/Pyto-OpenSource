#!/bin/bash
set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPS_DIR="$(cd "${TOOLS_DIR}/.." && pwd)"
LXML_DIR="${DEPS_DIR}/lxml"
LIBXML2_DIR="${DEPS_DIR}/libxml2"
LIBXSLT_DIR="${DEPS_DIR}/libxslt/libxslt-1.1.26"
OUT_DIR="${DEPS_DIR}/../Lxml"
# Keep all generated headers, archives and config scripts together.  In
# particular, never let configure find /usr/local or a Homebrew xml2-config.
PREFIX="${OUT_DIR}/.ios-prefix"

cd "${TOOLS_DIR}"
# environment.sh is intentionally sourced again immediately before setup.py
# below.  The native dependency builds temporarily replace its compiler flags.
source environment.sh
SDKROOT="${SDK}"
IOS_MIN="${IPHONEOS_DEPLOYMENT_TARGET}"
export CC="${XCRUN} --sdk iphoneos clang -arch arm64 -mios-version-min=${IOS_MIN}"
export CXX="${XCRUN} --sdk iphoneos clang++ -arch arm64 -mios-version-min=${IOS_MIN}"
export AR="$(xcrun --sdk iphoneos -f ar)"
export RANLIB="$(xcrun --sdk iphoneos -f ranlib)"
export CPPFLAGS="-arch arm64 -isysroot ${SDKROOT} -I${PREFIX}/include"
export CFLAGS="-arch arm64 -isysroot ${SDKROOT} -miphoneos-version-min=${IOS_MIN} -fPIC"
export LDFLAGS="-arch arm64 -isysroot ${SDKROOT} -miphoneos-version-min=${IOS_MIN} -L${PREFIX}/lib"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="${PREFIX}/lib/pkgconfig"
export PATH="${PREFIX}/bin:${PATH}"

# Homebrew prefixes GNU libtool commands to distinguish Apple's /usr/bin/libtool.
# autogen.sh calls libtoolize literally, so provide local aliases, not global changes.
GNU_TOOLS="${TOOLS_DIR}/.gnu-tools"
mkdir -p "${GNU_TOOLS}"
ln -sf "$(command -v glibtoolize)" "${GNU_TOOLS}/libtoolize"
ln -sf "$(command -v glibtool)" "${GNU_TOOLS}/libtool"
export PATH="${GNU_TOOLS}:${PATH}"
export LIBTOOLIZE="${GNU_TOOLS}/libtoolize"
export ACLOCAL_PATH="$(brew --prefix libtool)/share/aclocal:$(brew --prefix)/share/aclocal${ACLOCAL_PATH:+:$ACLOCAL_PATH}"
command -v pkg-config >/dev/null || brew install pkg-config

command -v autoconf >/dev/null || { echo "autoconf is required to build pinned libxml2/libxslt" >&2; exit 1; }
command -v automake >/dev/null || { echo "automake is required to build pinned libxml2/libxslt" >&2; exit 1; }
rm -rf "${PREFIX}"
mkdir -p "${PREFIX}"

# Build and install the pinned libxml2 first.  Its staged xml2-config is the
# only config script visible to the later libxslt and lxml builds.
cd "${LIBXML2_DIR}"
if [[ -x ./autogen.sh ]]; then
  ./autogen.sh --build=x86_64-apple-darwin --host=arm-apple-darwin \
    --prefix="${PREFIX}" --disable-dependency-tracking --disable-shared \
    --enable-static --without-python
else
  ./configure --build=x86_64-apple-darwin --host=arm-apple-darwin \
    --prefix="${PREFIX}" --disable-dependency-tracking --disable-shared \
    --enable-static --without-python
fi
make -j2
make install

# libxslt 1.1.26 is built with its own autoconf files, not the unrelated
# Xcode wrapper project.  This guarantees that it consumes the staged
# libxml2 headers and archive rather than host XML libraries.
cd "${LIBXSLT_DIR}"
"${TOOLS_DIR}/patch-libxslt-libxml2.sh" libxslt/functions.c
python3 - <<'PY'
from pathlib import Path
# Old libxslt probes with an undocumented extra argument rejected by xml2-config.
for name in ("configure", "configure.in"):
    path = Path(name)
    if path.exists():
        text = path.read_bytes()
        path.write_bytes(text.replace(b"--libs print", b"--libs"))
# The fork's header template added profiler support but its old configure
# never substitutes WITH_PROFILER. Match the shipped xsltconfig.h: enabled.
path = Path("libxslt/xsltconfig.h.in")
text = path.read_bytes()
path.write_bytes(text.replace(b"#if @WITH_PROFILER@", b"#if 1"))
PY
if [[ ! -x ./configure ]]; then
  autoreconf -fi
fi
XML2_CONFIG="${PREFIX}/bin/xml2-config" ./configure \
  --build=x86_64-apple-darwin --host=arm-apple-darwin \
  --prefix="${PREFIX}" --disable-dependency-tracking --disable-shared \
  --enable-static --without-python --without-crypto \
  --with-libxml-prefix="${PREFIX}" --with-libxml-include-prefix="${PREFIX}/include" \
  --with-libxml-libs-prefix="${PREFIX}/lib"
make -j2
make install

# Fail closed if either config script points outside our staging prefix.
for config in "${PREFIX}/bin/xml2-config" "${PREFIX}/bin/xslt-config"; do
  [[ -x "${config}" ]] || { echo "missing staged config script: ${config}" >&2; exit 1; }
  case "$("${config}" --cflags) $("${config}" --libs)" in
    *"/usr/local"*|*"/opt/homebrew"*|*"/home/linuxbrew"*)
      echo "host path leaked into ${config}" >&2; exit 1;;
  esac
done

rm -rf "${OUT_DIR}"/dependencies "${OUT_DIR}"/*.a
mkdir -p "${OUT_DIR}/dependencies"
cp "${PREFIX}/lib/libxml2.a" "${OUT_DIR}/libxml2.a"
cp "${PREFIX}/lib/libxslt.a" "${OUT_DIR}/libxslt.a"
cd "${OUT_DIR}/dependencies"
ar x ../libxml2.a
ar x ../libxslt.a
cd "${OUT_DIR}"
"${XCRUN}" -sdk iphoneos clang -shared -fPIC dependencies/*.o \
  -arch arm64 -isysroot "${SDKROOT}" -undefined dynamic_lookup -o dependencies/lxml
rm -f dependencies/__.SYMDEF\ SORTED dependencies/*.o
rm -rf lxml.framework
mkdir lxml.framework
mv dependencies/lxml lxml.framework/lxml
cp "${TOOLS_DIR}/lxml-Info.plist" lxml.framework/Info.plist
rm -rf dependencies/lxml-deps.framework
mv lxml.framework dependencies/lxml-deps.framework

# Restore the complete cross-platform/Pyto Python environment after the native
# builds; otherwise setup.py silently uses the host interpreter and flags.
cd "${TOOLS_DIR}"
source environment.sh
cd "${LXML_DIR}"
XML2_CONFIG="${PREFIX}/bin/xml2-config" \
XSLT_CONFIG="${PREFIX}/bin/xslt-config" \
PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig" \
PATH="${PREFIX}/bin:${PATH}" \
python3 setup.py bdist
python3 "${TOOLS_DIR}/make_frameworks.py" lxml Lxml
"${TOOLS_DIR}/copy-scripts.sh" build/lib*/* "${DEPS_DIR}/../../site-packages/lxml"
