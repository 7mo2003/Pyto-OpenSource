#ifndef PYTO_TYPED_AST_UNICODE_COMPAT_H
#define PYTO_TYPED_AST_UNICODE_COMPAT_H
#include <Python.h>
/* The iOS runtime is CPython 3.10.0. Newer host 3.10 headers stopped
 * declaring this private four-argument API, but the target runtime exports it.
 * Keep the target ABI rather than referencing a newer host-only symbol. */
PyAPI_FUNC(PyObject *) _PyUnicode_DecodeUnicodeEscape(
    const char *string, Py_ssize_t length, const char *errors,
    const char **first_invalid_escape);
#endif
