#!/bin/sh

. ../environment.sh
. /etc/profile.d/nextspace.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing ${OS_ID} packages for WRaster library build"
if [ ${OS_ID} = "debian" ] || [ ${OS_ID} = "ubuntu" ]; then
	${ECHO} "Debian-based Linux distribution: calling 'apt-get install'."
	sudo apt-get install -y ${WRASTER_DEPS} || exit 1
else
	${ECHO} "RedHat-based Linux distribution: calling 'yum -y install'."
	SPEC_FILE=${PROJECT_DIR}/Libraries/libwraster/libwraster.spec
	DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | grep -v nextspace-core-devel | awk -c '{print $1}'`
	sudo yum -y install ${DEPS} || exit 1
fi

#---------------------------------------------------------
# Solving deprecated dependency
# with libjpeg8 and libtiff5
# in WRASTER_RUN_DEPS
# Instead, libjpeg62(-turbo) and libtiff6 were installed
#---------------------------------------------------------

if [ ${OS_ID} = "debian" ];then
	# libjpeg8 --> libjpeg62
	if [ -f "/usr/lib/${MACHINE}-linux-gnu/libjpeg.so.62" ];then
		sudo ln -s "/usr/lib/${MACHINE}-linux-gnu/libjpeg.so.8" "/usr/lib/${MACHINE}-linux-gnu/libjpeg.so.62"
		${ECHO} "Symbolic link added for libjpeg.so.8"
	else
		${ECHO} "You need to find 'libjpeg.so.62' path fisrt !"
		${ECHO} "Aborting building..."
		exit 1
	fi
	# Libtiff5 --> Libtiff6
	if [ -f "/usr/lib/${MACHINE}-linux-gnu/libtiff.so.6" ];then
		sudo ln -s "/usr/lib/${MACHINE}-linux-gnu/libtiff.so.5" "/usr/lib/${MACHINE}-linux-gnu/libtiff.so.6"
		${ECHO} "Symbolic link added for libtiff.so.5"
	else
		${ECHO} "You need to find 'libtiff.so.6' path first !"
		${ECHO} "Aborting building..."
		exit 1
	fi
fi

#----------------------------------------
# Download
#----------------------------------------
SOURCES_DIR=${PROJECT_DIR}/Libraries/libwraster
BUILD_DIR=${BUILD_ROOT}/libwraster

if [ -d ${BUILD_DIR} ]; then
	rm -rf ${BUILD_DIR}
fi
cp -R ${SOURCES_DIR} ${BUILD_ROOT}

#----------------------------------------
# Build
#----------------------------------------
. /Developer/Makefiles/GNUstep.sh
cd ${BUILD_DIR}
export CC=${C_COMPILER}
export CMAKE=${CMAKE_CMD}
export QA_SKIP_BUILD_ROOT=1

$MAKE_CMD || exit 1
$INSTALL_CMD || exit 1

if [ "$DEST_DIR" = "" ]; then
	sudo ldconfig
fi
