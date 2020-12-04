#!/bin/sh
# -*-Shell-script-*-

. `dirname $0`/functions

if [ $# -eq 0 ];then
    print_help
    exit 1
fi

REPO_DIR=$1
SPEC_FILE=${REPO_DIR}/Libraries/libCoreFoundation/libCoreFoundation.spec
CF_VERSION=`rpm_version ${SPEC_FILE}`

print_H1 " Building Core Foundation (libCoreFoundation) package..."
cp ${REPO_DIR}/Libraries/libCoreFoundation/*.patch ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/libCoreFoundation/CFNotificationCenter.c ${SOURCES_DIR}

print_H2 "===== Install Core Foundation build dependencies..."
DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
sudo yum -y install ${DEPS}

print_H2 "===== Downloading Core Foundation sources..."
spectool -g -R ${SPEC_FILE}

print_H2 "===== Building CoreFoundation package..."
rpmbuild -bb ${SPEC_FILE}
STATUS=$?
if [ $STATUS -eq 0 ]; then 
    print_OK " Building of Core Foundation library RPM SUCCEEDED!"
    print_H2 "===== Installing libCoreFoundation RPMs..."

    install_rpm libCoreFoundation ${RPMS_DIR}/libCoreFoundation-${CF_VERSION}.rpm
    mv ${RPMS_DIR}/libCoreFoundation-${CF_VERSION}.rpm ${RELEASE_USR}

    install_rpm libCoreFoundation-devel ${RPMS_DIR}/libCoreFoundation-devel-${CF_VERSION}.rpm
    mv ${RPMS_DIR}/libCoreFoundation-devel-${CF_VERSION}.rpm ${RELEASE_DEV}
    if [ -f ${RPMS_DIR}/libCoreFoundation-debugsource-${CF_VERSION}.rpm ];then
        mv ${RPMS_DIR}/libCoreFoundation-debuginfo-${CF_VERSION}.rpm ${RELEASE_DEV}
        mv ${RPMS_DIR}/libCoreFoundation-debugsource-${CF_VERSION}.rpm ${RELEASE_DEV}
    fi
else
    print_ERR " Building of Core Foundation library RPM FAILED!"
    exit $STATUS
fi
