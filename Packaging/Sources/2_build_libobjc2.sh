#!/bin/sh

. ./versions.inc.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
if [ ${OS_NAME} != "debian" ] && [ ${OS_NAME} != "ubuntu" ]; then
	${ECHO} ">>> Installing ${OS_NAME} packages for ObjC 2.0 runtime build"
	${ECHO} "RedHat-based Linux distribution: calling 'yum -y install'."
	if [ "$OS_ID" == "centos" ];then
		SPEC_FILE=${PROJECT_DIR}/Libraries/libobjc2/libobjc2.spec
	else
		SPEC_FILE=${PROJECT_DIR}/Libraries/libobjc2/libobjc2-centos.spec
	fi
	DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | grep -v "libdispatch-devel" | awk -c '{print $1}'`
	sudo yum -y install ${DEPS} || exit 1
fi

#----------------------------------------
# Download
#----------------------------------------
GIT_PKG_NAME=libobjc2-${libobjc2_version}
if [ "$OS_ID" == "centos" ];then
	ROBIN_MAP_VERSION=1.2.1
else
	ROBIN_MAP_VERSION=757de829927489bee55ab02147484850c687b620
fi

if [ ! -d ${BUILD_ROOT}/${GIT_PKG_NAME} ]; then
	curl -L https://github.com/gnustep/libobjc2/archive/v${libobjc2_version}.tar.gz -o ${BUILD_ROOT}/${GIT_PKG_NAME}.tar.gz
	if [ "$OS_ID" == "centos" ];then
		curl -L https://github.com/Tessil/robin-map/archive/v${ROBIN_MAP_VERSION}.tar.gz -o ${BUILD_ROOT}/libobjc2_robin-map.tar.gz
	else
		curl -L https://github.com/Tessil/robin-map/archive/757de82.tar.gz -o ${BUILD_ROOT}/libobjc2_robin-map.tar.gz
	fi

	cd ${BUILD_ROOT}
	tar zxf ${GIT_PKG_NAME}.tar.gz
	tar zxf libobjc2_robin-map.tar.gz
fi

#----------------------------------------
# Build
#----------------------------------------
# build robin-map
${CMAKE_CMD} \
	-DCMAKE_CXX_COMPILER=${CXX_COMPILER} \
	-B${BUILD_ROOT}/robin-map-${ROBIN_MAP_VERSION} \
	-S${BUILD_ROOT}/robin-map-${ROBIN_MAP_VERSION}
${CMAKE_CMD} --build ${BUILD_ROOT}/robin-map-${ROBIN_MAP_VERSION}
# build libobjc2
cd ${BUILD_ROOT}/${GIT_PKG_NAME} || exit 1
rm -rf .build 2>/dev/null
mkdir -p .build
cd ./.build

$CMAKE_CMD .. \
	-Dtsl-robin-map_DIR=${BUILD_ROOT}/robin-map-${ROBIN_MAP_VERSION} \
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
