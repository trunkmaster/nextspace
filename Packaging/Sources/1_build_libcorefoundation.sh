#!/bin/sh

. ../environment.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing packages for CoreFoundation library build"
install_packages ${RUNTIME_DEPS}

#----------------------------------------
# Download
#----------------------------------------
CF_PKG_NAME=apple-corefoundation-${libcorefoundation_version}
CFNET_PKG_NAME=apple-cfnetwork

if [ ! -d ${BUILD_ROOT}/${CF_PKG_NAME} ]; then
    git clone --depth 1 https://github.com/trunkmaster/apple-corefoundation ${BUILD_ROOT}/${CF_PKG_NAME}
fi
if [ ! -d ${BUILD_ROOT}/${CFNET_PKG_NAME} ]; then
    git clone --depth 1 https://github.com/trunkmaster/apple-cfnetwork ${BUILD_ROOT}/${CFNET_PKG_NAME}
fi

#----------------------------------------
# Build
#----------------------------------------
# CoreFoundation
cd ${BUILD_ROOT}/${CF_PKG_NAME} || exit 1
# The NextSpace addition _NS_pthread_setname_np calls _CFThreadSetName,
# which lives in the DEPLOYMENT_RUNTIME_SWIFT-only tail of CFPlatform.c.
# With CF_DEPLOYMENT_SWIFT=NO that symbol is compiled out and Arch's bfd
# linker (unlike upstream's gold) refuses to link apps against the library.
# On Linux the wrapper is just pthread_setname_np - call it directly.
grep -q "ArchSTEP: swift-runtime-only" Base.subproj/CFPlatform.c || \
sed -i 's|_CFThreadSetName(GetCurrentThread(), name);|pthread_setname_np(pthread_self(), name); // ArchSTEP: swift-runtime-only wrapper avoided|' Base.subproj/CFPlatform.c
sed -i 's|_CFThreadSetName(pthread_self(),|pthread_setname_np(pthread_self(),|' Stream.subproj/CFStream.c
${RM_CMD} -rf .build
mkdir -p .build
cd .build
C_FLAGS="-I/usr/NextSpace/include -Wno-switch -Wno-enum-conversion"
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
	${RM_CMD} -rf .build
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
