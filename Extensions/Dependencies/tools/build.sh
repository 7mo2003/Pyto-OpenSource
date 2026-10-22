#!/bin/bash
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

# XML does not need generated target NumPy headers. Fail early on its toolchain.
echo "build-lxml.sh"
bash build-lxml.sh

echo "build-numpy.sh"
bash build-numpy.sh

for f in build-*.sh; do
    case "$f" in
        build-lxml.sh|build-numpy.sh|build-docs.sh) continue ;;
    esac
    echo "$f"
    bash "$f"
done

# Build bundled third-party documentation once, after all native modules.
bash build-docs.sh
