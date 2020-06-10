#!/bin/sh
# This script uses `sudo` to install generated RPMs. Please make sure user you 
# run this script as has appropriate rights.
# Notice it always rebuilds and reinstalls packages even if they're already installed.
#

. `dirname $0`/functions

if [ $# -eq 0 ];then
    print_help
    exit 1
fi

prepare_environment
if [ $? -eq 1 ];then
    print_ERR "Failed to setup building environment. Exiting..."
    exit 1
fi

# Build missed libraries for CentOS 8: libudisks2-devel and libart_lgpl
if [ -f /etc/os-release ]; then 
    source /etc/os-release;
    if [ $ID == "centos" ] && [ $VERSION_ID == "8" ];then
        rpm -q libart_lgpl 2>&1 > /dev/null
        if [ $? -eq 1 ]; then
            `dirname $0`/el8_build_libart.sh
            mv ${RPMS_DIR}/libart_lgpl-2.3.21-23.el8.x86_64.rpm ${RELEASE_USR}
            mv ${RPMS_DIR}/libart_lgpl-devel-2.3.21-23.el8.x86_64.rpm ${RELEASE_DEV}
            mv ${RPMS_DIR}/libart_lgpl-debuginfo-2.3.21-23.el8.x86_64.rpm ${RELEASE_DEV}
            mv ${RPMS_DIR}/libart_lgpl-debugsource-2.3.21-23.el8.x86_64.rpm ${RELEASE_DEV}
        fi
        rpm -q libudisks-devel 2>&1 > /dev/null
        if [ $? -eq 1 ]; then
            `dirname $0`/el8_build_udisks2.sh
        fi
    fi
fi

REPO_DIR=$1

# libdispatch
DISPATCH_VERSION=`rpm_version ${REPO_DIR}/Libraries/libdispatch/libdispatch.spec`
print_H1 " Building Grand Central Dispatch (libdispatch) package...\n Build log: libdispatch_build.log"
cp ${REPO_DIR}/Libraries/libdispatch/libdispatch.spec ${SPECS_DIR}
cp ${REPO_DIR}/Libraries/libdispatch/libdispatch-dispatch.h.patch ${SOURCES_DIR}
print_H2 "========== Install libdispatch build dependencies... ==========================="
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/libdispatch.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > libdispatch_build.log
print_H2 "========== Downloading libdispatch sources... =================================="
spectool -g -R ${SPECS_DIR}/libdispatch.spec
print_H2 "========== Building libdispatch package... ====================================="
rpmbuild -bb ${SPECS_DIR}/libdispatch.spec 2>&1 >> libdispatch_build.log
if [ $? -eq 0 ]; then 
    print_OK " Building of Grand Central Dispatch library RPM SUCCEEDED!"
    print_H2 "========== Installing libdispatch RPMs... ======================================"
    install_rpm libdispatch ${RPMS_DIR}/libdispatch-${DISPATCH_VERSION}.rpm
    mv ${RPMS_DIR}/libdispatch-${DISPATCH_VERSION}.rpm ${RELEASE_USR}
    install_rpm libdispatch-devel ${RPMS_DIR}/libdispatch-devel-${DISPATCH_VERSION}.rpm
    mv ${RPMS_DIR}/libdispatch-devel-${DISPATCH_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/libdispatch-debuginfo-${DISPATCH_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/libdispatch-debugsource-${DISPATCH_VERSION}.rpm ${RELEASE_DEV}
else
    print_ERR " Building of Grand Central Dispatch library RPM FAILED!"
    exit $?
fi
rm ${SPECS_DIR}/libdispatch.spec

# libobjc2
OBJC2_VERSION=`rpm_version ${REPO_DIR}/Libraries/libobjc2/libobjc2.spec`
print_H1 " Building Objective-C Runtime(libobjc2) package...\n Build log: libobjc2_build.log"
cp ${REPO_DIR}/Libraries/libobjc2/libobjc2.spec ${SPECS_DIR}
print_H2 "========== Install libobjc2 build dependencies... =============================="
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/libobjc2.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > libobjc2_build.log
print_H2 "========== Downloading libobjc2 sources... ====================================="
spectool -g -R ${SPECS_DIR}/libobjc2.spec
print_H2 "========== Building libobjc2 package... ========================================"
rpmbuild -bb ${SPECS_DIR}/libobjc2.spec 2>&1 >> libobjc2_build.log
if [ $? -eq 0 ]; then 
    print_OK " Building of Objective-C Runtime RPM SUCCEEDED!"
    install_rpm libobjc2 ${RPMS_DIR}/libobjc2-${OBJC2_VERSION}.rpm
    mv ${RPMS_DIR}/libobjc2-${OBJC2_VERSION}.rpm ${RELEASE_USR}
    install_rpm libobjc2-devel ${RPMS_DIR}/libobjc2-devel-${OBJC2_VERSION}.rpm
    mv ${RPMS_DIR}/libobjc2-devel-${OBJC2_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/libobjc2-debuginfo-${OBJC2_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/libobjc2-debugsource-${OBJC2_VERSION}.rpm ${RELEASE_DEV}
else
    print_ERR " Building of Objective-C Runtime RPM FAILED!"
    exit $?
fi
rm ${SPECS_DIR}/libobjc2.spec

# nextspace-core
print_H1 " Building of NEXTSPACE core components (nextspace-core) RPM...\n Build log: nextspace-core_build.log"
cp ${REPO_DIR}/Libraries/core/nextspace-core.spec ${SPECS_DIR}
print_H2 "========== Install nextspace-core build dependencies... ========================"
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/nextspace-core.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > nextspace-core_build.log
print_H2 "========== Downloading NEXTSPACE Core sources... ==============================="
CORE_VERSION=`rpmspec -q --qf "%{version}:" ${SPECS_DIR}/nextspace-core.spec | awk -F: '{print $1}'`
cd /tmp 
rm -rf ./nextspace-os_files-${CORE_VERSION}
mkdir -p /tmp/nextspace-os_files-${CORE_VERSION}
cp -R ${REPO_DIR}/System/* ./nextspace-os_files-${CORE_VERSION}/
rm ./nextspace-os_files-${CORE_VERSION}/GNUmakefile
tar zcf ${SOURCES_DIR}/nextspace-os_files-${CORE_VERSION}.tar.gz nextspace-os_files-${CORE_VERSION}
cd $CWD
CORE_VERSION=`rpm_version ${SPECS_DIR}/nextspace-core.spec`
cp ${REPO_DIR}/Libraries/core/nextspace.fsl ${SOURCES_DIR}
spectool -g -R ${SPECS_DIR}/nextspace-core.spec
print_H2 "========== Building NEXTSPACE core components (nextspace-core) RPM... =========="
rpmbuild -bb ${SPECS_DIR}/nextspace-core.spec 2>&1 >> nextspace-core_build.log
if [ $? -eq 0 ]; then 
    print_OK " Building of NEXTSPACE Core RPM SUCCEEDED!"
    install_rpm nextspace-core ${RPMS_DIR}/nextspace-core-${CORE_VERSION}.rpm
    mv ${RPMS_DIR}/nextspace-core-${CORE_VERSION}.rpm ${RELEASE_USR}
    install_rpm nextspace-core-devel ${RPMS_DIR}/nextspace-core-devel-${CORE_VERSION}.rpm
    mv ${RPMS_DIR}/nextspace-core-devel-${CORE_VERSION}.rpm ${RELEASE_DEV}
else
    print_ERR " Building of NEXTSPACE Core RPM FAILED!"
    exit $?
fi
rm ${SPECS_DIR}/nextspace-core.spec
rm ${SOURCES_DIR}/nextspace-os_files-${CORE_VERSION}.tar.gz

# libwraster
print_H1 " Building Raster graphics library (libwraster) RPM...\n Build log: libwraster_build.log"
cp ${REPO_DIR}/Libraries/libwraster/libwraster.spec ${SPECS_DIR}
print_H2 "========== Install libwraster build dependencies... ============================"
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/libwraster.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > libwraster_build.log
print_H2 "========== Downloading libwraster sources... ==================================="
source /Developer/Makefiles/GNUstep.sh
cd ${REPO_DIR}/Libraries/libwraster && make dist
cd $CWD
WRASTER_VERSION=`rpmspec -q --qf "%{version}:" ${SPECS_DIR}/libwraster.spec | awk -F: '{print $1}'`
mv ${REPO_DIR}/Libraries/libwraster-${WRASTER_VERSION}.tar.gz ${SOURCES_DIR}
WRASTER_VERSION=`rpm_version ${SPECS_DIR}/libwraster.spec`
spectool -g -R ${SPECS_DIR}/libwraster.spec
print_H2 "=========== Building libwraster RPM... ========================================="
rpmbuild -bb ${SPECS_DIR}/libwraster.spec 2>&1 >> libwraster_build.log
if [ $? -eq 0 ]; then 
    print_OK " Building libwraster RPM SUCCEEDED!"
    install_rpm libwraster ${RPMS_DIR}/libwraster-${WRASTER_VERSION}.rpm
    mv ${RPMS_DIR}/libwraster-${WRASTER_VERSION}.rpm ${RELEASE_USR}
    install_rpm libwraster-devel ${RPMS_DIR}/libwraster-devel-${WRASTER_VERSION}.rpm
    mv ${RPMS_DIR}/libwraster-devel-${WRASTER_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/libwraster-debuginfo-${WRASTER_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/libwraster-debugsource-${WRASTER_VERSION}.rpm ${RELEASE_DEV}
else
    print_ERR " Building libwraster RPM FAILED!"
    exit $?
fi
rm ${SPECS_DIR}/libwraster.spec

# GNUstep
GNUSTEP_VERSION=`rpm_version ${REPO_DIR}/Libraries/gnustep/nextspace-gnustep.spec`
print_H1 " Building NEXTSPACE GNUstep (nextspace-gnustep) package...\n Build log: gnustep_build.log"
cp ${REPO_DIR}/Libraries/gnustep/nextspace-gnustep.spec ${SPECS_DIR}
cp ${REPO_DIR}/Libraries/gnustep/gdnc-local.service ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/gnustep/gdnc.service ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/gnustep/gdomap.interfaces ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/gnustep/gdomap.service ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/gnustep/gpbs.service ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/gnustep/gnustep-gui-images.tar.gz ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/gnustep/projectcenter-images.tar.gz ${SOURCES_DIR}
print_H2 "========== Install GNUstep build dependencies... ==============================="
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/nextspace-gnustep.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > gnustep_build.log
print_H2 "========== Downloading GNUstep sources... ======================================"
spectool -g -R ${SPECS_DIR}/nextspace-gnustep.spec
print_H2 "========== Building GNUstep package... ========================================="
rpmbuild -bb ${SPECS_DIR}/nextspace-gnustep.spec 2>&1 >> gnustep_build.log
if [ $? -eq 0 ]; then 
    print_OK " Building of NEXTSPACE GNUstep RPM SUCCEEDED!"
    install_rpm nextspace-gnustep ${RPMS_DIR}/nextspace-gnustep-${GNUSTEP_VERSION}.rpm
    mv ${RPMS_DIR}/nextspace-gnustep-${GNUSTEP_VERSION}.rpm ${RELEASE_USR}
    install_rpm nextspace-gnustep-devel ${RPMS_DIR}/nextspace-gnustep-devel-${GNUSTEP_VERSION}.rpm
    mv ${RPMS_DIR}/nextspace-gnustep-devel-${GNUSTEP_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/nextspace-gnustep-debuginfo-${GNUSTEP_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/nextspace-gnustep-debugsource-${GNUSTEP_VERSION}.rpm ${RELEASE_DEV}
else
    print_ERR " Building of NEXTSPACE GNUstep RPM FAILED!"
    exit $?
fi
rm ${SPECS_DIR}/nextspace-gnustep.spec

print_OK " Build and install of NEXTSPACE Libraries SUCCEEDED!"

exit 0
