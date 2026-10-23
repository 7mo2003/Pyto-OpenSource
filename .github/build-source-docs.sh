#!/usr/bin/env bash
# Build only the three source-based documentation archives which cannot use
# the prebuilt HTML set.  This deliberately does not touch .venv-build, Git,
# CI files, native iOS artifacts, or the other documentation packages.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS="$ROOT/Extensions/Dependencies"
OUT="$ROOT/documentations"
VENV="$ROOT/.venv-docs"
PYTHON="${PYTHON:-python3.10}"
CONSTRAINT="$ROOT/docs/build-constraints.txt"

# These are the host-only pins.  In particular, do not let an unconstrained
# current theme/matplotlib enter the environment: the checked-out conf.py
# files are legacy configurations.
ASTROPY_VERSION="4.2"
ERFA_VERSION="2.0.0.1"
SCIPY_VERSION="1.7.3"
ASTROPY_COMMIT="01369fb9d230480220dd81813f3fff906f88d52d"
NUMPY_VERSION="1.22.4"
MATPLOTLIB_VERSION="3.5.3"
SPHINX_ASTROPY_VERSION="1.2"
ASTROPY_THEME_VERSION="1.0"
EXTENSION_HELPERS_VERSION="0.1"

fail() { echo "build-source-docs.sh: ERROR: $*" >&2; exit 1; }
need_dir() { [[ -d "$1" ]] || fail "missing checked-out source: $1 (initialize the pinned submodule first)"; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"; }

need_cmd "$PYTHON"
need_dir "$DEPS/astropy"
need_dir "$DEPS/erfa"
need_dir "$DEPS/scipy"
mkdir -p "$OUT"

# Compare every checkout with the gitlink recorded in this authorized repo.
for package in astropy erfa scipy; do
  expected="$(git -C "$ROOT" ls-tree HEAD "Extensions/Dependencies/$package" | awk '{print $3}')"
  actual="$(git -C "$DEPS/$package" rev-parse HEAD)"
  [[ -n "$expected" && "$actual" == "$expected" ]] || fail "$package does not match the pinned gitlink"
done
ASTROPY_HEAD="$(git -C "$DEPS/astropy" rev-parse HEAD 2>/dev/null || true)"
[[ "$ASTROPY_HEAD" == "$ASTROPY_COMMIT" ]] || fail "Astropy source is $ASTROPY_HEAD, expected pinned commit $ASTROPY_COMMIT"

if [[ ! -x "$VENV/bin/python" ]]; then
  "$PYTHON" -m venv "$VENV" || fail "cannot create independent $VENV"
fi
PY="$VENV/bin/python"
PIP="$PY -m pip"
"$PY" -m pip --version >/dev/null || fail "broken documentation venv: $VENV"

# Keep the root constraint opt-in and absolute.  The file is compatible with
# the historical host stack; if a checkout omits it, use explicit pins below.
if [[ -f "$CONSTRAINT" ]]; then
  export PIP_CONSTRAINT="$CONSTRAINT"
else
  unset PIP_CONSTRAINT || true
fi

# Install only host documentation/runtime tooling.  No TeX, brew, social
# dependencies, or native iOS requirements are pulled in.
$PIP install --upgrade 'pip<24' 'setuptools<60' wheel >/dev/null
$PIP install \
  "numpy==$NUMPY_VERSION" "matplotlib==$MATPLOTLIB_VERSION" \
  "scipy==$SCIPY_VERSION" "pyerfa==$ERFA_VERSION" \
  'Cython==0.29.37' 'setuptools-scm<7' 'packaging<24' \
  'Sphinx==4.5.0' 'numpydoc==1.5.0' 'sphinx-panels==0.6.0' \
  'pydata-sphinx-theme==0.8.1' 'sphinx-gallery==0.12.0' \
  'sphinx-automodapi==0.14.1' 'sphinxcontrib-bibtex==2.4.2' \
  'docutils==0.17.1' 'nbsphinx==0.8.12' 'IPython==8.12.3' \
  'pytest==7.4.4' 'PyYAML==6.0.1' \
  "sphinx-astropy==$SPHINX_ASTROPY_VERSION" \
  "astropy-sphinx-theme==$ASTROPY_THEME_VERSION" \
  "extension-helpers==$EXTENSION_HELPERS_VERSION" >/dev/null

# Build one archive atomically.  The existence check makes this script safe
# for a cache that already contains a completed zip.
build_astropy() {
  local src="$DEPS/astropy" html="$ROOT/.docs-html-astropy" stage="$ROOT/.docs-stage-astropy"
  [[ -f "$OUT/astropy.zip" ]] && return 0
  rm -rf "$html" "$stage"
  (cd "$src" && CFLAGS="${CFLAGS:-} -Wno-incompatible-function-pointer-types" "$PY" setup.py build) || fail "Astropy source build failed (extension_helpers is required)"
  local built
  built="$(find "$src" -type d -path '*/build/lib.macosx*/astropy' -print -quit)"
  [[ -n "$built" ]] || fail "Astropy setup.py produced no host build/lib.macosx*/astropy"
  # conf.py uses pkg_resources.get_distribution('Astropy'), which needs real
  # distribution metadata as well as the compiled package on PYTHONPATH.
  (cd "$src" && "$PY" setup.py egg_info --egg-base "$(dirname "$built")") || fail "Astropy distribution metadata generation failed"
  local source_docs="$src/docs"
  [[ -d "$source_docs" ]] || source_docs="$src/doc"
  need_dir "$source_docs"
  PYTHONPATH="$(dirname "$built")${PYTHONPATH:+:$PYTHONPATH}" \
    "$PY" -m sphinx -b html "$source_docs" "$html" || fail "Astropy HTML documentation failed"
  [[ -f "$html/index.html" ]] || fail "Astropy build produced no index.html"
  mkdir -p "$stage/astropy" && cp -R "$html"/. "$stage/astropy/"
  (cd "$stage" && zip -qr "$OUT/.astropy.tmp.zip" astropy) || fail "Astropy zip failed"
  mv -f "$OUT/.astropy.tmp.zip" "$OUT/astropy.zip"
  rm -rf "$html" "$stage"
}

build_erfa() {
  local src="$DEPS/erfa" html="$ROOT/.docs-html-erfa" stage="$ROOT/.docs-stage-erfa"
  [[ -f "$OUT/erfa.zip" ]] && return 0
  rm -rf "$html" "$stage"
  # The wheel supplies the compiled API module; the checked-out source supplies
  # the complete docs.  Pin the legacy sphinx_astropy theme to retain
  # bootstrap_astropy (newer themes raise AttributeError in this conf.py).
  $PIP install "pyerfa==$ERFA_VERSION" >/dev/null || fail "cannot install pinned PyERFA runtime"
  (cd "$src/docs" && "$PY" -m sphinx -b html . "$html") || fail "PyERFA HTML documentation failed (legacy sphinx_astropy/theme required)"
  [[ -f "$html/index.html" ]] || fail "PyERFA build produced no index.html"
  mkdir -p "$stage/erfa" && cp -R "$html"/. "$stage/erfa/"
  (cd "$stage" && zip -qr "$OUT/.erfa.tmp.zip" erfa) || fail "PyERFA zip failed"
  mv -f "$OUT/.erfa.tmp.zip" "$OUT/erfa.zip"
  rm -rf "$html" "$stage"
}

build_scipy() {
  local src="$DEPS/scipy" html="$ROOT/.docs-html-scipy" stage="$ROOT/.docs-stage-scipy"
  [[ -f "$OUT/scipy.zip" ]] && return 0
  rm -rf "$html" "$stage"
  # Do not resolve latest matplotlib: SciPy 1.7.3's conf.py is compatible with
  # matplotlib 3.5.3 and NumPy 1.22.4, not the current NumPy floor.
  $PIP install "scipy==$SCIPY_VERSION" >/dev/null || fail "cannot install pinned SciPy runtime"
  (cd "$src/doc/source" && "$PY" -m sphinx -b html . "$html") || fail "SciPy HTML documentation failed"
  [[ -f "$html/index.html" ]] || fail "SciPy build produced no index.html"
  mkdir -p "$stage/scipy" && cp -R "$html"/. "$stage/scipy/"
  (cd "$stage" && zip -qr "$OUT/.scipy.tmp.zip" scipy) || fail "SciPy zip failed"
  mv -f "$OUT/.scipy.tmp.zip" "$OUT/scipy.zip"
  rm -rf "$html" "$stage"
}

build_astropy
build_erfa
build_scipy
printf '%s\n' "source documentation archives ready: $OUT/astropy.zip $OUT/erfa.zip $OUT/scipy.zip"
