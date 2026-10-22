#!/usr/bin/env python3
"""Check the base-class patch used by the pinned SciPy setup.py."""
import distutils.command.build_ext
from numpy.distutils.command.build_ext import build_ext as numpy_build_ext

original = distutils.command.build_ext.build_ext
distutils.command.build_ext.build_ext = numpy_build_ext
try:
    from pythran.dist import PythranBuildExt
finally:
    distutils.command.build_ext.build_ext = original

if not issubclass(PythranBuildExt, numpy_build_ext):
    raise RuntimeError(
        "Pythran does not inherit NumPy's Fortran-aware build_ext; "
        "install the versions in build-constraints.txt"
    )
print("SciPy Pythran/NumPy build_ext compatibility verified:")
for base in PythranBuildExt.__mro__:
    print(f"  {base.__module__}.{base.__name__}")
