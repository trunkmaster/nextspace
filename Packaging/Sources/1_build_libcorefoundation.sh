#!/bin/sh

. ../environment.sh

#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing ${OS_ID} packages for CoreFoundation library build"
if is_debian_like; then
	${ECHO} "Debian-based Linux distribution: calling 'apt-get install'."
	install_apt_packages ${RUNTIME_DEPS}
else
	${ECHO} ">>> Installing ${OS_ID} packages for CoreFoundation build"
	${ECHO} "RedHat-based Linux distribution: calling 'sudo ${RPM_PACKAGE_MANAGER} -y install'."
	SPEC_FILE=${PROJECT_DIR}/Packaging/RedHat/SPECS/libcorefoundation.spec
	install_rpm_spec_buildrequires "${SPEC_FILE}"
	install_rpm_packages git
fi

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

CF_COMPAT_FILE="${BUILD_ROOT}/${CF_PKG_NAME}/CFThreadSetNameCompat.c"
if [ ! -f "${CF_COMPAT_FILE}" ]; then
	${ECHO} "Adding CoreFoundation _CFThreadSetName compatibility source..."
	cat > "${CF_COMPAT_FILE}" <<'EOF'
#if defined(__linux__)
__attribute__((weak)) int _CFThreadSetName(void *thread, const char *name)
{
    (void)thread;
    (void)name;
    return 0;
}
#endif
EOF
fi

CF_CMAKE_FILE=`grep -rl "CFPlatform.c" "${BUILD_ROOT}/${CF_PKG_NAME}" --include 'CMakeLists.txt' | head -n 1`
if [ -n "${CF_CMAKE_FILE}" ] && ! grep "CFThreadSetNameCompat.c" "${CF_CMAKE_FILE}" >/dev/null 2>&1; then
	${ECHO} "Adding CoreFoundation _CFThreadSetName compatibility source to CMake..."
	sed -i 's/CFPlatform\.c/CFPlatform.c CFThreadSetNameCompat.c/' "${CF_CMAKE_FILE}"
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
CF_BUILD_LIB=`find . -name 'libCoreFoundation.so*' -type f | head -n 1`
if [ -n "${CF_BUILD_LIB}" ] && nm -D "${CF_BUILD_LIB}" | grep " U _CFThreadSetName" >/dev/null 2>&1; then
	print_ERR "Built CoreFoundation still has undefined _CFThreadSetName."
	exit 1
fi

# CFNetwork
if [ -n  "$libcfnetwork_version" ]; then
	cd ${BUILD_ROOT}/${CFNET_PKG_NAME} || exit 1
	rm -rf .build 2>/dev/null
	mkdir -p .build
	cd .build
	CFN_CFLAGS="-F../../${CF_PKG_NAME}/.build -I/usr/NextSpace/include"
	CFN_LD_FLAGS="-L../../${CF_PKG_NAME}/.build/CoreFoundation.framework -L/usr/NextSpace/lib"
	cmake .. \
		-DCMAKE_C_COMPILER=${C_COMPILER} \
		-DCMAKE_CXX_COMPILER=${CXX_COMPILER} \
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
run_install

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
	run_install

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

refresh_ldconfig
