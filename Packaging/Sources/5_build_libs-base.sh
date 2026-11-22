#!/bin/sh

. ../environment.sh
. /Developer/Makefiles/GNUstep.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing ${OS_ID} packages for GNUstep Base (Foundation) build"
if [ ${OS_ID} = "freebsd" ]; then
	${ECHO} "FreeBSD: calling 'pkg install'..."
	sudo pkg install --yes --quiet ${GNUSTEP_BASE_DEPS}
elif [ ${OS_ID} = "debian" ] || [ ${OS_ID} = "ubuntu" ]; then
	${ECHO} "Debian-based Linux distribution: calling 'apt-get install'."
	sudo apt-get install -y ${GNUSTEP_BASE_DEPS} || exit 1
else
	${ECHO} "RedHat-based Linux distribution: calling 'yum -y install'."
	SPEC_FILE=${PROJECT_DIR}/Packaging/RedHat/SPECS/nextspace-gnustep.spec
	DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | grep -v libobjc2 | awk -c '{print $1}'`
	sudo yum -y install ${DEPS} || exit 1
fi

#----------------------------------------
# Download
#----------------------------------------
GIT_PKG_NAME=libs-base-base-${gnustep_base_version}

if [ ! -d ${BUILD_ROOT}/${GIT_PKG_NAME} ]; then
	curl -L https://github.com/gnustep/libs-base/archive/base-${gnustep_base_version}.tar.gz -o ${BUILD_ROOT}/${GIT_PKG_NAME}.tar.gz
	cd ${BUILD_ROOT}
	tar zxf ${GIT_PKG_NAME}.tar.gz || exit 1
	if [ ${OS_ID} = "freebsd" ]; then
		# FreeBSD: CPU-peg drainer fix + NSTask fork/reap race fix.
		cd ${GIT_PKG_NAME}
		patch -N -p0 < ${PROJECT_DIR}/Libraries/gnustep/libs-base_NSRunLoop-mainqueue-freebsd.patch || exit 1
		patch -N -p0 < ${PROJECT_DIR}/Libraries/gnustep/libs-base_NSTask-freebsd-registration.patch || exit 1
		cd ..
	fi
	cd ..
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
$INSTALL_CMD
cd ${_PWD}

#----------------------------------------
# Install services
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}/Libraries/gnustep
$MKDIR_CMD $DEST_DIR${NEXTSPACE_PREFIX}/etc
$CP_CMD ${SOURCES_DIR}/gdomap.interfaces $DEST_DIR${NEXTSPACE_PREFIX}/etc/

if [ ${OS_ID} = "freebsd" ]; then
	${ECHO} "TODO: make FreeBSD services for GNUstep daemons..."
	sudo ${NEXTSPACE_PREFIX}/bin/gnustep-services start
else
	$MKDIR_CMD $DEST_DIR${NEXTSPACE_PREFIX}/lib/systemd
	$CP_CMD ${SOURCES_DIR}/gdomap.service $DEST_DIR${NEXTSPACE_PREFIX}/lib/systemd
	$CP_CMD ${SOURCES_DIR}/gdnc.service $DEST_DIR${NEXTSPACE_PREFIX}/lib/systemd
	$CP_CMD ${SOURCES_DIR}/gdnc-local.service $DEST_DIR${NEXTSPACE_PREFIX}/lib/systemd

	if [ "$DEST_DIR" = "" ] && [ "$GITHUB_ACTIONS" != "true" ]; then
		sudo ldconfig
		sudo systemctl daemon-reload
		systemctl status gdomap || sudo systemctl enable ${NEXTSPACE_PREFIX}/lib/systemd/gdomap.service;
		systemctl status gdnc || sudo systemctl enable ${NEXTSPACE_PREFIX}/lib/systemd/gdnc.service;
		sudo systemctl enable ${NEXTSPACE_PREFIX}/lib/systemd/gdnc-local.service;
		sudo systemctl start gdomap gdnc
	fi
fi