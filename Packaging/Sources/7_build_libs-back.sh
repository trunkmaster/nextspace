#!/bin/sh

. ../environment.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
if is_debian_like; then
	${ECHO} ">>> Installing packages for GNUstep GUI Backend build"
	install_apt_packages ${BACK_ART_DEPS}
fi

#----------------------------------------
# Download
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}/Libraries/gnustep
BUILD_DIR=${BUILD_ROOT}/back

copy_clean_build_tree "${SOURCES_DIR}/back" "${BUILD_DIR}"

#----------------------------------------
# Build and install
#----------------------------------------
. /Developer/Makefiles/GNUstep.sh
cd ${BUILD_DIR}

# ART
$MAKE_CMD clean || exit 1
./configure \
	--enable-server=x11 \
	--enable-graphics=art \
	--with-name=art \
	|| exit 1

$MAKE_CMD || exit 1
run_install fonts=no || exit 1

# Cairo
$MAKE_CMD clean || exit 1
./configure \
	--enable-server=x11 \
	--enable-graphics=cairo \
	--with-name=cairo \
	|| exit 1
$MAKE_CMD || exit 1
run_install fonts=no || exit 1

#----------------------------------------
# Post install
#----------------------------------------
refresh_ldconfig
