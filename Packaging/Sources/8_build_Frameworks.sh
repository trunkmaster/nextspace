#!/bin/sh

. ./versions.inc.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing ${OS_NAME} packages for NextSpace frameworks build"
if [ ${OS_NAME} = "debian" ] || [ ${OS_NAME} = "ubuntu" ]; then
	${ECHO} "Debian-based Linux distribution: calling 'apt-get install'."
  sudo apt-get install -y ${FRAMEWORKS_BUILD_DEPS}
  sudo apt-get install -y ${FRAMEWORKS_RUN_DEPS}
else
	${ECHO} "RedHat-based Linux distribution: calling 'yum -y install'."
	SPEC_FILE=${PROJECT_DIR}/Frameworks/nextspace-frameworks.spec
	DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | grep -v "nextspace" | awk -c '{print $1}'`
	sudo yum -y install ${DEPS} || exit 1
fi

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
sudo -E $MAKE_CMD install
sudo ldconfig