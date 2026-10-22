#!/bin/bash
set -euo pipefail
[[ "$(uname -s)" == Darwin && "$(uname -m)" == x86_64 ]] || {
    echo 'The historical Fortran container setup requires an Intel macOS runner' >&2
    exit 2
}
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="$ROOT/build-local/docker-tools"
mkdir -p "$PREFIX/bin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# Same Lima/Colima versions and vz/virtiofs settings already tested in this repo.
# Only the Docker CLI is required; Compose/Buildx and a Homebrew update are not.
curl -fsSL --retry 2 https://github.com/lima-vm/lima/releases/download/v1.2.1/lima-1.2.1-Darwin-x86_64.tar.gz | tar -xz -C "$PREFIX"
curl -fsSL --retry 2 https://github.com/abiosoft/colima/releases/download/v0.9.1/colima-Darwin-x86_64 -o "$PREFIX/bin/colima"
chmod 755 "$PREFIX/bin/colima"
curl -fsSL --retry 2 https://download.docker.com/mac/static/stable/x86_64/docker-28.3.3.tgz | tar -xz -C "$TMP"
install -m 755 "$TMP/docker/docker" "$PREFIX/bin/docker"
export PATH="$PREFIX/bin:$PATH"
if [[ -n "${GITHUB_PATH:-}" ]]; then
    printf '%s\n' "$PREFIX/bin" >> "$GITHUB_PATH"
fi
limactl --version
colima version
docker --version
colima start --cpu 2 --memory 4 --arch x86_64 --vm-type=vz \
    --mount-type=virtiofs --mount /Users:w --mount /var/folders:w
docker info
