#!/bin/bash
set -euo pipefail

# libxslt 1.1.26 accesses XPath operation-limit fields removed by libxml2 2.13.
# Keep the old propagation for older libxml2; newer libxml2 enforces its own
# limits and no longer exposes these private fields.
file="${1:?path to libxslt/functions.c}"
python3 - "${file}" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text()
old = '''#if LIBXML_VERSION >= 20911 || \\
    defined(FUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION)
    xptrctxt->opLimit = ctxt->context->opLimit;
    xptrctxt->opCount = ctxt->context->opCount;
    xptrctxt->depth = ctxt->context->depth;

    resObj = xmlXPtrEval(fragment, xptrctxt);

    ctxt->context->opCount = xptrctxt->opCount;
#else'''
new = '''#if (LIBXML_VERSION >= 20911 && LIBXML_VERSION < 21300) || \\
    (defined(FUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION) && LIBXML_VERSION < 21300)
    xptrctxt->opLimit = ctxt->context->opLimit;
    xptrctxt->opCount = ctxt->context->opCount;
    xptrctxt->depth = ctxt->context->depth;

    resObj = xmlXPtrEval(fragment, xptrctxt);

    ctxt->context->opCount = xptrctxt->opCount;
#else'''
if new in s:
    raise SystemExit(0)  # already patched; safe for reruns
if old not in s:
    if 'xptrctxt->opLimit' not in s:
        raise SystemExit('libxslt/functions.c does not contain the expected XPath limit block')
    raise SystemExit('XPath limit block changed; refusing an unsafe patch')
p.write_text(s.replace(old, new, 1))
PY
