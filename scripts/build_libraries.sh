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
CWD=`pwd`
SOURCES_DIR=~/rpmbuild/SOURCES
SPECS_DIR=~/rpmbuild/SPECS
RPMS_DIR=~/rpmbuild/RPMS/x86_64

DISPATCH_VERSION=5.1.5
OBJC2_VERSION=2.0
CORE_VERSION=0.95
WRASTER_VERSION=5.0.0
GNUSTEP_VERSION=1_27_0_nextspace

echo "================================================================================"
echo " Prepare build environment"
echo "================================================================================"
echo "========== Install RPM build tools... =========================================="
BUILD_TOOLS="rpm-build rpmdevtools make patch"
if [ -f /etc/os-release ]; then 
    source /etc/os-release;
    if [ $ID == "centos" ];then
        if [ $VERSION_ID == "7" ];then
            BUILD_TOOLS="$BUILD_TOOLS centos-release-scl centos-release-scl-rh"
        fi
        if [ $VERSION_ID == "8" ];then
            yum config-manager --set-enabled PowerTools
            yum -y install http://mirror.ppa.trinitydesktop.org/trinity/rpm/el8/trinity-r14/RPMS/noarch/trinity-repo-14.0.7-1.el8.noarch.rpm
            yum -y install http://rpmfind.net/linux/centos/8-stream/PowerTools/x86_64/os/Packages/libudisks2-devel-2.8.3-2.el8.x86_64.rpm
            yum -y update
            BUILD_TOOLS="$BUILD_TOOLS epel-release dnf-plugins-core"
        fi
    fi
fi
sudo yum -y install ${BUILD_TOOLS}
echo "========== Create rpmbuild directories... ======================================"
mkdir -p $SOURCES_DIR
mkdir -p $SPECS_DIR

# libdispatch
echo "================================================================================"
echo " Building Grand Central Dispatch (libdispatch) package..."
echo " Build log: libdispatch_build.log"
echo "================================================================================"
cp ${REPO_DIR}/Libraries/libdispatch/libdispatch.spec ${SPECS_DIR}
cp ${REPO_DIR}/Libraries/libdispatch/libdispatch-dispatch.h.patch ${SOURCES_DIR}
echo "========== Install libdispatch build dependencies... ==========================="
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/libdispatch.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > libdispatch_build.log
echo "========== Downloading libdispatch sources... =================================="
spectool -g -R ${SPECS_DIR}/libdispatch.spec
echo "========== Building libdispatch package... ====================================="
rpmbuild -bb ${SPECS_DIR}/libdispatch.spec 2>&1 >> libdispatch_build.log
if [ $? -eq 0 ]; then 
    echo "================================================================================"
    echo " Building of Grand Central Dispatch library RPM SUCCEEDED!"
    echo "================================================================================"
    echo "========== Installing libdispatch RPMs... ======================================"
    sudo yum -y localinstall \
        ${RPMS_DIR}/libdispatch-${DISPATCH_VERSION}* \
        ${RPMS_DIR}/libdispatch-devel-${DISPATCH_VERSION}*
else
    echo "================================================================================"
    echo " Building of Grand Central Dispatch library RPM FAILED!"
    echo "================================================================================"
    exit $?
fi
rm ${SPECS_DIR}/libdispatch.spec

# libobjc2
echo "================================================================================"
echo " Building Objective-C Runtime(libobjc2) package..."
echo " Build log: libobjc2_build.log"
echo "================================================================================"
cp ${REPO_DIR}/Libraries/libobjc2/libobjc2.spec ${SPECS_DIR}
echo "========== Install libobjc2 build dependencies... =============================="
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/libobjc2.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > libobjc2_build.log
echo "========== Downloading libobjc2 sources... ====================================="
spectool -g -R ${SPECS_DIR}/libobjc2.spec
echo "========== Building libobjc2 package... ========================================"
rpmbuild -bb ${SPECS_DIR}/libobjc2.spec 2>&1 >> libobjc2_build.log
if [ $? -eq 0 ]; then 
    echo "================================================================================"
    echo " Building of Objective-C Runtime RPM SUCCEEDED!"
    echo "================================================================================"
    sudo yum -y localinstall \
        ${RPMS_DIR}/libobjc2-${OBJC2_VERSION}* \
        ${RPMS_DIR}/libobjc2-devel-${OBJC2_VERSION}*
else
    echo "================================================================================"
    echo " Building of Objective-C Runtime RPM FAILED!"
    echo "================================================================================"
    exit $?
fi
rm ${SPECS_DIR}/libobjc2.spec

