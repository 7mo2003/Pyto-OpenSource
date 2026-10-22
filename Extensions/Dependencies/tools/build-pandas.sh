#!/bin/bash
set -e

cd "$(dirname "${BASH_SOURCE[0]}")"

source environment.sh
export CFLAGS="$CFLAGS -Wno-error=unused-but-set-variable"

cd ../pandas
python3 setup.py bdist
python3 ../tools/make_frameworks.py pandas Pandas
../tools/copy-scripts.sh build/lib*/* ../../../site-packages/pandas
