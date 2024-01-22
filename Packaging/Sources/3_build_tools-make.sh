#!/bin/sh

. ./versions.inc.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing ${OS_NAME} packages for GNUstep Make build"
if [ ${OS_NAME} = "debian" ] || [ ${OS_NAME} = "ubuntu" ]; then
	${ECHO} "Debian-based Linux distribution: calling 'apt-get install'."
	sudo apt-get install -y ${GNUSTEP_MAKE_DEPS} || exit 1
else
	${ECHO} "RedHat-based Linux distribution: calling 'yum -y install'."
	SPEC_FILE=${PROJECT_DIR}/Core/nextspace-core.spec
	DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | grep -v libobjc2 | grep -v "libdispatch-devel" | awk -c '{print $1}'`
	sudo yum -y install ${DEPS} || exit 1
fi

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
