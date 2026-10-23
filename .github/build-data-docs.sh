#!/usr/bin/env bash
# Build the complete pandas 1.1.4 documentation, not a different iOS runtime.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/Extensions/Dependencies/pandas"
OUT="$ROOT/documentations/pandas.zip"
VENV="$ROOT/.venv-data-docs"
PIN=67a3d4241ab84419856b84fc3ebc9abcbe66c6b3
fail() { echo "pandas documentation: ERROR: $*" >&2; exit 1; }
[[ -f "$SRC/.git" || -d "$SRC/.git" ]] || fail 'pinned pandas submodule is not initialized'
[[ "$(git -C "$ROOT" ls-tree HEAD Extensions/Dependencies/pandas | awk '{print $3}')" == "$PIN" ]] || fail 'unexpected pandas gitlink'
[[ "$(git -C "$SRC" rev-parse HEAD)" == "$PIN" ]] || fail 'pandas source does not match its pin'
command -v python3.9 >/dev/null || fail 'Python 3.9 host is required for the original pandas wheel'
command -v pandoc >/dev/null || fail 'Pandoc is required to retain the original notebook documentation'
python3.9 -m venv "$VENV"
PY="$VENV/bin/python"
unset PIP_CONSTRAINT PYTHONPATH || true
export PATH="$VENV/bin:$PATH"
export MPLBACKEND=Agg
"$PY" -m pip install 'pip<24' 'setuptools<60' 'wheel==0.41.3' >/dev/null
"$PY" -m pip install \
  'setuptools<60' 'wheel==0.41.3' 'packaging==23.2' 'Pillow==9.5.0' 'pyparsing==2.4.7' \
  'matplotlib-inline==0.1.6' 'traitlets==5.9.0' 'jupyter-core==5.3.2' \
  'pandas==1.1.4' 'numpy==1.19.5' 'scipy==1.7.3' 'matplotlib==3.3.4' \
  'Sphinx==3.1.1' 'numpydoc==1.1.0' 'pydata-sphinx-theme==0.4.3' \
  'Jinja2==3.0.3' 'MarkupSafe==2.0.1' 'docutils==0.16' 'alabaster==0.7.13' \
  'sphinxcontrib-applehelp==1.0.4' 'sphinxcontrib-devhelp==1.0.2' \
  'sphinxcontrib-htmlhelp==2.0.1' 'sphinxcontrib-qthelp==1.0.3' \
  'sphinxcontrib-serializinghtml==1.1.5' \
  'IPython==7.34.0' 'ipykernel==6.16.2' 'jupyter-client==7.4.9' \
  'nbsphinx==0.8.12' 'nbconvert==6.5.4' 'nbformat==5.7.3' \
  'GitPython==3.1.43' 'PyYAML==6.0.1' 'seaborn==0.11.2' \
  'python-dateutil==2.8.2' 'pytz==2022.7.1' \
  'lxml==4.9.3' 'beautifulsoup4==4.12.3' 'html5lib==1.1' \
  'SQLAlchemy==1.4.54' 'openpyxl==3.0.10' 'xlrd==1.2.0' \
  'xlwt==1.3.0' 'XlsxWriter==1.3.7' 'odfpy==1.4.1' \
  'tabulate==0.8.10' 'xarray==0.16.2' >/dev/null
"$PY" -m pip check
"$PY" -c "import pandas; assert pandas.__version__ == '1.1.4'; import nbconvert; nbconvert.utils.pandoc.get_pandoc_version()"
WORK="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/pyto-pandas-docs.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/repo"
cp -R "$SRC/doc" "$SRC/web" "$WORK/repo/"
# The contributors extension reads Git history. It never updates this metadata.
ln -s "$(git -C "$SRC" rev-parse --absolute-git-dir)" "$WORK/repo/.git"
SITE="$("$PY" -c 'import pathlib, pandas; print(pathlib.Path(pandas.__file__).resolve().parent.parent)')"
(cd "$WORK/repo/doc" && "$PY" make.py --num-jobs 2 --python-path "$SITE" html)
HTML="$WORK/repo/doc/build/html"
[[ -s "$HTML/index.html" ]] || fail 'full HTML build produced no index.html'
mkdir -p "$WORK/stage/pandas" "$(dirname "$OUT")"
cp -R "$HTML"/. "$WORK/stage/pandas/"
PARTIAL="$OUT.partial"
(cd "$WORK/stage" && zip -qr "$PARTIAL" pandas)
"$PY" - "$ROOT/.github/complete-documentation.py" "$PARTIAL" <<'PY'
import runpy
import pathlib
import sys
verify = runpy.run_path(sys.argv[1])['verify_archive']
if not verify(pathlib.Path(sys.argv[2])):
    raise RuntimeError('Incomplete pandas HTML archive')
PY
mv -f "$PARTIAL" "$OUT"
echo "Complete pinned pandas 1.1.4 HTML archive ready: $OUT"
