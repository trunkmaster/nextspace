#!/bin/sh

. ./versions.inc.sh
. /Developer/Makefiles/GNUstep.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
if [ ${OS_NAME} = "debian" ] || [ ${OS_NAME} = "ubuntu" ]; then
  	${ECHO} ">>> Installing packages for GNUstep GUI (AppKit) build"
	sudo apt-get install -q -y ${GNUSTEP_GUI_DEPS}
fi

#----------------------------------------
# Download
#----------------------------------------
GIT_PKG_NAME=libs-gui-gui-${gnustep_gui_version}
SOURCES_DIR=${PROJECT_DIR}/Libraries/gnustep

if [ ! -d ${BUILD_ROOT}/${GIT_PKG_NAME} ]; then
	curl -L https://github.com/gnustep/libs-gui/archive/gui-${gnustep_gui_version}.tar.gz -o ${BUILD_ROOT}/${GIT_PKG_NAME}.tar.gz
	cd ${BUILD_ROOT}
	tar zxf ${GIT_PKG_NAME}.tar.gz || exit 1
	# Patches
	cd ${BUILD_ROOT}/${GIT_PKG_NAME}
	patch -p1 < ${SOURCES_DIR}/libs-gui_NSApplication.patch
	patch -p1 < ${SOURCES_DIR}/libs-gui_NSPopUpButton.patch
	cd Images
	tar zxf ${SOURCES_DIR}/gnustep-gui-images.tar.gz
fi

#----------------------------------------
# Build
#----------------------------------------
cd ${BUILD_ROOT}/${GIT_PKG_NAME} || exit 1
if [ -d obj ]; then
	$MAKE_CMD clean
fi
if [ ${OS_NAME} = "debian" ] || [ ${OS_NAME} = "ubuntu" ]; then
	./configure --disable-icu-config || exit 1
else
	./configure || exit 1
fi
$MAKE_CMD || exit 1

#----------------------------------------
# Install
#----------------------------------------
sudo -E $MAKE_CMD install
sudo ldconfig

#----------------------------------------
# Install services
#----------------------------------------
sudo cp ${SOURCES_DIR}/gpbs.service /usr/NextSpace/lib/systemd || exit 1
sudo systemctl daemon-reload || exit 1

systemctl status gpbs || sudo systemctl enable /usr/NextSpace/lib/systemd/gpbs.service;
