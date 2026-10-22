#!/usr/bin/env python3
"""Keep pre-C99 fallback macros out of C++11 standard library headers."""
from pathlib import Path
import sys

path = Path(sys.argv[1])
old = '#if (__STDC_VERSION__ < 199901L)'
new = '#if (!defined(__cplusplus) && __STDC_VERSION__ < 199901L) || (defined(__cplusplus) && __cplusplus < 201103L)'
text = path.read_text()
if new not in text:
    if text.count(old) != 1:
        raise SystemExit('Unexpected SciPy C99 header; refusing an ambiguous patch')
    path.write_text(text.replace(old, new, 1))
