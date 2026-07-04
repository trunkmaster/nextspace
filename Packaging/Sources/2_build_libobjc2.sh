#!/bin/sh

. ../environment.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
if is_rpm_like; then
	${ECHO} ">>> Installing ${OS_ID} packages for ObjC 2.0 runtime build"
	${ECHO} "RedHat-based Linux distribution: calling 'sudo ${RPM_PACKAGE_MANAGER} -y install'."
	SPEC_FILE=${PROJECT_DIR}/Packaging/RedHat/SPECS/libobjc2.spec
	install_rpm_spec_buildrequires "${SPEC_FILE}" "libdispatch-devel"
fi

#----------------------------------------
# Download
#----------------------------------------
OBJC_PKG_NAME=libobjc2-${libobjc2_version}
ROBIN_MAP_VERSION=1.2.1
ROBIN_MAP_PKG_NAME=v${ROBIN_MAP_VERSION}.tar.gz

if [ ! -d ${BUILD_ROOT}/libobjc2-${libobjc2_version} ]; then
	curl -L https://github.com/gnustep/libobjc2/archive/v${libobjc2_version}.tar.gz -o ${BUILD_ROOT}/libobjc2-${libobjc2_version}.tar.gz
	curl -L https://github.com/Tessil/robin-map/archive/${ROBIN_MAP_PKG_NAME} -o ${BUILD_ROOT}/libobjc2_robin-map.tar.gz

	cd "${BUILD_ROOT}" || exit 1
	tar zxf libobjc2-${libobjc2_version}.tar.gz
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
cd ${BUILD_ROOT}/${OBJC_PKG_NAME} || exit 1
rm -rf .build 2>/dev/null
mkdir -p .build
cd ./.build

$CMAKE_CMD .. \
	-Dtsl-robin-map_DIR=${BUILD_ROOT}/robin-map-${ROBIN_MAP_VERSION} \
	-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
	-DCMAKE_C_COMPILER=${C_COMPILER} \
	-DCMAKE_CXX_COMPILER=${CXX_COMPILER} \
	-DGNUSTEP_INSTALL_TYPE=NONE \
	-DCMAKE_C_FLAGS="-I/usr/NextSpace/include -g" \
	-DCMAKE_LIBRARY_PATH=/usr/NextSpace/lib \
	-DCMAKE_INSTALL_LIBDIR=lib \
	-DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
	-DCMAKE_MODULE_LINKER_FLAGS="${LD_GOLD_FLAG} -Wl,-rpath,/usr/NextSpace/lib" \
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
if [ -f $DEST_DIR/usr/NextSpace/include/Block.h ]; then
	$MV_CMD $DEST_DIR/usr/NextSpace/include/Block.h $DEST_DIR/usr/NextSpace/include/Block-libdispatch.h
fi
run_install || exit 1
if [ -f $DEST_DIR/usr/NextSpace/include/Block-libdispatch.h ]; then
	$MV_CMD $DEST_DIR/usr/NextSpace/include/Block.h $DEST_DIR/usr/NextSpace/include/Block-libobjc.h
	$MV_CMD $DEST_DIR/usr/NextSpace/include/Block-libdispatch.h $DEST_DIR/usr/NextSpace/include/Block.h
fi

refresh_ldconfig
