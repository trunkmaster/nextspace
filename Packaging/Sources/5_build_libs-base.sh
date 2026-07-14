#!/bin/sh

. ../environment.sh
. /Developer/Makefiles/GNUstep.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing packages for GNUstep Base (Foundation) build"
install_packages ${GNUSTEP_BASE_DEPS}

#----------------------------------------
# Sources (vendored)
#----------------------------------------
GIT_PKG_NAME=gnustep-base
${RM_CMD} -rf ${BUILD_ROOT}/${GIT_PKG_NAME}
cp -R ${PROJECT_DIR}/Libraries/gnustep/base ${BUILD_ROOT}/${GIT_PKG_NAME}

#----------------------------------------
# Build
#----------------------------------------
cd ${BUILD_ROOT}/${GIT_PKG_NAME} || exit 1
if [ -d obj ]; then
	$MAKE_CMD clean
fi
# clang >= 16 promotes several classic C warnings to errors by default;
# the pinned 1.31.1 configure tests and sources predate that.
BASE_CFLAGS="-Wno-error=incompatible-pointer-types -Wno-error=int-conversion -Wno-error=implicit-function-declaration -Wno-error=implicit-int"
CFLAGS="${BASE_CFLAGS}" OBJCFLAGS="${BASE_CFLAGS}" ./configure || exit 1
$MAKE_CMD || exit 1

#----------------------------------------
# Install
#----------------------------------------
$INSTALL_CMD
cd ${_PWD}

#----------------------------------------
# Install services
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}/Libraries/gnustep

$MKDIR_CMD $DEST_DIR/usr/NextSpace/etc
$CP_CMD ${SOURCES_DIR}/gdomap.interfaces $DEST_DIR/usr/NextSpace/etc/
$MKDIR_CMD $DEST_DIR/usr/NextSpace/lib/systemd
$CP_CMD ${SOURCES_DIR}/gdomap.service $DEST_DIR/usr/NextSpace/lib/systemd
$CP_CMD ${SOURCES_DIR}/gdnc.service $DEST_DIR/usr/NextSpace/lib/systemd
$CP_CMD ${SOURCES_DIR}/gdnc-local.service $DEST_DIR/usr/NextSpace/lib/systemd

if [ "$DEST_DIR" = "" ] && [ "$GITHUB_ACTIONS" != "true" ]; then
	sudo ldconfig
	sudo systemctl daemon-reload
	systemctl status gdomap || sudo systemctl enable /usr/NextSpace/lib/systemd/gdomap.service;
	systemctl status gdnc || sudo systemctl enable /usr/NextSpace/lib/systemd/gdnc.service;
	sudo systemctl enable /usr/NextSpace/lib/systemd/gdnc-local.service;
	sudo systemctl start gdomap gdnc
fi
