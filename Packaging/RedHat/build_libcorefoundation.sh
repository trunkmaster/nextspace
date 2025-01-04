#!/bin/sh
# -*-Shell-script-*-

BUILD_RPM=1
. `dirname $0`/../functions.sh
. `dirname $0`/../environment.sh

SPEC_FILE=${PROJECT_DIR}/Libraries/libcorefoundation/libcorefoundation.spec
CF_VERSION=`rpm_version ${SPEC_FILE}`

print_H1 " Building Core Foundation (libcorefoundation) package..."
print_H2 "===== Install Core Foundation build dependencies..."
DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
sudo yum -y install ${DEPS}

print_H2 "===== Downloading Core Foundation sources..."
_VER=`rpmspec -q --qf "%{version}:" ${SPEC_FILE} | awk -F: '{print $1}'`
_REL=`rpmspec -q --qf "%{release}:" ${SPEC_FILE} | awk -F: '{print $1}' | awk -F. '{print $1}'`
curl -L https://github.com/trunkmaster/apple-corefoundation/archive/refs/tags/${_VER}-${_REL}.tar.gz -o ${RPM_SOURCES_DIR}/libcorefoundation-${_VER}-${_REL}.tar.gz
spectool -g -R ${SPEC_FILE}

print_H2 "===== Building CoreFoundation package..."
rpmbuild -bb ${SPEC_FILE}
STATUS=$?
if [ $STATUS -eq 0 ]; then 
    print_OK " Building of Core Foundation library RPM SUCCEEDED!"
    print_H2 "===== Installing libcorefoundation RPMs..."

    install_rpm libcorefoundation-${CF_VERSION} ${RPMS_DIR}/libcorefoundation-${CF_VERSION}.rpm
    mv ${RPMS_DIR}/libcorefoundation-${CF_VERSION}.rpm ${RELEASE_USR}

    install_rpm libcorefoundation-devel-${CF_VERSION} ${RPMS_DIR}/libcorefoundation-devel-${CF_VERSION}.rpm
    mv ${RPMS_DIR}/libcorefoundation-devel-${CF_VERSION}.rpm ${RELEASE_DEV}
    if [ -f ${RPMS_DIR}/libcorefoundation-debugsource-${CF_VERSION}.rpm ];then
        mv ${RPMS_DIR}/libcorefoundation-debuginfo-${CF_VERSION}.rpm ${RELEASE_DEV}
        mv ${RPMS_DIR}/libcorefoundation-debugsource-${CF_VERSION}.rpm ${RELEASE_DEV}
    fi
else
    print_ERR " Building of Core Foundation library RPM FAILED!"
    exit $STATUS
fi
