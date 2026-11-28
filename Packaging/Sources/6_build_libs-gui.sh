#!/bin/sh

. ../environment.sh
. /Developer/Makefiles/GNUstep.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
if is_debian_like; then
  	${ECHO} ">>> Installing packages for GNUstep GUI (AppKit) build"
	install_apt_packages ${GNUSTEP_GUI_DEPS}
fi

#----------------------------------------
# Download
#----------------------------------------
GIT_PKG_NAME=libs-gui-gui-${gnustep_gui_version}
SOURCES_DIR=${PROJECT_DIR}/Libraries/gnustep

if [ ! -d ${BUILD_ROOT}/${GIT_PKG_NAME} ]; then
	download_tarball_once \
		"https://github.com/gnustep/libs-gui/archive/gui-${gnustep_gui_version}.tar.gz" \
		"${BUILD_ROOT}/${GIT_PKG_NAME}.tar.gz" \
		"${BUILD_ROOT}/${GIT_PKG_NAME}"
	# Patches
	cd ${BUILD_ROOT}/${GIT_PKG_NAME}
	patch -p1 < ${SOURCES_DIR}/libs-gui_NSApplication.patch
	patch -p1 < ${SOURCES_DIR}/libs-gui_NSPopUpButton.patch
	patch -p1 < ${SOURCES_DIR}/libs-gui_GSThemeDrawing.patch
#	cd Images
#	tar zxf ${SOURCES_DIR}/gnustep-gui-images.tar.gz
fi

#----------------------------------------
# Build
#----------------------------------------
cd ${BUILD_ROOT}/${GIT_PKG_NAME} || exit 1
if [ -d obj ]; then
	$MAKE_CMD clean
fi
if is_debian_like; then
	./configure --disable-icu-config || exit 1
else
	./configure || exit 1
fi
$MAKE_CMD || exit 1

#----------------------------------------
# Install
#----------------------------------------
run_install || exit 1
# libwraster crashes on loading default GNUstep common_Tile.tiff.
# Replace it in case when NextSpace theme will be disabled.
print_H2 "Replacing /Library/Images/common_Tile.tiff..."
$CP_CMD -f -v ${SOURCES_DIR}/nextspace-theme/Resources/ThemeImages/common_Tile.tiff /Library/Images || exit 1

#----------------------------------------
# Download theme
#----------------------------------------
THEME_SOURCES_DIR=${SOURCES_DIR}/nextspace-theme
BUILD_DIR=${BUILD_ROOT}/nextspace-theme

copy_clean_build_tree "${THEME_SOURCES_DIR}" "${BUILD_DIR}"

#----------------------------------------
# Build and install theme
#----------------------------------------
cd ${BUILD_DIR} || exit 1
$MAKE_CMD || exit 1
run_install || exit 1

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

if [ "$DEST_DIR" = "" ] && [ "$GITHUB_ACTIONS" != "true" ] && [ "$CI" != "true" ]; then
	refresh_ldconfig
	reload_systemd_if_live
	enable_service_once gpbs /usr/NextSpace/lib/systemd/gpbs.service
fi
