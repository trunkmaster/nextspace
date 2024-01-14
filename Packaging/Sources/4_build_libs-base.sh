#!/bin/bash

. ./versions.inc.sh
. /Developer/Makefiles/GNUstep.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Download
#----------------------------------------
GIT_PKG_NAME=libs-base-base-${gnustep_base_version}

if [ ! -d ${BUILD_ROOT}/${GIT_PKG_NAME} ]; then
	curl -L https://github.com/gnustep/libs-base/archive/base-${gnustep_base_version}.tar.gz -o ${BUILD_ROOT}/${GIT_PKG_NAME}.tar.gz
	cd ${BUILD_ROOT}
	tar zxf ${GIT_PKG_NAME}.tar.gz || exit 1
	cd ..
fi

#----------------------------------------
# Build
#----------------------------------------
cd ${BUILD_ROOT}/${GIT_PKG_NAME} || exit 1
if [ -d obj ]; then
    $MAKE_CMD clean
fi
./configure || exit 1
$MAKE_CMD 

#----------------------------------------
# Install
#----------------------------------------
sudo -E $MAKE_CMD install
sudo ldconfig
cd ${_PWD}

#----------------------------------------
# Install services
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}/Libraries/gnustep

sudo mkdir -p /usr/NextSpace/etc
sudo cp ${SOURCES_DIR}/gdomap.interfaces /usr/NextSpace/etc/
sudo mkdir -p /usr/NextSpace/lib/systemd
sudo cp ${SOURCES_DIR}/gdomap.service /usr/NextSpace/lib/systemd
sudo cp ${SOURCES_DIR}/gdnc.service /usr/NextSpace/lib/systemd
sudo cp ${SOURCES_DIR}/gdnc-local.service /usr/NextSpace/lib/systemd
sudo systemctl daemon-reload

systemctl status gdomap || sudo systemctl enable /usr/NextSpace/lib/systemd/gdomap.service;
systemctl status gdnc || sudo systemctl enable /usr/NextSpace/lib/systemd/gdnc.service;
sudo systemctl enable /usr/NextSpace/lib/systemd/gdnc-local.service;
sudo systemctl start gdomap gdnc