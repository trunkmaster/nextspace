#!/bin/sh

. ./versions.inc.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing ${OS_NAME} packages for NextSpace applications build"
if [ ${OS_NAME} = "debian" ] || [ ${OS_NAME} = "ubuntu" ]; then
	${ECHO} "Debian-based Linux distribution: calling 'apt-get install'."
	sudo apt-get install -y ${APPS_BUILD_DEPS}
	sudo apt-get install -y ${APPS_RUN_DEPS}
else
	${ECHO} "RedHat-based Linux distribution: calling 'yum -y install'."
	SPEC_FILE=${PROJECT_DIR}/Applications/nextspace-applications.spec
	DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | grep -v "nextspace" | grep -v "corefoundation" | awk -c '{print $1}'`
	sudo yum -y install ${DEPS} || exit 1
	DEPS=`rpmspec -q --requires ${SPEC_FILE} | grep -v corefoundation | grep -v nextspace`
	sudo yum -y install ${DEPS} || exit 1
fi

#----------------------------------------
# Download
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}
APP_BUILD_DIR=${BUILD_ROOT}/Applications
GORM_BUILD_DIR=${BUILD_ROOT}/gorm-${gorm_version}
PC_BUILD_DIR=${BUILD_ROOT}/projectcenter-${projectcenter_version}

if [ -d ${APP_BUILD_DIR} ]; then
	sudo rm -rf ${APP_BUILD_DIR}
fi
cp -R ${SOURCES_DIR}/Applications ${BUILD_ROOT}

# GORM
if [ -d ${GORM_BUILD_DIR} ]; then
	sudo rm -rf ${GORM_BUILD_DIR}
fi
git_remote_archive https://github.com/gnustep/apps-gorm ${GORM_BUILD_DIR} gorm-${gorm_version}

# ProjectCenter
if [ -d ${PC_BUILD_DIR} ]; then
	sudo rm -rf ${PC_BUILD_DIR}
fi
git_remote_archive https://github.com/gnustep/apps-projectcenter ${PC_BUILD_DIR} projectcenter-${projectcenter_version}

#----------------------------------------
# Build
#----------------------------------------
. /Developer/Makefiles/GNUstep.sh

cd ${APP_BUILD_DIR}
export CC=${C_COMPILER}
export CMAKE=${CMAKE_CMD}
$MAKE_CMD clean
$MAKE_CMD || exit 1
sudo -E $MAKE_CMD install || exit

export GNUSTEP_INSTALLATION_DOMAIN=NETWORK
cd ${GORM_BUILD_DIR}
tar zxf ${SOURCES_DIR}/Libraries/gnustep/gorm-images.tar.gz
$MAKE_CMD
sudo -E $MAKE_CMD install || exit

cd ${PC_BUILD_DIR}
tar zxf ${SOURCES_DIR}/Libraries/gnustep/projectcenter-images.tar.gz
$MAKE_CMD
sudo -E $MAKE_CMD install || exit

sudo ldconfig

#----------------------------------------
# Post install
#----------------------------------------
sudo systemctl enable /usr/NextSpace/Apps/Login.app/Resources/loginwindow.service
sudo systemctl set-default graphical.target