#!/bin/sh

. ../environment.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
if [ ${OS_ID} != "debian" ] && [ ${OS_ID} != "ubuntu" ]; then
	${ECHO} ">>> Installing ${OS_ID} packages for CoreFoundation build"
	${ECHO} "RedHat-based Linux distribution: calling 'yum -y install'."
	SPEC_FILE=${PROJECT_DIR}/Libraries/libcorefoundation/libcorefoundation.spec
	DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | grep -v "libdispatch-devel" |awk -c '{print $1}'`
	sudo yum -y install ${DEPS} git || exit 1
fi

#----------------------------------------
# Download
#----------------------------------------
if [ "${OS_ID}" = "centos" ] && [ "${OS_VERSION}" = "7" ]; then
	CF_PKG_NAME=swift-corelibs-foundation-swift-${libcorefoundation_version}-RELEASE
else
	CF_PKG_NAME=apple-corefoundation-${libcorefoundation_version}
	CFNET_PKG_NAME=apple-cfnetwork
fi

if [ ! -d ${BUILD_ROOT}/${CF_PKG_NAME} ]; then
	if [ "${OS_ID}" = "centos" ] && [ "${OS_VERSION}" = "7" ]; then
		curl -L https://github.com/apple/swift-corelibs-foundation/archive/swift-${libcorefoundation_version}-RELEASE.tar.gz -o ${BUILD_ROOT}/${CF_PKG_NAME}.tar.gz
		cd ${BUILD_ROOT}
		tar zxf ${CF_PKG_NAME}.tar.gz

		cd ${CF_PKG_NAME}
		SOURCES_DIR=${PROJECT_DIR}/Libraries/libcorefoundation
		patch -p1 < ${SOURCES_DIR}/CF_shared_on_linux.patch
		patch -p1 < ${SOURCES_DIR}/CF_centos7.patch
		patch -p1 < ${SOURCES_DIR}/CFString_centos.patch
		
		cp ${SOURCES_DIR}/CFNotificationCenter.c CoreFoundation/AppServices.subproj/
		patch -p1 < ${SOURCES_DIR}/CFNotificationCenter.patch

		cp ${SOURCES_DIR}/CFFileDescriptor.h CoreFoundation/RunLoop.subproj/
		cp ${SOURCES_DIR}/CFFileDescriptor.c CoreFoundation/RunLoop.subproj/
		patch -p1 < ${SOURCES_DIR}/CFFileDescriptor.patch

		cp CoreFoundation/Base.subproj/SwiftRuntime/TargetConditionals.h CoreFoundation/Base.subproj/

		cd ../..
	else
		git clone --depth 1 https://github.com/trunkmaster/apple-corefoundation ${BUILD_ROOT}/${CF_PKG_NAME}
		git clone --depth 1 https://github.com/trunkmaster/apple-cfnetwork ${BUILD_ROOT}/${CFNET_PKG_NAME}
	fi
fi

#----------------------------------------
# Build
#----------------------------------------
# CoreFoundation
cd ${BUILD_ROOT}/${CF_PKG_NAME} || exit 1
rm -rf .build 2>/dev/null
mkdir -p .build
cd .build
C_FLAGS="-I/usr/NextSpace/include -Wno-switch -Wno-enum-conversion"
if [ "${OS_ID}" != "centos" ] || [ "${OS_VERSION}" != "7" ]; then
	C_FLAGS="${C_FLAGS} -Wno-implicit-const-int-float-conversion"
fi
$CMAKE_CMD .. \
	-DCMAKE_C_COMPILER=${C_COMPILER} \
	-DCMAKE_C_FLAGS="${C_FLAGS}" \
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

$MAKE_CMD || exit 1

# CFNetwork
if [ -n  "$libcfnetwork_version" ]; then
	cd ${BUILD_ROOT}/${CFNET_PKG_NAME} || exit 1
	rm -rf .build 2>/dev/null
	mkdir -p .build
	cd .build
	CFN_CFLAGS="-F../../${CF_PKG_NAME}/.build -I/usr/NextSpace/include"
	CFN_LD_FLAGS="-L/usr/NextSpace/lib -L../../${CF_PKG_NAME}/.build/CoreFoundation.framework"
	cmake .. \
			-DCMAKE_C_COMPILER=${C_COMPILER} \
			-DCMAKE_CXX_COMPILER=clang++ \
			-DCFNETWORK_CFLAGS="${CFN_CFLAGS}" \
			-DCFNETWORK_LDLAGS="${CFN_LD_FLAGS}" \
			-DBUILD_SHARED_LIBS=YES \
			-DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
			-DCMAKE_INSTALL_LIBDIR=/usr/NextSpace/lib \
			\
			-DCMAKE_SKIP_RPATH=ON \
			-DCMAKE_BUILD_TYPE=Debug
	$MAKE_CMD || exit 1
fi

#----------------------------------------
# Install
#----------------------------------------

### CoreFoundation
cd ${BUILD_ROOT}/${CF_PKG_NAME}/.build || exit 1
$INSTALL_CMD

CF_DIR=${DEST_DIR}/usr/NextSpace/Frameworks/CoreFoundation.framework

$MKDIR_CMD ${CF_DIR}/Versions/${libcorefoundation_version}
cd $CF_DIR
# Headers
$MV_CMD Headers Versions/${libcorefoundation_version}
$LN_CMD Versions/Current/Headers Headers
cd Versions
$LN_CMD ${libcorefoundation_version} Current
cd ..
# Libraries
$MV_CMD libCoreFoundation.so* Versions/${libcorefoundation_version}
$LN_CMD Versions/Current/libCoreFoundation.so.${libcorefoundation_version} libCoreFoundation.so
$LN_CMD Versions/Current/libCoreFoundation.so.${libcorefoundation_version} CoreFoundation
cd ../../lib
$RM_CMD libCoreFoundation.so*
$LN_CMD ../Frameworks/CoreFoundation.framework/Versions/${libcorefoundation_version}/libCoreFoundation.so* ./

### CFNetwork
if [ -n  "$libcfnetwork_version" ]; then
	cd ${BUILD_ROOT}/${CFNET_PKG_NAME}/.build || exit 1
	$INSTALL_CMD

	CFNET_DIR=${DEST_DIR}/usr/NextSpace/Frameworks/CFNetwork.framework

	$MKDIR_CMD $CFNET_DIR/Versions/${libcfnetwork_version}
	cd $CFNET_DIR
	# Headers
	$MV_CMD Headers Versions/${libcfnetwork_version}
	$LN_CMD Versions/Current/Headers Headers
	cd Versions
	$LN_CMD ${libcfnetwork_version} Current
	cd ..
	# Libraries
	$MV_CMD libCFNetwork.so* Versions/${libcfnetwork_version}
	$LN_CMD Versions/Current/libCFNetwork.so.${libcfnetwork_version} libCFNetwork.so
	$LN_CMD Versions/Current/libCFNetwork.so.${libcfnetwork_version} CFNetwork
	cd ../../lib
	$RM_CMD libCFNetwork.so*
	$LN_CMD ../Frameworks/CFNetwork.framework/Versions/${libcfnetwork_version}/libCFNetwork.so* ./
fi

if [ "$DEST_DIR" = "" ]; then
	sudo ldconfig
fi
