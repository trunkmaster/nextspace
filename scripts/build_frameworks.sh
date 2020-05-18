#!/bin/sh
# This script uses `sudo` to install generated RPMs. Please make sure user you 
# run this script as has appropriate rights.
#

if [ $# -eq 0 ];then
    printf "\nERROR: No NEXTSPACE directory specified.\n\n"
    printf "You have to specify directory where NEXTSPACE git clone resides.\n"
    printf "For example, consider this scenario:\n\n"
    printf "$ cd ~/Developer\n"
    printf "$ git clone https://github.com/trunkmaster/nextspace\n"
    printf "$ cd nextspace\n"
    printf "$ ./build_frameworks.sh ~/nextspace\n\n"
    exit
fi

REPO_DIR=$1
CWD=`pwd`
SOURCES_DIR=~/rpmbuild/SOURCES
SPECS_DIR=~/rpmbuild/SPECS
RPMS_DIR=~/rpmbuild/RPMS/x86_64

FRAMEWORKS_VERSION=0.90

echo "================================================================================"
echo " Prepare build environment"
echo "================================================================================"
echo "========== Install RPM build tools... =========================================="
sudo yum -y install rpm-build
echo "========== Create rpmbuild directories... ======================================"
mkdir -p $SOURCES_DIR
mkdir -p $SPECS_DIR

echo "================================================================================"
echo " Building NEXTSPACE Frameworks package..."
echo "================================================================================"
cp ${REPO_DIR}/Frameworks/nextspace-frameworks.spec ${SPECS_DIR}
echo "========== Install nextspace-frameworks build dependencies... ==================="
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/nextspace-frameworks.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > frameworks_build.log
echo "========== Downloading nextspace-frameworks sources... ========================="
source /Developer/Makefiles/GNUstep.sh
cd ${REPO_DIR}/Frameworks && make dist 2>&1 >> frameworks_build.log
cd $CWD
mv ${REPO_DIR}/nextspace-frameworks-${FRAMEWORKS_VERSION}.tar.gz ${SOURCES_DIR}
spectool -g -R ${SPECS_DIR}/nextspace-frameworks.spec 2>&1 >> frameworks_build.log
echo "========== Building nextspace-frameworks package... ============================"
rpmbuild -bb ${SPECS_DIR}/nextspace-frameworks.spec 2>&1 >> frameworks_build.log
rm ${SPECS_DIR}/nextspace-frameworks.spec
if [ $? -eq 0 ]; then 
    echo "================================================================================"
    echo " Building of NEXTSPACE Frameworks RPM SUCCEEDED!"
    echo "================================================================================"
    echo "========== Installing nextspace-frameworks RPMs... ============================="
    sudo yum -y localinstall \
        ${RPMS_DIR}/nextspace-frameworks-${FRAMEWORKS_VERSION}* \
        ${RPMS_DIR}/nextspace-frameworks-devel-${FRAMEWORKS_VERSION}*
else
    echo "================================================================================"
    echo " Building of NEXTSPACE Frameworks RPM FAILED!"
    echo "================================================================================"
    exit $?
fi

exit 0