# nextspace-core
echo "================================================================================"
echo " Building of NEXTSPACE core components (nextspace-core) RPM..."
echo " Build log: nextspace-core_build.log"
echo "================================================================================"
cp ${REPO_DIR}/Libraries/core/nextspace-core.spec ${SPECS_DIR}
echo "========== Install nextspace-core build dependencies... ========================"
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/nextspace-core.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > nextspace-core_build.log
echo "========== Downloading NEXTSPACE Core sources... ==============================="
cd /tmp 
rm -rf ./nextspace-os_files-${CORE_VERSION}
mkdir -p /tmp/nextspace-os_files-${CORE_VERSION}
cp -R ${REPO_DIR}/System/* ./nextspace-os_files-${CORE_VERSION}/
rm ./nextspace-os_files-${CORE_VERSION}/GNUmakefile
tar zcf ${SOURCES_DIR}/nextspace-os_files-${CORE_VERSION}.tar.gz nextspace-os_files-${CORE_VERSION}
cd $CWD
cp ${REPO_DIR}/Libraries/core/nextspace.fsl ${SOURCES_DIR}
spectool -g -R ${SPECS_DIR}/nextspace-core.spec
echo "========== Building NEXTSPACE core components (nextspace-core) RPM... =========="
rpmbuild -bb ${SPECS_DIR}/nextspace-core.spec 2>&1 >> nextspace-core_build.log
if [ $? -eq 0 ]; then 
    echo "================================================================================"
    echo " Building of NEXTSPACE Core RPM SUCCEEDED!"
    echo "================================================================================"
    sudo yum -y localinstall \
        ${RPMS_DIR}/nextspace-core-${CORE_VERSION}* \
        ${RPMS_DIR}/nextspace-core-devel-${CORE_VERSION}*
else
    echo "================================================================================"
    echo " Building of NEXTSPACE Core RPM FAILED!"
    echo "================================================================================"
    exit $?
fi
rm ${SPECS_DIR}/nextspace-core.spec
rm ${SOURCES_DIR}/nextspace-os_files-${CORE_VERSION}.tar.gz

# libwraster
echo "================================================================================"
echo " Building Raster graphics library (libwraster) RPM..."
echo " Build log: libwraster_build.log"
echo "================================================================================"
cp ${REPO_DIR}/Libraries/libwraster/libwraster.spec ${SPECS_DIR}
echo "========== Install libwraster build dependencies... ============================"
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/libwraster.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > libwraster_build.log
echo "========== Downloading libwraster sources... ==================================="
source /Developer/Makefiles/GNUstep.sh
cd ${REPO_DIR}/Libraries/libwraster && make dist
cd $CWD
mv ${REPO_DIR}/Libraries/libwraster-${WRASTER_VERSION}.tar.gz ${SOURCES_DIR}
spectool -g -R ${SPECS_DIR}/libwraster.spec
echo "=========== Building libwraster RPM... ========================================="
rpmbuild -bb ${SPECS_DIR}/libwraster.spec 2>&1 >> libwraster_build.log
if [ $? -eq 0 ]; then 
    echo "================================================================================"
    echo " Building libwraster RPM SUCCEEDED!"
    echo "================================================================================"
    sudo yum -y localinstall \
        ${RPMS_DIR}/libwraster-${WRASTER_VERSION}* \
        ${RPMS_DIR}/libwraster-devel-${WRASTER_VERSION}*
else
    echo "================================================================================"
    echo " Building libwraster RPM FAILED!"
    echo "================================================================================"
    exit $?
fi
rm ${SPECS_DIR}/libwraster.spec

# GNUstep
echo "================================================================================"
echo " Building NEXTSPACE GNUstep (nextspace-gnustep) package..."
echo " Build log: gnustep_build.log"
echo "================================================================================"
cp ${REPO_DIR}/Libraries/gnustep/nextspace-gnustep.spec ${SPECS_DIR}
cp ${REPO_DIR}/Libraries/gnustep/gdnc-local.service ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/gnustep/gdnc.service ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/gnustep/gdomap.interfaces ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/gnustep/gdomap.service ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/gnustep/gpbs.service ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/gnustep/gnustep-gui-images.tar.gz ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/gnustep/projectcenter-images.tar.gz ${SOURCES_DIR}
echo "========== Install GNUstep build dependencies... ==============================="
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/nextspace-gnustep.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > gnustep_build.log
echo "========== Downloading GNUstep sources... ======================================"
spectool -g -R ${SPECS_DIR}/nextspace-gnustep.spec
echo "========== Building GNUstep package... ========================================="
rpmbuild -bb ${SPECS_DIR}/nextspace-gnustep.spec 2>&1 >> gnustep_build.log
if [ $? -eq 0 ]; then 
    echo "================================================================================"
    echo " Building of NEXTSPACE GNUstep RPM SUCCEEDED!"
    echo "================================================================================"
    sudo yum -y localinstall \
        ${RPMS_DIR}/nextspace-gnustep-${GNUSTEP_VERSION}* \
        ${RPMS_DIR}/nextspace-gnustep-devel-${GNUSTEP_VERSION}*
else
    echo "================================================================================"
    echo " Building of NEXTSPACE GNUstep RPM FAILED!"
    echo "================================================================================"
    exit $?
fi
rm ${SPECS_DIR}/nextspace-gnustep.spec

echo "================================================================================"
echo " Build and install of NEXTSPACE Libraries SUCCEEDED!"
echo "================================================================================"

exit 0
