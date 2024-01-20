#!/bin/sh

. ./versions.inc.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
if [ ${OS_NAME} != "debian" ] || [ ${OS_NAME} != "ubuntu" ]; then
	${ECHO} ">>> Installing ${OS_NAME} packages for CoreFoundation build"
	${ECHO} "RedHat-based Linux distribution: calling 'yum -y install'."
	SPEC_FILE=${PROJECT_DIR}/Libraries/libcorefoundation/libcorefoundation.spec
	DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | grep -v "libdispatch-devel" |awk -c '{print $1}'`
	sudo yum -y install ${DEPS} || exit 1
fi

#----------------------------------------
# Download
#----------------------------------------
GIT_PKG_NAME=apple-corefoundation-${libcorefoundation_version}

if [ ! -d ${BUILD_ROOT}/${GIT_PKG_NAME} ]; then
	git clone --depth 1 https://github.com/trunkmaster/apple-corefoundation ${BUILD_ROOT}/${GIT_PKG_NAME}
fi

#----------------------------------------
# Build
#----------------------------------------
cd ${BUILD_ROOT}/${GIT_PKG_NAME} || exit 1
rm -rf CoreFoundation/_build 2>/dev/null
mkdir -p CoreFoundation/_build
cd CoreFoundation/_build
C_FLAGS="-I/usr/NextSpace/include -Wno-switch"
cmake .. \
	-DCMAKE_C_COMPILER=${C_COMPILER} \
	-DCMAKE_C_FLAGS=${C_FLAGS} \
	-DCMAKE_SHARED_LINKER_FLAGS="-L/usr/NextSpace/lib -luuid" \
	-DCF_DEPLOYMENT_SWIFT=NO \
	-DBUILD_SHARED_LIBS=YES \
	-DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
	-DCMAKE_INSTALL_LIBDIR=/usr/NextSpace/lib \
	-DCMAKE_LIBRARY_PATH=/usr/NextSpace/lib \
	\
	-DCMAKE_SKIP_RPATH=ON \
	-DCMAKE_BUILD_TYPE=Debug \
	|| exit 1
#	-DCMAKE_LINKER=/usr/bin/ld.gold \

$MAKE_CMD clean
$MAKE_CMD || exit 1

#----------------------------------------
# Install
#----------------------------------------
sudo $MAKE_CMD install
sudo mkdir -p /usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/${libcorefoundation_version}
sudo cp -R CoreFoundation.framework/Headers /usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/${libcorefoundation_version}
sudo cp -R CoreFoundation.framework/libCoreFoundation.so /usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/${libcorefoundation_version}/libCoreFoundation.so.${libcorefoundation_version}
cd /usr/NextSpace/Frameworks/CoreFoundation.framework/Versions
sudo ln -sf ${libcorefoundation_version} Current
cd ..
sudo ln -sf Versions/Current/Headers Headers
sudo ln -sf Versions/Current/libCoreFoundation.so.${libcorefoundation_version} libCoreFoundation.so
# lib
sudo mkdir -p /usr/NextSpace/lib
cd /usr/NextSpace/lib
sudo ln -sf ../Frameworks/CoreFoundation.framework/libCoreFoundation.so libCoreFoundation.so
# include
sudo mkdir -p /usr/NextSpace/include
cd /usr/NextSpace/include
sudo ln -sf ../Frameworks/CoreFoundation.framework/Headers CoreFoundation

sudo ldconfig
