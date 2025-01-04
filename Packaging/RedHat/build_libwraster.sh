#!/bin/sh
# -*-Shell-script-*-

BUILD_RPM=1
. `dirname $0`/../functions.sh
. `dirname $0`/../environment.sh
. /Developer/Makefiles/GNUstep.sh
. /etc/profile.d/nextspace.sh

SPEC_FILE=${PROJECT_DIR}/Libraries/libwraster/libwraster.spec

print_H1 " Building Raster graphics library (libwraster) RPM..."

print_H2 "===== Install libwraster build dependencies..."
DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
sudo yum -y install ${DEPS}

print_H2 "===== Downloading libwraster sources..."
source /Developer/Makefiles/GNUstep.sh
cd ${PROJECT_DIR}/Libraries/libwraster && make dist
cd $CWD
WRASTER_VERSION=`rpmspec -q --qf "%{version}:" ${SPEC_FILE} | awk -F: '{print $1}'`
mv ${PROJECT_DIR}/Libraries/libwraster-${WRASTER_VERSION}.tar.gz ${RPM_SOURCES_DIR}

spectool -g -R ${SPEC_FILE}
print_H2 "===== Building libwraster RPM..."
rpmbuild -bb ${SPEC_FILE}
STATUS=$?
if [ $STATUS -eq 0 ]; then 
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
    exit $STATUS
fi
