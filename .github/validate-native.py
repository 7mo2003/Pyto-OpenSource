#!/usr/bin/env python3
"""Check generated device frameworks before caching or Xcode packaging."""
import pathlib
import plistlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parent.parent
tools = root / 'Extensions/Dependencies/tools'
groups = set()
for script in tools.glob('build-*.sh'):
    for line in script.read_text().splitlines():
        match = re.search(r'make_frameworks\.py["\']?\s+\S+\s+(\w+)', line)
        if match:
            groups.add(match[1])
if len(groups) < 20:
    raise SystemExit('Unable to discover the expected native framework groups')
for required in ('typed_ast-_ast27.framework', 'typed_ast-_ast3.framework'):
    if not (root / 'Extensions' / 'TypedAST' / required).is_dir():
        raise SystemExit('Missing required TypedAST parser: ' + required)
count = 0
for group in sorted(groups):
    frameworks = sorted((root / 'Extensions' / group).glob('*.framework'))
    if not frameworks:
        raise SystemExit('Missing native framework group: ' + group)
    for framework in frameworks:
        with (framework / 'Info.plist').open('rb') as f:
            info = plistlib.load(f)
        binary = framework / info['CFBundleExecutable']
        if not binary.is_file() or not binary.stat().st_size:
            raise SystemExit('Missing framework executable: ' + str(binary))
        arch = subprocess.check_output(['xcrun', 'lipo', '-archs', str(binary)], text=True)
        if 'arm64' not in arch.split():
            raise SystemExit('Framework lacks arm64: ' + str(binary))
        commands = subprocess.check_output(['xcrun', 'otool', '-l', str(binary)], text=True)
        if not re.search(r'LC_VERSION_MIN_IPHONEOS|platform\s+(?:2|IOS)\b', commands):
            raise SystemExit('Framework is not tagged for iOS device: ' + str(binary))
        count += 1
    print(f'{group}: {len(frameworks)} device frameworks', flush=True)
print(f'Validated {count} frameworks across {len(groups)} groups; runtime testing is still required.')
