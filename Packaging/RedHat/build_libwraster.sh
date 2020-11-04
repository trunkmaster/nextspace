#!/bin/sh
# -*-Shell-script-*-

. `dirname $0`/functions

if [ $# -eq 0 ];then
    print_help
    exit 1
fi

REPO_DIR=$1
SPEC_FILE=${REPO_DIR}/Libraries/libwraster/libwraster.spec

print_H1 " Building Raster graphics library (libwraster) RPM...\n Build log: libwraster_build.log"

print_H2 "===== Install libwraster build dependencies..."
DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > libwraster_build.log

print_H2 "===== Downloading libwraster sources..."
source /Developer/Makefiles/GNUstep.sh
cd ${REPO_DIR}/Libraries/libwraster && make dist
cd $CWD
WRASTER_VERSION=`rpmspec -q --qf "%{version}:" ${SPEC_FILE} | awk -F: '{print $1}'`
mv ${REPO_DIR}/Libraries/libwraster-${WRASTER_VERSION}.tar.gz ${SOURCES_DIR}

spectool -g -R ${SPEC_FILE}
print_H2 "===== Building libwraster RPM..."
rpmbuild -bb ${SPEC_FILE} 2>&1 >> libwraster_build.log
if [ $? -eq 0 ]; then 
    WRASTER_VERSION=`rpm_version ${SPEC_FILE}`
    print_OK " Building libwraster RPM SUCCEEDED!"

    install_rpm libwraster ${RPMS_DIR}/libwraster-${WRASTER_VERSION}.rpm
    mv ${RPMS_DIR}/libwraster-${WRASTER_VERSION}.rpm ${RELEASE_USR}

    install_rpm libwraster-devel ${RPMS_DIR}/libwraster-devel-${WRASTER_VERSION}.rpm
    mv ${RPMS_DIR}/libwraster-devel-${WRASTER_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/libwraster-debuginfo-${WRASTER_VERSION}.rpm ${RELEASE_DEV}
    if [ -f ${RPMS_DIR}/libwraster-debugsource-${WRASTER_VERSION}.rpm ];then
        mv ${RPMS_DIR}/libwraster-debugsource-${WRASTER_VERSION}.rpm ${RELEASE_DEV}
    fi
else
    print_ERR " Building libwraster RPM FAILED!"
    exit $?
fi
