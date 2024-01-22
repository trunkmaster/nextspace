#!/bin/sh

. ./versions.inc.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing ${OS_NAME} packages for Grand Central Dispatch build"
if [ ${OS_NAME} = "debian" ] || [ ${OS_NAME} = "ubuntu" ]; then
	${ECHO} "Debian-based Linux distribution: calling 'apt-get install'."
	sudo apt-get install -y ${BUILD_TOOLS} ${RUNTIME_DEPS} || exit 1
else
	${ECHO} "RedHat-based Linux distribution: calling 'yum -y install'."
	SPEC_FILE=${PROJECT_DIR}/Libraries/libdispatch/libdispatch.spec
	DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
	sudo yum -y install ${DEPS} || exit 1
fi

#----------------------------------------
# Download
#----------------------------------------
GIT_PKG_NAME=swift-corelibs-libdispatch-swift-${libdispatch_version}-RELEASE

if [ ! -d ${BUILD_ROOT}/${GIT_PKG_NAME} ]; then
	curl -L https://github.com/apple/swift-corelibs-libdispatch/archive/swift-${libdispatch_version}-RELEASE.tar.gz -o ${BUILD_ROOT}/${GIT_PKG_NAME}.tar.gz
	cd ${BUILD_ROOT}
	tar zxf ${GIT_PKG_NAME}.tar.gz
	cd ..
fi

#----------------------------------------
# Build
#----------------------------------------
cd ${BUILD_ROOT}/${GIT_PKG_NAME} || exit 1
if [ "${OS_NAME}" = "centos" ] && [ "${OS_VERSION}" = "7" ]; then
	patch -p1 < ${PROJECT_DIR}/Libraries/libdispatch/libdispatch-dispatch.h.patch
fi
rm -rf _build 2>/dev/null
mkdir -p _build
cd _build

C_FLAGS="-Wno-error=unused-but-set-variable"
$CMAKE_CMD .. \
	-DCMAKE_C_COMPILER=${C_COMPILER} \
	-DCMAKE_CXX_COMPILER=${CXX_COMPILER} \
	-DCMAKE_C_FLAGS=${C_FLAGS} \
	-DCMAKE_CXX_FLAGS=${C_FLAGS} \
	-DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
	-DCMAKE_INSTALL_LIBDIR=/usr/NextSpace/lib \
	-DCMAKE_INSTALL_MANDIR=/usr/NextSpace/Documentation/man \
	-DINSTALL_PRIVATE_HEADERS=YES \
	-DBUILD_TESTING=OFF \
	\
	-DCMAKE_SKIP_RPATH=ON \
	-DCMAKE_BUILD_TYPE=Debug \
	|| exit 1
#	-DCMAKE_LINKER=/usr/bin/ld.gold \

$MAKE_CMD clean
$MAKE_CMD

#----------------------------------------
# Install
#----------------------------------------
sudo $MAKE_CMD install

#----------------------------------------
# Postinstall
#----------------------------------------
sudo rm /usr/NextSpace/include/Block_private.h

sudo mv /usr/NextSpace/lib/libBlocksRuntime.so /usr/NextSpace/lib/libBlocksRuntime.so.${libdispatch_version}
sudo ln -s /usr/NextSpace/lib/libBlocksRuntime.so.${libdispatch_version} /usr/NextSpace/lib/libBlocksRuntime.so

sudo mv /usr/NextSpace/lib/libdispatch.so /usr/NextSpace/lib/libdispatch.so.${libdispatch_version}
sudo ln -s /usr/NextSpace/lib/libdispatch.so.${libdispatch_version} /usr/NextSpace/lib/libdispatch.so

sudo ldconfig
