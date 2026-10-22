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

if [[ "${PYTO_YAML_READY:-0}" == 1 ]]; then
    [[ -f ../../PyYaml/yaml-_yaml.framework/Info.plist ]] || {
        echo 'The separate YAML stage has not produced its native framework' >&2
        exit 1
    }
else
    echo "build-pyyaml.sh"
    bash build-pyyaml.sh
fi

echo "build-numpy.sh"
bash build-numpy.sh

# SciPy is the remaining cross-Fortran prerequisite; validate it before dependents.
echo "build-scipy.sh"
bash build-scipy.sh

for f in build-*.sh; do
    case "$f" in
        build-lxml.sh|build-pyyaml.sh|build-numpy.sh|build-scipy.sh|build-docs.sh) continue ;;
    esac
    echo "$f"
    bash "$f"
done

# Build bundled third-party documentation once, after all native modules.
bash build-docs.sh
