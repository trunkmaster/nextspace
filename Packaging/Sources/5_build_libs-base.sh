#!/bin/sh

. ../environment.sh
. /Developer/Makefiles/GNUstep.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing ${OS_ID} packages for GNUstep Base (Foundation) build"
if is_debian_like; then
	${ECHO} "Debian-based Linux distribution: calling 'apt-get install'."
	install_apt_packages ${GNUSTEP_BASE_DEPS}
else
	${ECHO} "RedHat-based Linux distribution: calling 'sudo ${RPM_PACKAGE_MANAGER} -y install'."
	SPEC_FILE=${PROJECT_DIR}/Packaging/RedHat/SPECS/nextspace-gnustep.spec
	install_rpm_spec_buildrequires "${SPEC_FILE}" "libobjc2"
fi

#----------------------------------------
# Download
#----------------------------------------
GIT_PKG_NAME=libs-base-base-${gnustep_base_version}

if [ ! -d ${BUILD_ROOT}/${GIT_PKG_NAME} ]; then
	download_tarball_once \
		"https://github.com/gnustep/libs-base/archive/base-${gnustep_base_version}.tar.gz" \
		"${BUILD_ROOT}/${GIT_PKG_NAME}.tar.gz" \
		"${BUILD_ROOT}/${GIT_PKG_NAME}"
fi

#----------------------------------------
# Build
#----------------------------------------
cd ${BUILD_ROOT}/${GIT_PKG_NAME} || exit 1
if [ -d obj ]; then
	$MAKE_CMD clean
fi
./configure || exit 1
$MAKE_CMD || exit 1

#----------------------------------------
# Install
#----------------------------------------
run_install
cd ${_PWD}

#----------------------------------------
# Install services
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}/Libraries/gnustep

$MKDIR_CMD $DEST_DIR/usr/NextSpace/etc
$CP_CMD ${SOURCES_DIR}/gdomap.interfaces $DEST_DIR/usr/NextSpace/etc/
$MKDIR_CMD $DEST_DIR/usr/NextSpace/lib/systemd
$CP_CMD ${SOURCES_DIR}/gdomap.service $DEST_DIR/usr/NextSpace/lib/systemd
$CP_CMD ${SOURCES_DIR}/gdnc.service $DEST_DIR/usr/NextSpace/lib/systemd
$CP_CMD ${SOURCES_DIR}/gdnc-local.service $DEST_DIR/usr/NextSpace/lib/systemd

if [ "$DEST_DIR" = "" ] && [ "$GITHUB_ACTIONS" != "true" ] && [ "$CI" != "true" ]; then
	refresh_ldconfig
	reload_systemd_if_live
	enable_service_once gdomap /usr/NextSpace/lib/systemd/gdomap.service
	enable_service_once gdnc /usr/NextSpace/lib/systemd/gdnc.service
	enable_service_once gdnc-local /usr/NextSpace/lib/systemd/gdnc-local.service
fi
