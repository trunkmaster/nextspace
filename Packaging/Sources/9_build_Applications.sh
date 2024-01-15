#!/bin/sh

. ./versions.inc.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing packages for NextSpace applications build"
sudo apt-get install -y ${APPS_BUILD_DEPS}
sudo apt-get install -y ${APPS_RUN_DEPS}


#----------------------------------------
# Download
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}
APP_BUILD_DIR=${BUILD_ROOT}/Applications
GORM_BUILD_DIR=${BUILD_ROOT}/gorm-${gorm_version}
PC_BUILD_DIR=${BUILD_ROOT}/projectcenter-${projectcenter_version}

if [ -d ${APP_BUILD_DIR} ]; then
  rm -rf ${APP_BUILD_DIR}
fi
cp -R ${SOURCES_DIR}/Applications ${BUILD_ROOT}

# GORM
if [ -d ${GORM_BUILD_DIR} ]; then
  rm -rf ${GORM_BUILD_DIR}
fi
git_remote_archive https://github.com/gnustep/apps-gorm ${GORM_BUILD_DIR} gorm-${gorm_version}

# ProjectCenter
if [ -d ${PC_BUILD_DIR} ]; then
  rm -rf ${PC_BUILD_DIR}
fi
git_remote_archive https://github.com/gnustep/apps-projectcenter ${PC_BUILD_DIR} projectcenter-${projectcenter_version}

#----------------------------------------
# Build
#----------------------------------------
. /Developer/Makefiles/GNUstep.sh

cd ${APP_BUILD_DIR}
$MAKE_CMD clean
$MAKE_CMD
sudo -E $MAKE_CMD install

export GNUSTEP_INSTALLATION_DOMAIN=NETWORK
cd ${GORM_BUILD_DIR}
tar zxf ${SOURCES_DIR}/Libraries/gnustep/gorm-images.tar.gz
$MAKE_CMD
sudo -E $MAKE_CMD install

cd ${PC_BUILD_DIR}
tar zxf ${SOURCES_DIR}/Libraries/gnustep/projectcenter-images.tar.gz
$MAKE_CMD
sudo -E $MAKE_CMD install

sudo ldconfig

#----------------------------------------
# Post install
#----------------------------------------
sudo systemctl enable /usr/NextSpace/Apps/Login.app/Resources/loginwindow.service
sudo systemctl set-default graphical.target