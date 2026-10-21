#!/bin/bash

cd "$(dirname "${BASH_SOURCE[0]}")"

python3 -m pip install wheel 'cppy==1.1.0'

source environment.sh

cd ../kiwisolver
python3 setup.py bdist
python3 ../tools/make_frameworks.py kiwisolver Kiwisolver
