#!/bin/sh
# FreeBSD ports swift510 dispatch, pinned independently of the Linux build.
set -eu
build_root=$1
project_dir=$2
dest_dir=${3:-}
prefix=${4:-/usr/local/NextSpace}
archive="$build_root/libdispatch-freebsd-5.10.1.tar.gz"
expected=affa3544b0fdb60f8f175bc0d2846177436d5848ef8ca73e3e560d23986f38b3
if [ ! -f "$archive" ]; then
    curl -fL https://github.com/swiftlang/swift-corelibs-libdispatch/archive/swift-5.10.1-RELEASE.tar.gz -o "$archive"
fi
[ "$(sha256 -q "$archive")" = "$expected" ] || { echo 'dispatch source checksum mismatch' >&2; exit 1; }
work="$build_root/libdispatch-freebsd"
rm -rf "$work"
mkdir -p "$work"
tar -xzf "$archive" -C "$work" --strip-components 1
for patch_file in "$project_dir"/Libraries/libdispatch/freebsd/patches/*; do
    patch -d "$work" -p1 < "$patch_file"
done
# Match dispatch's public ABI major (project VERSION 1.3), including existing
# FreeBSD consumers linked against libdispatch.so.1. Never rename a symlink
# over its missing target as the old postinstall did.
printf '\nset_target_properties(dispatch PROPERTIES VERSION 1.3 SOVERSION 1)\n' >> "$work/src/CMakeLists.txt"
cmake -S "$work" -B "$work/_build" \
    -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=OFF \
    -DINSTALL_PRIVATE_HEADERS=YES -DCMAKE_SKIP_RPATH=ON \
    -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_INSTALL_MANDIR=Documentation/man
cmake --build "$work/_build" -j 2
DESTDIR="$dest_dir" cmake --install "$work/_build"
[ -f "$dest_dir$prefix/lib/libdispatch.so.1.3" ]
