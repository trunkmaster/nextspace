#!/bin/sh

. ../environment.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing ${OS_ID} packages for WRaster library build"
if is_debian_like; then
	${ECHO} "Debian-based Linux distribution: calling 'apt-get install'."
	install_apt_packages ${WRASTER_DEPS}
else
	${ECHO} "RedHat-based Linux distribution: calling 'sudo ${RPM_PACKAGE_MANAGER} -y install'."
	SPEC_FILE=${PROJECT_DIR}/Packaging/RedHat/SPECS/libwraster.spec
	install_rpm_spec_buildrequires "${SPEC_FILE}" "nextspace-core-devel"
fi


#----------------------------------------
# Download
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}/Libraries/libwraster
BUILD_DIR=${BUILD_ROOT}/libwraster

copy_clean_build_tree "${SOURCES_DIR}" "${BUILD_DIR}"

#----------------------------------------
# Build
#----------------------------------------
. /Developer/Makefiles/GNUstep.sh
cd ${BUILD_DIR}
export CC=${C_COMPILER}
export CMAKE=${CMAKE_CMD}
export QA_SKIP_BUILD_ROOT=1

$MAKE_CMD || exit 1
run_install || exit 1

refresh_ldconfig
