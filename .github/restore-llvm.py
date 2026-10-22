#!/usr/bin/env python3
"""Restore upstream LLVM 14 and ios_system iOS frameworks, never from an IPA.

Published hashes: holzschu/llvm-project Package.swift at
58ffbab73924e2734ccb3567fc16d63c8e762355 (binaryTarget checksums).
The project's bundled Clang and LLVM headers are version 14.0.0.
ios_system hash: https://github.com/holzschu/ios_system/releases/tag/v3.0.0
"""
import hashlib
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile

HASHES = {
    "ios_system": "66f4a5e696e29f3c70e8bab3a3e8c5f5a0bda48ab102e9db98a90db93b0981ea",
    "libLLVM": "bbae5b3a7952b2f1e89fb93b25b41931a53b6d8c99d24dfe6a893e615b177428",
    "clang": "9de9f72334c99f27d3ac5844b8d3feffcaed3086997e7c2538f887667e8ca179",
    "link": "3bf79972c961f418c9964df04dec81794dd6beae88f07702e8b51e074ed2085f",
    "lli": "a7976820f7349daf1c136ae513d506c954502ff10b92a92dbd3538bd625e0719",
}
BASE = "https://github.com/holzschu/llvm-project/releases/download/14.0.0"


def device_slice(info):
    candidates = [entry for entry in info["AvailableLibraries"]
                  if entry.get("SupportedPlatform") == "ios"
                  and not entry.get("SupportedPlatformVariant")
                  and "arm64" in entry.get("SupportedArchitectures", [])]
    if len(candidates) != 1:
        raise RuntimeError(f"Expected one iOS arm64 slice, found {candidates}")
    return candidates[0]


def main():
    root = Path(__file__).resolve().parents[1]
    destination = root / "Extensions/Dependencies/ios_system"
    destination.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="pyto-llvm-", dir=os.environ.get("RUNNER_TEMP")) as temporary:
        work = Path(temporary)
        for name, expected in HASHES.items():
            archive = work / f"{name}.xcframework.zip"
            base = ("https://github.com/holzschu/ios_system/releases/download/v3.0.0"
                    if name == "ios_system" else BASE)
            subprocess.run(["curl", "--fail", "--location", "--retry", "3",
                            f"{base}/{archive.name}", "-o", str(archive)], check=True)
            digest = hashlib.sha256()
            with archive.open("rb") as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(chunk)
            if digest.hexdigest() != expected:
                raise RuntimeError(f"Official checksum mismatch for {name}")
            print(f"Verified upstream SHA256: {name} {expected}", flush=True)
            subprocess.run(["unzip", "-q", "-o", str(archive), "-d", str(work)], check=True)
            container = work / f"{name}.xcframework"
            info = plistlib.loads((container / "Info.plist").read_bytes())
            selection = device_slice(info)
            framework = container / selection["LibraryIdentifier"] / selection["LibraryPath"]
            if framework.name != f"{name}.framework":
                raise RuntimeError(f"Unexpected framework path: {framework}")
            framework_info = plistlib.loads((framework / "Info.plist").read_bytes())
            binary = framework / framework_info["CFBundleExecutable"]
            architectures = subprocess.check_output(["xcrun", "lipo", "-archs", str(binary)], text=True).split()
            if "arm64" not in architectures:
                raise RuntimeError(f"No arm64 binary: {binary}")
            shutil.copytree(framework, destination / framework.name, symlinks=True, dirs_exist_ok=True)
            print(f"Restored {framework.name}, iOS architectures: {architectures}", flush=True)


if __name__ == "__main__":
    main()
