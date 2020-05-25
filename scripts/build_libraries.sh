#!/bin/sh
# This script uses `sudo` to install generated RPMs. Please make sure user you 
# run this script as has appropriate rights.
#

if [ $# -eq 0 ];then
    printf "\nERROR: No NEXTSPACE directory specified.\n\n"
    printf "You have to specify directory where NEXTSPACE git clone resides.\n"
    printf "For example, consider this scenario:\n\n"
    printf "$ cd ~/Devloper\n"
    printf "$ git clone https://github.com/trunkmaster/nextspace\n"
    printf "$ cd nextspace/Libraries\n"
    printf "$ ./install_libraries.sh ~/Developer/nextspace\n\n"
    exit
fi

REPO_DIR=$1
. ./scripts/functions
LOG_FILE=${CWD}/libraries_build.log

DISPATCH_VERSION=5.1.5
OBJC2_VERSION=2.0
CORE_VERSION=0.95
WRASTER_VERSION=5.0.0
GNUSTEP_VERSION=1_27_0_nextspace

prepare_environment

# libdispatch
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
    sudo yum -y install \
        ${RPMS_DIR}/libdispatch-${DISPATCH_VERSION}* \
        ${RPMS_DIR}/libdispatch-devel-${DISPATCH_VERSION}*
else
    print_ERR " Building of Grand Central Dispatch library RPM FAILED!"
    exit $?
fi
rm ${SPECS_DIR}/libdispatch.spec

# libobjc2
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
    sudo yum -y install \
        ${RPMS_DIR}/libobjc2-${OBJC2_VERSION}* \
        ${RPMS_DIR}/libobjc2-devel-${OBJC2_VERSION}*
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
cd /tmp 
rm -rf ./nextspace-os_files-${CORE_VERSION}
mkdir -p /tmp/nextspace-os_files-${CORE_VERSION}
cp -R ${REPO_DIR}/System/* ./nextspace-os_files-${CORE_VERSION}/
rm ./nextspace-os_files-${CORE_VERSION}/GNUmakefile
tar zcf ${SOURCES_DIR}/nextspace-os_files-${CORE_VERSION}.tar.gz nextspace-os_files-${CORE_VERSION}
cd $CWD
cp ${REPO_DIR}/Libraries/core/nextspace.fsl ${SOURCES_DIR}
spectool -g -R ${SPECS_DIR}/nextspace-core.spec
print_H2 "========== Building NEXTSPACE core components (nextspace-core) RPM... =========="
rpmbuild -bb ${SPECS_DIR}/nextspace-core.spec 2>&1 >> nextspace-core_build.log
if [ $? -eq 0 ]; then 
    print_OK " Building of NEXTSPACE Core RPM SUCCEEDED!"
    sudo yum -y install \
        ${RPMS_DIR}/nextspace-core-${CORE_VERSION}* \
        ${RPMS_DIR}/nextspace-core-devel-${CORE_VERSION}*
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
mv ${REPO_DIR}/Libraries/libwraster-${WRASTER_VERSION}.tar.gz ${SOURCES_DIR}
spectool -g -R ${SPECS_DIR}/libwraster.spec
print_H2 "=========== Building libwraster RPM... ========================================="
rpmbuild -bb ${SPECS_DIR}/libwraster.spec 2>&1 >> libwraster_build.log
if [ $? -eq 0 ]; then 
    print_OK " Building libwraster RPM SUCCEEDED!"
    sudo yum -y install \
        ${RPMS_DIR}/libwraster-${WRASTER_VERSION}* \
        ${RPMS_DIR}/libwraster-devel-${WRASTER_VERSION}*
else
    print_ERR " Building libwraster RPM FAILED!"
    exit $?
fi
rm ${SPECS_DIR}/libwraster.spec

# GNUstep
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
    rpm -qa | grep nextspace-gnustep
    if [ $? -eq 1 ]; then 
        INST_CMD=install
    else
        INST_CMD=reinstall
    fi
    sudo yum -y $INST_CMD ${RPMS_DIR}/nextspace-gnustep-${GNUSTEP_VERSION}*
    rpm -qa | grep nextspace-gnustep-devel
    if [ $? -eq 1 ]; then 
        INST_CMD=install
    else
        INST_CMD=reinstall
    fi
    sudo yum -y $INST_CMD ${RPMS_DIR}/nextspace-gnustep-devel-${GNUSTEP_VERSION}*
else
    print_ERR " Building of NEXTSPACE GNUstep RPM FAILED!"
    exit $?
fi
rm ${SPECS_DIR}/nextspace-gnustep.spec

print_OK " Build and install of NEXTSPACE Libraries SUCCEEDED!"

exit 0
