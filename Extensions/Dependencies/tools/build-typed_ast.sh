#!/bin/bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

source environment.sh

# Use the API exported by the bundled target runtime, not a newer private
# symbol from the host Python headers.
xcrun nm -gU ../../../python3_ios/Python3_ios/libPython3.10.a | grep -E '[[:space:]]T __PyUnicode_DecodeUnicodeEscape$' >/dev/null || {
    echo 'Bundled iOS Python lacks the Unicode API required by TypedAST' >&2
    exit 2
}
export CFLAGS="${CFLAGS:-} -include '$PWD/typed-ast-unicode-compat.h'"

cd ../typed_ast
python3 setup.py bdist
python3 ../tools/make_frameworks.py typed_ast TypedAST
../tools/copy-scripts.sh build/lib*/* ../../../site-packages/typed_ast
