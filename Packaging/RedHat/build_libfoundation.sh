#!/bin/sh
# -*-Shell-script-*-

. `dirname $0`/functions

if [ $# -eq 0 ];then
    print_help
    exit 1
fi

REPO_DIR=$1
SPEC_FILE=${REPO_DIR}/Libraries/libfoundation/libfoundation.spec
CF_VERSION=`rpm_version ${SPEC_FILE}`

print_H1 " Building Core Foundation (libfoundation) package..."
cp ${REPO_DIR}/Libraries/libfoundation/*.patch ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/libfoundation/CFNotificationCenter.c ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/libfoundation/CFFileDescriptor.[ch] ${SOURCES_DIR}

print_H2 "===== Install Core Foundation build dependencies..."
DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
sudo yum -y install ${DEPS}

print_H2 "===== Downloading Core Foundation sources..."
rm ${SOURCES_DIR}/swift*.tar.gz
spectool -g -R ${SPEC_FILE}

print_H2 "===== Building CoreFoundation package..."
rpmbuild -bb ${SPEC_FILE}
STATUS=$?
if [ $STATUS -eq 0 ]; then 
    print_OK " Building of Core Foundation library RPM SUCCEEDED!"
    print_H2 "===== Installing libfoundation RPMs..."

    install_rpm libfoundation-${CF_VERSION} ${RPMS_DIR}/libfoundation-${CF_VERSION}.rpm
    mv ${RPMS_DIR}/libfoundation-${CF_VERSION}.rpm ${RELEASE_USR}

    install_rpm libfoundation-devel-${CF_VERSION} ${RPMS_DIR}/libfoundation-devel-${CF_VERSION}.rpm
    mv ${RPMS_DIR}/libfoundation-devel-${CF_VERSION}.rpm ${RELEASE_DEV}
    if [ -f ${RPMS_DIR}/libfoundation-debugsource-${CF_VERSION}.rpm ];then
        mv ${RPMS_DIR}/libfoundation-debuginfo-${CF_VERSION}.rpm ${RELEASE_DEV}
        mv ${RPMS_DIR}/libfoundation-debugsource-${CF_VERSION}.rpm ${RELEASE_DEV}
    fi
else
    print_ERR " Building of Core Foundation library RPM FAILED!"
    exit $STATUS
fi
