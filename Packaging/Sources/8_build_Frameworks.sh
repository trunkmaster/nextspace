#!/bin/sh

. ../environment.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing ${OS_ID} packages for NextSpace frameworks build"
if is_debian_like; then
	${ECHO} "Debian-based Linux distribution: calling 'apt-get install'."
	install_apt_packages ${FRAMEWORKS_BUILD_DEPS}
	install_apt_packages ${FRAMEWORKS_RUN_DEPS}
else
	${ECHO} "RedHat-based Linux distribution: calling 'sudo ${RPM_PACKAGE_MANAGER} -y install'."
	SPEC_FILE=${PROJECT_DIR}/Packaging/RedHat/SPECS/nextspace-frameworks.spec
	install_rpm_spec_buildrequires "${SPEC_FILE}" "nextspace"
	install_rpm_spec_requires "${SPEC_FILE}" "corefoundation" "nextspace"
fi

#----------------------------------------
# Download
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}/Frameworks
BUILD_DIR=${BUILD_ROOT}/Frameworks

copy_clean_build_tree "${SOURCES_DIR}" "${BUILD_DIR}"

#----------------------------------------
# Build
#----------------------------------------
. /Developer/Makefiles/GNUstep.sh
cd ${BUILD_DIR}

$MAKE_CMD clean
$MAKE_CMD || exit 1

#----------------------------------------
# Install
#----------------------------------------
run_install
if [ "$DEST_DIR" = "" ]; then
	refresh_ldconfig
	$LN_CMD /usr/NextSpace/Frameworks/DesktopKit.framework/Resources/25-nextspace-fonts.conf /etc/fonts/conf.d/25-nextspace-fonts.conf
fi
