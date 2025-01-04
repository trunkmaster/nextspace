#!/bin/sh
# -*-Shell-script-*-

BUILD_RPM=1
. `dirname $0`/../functions.sh
. `dirname $0`/../environment.sh

if [ "${OS_ID}" = "fedora" ]; then
	${ECHO} "No need to build - installing 'libdispatch-devel' from Fedora repository..."
	sudo dnf -y install libdispatch-devel || exit 1
	exit 0
fi

SPEC_FILE=${PROJECT_DIR}/Libraries/libdispatch/libdispatch.spec
DISPATCH_VERSION=`rpm_version ${SPEC_FILE}`

# libdispatch
print_H1 " Building Grand Central Dispatch (libdispatch) package..."
print_H2 "===== Install libdispatch build dependencies..."
DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
sudo yum -y install ${DEPS}

print_H2 "===== Downloading libdispatch sources..."
VER=`rpmspec -q --qf "%{version}:" ${SPEC_FILE} | awk -F: '{print $1}'`
curl -L https://github.com/apple/swift-corelibs-libdispatch/archive/swift-${VER}-RELEASE.tar.gz -o ${RPM_SOURCES_DIR}/libdispatch-${VER}.tar.gz
spectool -g -R ${SPEC_FILE}

print_H2 "===== Building libdispatch package..."
rpmbuild -bb ${SPEC_FILE}
STATUS=$?
if [ $STATUS -eq 0 ]; then 
    print_OK " Building of Grand Central Dispatch library RPM SUCCEEDED!"
    print_H2 "===== Installing libdispatch RPMs..."

    install_rpm libdispatch-${DISPATCH_VERSION} ${RPMS_DIR}/libdispatch-${DISPATCH_VERSION}.rpm
    mv ${RPMS_DIR}/libdispatch-${DISPATCH_VERSION}.rpm ${RELEASE_USR}

    install_rpm libdispatch-devel-${DISPATCH_VERSION} ${RPMS_DIR}/libdispatch-devel-${DISPATCH_VERSION}.rpm
    mv ${RPMS_DIR}/libdispatch-devel-${DISPATCH_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/libdispatch-debuginfo-${DISPATCH_VERSION}.rpm ${RELEASE_DEV}
    if [ -f ${RPMS_DIR}/libdispatch-debugsource-${DISPATCH_VERSION}.rpm ];then
        mv ${RPMS_DIR}/libdispatch-debugsource-${DISPATCH_VERSION}.rpm ${RELEASE_DEV}
    fi
else
    print_ERR " Building of Grand Central Dispatch library RPM FAILED!"
    exit $STATUS
fi
