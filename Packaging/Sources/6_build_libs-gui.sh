#!/bin/sh

. ../environment.sh
. /Developer/Makefiles/GNUstep.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
install_packages ${GNUSTEP_GUI_DEPS}

#----------------------------------------
# Sources (vendored; NEXTSPACE patches are commits on the tree)
#----------------------------------------
GIT_PKG_NAME=gnustep-gui
SOURCES_DIR=${PROJECT_DIR}/Libraries/gnustep
${RM_CMD} -rf ${BUILD_ROOT}/${GIT_PKG_NAME}
cp -R ${PROJECT_DIR}/Libraries/gnustep/gui ${BUILD_ROOT}/${GIT_PKG_NAME}

#----------------------------------------
# Build
#----------------------------------------
cd ${BUILD_ROOT}/${GIT_PKG_NAME} || exit 1
if [ -d obj ]; then
	$MAKE_CMD clean
fi
# Arch's ICU no longer ships icu-config; pkg-config is used instead.
./configure --disable-icu-config || exit 1
$MAKE_CMD || exit 1

#----------------------------------------
# Install
#----------------------------------------
$INSTALL_CMD || exit 1
# libwraster crashes on loading default GNUstep common_Tile.tiff.
# Replace it in case when NextSpace theme will be disabled.
print_H2 "Replacing /Library/Images/common_Tile.tiff..."
$CP_CMD -f -v ${SOURCES_DIR}/nextspace-theme/Resources/ThemeImages/common_Tile.tiff /Library/Images || exit 1

#----------------------------------------
# Download theme
#----------------------------------------
THEME_SOURCES_DIR=${SOURCES_DIR}/nextspace-theme
BUILD_DIR=${BUILD_ROOT}/nextspace-theme

if [ -d ${BUILD_DIR} ]; then
	rm -rf ${BUILD_DIR} || exit 1
fi
cp -R ${THEME_SOURCES_DIR} ${BUILD_ROOT} || exit 1

#----------------------------------------
# Build and install theme
#----------------------------------------
cd ${BUILD_DIR} || exit 1
$MAKE_CMD || exit 1
$INSTALL_CMD || exit 1

#----------------------------------------
# Install global defaults
#----------------------------------------
print_H2 "Installing /Libraries/Preferences/GlobalDefaults.plist..."
if ! [ -d $DEST_DIR/Library/Preferences ];then
	$MKDIR_CMD -v $DEST_DIR/Library/Preferences || exit 1
fi
$CP_CMD ${SOURCES_DIR}/GlobalDefaults.plist $DEST_DIR/Library/Preferences || exit 1

#----------------------------------------
# Install services
#----------------------------------------
$CP_CMD ${SOURCES_DIR}/gpbs.service $DEST_DIR/usr/NextSpace/lib/systemd || exit 1

if [ "$DEST_DIR" = "" ] && [ "$GITHUB_ACTIONS" != "true" ]; then
	sudo ldconfig
	sudo systemctl daemon-reload || exit 1
	systemctl status gpbs || sudo systemctl enable /usr/NextSpace/lib/systemd/gpbs.service;
fi
