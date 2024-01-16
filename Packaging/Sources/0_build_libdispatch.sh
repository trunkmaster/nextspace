#!/bin/sh

. ./versions.inc.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing packages for libdispatch build"
sudo apt-get install -y ${BUILD_TOOLS} ${RUNTIME_DEPS}

#----------------------------------------
# Download
#----------------------------------------
GIT_PKG_NAME=swift-corelibs-libdispatch-swift-${libdispatch_version}-RELEASE

if [ ! -d ${BUILD_ROOT}/${GIT_PKG_NAME} ]; then
	curl -L https://github.com/apple/swift-corelibs-libdispatch/archive/swift-${libdispatch_version}-RELEASE.tar.gz -o ${BUILD_ROOT}/${GIT_PKG_NAME}.tar.gz
	cd ${BUILD_ROOT}
	tar zxf ${GIT_PKG_NAME}.tar.gz
	cd ..
fi

#----------------------------------------
# Build
#----------------------------------------
cd ${BUILD_ROOT}/${GIT_PKG_NAME} || exit 1
rm -rf _build 2>/dev/null
mkdir -p _build
cd _build

C_FLAGS="-Wno-error=unused-but-set-variable"
cmake .. \
	-DCMAKE_C_COMPILER=${C_COMPILER} \
	-DCMAKE_CXX_COMPILER=${CXX_COMPILER} \
	-DCMAKE_C_FLAGS=${C_FLAGS} \
	-DCMAKE_CXX_FLAGS=${C_FLAGS} \
	-DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
	-DCMAKE_INSTALL_LIBDIR=/usr/NextSpace/lib \
	-DCMAKE_INSTALL_MANDIR=/usr/NextSpace/Documentation/man \
	-DINSTALL_PRIVATE_HEADERS=YES \
	-DBUILD_TESTING=OFF \
	\
	-DCMAKE_SKIP_RPATH=ON \
	-DCMAKE_BUILD_TYPE=Debug \
	|| exit 1
#	-DCMAKE_LINKER=/usr/bin/ld.gold \

$MAKE_CMD clean
$MAKE_CMD

#----------------------------------------
# Install
#----------------------------------------
sudo $MAKE_CMD install

#----------------------------------------
# Postinstall
#----------------------------------------
sudo rm /usr/NextSpace/include/Block_private.h

sudo mv /usr/NextSpace/lib/libBlocksRuntime.so /usr/NextSpace/lib/libBlocksRuntime.so.${libdispatch_version}
sudo ln -s /usr/NextSpace/lib/libBlocksRuntime.so.${libdispatch_version} /usr/NextSpace/lib/libBlocksRuntime.so

sudo mv /usr/NextSpace/lib/libdispatch.so /usr/NextSpace/lib/libdispatch.so.${libdispatch_version}
sudo ln -s /usr/NextSpace/lib/libdispatch.so.${libdispatch_version} /usr/NextSpace/lib/libdispatch.so

sudo ldconfig
