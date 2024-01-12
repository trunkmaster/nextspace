#!/bin/bash

. ./versions.inc.sh

### Download
#git_remote_archive https://github.com/apple/swift-corelibs-libdispatch libdispatch ${libdispatch_version} swift-${libdispatch_version}-RELEASE
GIT_PKG_NAME=swift-corelibs-libdispatch-swift-${libdispatch_version}-RELEASE

if [ ! -d ${GIT_PKG_NAME} ]; then
	curl -L https://github.com/apple/swift-corelibs-libdispatch/archive/swift-${libdispatch_version}-RELEASE.tar.gz -o ./${GIT_PKG_NAME}.tar.gz
	tar zxf ./${GIT_PKG_NAME}.tar.gz
fi

### Build
cd ./${GIT_PKG_NAME} ||  exit 1
rm -R _build 2>/dev/null
mkdir -p _build
cd _build

C_FLAGS="-Wno-error=unused-but-set-variable"
cmake .. \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_CXX_COMPILER=clang++ \
	-DCMAKE_C_FLAGS=${C_FLAGS} \
	-DCMAKE_CXX_FLAGS=${C_FLAGS} \
	-DCMAKE_LINKER=/usr/bin/ld.gold \
	-DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
	-DCMAKE_INSTALL_LIBDIR=/usr/NextSpace/lib \
	-DCMAKE_INSTALL_MANDIR=/usr/NextSpace/Documentation/man \
	-DINSTALL_PRIVATE_HEADERS=YES \
	-DBUILD_TESTING=OFF \
	\
	-DCMAKE_SKIP_RPATH=ON \
	-DCMAKE_BUILD_TYPE=Release

$MAKE_CMD clean
$MAKE_CMD

### Install
sudo $MAKE_CMD install
sudo rm /usr/NextSpace/include/Block_private.h
sudo ldconfig
