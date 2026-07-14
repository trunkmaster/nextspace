#!/bin/sh

. ../environment.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing packages for Grand Central Dispatch build"
install_packages ${BUILD_TOOLS} ${RUNTIME_DEPS}

#----------------------------------------
# Sources (vendored)
#----------------------------------------
GIT_PKG_NAME=libdispatch
${RM_CMD} -rf ${BUILD_ROOT}/${GIT_PKG_NAME}
cp -R ${PROJECT_DIR}/Libraries/libdispatch ${BUILD_ROOT}/${GIT_PKG_NAME}

#----------------------------------------
# Build
#----------------------------------------
cd ${BUILD_ROOT}/${GIT_PKG_NAME} || exit 1
${RM_CMD} -rf _build
mkdir -p _build
cd _build

# Pinned 5.9.2 sources predate current clang's stricter -Werror defaults
# (cast-function-type-mismatch, sign-conversion, ...) - don't hold 2023
# code to them; warnings stay visible in the log.
C_FLAGS="-Wno-error"
$CMAKE_CMD .. \
	-DCMAKE_C_COMPILER=${C_COMPILER} \
	-DCMAKE_CXX_COMPILER=${CXX_COMPILER} \
	-DCMAKE_C_FLAGS="${C_FLAGS}" \
	-DCMAKE_CXX_FLAGS="${C_FLAGS}" \
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
$MAKE_CMD || exit 1

#----------------------------------------
# Install
#----------------------------------------
$INSTALL_CMD || exit 1

#----------------------------------------
# Postinstall
#----------------------------------------
$RM_CMD $DEST_DIR/usr/NextSpace/include/Block_private.h
SHORT_VER=`echo ${libdispatch_version} | awk -F. '{print $1}'`

cd ${DEST_DIR}/usr/NextSpace/lib

$ECHO "-- Creating link for libBlocksRuntime.so.${libdispatch_version}"
$MV_CMD libBlocksRuntime.so libBlocksRuntime.so.${libdispatch_version}
$LN_CMD libBlocksRuntime.so.${libdispatch_version} libBlocksRuntime.so.${SHORT_VER}
$LN_CMD libBlocksRuntime.so.${libdispatch_version} libBlocksRuntime.so

$ECHO "-- Creating link for libdispatch.so.${libdispatch_version}"
$MV_CMD libdispatch.so libdispatch.so.${libdispatch_version}
$LN_CMD libdispatch.so.${libdispatch_version} libdispatch.so.${SHORT_VER}
$LN_CMD libdispatch.so.${libdispatch_version} libdispatch.so

if [ "$DEST_DIR" = "" ]; then
	sudo ldconfig
fi
