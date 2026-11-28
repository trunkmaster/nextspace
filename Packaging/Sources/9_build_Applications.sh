#!/bin/sh

. ../environment.sh
. /etc/profile.d/nextspace.sh

_PWD=`pwd`

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing ${OS_ID} packages for NextSpace applications build"
if is_debian_like; then
	${ECHO} "Debian-based Linux distribution: calling 'apt-get install'."
	install_apt_packages ${APPS_BUILD_DEPS}
	install_apt_packages ${APPS_RUN_DEPS}
else
	${ECHO} "RedHat-based Linux distribution: calling 'sudo ${RPM_PACKAGE_MANAGER} -y install'."
	SPEC_FILE=${PROJECT_DIR}/Packaging/RedHat/SPECS/nextspace-applications.spec
	install_rpm_spec_buildrequires "${SPEC_FILE}" "nextspace" "corefoundation"
	install_rpm_spec_requires "${SPEC_FILE}" "corefoundation" "nextspace"
fi

#----------------------------------------
# Download
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}
APP_BUILD_DIR=${BUILD_ROOT}/Applications
GORM_BUILD_DIR=${BUILD_ROOT}/gorm-${gorm_version}
PC_BUILD_DIR=${BUILD_ROOT}/projectcenter-${projectcenter_version}

copy_clean_build_tree "${SOURCES_DIR}/Applications" "${APP_BUILD_DIR}"

# GORM
rm -rf "${GORM_BUILD_DIR}" 2>/dev/null
git_remote_archive https://github.com/gnustep/apps-gorm ${GORM_BUILD_DIR} gorm-${gorm_version}

# ProjectCenter
rm -rf "${PC_BUILD_DIR}" 2>/dev/null
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
run_install || exit

export GNUSTEP_INSTALLATION_DOMAIN=NETWORK
cd ${GORM_BUILD_DIR}
tar zxf ${SOURCES_DIR}/Libraries/gnustep/gorm-images.tar.gz
patch -p1 < ${SOURCES_DIR}/Libraries/gnustep/gorm.patch
$MAKE_CMD
run_install || exit

cd ${PC_BUILD_DIR}
tar zxf ${SOURCES_DIR}/Libraries/gnustep/projectcenter-images.tar.gz
patch -p1 < ${SOURCES_DIR}/Libraries/gnustep/pc.patch
$MAKE_CMD
run_install || exit

refresh_ldconfig

#----------------------------------------
# Post install
#----------------------------------------
if [ "$DEST_DIR" = "" ] && [ "$GITHUB_ACTIONS" != "true" ] && [ "$CI" != "true" ]; then
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

	# SELinux
	if [ -f /etc/selinux/config ]; then
		SELINUX_STATE=`grep "^SELINUX=.*" /etc/selinux/config | awk -F= '{print $2}'`
		if [ "${SELINUX_STATE}" != "disabled" ]; then
			${ECHO_N} "SELinux enabled - dissabling it..."
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
