#!/bin/bash
set -euo pipefail

"$(dirname "${BASH_SOURCE[0]}")"/iosxcrun.py --sdk iphoneos clang -arch arm64 "$@"
