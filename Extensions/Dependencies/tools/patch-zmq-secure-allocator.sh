#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'usage: %s PATH_TO_SECURE_ALLOCATOR_HPP\n' "$0" >&2
    exit 2
fi

file=$1
[[ -f "$file" ]] || { printf 'missing secure allocator: %s\n' "$file" >&2; exit 1; }

python3 - "$file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
needle = "template <typename T> struct secure_allocator_t : std::allocator<T>\n{\n"
rebind = "    template <class U> struct rebind\n    {\n        typedef secure_allocator_t<U> other;\n    };\n"

if needle not in text:
    raise SystemExit("unsupported secure_allocator_t definition: " + str(path))

branch_start = text.index(needle) + len(needle)
branch_end = text.find("};", branch_start)
if branch_end < 0:
    raise SystemExit("unterminated secure_allocator_t definition: " + str(path))
if "secure_allocator_t<U> other;" in text[branch_start:branch_end]:
    raise SystemExit(0)

updated = text[:branch_start] + "\n" + rebind + text[branch_start:]
path.write_text(updated)
PY
