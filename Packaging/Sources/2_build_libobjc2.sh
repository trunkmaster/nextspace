#!/bin/sh

. ../environment.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
install_packages ${BUILD_TOOLS} ${RUNTIME_DEPS}

#----------------------------------------
# Sources (vendored; tsl-robin-map comes from the robin-map package)
#----------------------------------------
OBJC_PKG_NAME=libobjc2
${RM_CMD} -rf ${BUILD_ROOT}/${OBJC_PKG_NAME}
cp -R ${PROJECT_DIR}/Libraries/libobjc2 ${BUILD_ROOT}/${OBJC_PKG_NAME}

#----------------------------------------
# Build
#----------------------------------------
cd ${BUILD_ROOT}/${OBJC_PKG_NAME} || exit 1
mkdir -p .build
cd ./.build

$CMAKE_CMD .. \
	-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
	-DCMAKE_C_COMPILER=${C_COMPILER} \
	-DCMAKE_CXX_COMPILER=${CXX_COMPILER} \
	-DGNUSTEP_INSTALL_TYPE=NONE \
	-DCMAKE_C_FLAGS="-I/usr/NextSpace/include -g" \
	-DCMAKE_LIBRARY_PATH=/usr/NextSpace/lib \
	-DCMAKE_INSTALL_LIBDIR=lib \
	-DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
	-DCMAKE_MODULE_LINKER_FLAGS="-Wl,-rpath,/usr/NextSpace/lib" \
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
$INSTALL_CMD || exit 1
if [ -f $DEST_DIR/usr/NextSpace/include/Block-libdispatch.h ]; then
	$MV_CMD $DEST_DIR/usr/NextSpace/include/Block.h $DEST_DIR/usr/NextSpace/include/Block-libobjc.h
	$MV_CMD $DEST_DIR/usr/NextSpace/include/Block-libdispatch.h $DEST_DIR/usr/NextSpace/include/Block.h
fi

if [ "$DEST_DIR" = "" ]; then
	sudo ldconfig
fi
