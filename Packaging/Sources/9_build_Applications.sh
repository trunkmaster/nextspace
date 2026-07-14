#!/bin/sh

. ../environment.sh
. /etc/profile.d/nextspace.sh

_PWD=`pwd`

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing packages for NextSpace applications build"
install_packages ${APPS_BUILD_DEPS} ${APPS_RUN_DEPS}

#----------------------------------------
# Sources (vendored; Gorm and ProjectCenter ride along in Applications/)
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}
APP_BUILD_DIR=${BUILD_ROOT}/Applications
GORM_BUILD_DIR=${APP_BUILD_DIR}/Gorm
PC_BUILD_DIR=${APP_BUILD_DIR}/ProjectCenter

if [ -d ${APP_BUILD_DIR} ]; then
	sudo rm -rf ${APP_BUILD_DIR}
fi
cp -R ${SOURCES_DIR}/Applications ${BUILD_ROOT}

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
$MAKE_CMD
$INSTALL_CMD || exit

cd ${PC_BUILD_DIR}
$MAKE_CMD
$INSTALL_CMD || exit

sudo ldconfig

#----------------------------------------
# Post install
#----------------------------------------
if [ "$DEST_DIR" = "" ] && [ "$GITHUB_ACTIONS" != "true" ]; then
	# Login
	systemctl --quiet is-active loginwindow.service
	if [ $? -eq 0 ];then
		${ECHO} "A Login panel is already running: refresh systemd unit info."
		sudo systemctl daemon-reload
	else
		print_H2 "Setting up Login window service to run at system startup..."
		systemctl --quiet is-active display-manager.service
		if [ $? -eq 0 ];then
			if [ -z $DISPLAY ];then
				print_H2 "A session manager is already running: we must stop it now."
				sudo systemctl stop display-manager.service
			else
				print_H1 "You're in graphical session.\nTo enable Login panel you need to execute the following commands in console:\n  $ sudo systemctl stop display-manager.service\n  $ sudo systemctl enable /usr/NextSpace/lib/systemd/loginwindow.service"
			fi
		else
			systemctl --quiet is-enabled display-manager.service
			if [ $? -eq 0 ];then
				print_H2 "A session manager is already set: we must disable it now."
				sudo systemctl disable display-manager.service
			fi
			${ECHO} "Setting up Login window service..."
			sudo systemctl enable /usr/NextSpace/lib/systemd/loginwindow.service
			sudo systemctl set-default graphical.target
		fi
	fi

fi

cd ${_PWD} || exit 1