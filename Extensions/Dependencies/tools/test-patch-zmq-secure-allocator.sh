#!/bin/bash
set -euo pipefail

self_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
fixture="$tmp_dir/secure_allocator.hpp"
cat > "$fixture" <<'EOF'
#ifdef ZMQ_HAVE_CURVE
namespace zmq {
#if defined(ZMQ_USE_LIBSODIUM)
template <typename T> struct secure_allocator_t {
    template <class U> struct rebind { typedef secure_allocator_t<U> other; };
};
#else
template <typename T> struct secure_allocator_t : std::allocator<T>
{
    secure_allocator_t () ZMQ_DEFAULT;
};
#endif
}
#endif
EOF

"$self_dir/patch-zmq-secure-allocator.sh" "$fixture"
cp "$fixture" "$tmp_dir/first"
"$self_dir/patch-zmq-secure-allocator.sh" "$fixture"
cmp -s "$fixture" "$tmp_dir/first"
grep -Fq 'typedef secure_allocator_t<U> other;' "$fixture"
