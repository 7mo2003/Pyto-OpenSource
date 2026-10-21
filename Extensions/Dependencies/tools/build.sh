#!/bin/bash
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

echo "build-numpy.sh"
bash build-numpy.sh

for f in build-*.sh; do
    case "$f" in
        build-numpy.sh|build-docs.sh) continue ;;
    esac
    echo "$f"
    bash "$f"
done

# Build bundled third-party documentation once, after all native modules.
bash build-docs.sh
