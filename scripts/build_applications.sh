#!/bin/sh
# This script uses `sudo` to install generated RPMs. Please make sure user you 
# run this script as has appropriate rights.
#

REPO_DIR=$1
. `dirname $0`/functions

if [ $# -eq 0 ];then
    print_help
    exit
fi

LOG_FILE=${CWD}/applications_build.log
APPLICATIONS_VERSION=0.90

prepare_environment

print_H1 " Building NEXTSPACE Applications package..."
cp ${REPO_DIR}/Applications/nextspace-applications.spec ${SPECS_DIR}
print_H2 "========== Install nextspace-applications build dependencies... ================"
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/nextspace-applications.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > ${LOG_FILE}
print_H2 "========== Downloading nextspace-frameworks sources... ========================="
source /Developer/Makefiles/GNUstep.sh
if [ -f /etc/os-release ]; then 
    source /etc/os-release;
    if [ $ID == "centos" ] && [ $VERSION_ID == "7" ];then
        source /opt/rh/llvm-toolset-7.0/enable
    fi
fi
print_H2 "--- Prepare Workspace sources ---"
cd ${REPO_DIR}/Applications/Workspace && ./WM.configure 2>&1 >> ${LOG_FILE}
print_H2 "--- Creating applications source tarball ---"
cd ${REPO_DIR}/Applications && make dist 2>&1 >> ${LOG_FILE}
cd $CWD
mv ${REPO_DIR}/nextspace-applications-${APPLICATIONS_VERSION}.tar.gz ${SOURCES_DIR}
spectool -g -R ${SPECS_DIR}/nextspace-applications.spec 2>&1 >> ${LOG_FILE}
print_H2 "========== Building nextspace-applications package... =========================="
rpmbuild -bb ${SPECS_DIR}/nextspace-applications.spec 2>&1 >> ${LOG_FILE}
if [ $? -eq 0 ]; then 
    print_OK " Building of NEXTSPACE Applications RPM SUCCEEDED!"
    print_H2 "========== Installing nextspace-applications RPMs... ==========================="
    sudo yum -y install \
        ${RPMS_DIR}/nextspace-applications-${APPLICATIONS_VERSION}* \
        ${RPMS_DIR}/nextspace-applications-devel-${APPLICATIONS_VERSION}*
else
    print_ERR " Building of NEXTSPACE Applications RPM FAILED!"
    exit $?
fi
rm ${SPECS_DIR}/nextspace-applications.spec

exit 0

