#!/bin/sh

. ../environment.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
if [ ${OS_ID} = "debian" ] || [ ${OS_ID} = "ubuntu" ]; then
	${ECHO} ">>> Installing packages for GNUstep GUI Backend build"
	sudo apt-get install -y ${BACK_ART_DEPS}
fi

#----------------------------------------
# Download
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}/Libraries/gnustep
BUILD_DIR=${BUILD_ROOT}/back

if [ -d ${BUILD_DIR} ]; then
	rm -rf ${BUILD_DIR}
fi
cp -R ${SOURCES_DIR}/back ${BUILD_ROOT}

#----------------------------------------
# Build and install
#----------------------------------------
. /Developer/Makefiles/GNUstep.sh
cd ${BUILD_DIR}

# ART
$MAKE_CMD clean || exit 1
./configure \
	--enable-graphics=art \
	--with-name=art \
	|| exit 1

$MAKE_CMD || exit 1
$INSTALL_CMD fonts=no || exit 1

# Cairo
$MAKE_CMD clean || exit 1
./configure \
	--enable-graphics=cairo \
	--with-name=cairo \
	|| exit 1
$MAKE_CMD || exit 1
$INSTALL_CMD fonts=no || exit 1

#----------------------------------------
# Post install
#----------------------------------------
if [ "$DEST_DIR" = "" ]; then
	sudo ldconfig
fi
