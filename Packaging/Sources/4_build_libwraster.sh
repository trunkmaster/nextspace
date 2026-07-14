#!/bin/sh

. ../environment.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing packages for WRaster library build"
install_packages ${WRASTER_DEPS}


#----------------------------------------
# Download
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}/Libraries/libwraster
BUILD_DIR=${BUILD_ROOT}/libwraster

if [ -d ${BUILD_DIR} ]; then
	rm -rf ${BUILD_DIR}
fi
cp -R ${SOURCES_DIR} ${BUILD_ROOT}

#----------------------------------------
# Build
#----------------------------------------
. /Developer/Makefiles/GNUstep.sh
cd ${BUILD_DIR}
export CC=${C_COMPILER}
export CMAKE=${CMAKE_CMD}
export QA_SKIP_BUILD_ROOT=1

$MAKE_CMD || exit 1
$INSTALL_CMD || exit 1

if [ "$DEST_DIR" = "" ]; then
	sudo ldconfig
fi