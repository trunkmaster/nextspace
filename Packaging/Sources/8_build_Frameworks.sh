#!/bin/sh

. ../environment.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing packages for NextSpace frameworks build"
install_packages ${FRAMEWORKS_BUILD_DEPS} ${FRAMEWORKS_RUN_DEPS}

#----------------------------------------
# Download
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}/Frameworks
BUILD_DIR=${BUILD_ROOT}/Frameworks

if [ -d ${BUILD_DIR} ]; then
	rm -rf ${BUILD_DIR}
fi
cp -R ${SOURCES_DIR} ${BUILD_ROOT}

#----------------------------------------
# Build
#----------------------------------------
. /Developer/Makefiles/GNUstep.sh
cd ${BUILD_DIR}

$MAKE_CMD clean
$MAKE_CMD || exit 1

#----------------------------------------
# Install
#----------------------------------------
$INSTALL_CMD
if [ "$DEST_DIR" = "" ]; then
	sudo ldconfig
	$LN_CMD /usr/NextSpace/Frameworks/DesktopKit.framework/Resources/25-nextspace-fonts.conf /etc/fonts/conf.d/25-nextspace-fonts.conf
fi
