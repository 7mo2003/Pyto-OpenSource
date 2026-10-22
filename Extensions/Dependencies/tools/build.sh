#!/bin/bash
set -e
cd "$(dirname "${BASH_SOURCE[0]}")"

# XML does not need generated target NumPy headers. Fail early on its toolchain.
if [[ "${PYTO_XML_READY:-0}" == 1 ]]; then
    [[ -f ../../Lxml/lxml-etree.framework/Info.plist && -f ../../Lxml/dependencies/lxml-deps.framework/Info.plist ]] || {
        echo 'The separate XML stage has not produced the required frameworks' >&2
        exit 1
    }
else
    echo "build-lxml.sh"
    bash build-lxml.sh
fi

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
