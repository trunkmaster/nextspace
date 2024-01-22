#!/bin/sh

. ./versions.inc.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing packages for libwraster build"
sudo apt-get install -y ${WRASTER_DEPS}

${ECHO} ">>> Installing ${OS_NAME} packages for WRaster library build"
if [ ${OS_NAME} = "debian" ] || [ ${OS_NAME} = "ubuntu" ]; then
	${ECHO} "Debian-based Linux distribution: calling 'apt-get install'."
	sudo apt-get install -y ${WRASTER_DEPS} || exit 1
else
	${ECHO} "RedHat-based Linux distribution: calling 'yum -y install'."
	SPEC_FILE=${PROJECT_DIR}/Libraries/libwraster/libwraster.spec
	DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | grep -v nextspace-core-devel | awk -c '{print $1}'`
	sudo yum -y install ${DEPS} || exit 1
fi


#----------------------------------------
# Download
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}/Libraries/libwraster
BUILD_DIR=${BUILD_ROOT}/libwraster

if [ -d ${BUILD_DIR} ]; then
  rm -rf ${BUILD_DIR}
fi
cp -R ${SOURCES_DIR} ${BUILD_ROOT}

#----------------------------------------
# Build
#----------------------------------------
. /Developer/Makefiles/GNUstep.sh
cd ${BUILD_DIR}
export CC=${C_COMPILER}
export CMAKE=${CMAKE_CMD}
export QA_SKIP_BUILD_ROOT=1

$MAKE_CMD
sudo -E $MAKE_CMD install
sudo ldconfig