#!/bin/sh
# -*-Shell-script-*-

BUILD_RPM=1
. `dirname $0`/../functions.sh
. `dirname $0`/../environment.sh

SPEC_FILE=${PROJECT_DIR}/Libraries/libobjc2/libobjc2.spec
OBJC2_VERSION=`rpm_version ${SPEC_FILE}`

print_H1 " Building Objective-C Runtime(libobjc2) package..."
print_H2 "===== Install libobjc2 build dependencies..."
DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
sudo yum -y install ${DEPS}

print_H2 "===== Downloading libobjc2 sources..."
spectool -g -R ${SPEC_FILE}

print_H2 "===== Building libobjc2 package..."
rpmbuild -bb ${SPEC_FILE}
STATUS=$?
if [ $STATUS -eq 0 ]; then 
    print_OK " Building of Objective-C Runtime RPM SUCCEEDED!"

    install_rpm libobjc2 ${RPMS_DIR}/libobjc2-${OBJC2_VERSION}.rpm
    mv ${RPMS_DIR}/libobjc2-${OBJC2_VERSION}.rpm ${RELEASE_USR}

    install_rpm libobjc2-devel ${RPMS_DIR}/libobjc2-devel-${OBJC2_VERSION}.rpm
    mv ${RPMS_DIR}/libobjc2-devel-${OBJC2_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/libobjc2-debuginfo-${OBJC2_VERSION}.rpm ${RELEASE_DEV}
    if [ -f ${RPMS_DIR}/libobjc2-debugsource-${OBJC2_VERSION}.rpm ];then
        mv ${RPMS_DIR}/libobjc2-debugsource-${OBJC2_VERSION}.rpm ${RELEASE_DEV}
    fi
else
    print_ERR " Building of Objective-C Runtime RPM FAILED!"
    exit $STATUS
fi
