#!/bin/bash
set -e

cd "$(dirname "${BASH_SOURCE[0]}")"

FREETYPE_LIBDIR="$(bash ensure-ios-freetype.sh)"

source environment.sh
export CFLAGS="$CFLAGS -I$PWD/../../../freetype2-ios/include "
export LDFLAGS="$LDFLAGS -L$FREETYPE_LIBDIR"

cd ../matplotlib
rm -f setup.cfg
rm -f lib/matplotlib/font_manager.py
cp ../tools/font_manager.py lib/matplotlib
cp ../tools/matplotlib-setup.cfg setup.cfg

python3 - <<'PY'
from pathlib import Path

source = Path("src/ft2font.cpp")
text = source.read_text()
old = "        tags = outline.tags + first;"
new = "        tags = reinterpret_cast<char *>(outline.tags + first);"
if text.count(old) != 2:
    raise SystemExit(f"expected exactly two ft2font tag assignments, found {text.count(old)}")
source.write_text(text.replace(old, new))
PY

python3 setup.py bdist
python3 ../tools/make_frameworks.py matplotlib Matplotlib
grep -qxF "# Code implemented by Pyto for showing images with the AGG backend" build/lib*/matplotlib/backends/backend_agg.py || cat ../tools/agg.py >> build/lib*/matplotlib/backends/backend_agg.py
../tools/copy-scripts.sh build/lib*/matplotlib ../../../site-packages/matplotlib

rm -f ../../../site-packages/pyblab.py
rm -rf ../../../site-packages/mpl_toolkits
rm -rf ../../../site-packages/mpl-data

cp -r build/lib*/mpl_toolkits ../../../site-packages/
cp -r build/lib*/matplotlib/mpl-data ../../../site-packages/
cp build/lib*/pylab.py ../../../site-packages/

find ../../../site-packages/matplotlib -name ".*" -delete
