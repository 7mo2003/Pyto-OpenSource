#!/bin/bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

source environment.sh
export CC="clang.sh"
export CXX="clang.sh"

cd ../pyzmq
python3 setup.py configure --zmq=bundled
../tools/patch-zmq-secure-allocator.sh bundled/zeromq/src/secure_allocator.hpp
python3 setup.py bdist --zmq=bundled
python3 ../tools/make_frameworks.py pyzmq Zmq
../tools/copy-scripts.sh build/lib*/* ../../../site-packages/zmq
