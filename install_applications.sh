#!/bin/sh
# This script uses `sudo` to install generated RPMs. Please make sure user you 
# run this script as has appropriate rights.
#

if [ $# -eq 0 ];then
    printf "\nERROR: No NEXTSPACE directory specified.\n\n"
    printf "You have to specify directory where NEXTSPACE git clone resides.\n"
    printf "For example, consider this scenario:\n\n"
    printf "$ git clone https://github.com/trunkmaster/nextspace\n"
    printf "$ cd nextspace\n"
    printf "$ ./install_applications.sh ~/nextspace\n\n"
    exit
fi

REPO_DIR=$1
CWD=`pwd`
SOURCES_DIR=~/rpmbuild/SOURCES
SPECS_DIR=~/rpmbuild/SPECS
RPMS_DIR=~/rpmbuild/RPMS/x86_64

APPLICATIONS_VERSION=0.90

echo "================================================================================"
echo " Prepare build environment"
echo "================================================================================"
echo "========== Install RPM build tools... =========================================="
sudo yum -y install rpm-build
echo "========== Create rpmbuild directories... ======================================"
mkdir -p $SOURCES_DIR
mkdir -p $SPECS_DIR

echo "================================================================================"
echo " Building NEXTSPACE Applications package..."
echo "================================================================================"
cp ${REPO_DIR}/Applications/nextspace-applications.spec ${SPECS_DIR}
echo "========== Install nextspace-applications build dependencies... ================"
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/nextspace-applications.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > applications_build.log
echo "========== Downloading nextspace-frameworks sources... ========================="
cd ${REPO_DIR}/Applications && make dist 2>&1 >> applications_build.log
cd $CWD
mv ${REPO_DIR}/nextspace-applications-${APPLICATIONS_VERSION}.tar.gz ${SOURCES_DIR}
spectool -g -R ${SPECS_DIR}/nextspace-applications.spec 2>&1 >> applications_build.log
echo "========== Building nextspace-applications package... =========================="
rpmbuild -bb ${SPECS_DIR}/nextspace-applications.spec 2>&1 >> applications_build.log
rm ${SPECS_DIR}/nextspace-applications.spec
if [ $? -eq 0 ]; then 
    echo "================================================================================"
    echo " Building of NEXTSPACE Applications RPM SUCCEEDED!"
    echo "================================================================================"
    echo "========== Installing nextspace-applications RPMs... ==========================="
    sudo yum -y localinstall \
        ${RPMS_DIR}/nextspace-applications-${APPLICATIONS_VERSION}* \
        ${RPMS_DIR}/nextspace-applications-devel-${APPLICATIONS_VERSION}*
else
    echo "================================================================================"
    echo " Building of NEXTSPACE Applications RPM FAILED!"
    echo "================================================================================"
    exit $?
fi

exit 0

