#!/bin/sh

. ./versions.inc.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
if [ ${OS_NAME} = "debian" ] || [ ${OS_NAME} = "ubuntu" ]; then
  ${ECHO} ">>> Installing packages for GNUstep GUI Backend (ART) build"
  sudo apt-get install -y ${BACK_ART_DEPS}
fi

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
if [ "${OS_NAME}" = "centos" ] && [ "${OS_VERSION}" = "7" ]; then
  patch -p2 < ${SOURCES_DIR}/back-art_centos7.patch
fi

./configure \
  --enable-graphics=art \
  --with-name=art

$MAKE_CMD
sudo -E $MAKE_CMD fonts=no install
sudo ldconfig