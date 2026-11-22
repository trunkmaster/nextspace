#!/bin/sh
# Pinned last pre-Zig-0.16 Ghostty revision with the terminal-state C API.
set -eu
source_dir=${1:?usage: build.sh SOURCE_DIR PREFIX}
prefix=${2:?usage: build.sh SOURCE_DIR PREFIX}
revision=74d0c72fd9318ad3ab95bfb56f6c2d995e267e2e
if ! command -v zig >/dev/null 2>&1; then
    pkg install -y zig015
fi
test "$(zig version)" = 0.15.2 || {
    echo 'libghostty-vt requires Zig 0.15.2 for this pinned revision' >&2
    exit 1
}
if [ ! -d "$source_dir" ]; then
    git init "$source_dir"
    git -C "$source_dir" remote add origin https://github.com/ghostty-org/ghostty.git
    git -C "$source_dir" fetch --depth 1 origin "$revision"
    git -C "$source_dir" checkout --detach FETCH_HEAD
fi
test "$(git -C "$source_dir" rev-parse HEAD)" = "$revision" || {
    echo "Unexpected Ghostty revision in $source_dir; use a fresh build directory" >&2
    exit 1
}
cd "$source_dir"
zig build -Demit-lib-vt=true -Demit-exe=false -Doptimize=ReleaseFast \
    -Dsimd=false --prefix "$prefix"
test -f "$prefix/lib/libghostty-vt.so.0"
test -f "$prefix/include/ghostty/vt/terminal.h"
