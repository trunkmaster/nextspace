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

echo "================================================================================"
echo " Prepare build environment"
echo "================================================================================"
echo "========== Install RPM build tools... =========================================="
sudo yum -y install rpm-build
echo "========== Create rpmbuild directories... ======================================"
mkdir -p $SOURCES_DIR
mkdir -p $SPECS_DIR
#cd $REPO_DIR

# libdispatch
echo "================================================================================"
echo " Building Grand Central Dispatch (libdispatch) package..."
echo " Build log: libdispatch_build.log"
echo "================================================================================"
cp ${REPO_DIR}/Libraries/libdispatch/libdispatch.spec ${SPECS_DIR}
cp ${REPO_DIR}/Libraries/libdispatch/libdispatch-dispatch.h.patch ${SOURCES_DIR}
echo "========== Install libdispatch build dependecies... ============================"
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/libdispatch.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > libdispatch_build.log
echo "========== Downloading libdispatch sources... =================================="
spectool -g -R ${SPECS_DIR}/libdispatch.spec 2>&1 >> libdispatch_build.log
echo "========== Building libdispatch package... ====================================="
rpmbuild -bb ${SPECS_DIR}/libdispatch.spec 2>&1 >> libdispatch_build.log
rm ${SPECS_DIR}/libdispatch.spec
if [ $? -eq 0 ]; then 
    echo "================================================================================"
    echo " Building of Grand Central Dispatch library RPM SUCCEEDED!"
    echo "================================================================================"
    echo "========== Installing libdispatch RPMs... ======================================"
#    sudo yum -y localinstall \
#        ${RPMS_DIR}/libdispatch-5.1.5* \
#        ${RPMS_DIR}/libdispatch-devel-5.1.5*
else
    echo "================================================================================"
    echo " Building of Grand Central Dispatch library RPM FAILED!"
    echo "================================================================================"
    exit $?
fi

# libobjc2
echo "================================================================================"
echo " Building Objective-C Runtime(libobjc2) package..."
echo " Build log: libobjc2_build.log"
echo "================================================================================"
cp ${REPO_DIR}/Libraries/libobjc2/libobjc2.spec ${SPECS_DIR}
echo "========== Install libobjc2 build dependecies... ==============================="
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/libobjc2.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > libobjc2_build.log
echo "========== Downloading libobjc2 sources... ====================================="
spectool -g -R ${SPECS_DIR}/libobjc2.spec 2>&1 >> libobjc2_build.log
echo "========== Building libobjc2 package... ========================================"
rpmbuild -bb ${SPECS_DIR}/libobjc2.spec 2>&1 >> libobjc2_build.log
rm ${SPECS_DIR}/libobjc2.spec
if [ $? -eq 0 ]; then 
    echo "================================================================================"
    echo " Building of Objective-C Runtime RPM SUCCEEDED!"
    echo "================================================================================"
#    sudo yum -y localinstall \
#        ${RPMS_DIR}/libobjc2-${OBJC2_VERSION}* \
#        ${RPMS_DIR}/libobjc2-devel-${OBJC2_VERSION}*
else
    echo "================================================================================"
    echo " Building of Objective-C Runtime RPM FAILED!"
    echo "================================================================================"
    exit $?
fi

# nextspace-core
echo "================================================================================"
echo " Building of NEXTSPACE core components (nextspace-core) RPM..."
echo " Build log: nextspace-core_build.log"
echo "================================================================================"
cp ${REPO_DIR}/Libraries/core/nextspace-core.spec ${SPECS_DIR}
echo "========== Install nextspace-core build dependecies... ========================="
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/nextspace-core.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > nextspace-core_build.log
echo "========== Downloading NEXTSPACE Core sources... ==============================="
cd ${REPO_DIR}/System && make dist 2>&1 > /dev/null
cd $CWD
mv ${REPO_DIR}/nextspace-os_files-${CORE_VERSION}.tar.gz ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/core/nextspace.fsl ${SOURCES_DIR}
spectool -g -R ${SPECS_DIR}/nextspace-core.spec 2>&1 >> nextspace-core_build.log
echo "========== Building NEXTSPACE core components (nextspace-core) RPM... =========="
rpmbuild -bb ${SPECS_DIR}/nextspace-core.spec 2>&1 >> nextspace-core_build.log
rm ${SPECS_DIR}/nextspace-core.spec
rm ${SOURCES_DIR}/nextspace-os_files-${CORE_VERSION}.tar.gz
if [ $? -eq 0 ]; then 
    echo "================================================================================"
    echo " Building of NEXTSPACE Core RPM SUCCEEDED!"
    echo "================================================================================"
#    sudo yum -y localinstall \
#        ${RPMS_DIR}/nextspace-core-0.95* \
#        ${RPMS_DIR}/nextspace-core-devel-0.95*
else
    echo "================================================================================"
    echo " Building of NEXTSPACE Core RPM FAILED!"
    echo "================================================================================"
    exit $?
fi

# libwraster
echo "================================================================================"
echo " Building Raster library (libwraster) RPM..."
echo " Build log: libwraster_build.log"
echo "================================================================================"
cp ${REPO_DIR}/Libraries/libwraster/libwraster.spec ${SPECS_DIR}
echo "========== Install libwraster build dependecies... ============================="
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/libwraster.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > libwraster_build.log
echo "========== Downloading libwraster sources... ==================================="
cd ${REPO_DIR}/Libraries/libwraster && make dist 2>&1 >> libwraster_build.log
cd $CWD
mv ${REPO_DIR}/Libraries/libwraster-${WRASTER_VERSION}.tar.gz ${SOURCES_DIR}
spectool -g -R ${SPECS_DIR}/libwraster.spec 2>&1 >> libwraster_build.log
echo "=========== Building libwraster RPM... ========================================="
rpmbuild -bb ${SPECS_DIR}/libwraster.spec 2>&1 >> libwraster_build.log
if [ $? -eq 0 ]; then 
    echo "================================================================================"
    echo " Building libwraster RPM SUCCEEDED!"
    echo "================================================================================"
#    sudo yum -y localinstall \
#        ${RPMS_DIR}/libwraster-${WRASTER_VERSION}* \
#        ${RPMS_DIR}/libwraster-devel-${WRASTER_VERSION}*
else
    echo "================================================================================"
    echo " Building libwraster RPM FAILED!"
    echo "================================================================================"
    exit $?
fi
rm ${SPECS_DIR}/libwraster.spec

echo "================================================================================"
echo " Build and install of NEXTSPACE Libraries SUCCEEDED!"
echo "================================================================================"

exit 0
