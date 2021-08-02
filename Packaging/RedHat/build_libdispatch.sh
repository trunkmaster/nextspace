#!/bin/sh
# -*-Shell-script-*-

. `dirname $0`/functions

if [ $# -eq 0 ];then
    print_help
    exit 1
fi

REPO_DIR=$1
SPEC_FILE=${REPO_DIR}/Libraries/libdispatch/libdispatch.spec
DISPATCH_VERSION=`rpm_version ${SPEC_FILE}`

# libdispatch
print_H1 " Building Grand Central Dispatch (libdispatch) package..."
cp ${REPO_DIR}/Libraries/libdispatch/libdispatch-dispatch.h.patch ${SOURCES_DIR}

print_H2 "===== Install libdispatch build dependencies..."
DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
sudo yum -y install ${DEPS}

print_H2 "===== Downloading libdispatch sources..."
rm ${SOURCES_DIR}/swift*.tar.gz
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
