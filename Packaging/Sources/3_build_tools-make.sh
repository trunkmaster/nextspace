#!/bin/sh

. ../environment.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing ${OS_ID} packages for GNUstep Make build"
if is_debian_like; then
	${ECHO} "Debian-based Linux distribution: calling 'apt-get install'."
	install_apt_packages ${GNUSTEP_MAKE_DEPS}
else
	${ECHO} "RedHat-based Linux distribution: calling 'sudo ${RPM_PACKAGE_MANAGER} -y install'."
	SPEC_FILE=${PROJECT_DIR}/Packaging/RedHat/SPECS/nextspace-core.spec
	install_rpm_spec_buildrequires "${SPEC_FILE}" "libobjc2" "libdispatch-devel"
fi

#----------------------------------------
# Download
#----------------------------------------
GIT_PKG_NAME=tools-make-make-${gnustep_make_version}
if [ ! -d ${BUILD_ROOT}/${GIT_PKG_NAME} ]; then
	download_tarball_once \
		"https://github.com/gnustep/tools-make/archive/make-${gnustep_make_version}.tar.gz" \
		"${BUILD_ROOT}/${GIT_PKG_NAME}.tar.gz" \
		"${BUILD_ROOT}/${GIT_PKG_NAME}"
fi

#----------------------------------------
# Build
#----------------------------------------
cd ${BUILD_ROOT}/${GIT_PKG_NAME}
$MAKE_CMD clean
#export RUNTIME_VERSION="gnustep-1.8"
export PKG_CONFIG_PATH="/usr/NextSpace/lib/pkgconfig"
export CC=clang
export CXX=clang++
export CFLAGS="-F/usr/NextSpace/Frameworks"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"/usr/NextSpace/lib"

cp ${PROJECT_DIR}/Libraries/gnustep/nextspace.fsl ${BUILD_ROOT}/tools-make-make-${gnustep_make_version}/FilesystemLayouts/nextspace
./configure \
	--prefix=/ \
	--with-config-file=/Library/Preferences/GNUstep.conf \
	--with-layout=nextspace \
	--enable-native-objc-exceptions \
	--enable-debug-by-default \
	--with-library-combo=ng-gnu-gnu

#----------------------------------------
# Install
#----------------------------------------
run_install || exit 1
cd ${_PWD}
