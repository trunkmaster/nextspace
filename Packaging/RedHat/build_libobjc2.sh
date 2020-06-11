#!/bin/sh
# -*-Shell-script-*-

. `dirname $0`/functions

if [ $# -eq 0 ];then
    print_help
    exit 1
fi

REPO_DIR=$1
SPEC_FILE=${REPO_DIR}/Libraries/libobjc2/libobjc2.spec
OBJC2_VERSION=`rpm_version ${SPEC_FILE}`

print_H1 " Building Objective-C Runtime(libobjc2) package...\n Build log: libobjc2_build.log"

print_H2 "===== Install libobjc2 build dependencies..."
DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > libobjc2_build.log

print_H2 "===== Downloading libobjc2 sources..."
spectool -g -R ${SPEC_FILE}

print_H2 "===== Building libobjc2 package..."
rpmbuild -bb ${SPEC_FILE} 2>&1 >> libobjc2_build.log
if [ $? -eq 0 ]; then 
    print_OK " Building of Objective-C Runtime RPM SUCCEEDED!"

    install_rpm libobjc2 ${RPMS_DIR}/libobjc2-${OBJC2_VERSION}.rpm
    mv ${RPMS_DIR}/libobjc2-${OBJC2_VERSION}.rpm ${RELEASE_USR}

    install_rpm libobjc2-devel ${RPMS_DIR}/libobjc2-devel-${OBJC2_VERSION}.rpm
    mv ${RPMS_DIR}/libobjc2-devel-${OBJC2_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/libobjc2-debuginfo-${OBJC2_VERSION}.rpm ${RELEASE_DEV}
    if [ $OS_NAME == "centos" ] && [ $OS_VERSION != "7" ];then
        mv ${RPMS_DIR}/libobjc2-debugsource-${OBJC2_VERSION}.rpm ${RELEASE_DEV}
    fi
else
    print_ERR " Building of Objective-C Runtime RPM FAILED!"
    exit $?
fi
