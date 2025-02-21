#!/bin/sh

. ../environment.sh
. /etc/profile.d/nextspace.sh

_PWD=`pwd`

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing ${OS_ID} packages for NextSpace applications build"
if [ ${OS_ID} = "debian" ] || [ ${OS_ID} = "ubuntu" ]; then
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
$INSTALL_CMD || exit

export GNUSTEP_INSTALLATION_DOMAIN=NETWORK
cd ${GORM_BUILD_DIR}
tar zxf ${SOURCES_DIR}/Libraries/gnustep/gorm-images.tar.gz
patch -p1 < ${SOURCES_DIR}/Libraries/gnustep/gorm.patch
$MAKE_CMD
$INSTALL_CMD || exit

cd ${PC_BUILD_DIR}
tar zxf ${SOURCES_DIR}/Libraries/gnustep/projectcenter-images.tar.gz
patch -p1 < ${SOURCES_DIR}/Libraries/gnustep/pc.patch
$MAKE_CMD
$INSTALL_CMD || exit

sudo ldconfig

#----------------------------------------
# Post install
#----------------------------------------

if [ "$DEST_DIR" = "" ] && [ "$GITHUB_ACTIONS" != "true" ]; then
	# Login
	${ECHO} "Setting up Login window service to run at system startup..."
	systemctl --quiet is-active display-manager.service
	if [ $? -eq 0 ];then
		${ECHO} "A Display Manager is already running: we must stop it now."
		sudo systemctl stop display-manager.service
	fi

	systemctl --quiet is-enabled display-manager.service
	if [ $? -eq 0 ];then
		${ECHO} "A display Manager is already set: we must disable it now."
		sudo systemctl disable display-manager.service
	fi
	${ECHO} "Setting up Login window service..."
	sudo systemctl enable /usr/NextSpace/lib/systemd/loginwindow.service
	sudo systemctl set-default graphical.target

	# SELinux
	if [ -f /etc/selinux/config ]; then
		SELINUX_STATE=`grep "^SELINUX=.*" /etc/selinux/config | awk -F= '{print $2}'`
		if [ "${SELINUX_STATE}" != "disabled" ]; then
			${ECHO} -n "SELinux enabled - dissabling it..."
			sudo sed -i -e ' s/SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
			${ECHO} "done"
			${ECHO} "Please reboot to apply changes."
		fi
	fi
fi

cd ${_PWD} || exit 1

#---------------------------------------
# Inform about the RPI flickering issue
#---------------------------------------

if [ "$MACHINE" = "aarch64" ] && [ "$MODEL" = "Raspberry" ] && [ "$GPU" = "bcm2711" ];then
	if [ -f ${_PWD}/rpi_info.sh ];then
		. "${_PWD}/rpi_info.sh"
	fi
fi