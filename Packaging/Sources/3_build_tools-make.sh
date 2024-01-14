#!/bin/bash

. ./versions.inc.sh

#----------------------------------------
# Download
#----------------------------------------
GIT_PKG_NAME=tools-make-make-${gnustep_make_version}
CORE_SOURCES=${PROJECT_DIR}/Core

if [ ! -d ${BUILD_ROOT}/${GIT_PKG_NAME} ]; then
	curl -L https://github.com/gnustep/tools-make/archive/make-${gnustep_make_version}.tar.gz -o ${BUILD_ROOT}/${GIT_PKG_NAME}.tar.gz
	cd ${BUILD_ROOT}
	tar zxf ${GIT_PKG_NAME}.tar.gz || exit 1
	cd ..
fi

#----------------------------------------
# Build
#----------------------------------------
cd ${BUILD_ROOT}/${GIT_PKG_NAME}
#export RUNTIME_VERSION="-fobjc-runtime=gnustep-1.8"
$MAKE_CMD clean
export CC=clang
export CXX=clang++
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"/usr/NextSpace/lib"

cp ${CORE_SOURCES}/nextspace.fsl ${BUILD_ROOT}/tools-make-make-${gnustep_make_version}/FilesystemLayouts/nextspace
./configure \
	    --prefix=/ \
	    --with-config-file=/Library/Preferences/GNUstep.conf \
	    --with-layout=nextspace \
	    --enable-native-objc-exceptions \
	    --enable-debug-by-default \
	    --with-library-combo=ng-gnu-gnu

#----------------------------------------
# Install
#----------------------------------------
sudo $MAKE_CMD install
cd ${_PWD}

#----------------------------------------
# Install system configuration files
#----------------------------------------
CORE_SOURCES=${CORE_SOURCES}/os_files

sudo mkdir -p /Library/Preferences
sudo cp ${CORE_SOURCES}/Library/Preferences/* /Library/Preferences/

if [ -d /etc/ld.so.conf.d ];then
	sudo cp ${CORE_SOURCES}/etc/ld.so.conf.d/nextspace.conf /etc/ld.so.conf.d/
	sudo ldconfig
fi

sudo mkdir -p /etc/profile.d
sudo cp ${CORE_SOURCES}/etc/profile.d/nextspace.sh /etc/profile.d/

sudo mkdir -p /etc/skel
sudo cp -R ${CORE_SOURCES}/etc/skel/Library /etc/skel

sudo cp ${CORE_SOURCES}/usr/NextSpace/bin/* /usr/NextSpace/bin/

sudo cp -R ${CORE_SOURCES}/usr/share/* /usr/share/
