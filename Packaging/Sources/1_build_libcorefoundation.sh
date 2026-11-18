#!/bin/sh

. ../environment.sh
#----------------------------------------
# Install package dependecies
#----------------------------------------
${ECHO} ">>> Installing ${OS_ID} packages for CoreFoundation library build"
if [ ${OS_ID} = "freebsd" ]; then
	${ECHO} "FreeBSD: calling 'pkg install'..."
	sudo pkg install --yes --quiet ${CORE_SYSTEM_DEPS}
elif [ ${OS_ID} = "debian" ] || [ ${OS_ID} = "ubuntu" ]; then
	${ECHO} "Debian-based Linux distribution: calling 'apt-get install'."
	sudo apt-get install -y ${RUNTIME_DEPS} || exit 1
else
	${ECHO} ">>> Installing ${OS_ID} packages for CoreFoundation build"
	${ECHO} "RedHat-based Linux distribution: calling 'yum -y install'."
	SPEC_FILE=${PROJECT_DIR}/Packaging/RedHat/SPECS/libcorefoundation.spec
	DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
	sudo yum -y install ${DEPS} git || exit 1
fi

#----------------------------------------
# Download
#----------------------------------------
CF_PKG_NAME=apple-corefoundation-${libcorefoundation_version}
CFNET_PKG_NAME=apple-cfnetwork

