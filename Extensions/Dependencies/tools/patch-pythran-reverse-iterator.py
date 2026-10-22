#!/usr/bin/env python3
"""Patch Pythran 0.9.12 string reverse iterators for modern libc++/Clang.

Usage: patch-pythran-reverse-iterator.py path/to/pythran/pythonic/types/str.hpp

The patch is the upstream fix from Pythran commit fe96d936ea8f (Fix #1937):
construct std::reverse_iterator<string_iterator> from data->end()/begin(),
not from the container's reverse_iterator.  This is deliberately strict and
idempotent so it cannot silently patch an unrelated header.
"""
from pathlib import Path
import sys

OLD = """  typename str::reverse_iterator str::rbegin() const
  {
    return {data->rbegin()};
  }
"""
NEW = """  typename str::reverse_iterator str::rbegin() const
  {
    string_iterator iter(data->end());
    return typename str::reverse_iterator(iter);
  }
"""
OLD_REND = """  typename str::reverse_iterator str::rend() const
  {
    return {data->rend()};
  }
"""
NEW_REND = """  typename str::reverse_iterator str::rend() const
  {
    string_iterator iter(data->begin());
    return typename str::reverse_iterator(iter);
  }
"""


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {Path(sys.argv[0]).name} path/to/str.hpp")
    path = Path(sys.argv[1])
    if not path.is_file():
        raise SystemExit(f"not a file: {path}")
    text = path.read_text()
    if NEW in text and NEW_REND in text:
        return 0
    if OLD not in text or OLD_REND not in text:
        raise SystemExit(
            f"{path} does not contain the expected unpatched Pythran rbegin/rend blocks; refusing unsafe patch"
        )
    patched = text.replace(OLD, NEW, 1).replace(OLD_REND, NEW_REND, 1)
    if OLD in patched or OLD_REND in patched:
        raise SystemExit("internal patch validation failed")
    path.write_text(patched)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
