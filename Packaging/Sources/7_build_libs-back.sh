#!/bin/bash

. ./versions.inc.sh

#----------------------------------------
# Download
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}/Libraries/gnustep
BUILD_DIR=${BUILD_ROOT}/back-art

if [ -d ${BUILD_DIR} ]; then
  rm -rf ${BUILD_DIR}
fi
cp -R ${SOURCES_DIR}/back-art ${BUILD_ROOT}

#----------------------------------------
# Build
#----------------------------------------
. /Developer/Makefiles/GNUstep.sh
cd ${BUILD_DIR}

./configure \
  --enable-graphics=art \
  --with-name=art

$MAKE_CMD
sudo -E $MAKE_CMD fonts=no install
sudo ldconfig