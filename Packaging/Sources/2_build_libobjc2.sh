#!/bin/sh

. ./versions.inc.sh


#----------------------------------------
# Install package dependecies
#----------------------------------------
if [ ${OS_NAME} != "debian" ] && [ ${OS_NAME} != "ubuntu" ]; then
	${ECHO} ">>> Installing ${OS_NAME} packages for ObjC 2.0 runtime build"
	${ECHO} "RedHat-based Linux distribution: calling 'yum -y install'."
	SPEC_FILE=${PROJECT_DIR}/Libraries/libobjc2/libobjc2.spec
	DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | grep -v "libdispatch-devel" |awk -c '{print $1}'`
	sudo yum -y install ${DEPS} || exit 1
fi

#----------------------------------------
# Download
#----------------------------------------
GIT_PKG_NAME=libobjc2-${libobjc2_version}

if [ ! -d ${BUILD_ROOT}/${GIT_PKG_NAME} ]; then
	# Use forked and fixed repo until upstream create a new release tag wit fix.
#	curl -L https://github.com/gnustep/libobjc2/archive/v${libobjc2_version}.tar.gz -o ${BUILD_ROOT}/${GIT_PKG_NAME}.tar.gz
	curl -L https://github.com/trunkmaster/libobjc2/archive/v${libobjc2_version}.tar.gz -o ${BUILD_ROOT}/${GIT_PKG_NAME}.tar.gz
	curl -L https://github.com/Tessil/robin-map/archive/v1.2.1.tar.gz -o ${BUILD_ROOT}/libobjc2_robin-map.tar.gz

	cd ${BUILD_ROOT}
	tar zxf ${GIT_PKG_NAME}.tar.gz
	tar zxf libobjc2_robin-map.tar.gz
	mkdir -p ${GIT_PKG_NAME}/third_party
	mv robin-map-1.2.1 ${GIT_PKG_NAME}/third_party/robin-map
fi

#----------------------------------------
# Build
#----------------------------------------
# build robin-map
${CMAKE_CMD} -B${BUILD_ROOT}/${GIT_PKG_NAME}/third_party/robin-map -S${BUILD_ROOT}/${GIT_PKG_NAME}/third_party/robin-map
${CMAKE_CMD} --build ${BUILD_ROOT}/${GIT_PKG_NAME}/third_party/robin-map
# build libobjc2
cd ${BUILD_ROOT}/${GIT_PKG_NAME} || exit 1
rm -rf .build 2>/dev/null
mkdir -p .build
cd ./.build

$CMAKE_CMD .. \
	-Dtsl-robin-map_DIR=${BUILD_ROOT}/${GIT_PKG_NAME}/third_party/robin-map \
	-DCMAKE_C_COMPILER=${C_COMPILER} \
	-DCMAKE_CXX_COMPILER=${CXX_COMPILER} \
	-DGNUSTEP_INSTALL_TYPE=NONE \
	-DCMAKE_C_FLAGS="-I/usr/NextSpace/include -g" \
	-DCMAKE_LIBRARY_PATH=/usr/NextSpace/lib \
	-DCMAKE_INSTALL_LIBDIR=lib \
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
