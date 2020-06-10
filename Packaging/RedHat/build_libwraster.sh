#!/bin/sh
# -*-Shell-script-*-

. `dirname $0`/functions

if [ $# -eq 0 ];then
    print_help
    exit 1
fi

REPO_DIR=$1

print_H1 " Building Raster graphics library (libwraster) RPM...\n Build log: libwraster_build.log"
cp ${REPO_DIR}/Libraries/libwraster/libwraster.spec ${SPECS_DIR}

print_H2 "===== Install libwraster build dependencies..."
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/libwraster.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > libwraster_build.log

print_H2 "===== Downloading libwraster sources..."
source /Developer/Makefiles/GNUstep.sh
cd ${REPO_DIR}/Libraries/libwraster && make dist
cd $CWD
WRASTER_VERSION=`rpmspec -q --qf "%{version}:" ${SPECS_DIR}/libwraster.spec | awk -F: '{print $1}'`
mv ${REPO_DIR}/Libraries/libwraster-${WRASTER_VERSION}.tar.gz ${SOURCES_DIR}

spectool -g -R ${SPECS_DIR}/libwraster.spec
print_H2 "===== Building libwraster RPM..."
rpmbuild -bb ${SPECS_DIR}/libwraster.spec 2>&1 >> libwraster_build.log
if [ $? -eq 0 ]; then 
    WRASTER_VERSION=`rpm_version ${SPECS_DIR}/libwraster.spec`
    print_OK " Building libwraster RPM SUCCEEDED!"
    install_rpm libwraster ${RPMS_DIR}/libwraster-${WRASTER_VERSION}.rpm
    mv ${RPMS_DIR}/libwraster-${WRASTER_VERSION}.rpm ${RELEASE_USR}
    install_rpm libwraster-devel ${RPMS_DIR}/libwraster-devel-${WRASTER_VERSION}.rpm
    mv ${RPMS_DIR}/libwraster-devel-${WRASTER_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/libwraster-debuginfo-${WRASTER_VERSION}.rpm ${RELEASE_DEV}
    if [ $OS_NAME == "centos" ] && [ $OS_VERSION != "7" ];then
        mv ${RPMS_DIR}/libwraster-debugsource-${WRASTER_VERSION}.rpm ${RELEASE_DEV}
    fi
else
    print_ERR " Building libwraster RPM FAILED!"
    exit $?
fi

rm ${SPECS_DIR}/libwraster.spec