if [ ${OS_ID} = "freebsd" ]; then
	# ---------------------------------------------------------------------
	# FreeBSD: build a HYBRID CoreFoundation.
	#
	# trunkmaster's apple-corefoundation carries its own CFFileDescriptor
	# implementation (patch 0002) that busy-spins on FreeBSD: its libdispatch
	# READ source on the X11 fd re-signals the run-loop source every pass, so
	# CFRunLoop never blocks and Workspace pegs a core. Instead, build on the
	# swift-corelibs CoreFoundation base + the FreeBSD ports(7) CF patches
	# (which carry the working BSD CFRunLoop/CFFileDescriptor path), then
	# layer trunkmaster's *other* edits on top, dropping their CFFileDescriptor
	# implementation. This mirrors what developer-release-1.03 ships; see
	# Libraries/libcorefoundation/freebsd/README.md.
	# ---------------------------------------------------------------------
	CF_SOURCE_REF=${CF_SOURCE_REF:-9e27fa550d759e8dc6132ce70834d3c94d493254}
	TRUNKMASTER_FORK_SHA=dbca8c7ddcfd19f7f6f6e1b60fd3ee3f748e263c
	FOUNDATION_TAG=swift-5.10.1-RELEASE
	CF_PATCH_DIR=${PROJECT_DIR}/Libraries/libcorefoundation/freebsd/patches

	# trunkmaster CF, full history (needed to regenerate its patch series).
	TM_REPO=${BUILD_ROOT}/apple-corefoundation-trunkmaster
	if [ ! -d ${TM_REPO} ]; then
		git clone https://github.com/trunkmaster/apple-corefoundation ${TM_REPO} || exit 1
	fi
	git -C ${TM_REPO} checkout --detach ${CF_SOURCE_REF} || exit 1

	TM_PATCHES=${BUILD_ROOT}/cf-trunkmaster-patches
	rm -rf ${TM_PATCHES}; mkdir -p ${TM_PATCHES}
	git -C ${TM_REPO} format-patch -o ${TM_PATCHES} ${TRUNKMASTER_FORK_SHA}..HEAD || exit 1
	# Drop trunkmaster's CFFileDescriptor implementation - that is the peg.
	rm -f ${TM_PATCHES}/0002-Added-implementation-of-CFFileDescriptor.patch

	# swift-corelibs CoreFoundation base + FreeBSD ports CF patches.
	FND=swift-corelibs-foundation-${FOUNDATION_TAG}
	if [ ! -f ${BUILD_ROOT}/${FND}.tar.gz ]; then
		curl -L https://github.com/swiftlang/swift-corelibs-foundation/archive/${FOUNDATION_TAG}.tar.gz \
			-o ${BUILD_ROOT}/${FND}.tar.gz || exit 1
	fi
	rm -rf ${BUILD_ROOT}/swift-corelibs-foundation
	cd ${BUILD_ROOT}
	tar zxf ${FND}.tar.gz || exit 1
	mv ${FND} swift-corelibs-foundation
	# ports CF patches carry paths swift-corelibs-foundation/CoreFoundation/...
	for p in ${CF_PATCH_DIR}/patch-swift-corelibs-foundation_CoreFoundation_*; do
		${ECHO} ">>> ports CF patch: `basename $p`"
		patch -p0 < "$p" || exit 1
	done

	# Reconcile trunkmaster's edits onto the base (fuzzy; --reject tolerated,
	# same as developer-release-1.03), then the FreeBSD CFFileDescriptor.h fix.
	cd ${BUILD_ROOT}/swift-corelibs-foundation
	git init -q .
	git -c user.name=nextspace -c user.email=nextspace@localhost add -A
	git -c user.name=nextspace -c user.email=nextspace@localhost commit -qm 'ports CoreFoundation base'
	git apply --reject -p1 ${TM_PATCHES}/*.patch || true
	git apply -p1 ${CF_PATCH_DIR}/0001-CoreFoundation_RunLoop.subproj_CFFileDescriptor.h.patch || exit 1

	# Assemble the source tree the Build section below compiles.
	rm -rf ${BUILD_ROOT}/${CF_PKG_NAME}
	mkdir -p ${BUILD_ROOT}/${CF_PKG_NAME}
	cp -R ${BUILD_ROOT}/swift-corelibs-foundation/CoreFoundation/* ${BUILD_ROOT}/${CF_PKG_NAME}/
	cd ${_PWD}
else
	if [ ! -d ${BUILD_ROOT}/${CF_PKG_NAME} ]; then
		git clone --depth 1 https://github.com/trunkmaster/apple-corefoundation ${BUILD_ROOT}/${CF_PKG_NAME}
	fi
	if [ ! -d ${BUILD_ROOT}/${CFNET_PKG_NAME} ]; then
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
C_FLAGS="-I/usr/local/include -I${NEXTSPACE_PREFIX}/include -Wno-switch -Wno-enum-conversion"
$CMAKE_CMD .. \
	-DCMAKE_C_COMPILER=${C_COMPILER} \
	-DCMAKE_C_FLAGS="${C_FLAGS}" \
	-DCMAKE_SHARED_LINKER_FLAGS="-L/usr/local/lib -L${NEXTSPACE_PREFIX}/lib -luuid" \
	-DCF_DEPLOYMENT_SWIFT=NO \
	-DBUILD_SHARED_LIBS=YES \
	-DCMAKE_INSTALL_PREFIX=${NEXTSPACE_PREFIX} \
	-DCMAKE_INSTALL_LIBDIR=${NEXTSPACE_PREFIX}/lib \
	-DCMAKE_LIBRARY_PATH=${NEXTSPACE_PREFIX}/lib \
	\
	-DCMAKE_SKIP_RPATH=ON \
	-DCMAKE_BUILD_TYPE=Debug \
	|| exit 1

$MAKE_CMD || exit 1

# CFNetwork
# No support for FreeBSD yet
if [ ${OS_ID} != "freebsd" ]; then
	if [ -n  "$libcfnetwork_version" ]; then
		cd ${BUILD_ROOT}/${CFNET_PKG_NAME} || exit 1
		rm -rf .build 2>/dev/null
		mkdir -p .build
		cd .build
		CFN_CFLAGS="-F../../${CF_PKG_NAME}/.build -I/usr/local/include -I${NEXTSPACE_PREFIX}/include"
		CFN_LD_FLAGS="-L${NEXTSPACE_PREFIX}/lib -L../../${CF_PKG_NAME}/.build/CoreFoundation.framework"
		cmake .. \
			-DCMAKE_C_COMPILER=${C_COMPILER} \
			-DCMAKE_CXX_COMPILER=clang++ \
			-DCFNETWORK_CFLAGS="${CFN_CFLAGS}" \
			-DCFNETWORK_LDLAGS="${CFN_LD_FLAGS}" \
			-DBUILD_SHARED_LIBS=YES \
			-DCMAKE_INSTALL_PREFIX=${NEXTSPACE_PREFIX} \
			-DCMAKE_INSTALL_LIBDIR=${NEXTSPACE_PREFIX}/lib \
			\
			-DCMAKE_SKIP_RPATH=ON \
			-DCMAKE_BUILD_TYPE=Debug
		$MAKE_CMD || exit 1
	fi
fi

#----------------------------------------
# Install
#----------------------------------------

### CoreFoundation
cd ${BUILD_ROOT}/${CF_PKG_NAME}/.build || exit 1
CF_DIR=${DEST_DIR}${NEXTSPACE_PREFIX}/Frameworks/CoreFoundation.framework
if [ ${OS_ID} = "freebsd" ]; then
    # A prior install leaves framework aliases pointing into Versions/.
    # Remove only these aliases so CMake installs fresh real files/directories
    # before the versioned layout below is rebuilt. Otherwise Headers becomes
    # a dangling self-referential alias when Versions/ is removed.
    for framework_alias in Headers Modules libCoreFoundation.so; do
        if [ -L "${CF_DIR}/${framework_alias}" ]; then
            sudo rm "${CF_DIR}/${framework_alias}" || exit 1
        fi
    done
fi
$INSTALL_CMD || exit 1

ver=${libcorefoundation_version}

if [ ${OS_ID} = "freebsd" ]; then
	# The swift-corelibs CoreFoundation build installs a single, unversioned
	# libCoreFoundation.so (no SONAME). The rest of NextSpace links against
	# libCoreFoundation.so.5 / .so.${ver}, so lay out the versioned framework
	# ourselves. Idempotent: rebuild Versions/ from scratch on re-install.
	VDIR=${CF_DIR}/Versions/${ver}
	sudo rm -rf ${CF_DIR}/Versions
	sudo mkdir -p ${VDIR}
	sudo mv ${CF_DIR}/Headers ${VDIR}/Headers
	[ -d ${CF_DIR}/Modules ] && sudo mv ${CF_DIR}/Modules ${VDIR}/Modules
	sudo mv ${CF_DIR}/libCoreFoundation.so ${VDIR}/libCoreFoundation.so.${ver}
	( cd ${CF_DIR}/Versions && sudo ln -sf ${ver} Current )
	( cd ${VDIR} && \
		sudo ln -sf libCoreFoundation.so.${ver} libCoreFoundation.so.5 && \
		sudo ln -sf libCoreFoundation.so.${ver} libCoreFoundation.so )
	( cd ${CF_DIR} && \
		sudo ln -sf Versions/Current/Headers Headers && \
		{ [ -d ${VDIR}/Modules ] && sudo ln -sf Versions/Current/Modules Modules; true; } && \
		sudo ln -sf Versions/Current/libCoreFoundation.so.${ver} libCoreFoundation.so && \
		sudo ln -sf Versions/Current/libCoreFoundation.so.${ver} CoreFoundation )
	cd ${DEST_DIR}${NEXTSPACE_PREFIX}/lib
	sudo rm -f libCoreFoundation.so libCoreFoundation.so.5 libCoreFoundation.so.${ver}
	for n in libCoreFoundation.so.${ver} libCoreFoundation.so.5 libCoreFoundation.so; do
		sudo ln -sf ../Frameworks/CoreFoundation.framework/Versions/${ver}/libCoreFoundation.so.${ver} $n
	done
else
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
fi

### CFNetwork
if [ ${OS_ID} != "freebsd" ]; then
	if [ -n  "$libcfnetwork_version" ]; then
		cd ${BUILD_ROOT}/${CFNET_PKG_NAME}/.build || exit 1
		$INSTALL_CMD

		CFNET_DIR=${DEST_DIR}${NEXTSPACE_PREFIX}/Frameworks/CFNetwork.framework

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
fi

if [ "$DEST_DIR" = "" ]; then
	sudo ldconfig
fi
