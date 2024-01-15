#!/bin/sh

. ./versions.inc.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing packages for libwraster build"
sudo apt-get install -y ${WRASTER_DEPS}

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
export CMAKE=cmake
export QA_SKIP_BUILD_ROOT=1

$MAKE_CMD
sudo -E $MAKE_CMD install
sudo ldconfig