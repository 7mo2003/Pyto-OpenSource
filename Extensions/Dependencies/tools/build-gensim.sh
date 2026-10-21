#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"

source environment.sh

cd ../gensim
python3 -m pip install Cython==0.29.37
python3 - <<'PY'
from pathlib import Path

setup = Path("setup.py")
old = "Cython==0.29.14"
new = "Cython==0.29.37"
text = setup.read_text()
matches = text.count(old)
if matches != 1:
    raise SystemExit(
        f"Expected exactly one {old!r} requirement in {setup}, found {matches}"
    )
setup.write_text(text.replace(old, new))
PY
python3 setup.py bdist
python3 ../tools/make_frameworks.py gensim Gensim
../tools/copy-scripts.sh build/lib*/* ../../../site-packages/gensim
