#!/bin/bash

. ./versions.inc.sh

#----------------------------------------
# Download
#----------------------------------------
GIT_PKG_NAME=libobjc2-${libobjc2_version}

if [ ! -d ${BUILD_ROOT}/${GIT_PKG_NAME} ]; then
	curl -L https://github.com/gnustep/libobjc2/archive/v${libobjc2_version}.tar.gz -o ${BUILD_ROOT}/${GIT_PKG_NAME}.tar.gz
	curl -L https://github.com/Tessil/robin-map/archive/757de82.tar.gz -o ${BUILD_ROOT}/libobjc2_robin-map.tar.gz
	cd ${BUILD_ROOT}
	tar zxf ${GIT_PKG_NAME}.tar.gz
	tar zxf libobjc2_robin-map.tar.gz
	mv robin-map-757de829927489bee55ab02147484850c687b620/* ${GIT_PKG_NAME}/third_party/robin-map
	cd ..
fi

#----------------------------------------
# Build
#----------------------------------------
cd ${BUILD_ROOT}/libobjc2-${libobjc2_version} || exit 1
rm -rf _build 2>/dev/null
mkdir -p _build
cd ./_build

cmake .. \
	-DCMAKE_C_COMPILER=${C_COMPILER} \
	-DCMAKE_CXX_COMPILER=${CXX_COMPILER} \
	-DGNUSTEP_INSTALL_TYPE=NONE \
	-DCMAKE_C_FLAGS="-I/usr/NextSpace/include -g" \
	-DCMAKE_LIBRARY_PATH=/usr/NextSpace/lib \
	-DCMAKE_INSTALL_LIBDIR=/usr/NextSpace/lib \
	-DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
	-DCMAKE_MODULE_LINKER_FLAGS="-fuse-ld=/usr/bin/ld.gold -Wl,-rpath,/usr/NextSpace/lib" \
	-DCMAKE_SKIP_RPATH=ON \
	-DTESTS=OFF \
	-DCMAKE_BUILD_TYPE=Release \
	|| exit 1
#	-DCMAKE_LINKER=/usr/bin/ld.gold \

$MAKE_CMD clean
$MAKE_CMD

#----------------------------------------
# Install
#----------------------------------------
sudo mv -v /usr/NextSpace/include/Block.h /usr/NextSpace/include/Block-libdispatch.h
sudo $MAKE_CMD install || exit 1
sudo mv -v /usr/NextSpace/include/Block.h /usr/NextSpace/include/Block-libobjc.h
sudo mv -v /usr/NextSpace/include/Block-libdispatch.h /usr/NextSpace/include/Block.h
sudo ldconfig
