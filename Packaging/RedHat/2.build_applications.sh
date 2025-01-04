#!/bin/sh
# This script uses `sudo` to install generated RPMs. Please make sure user you 
# run this script as has appropriate rights.
#

BUILD_RPM=1
. `dirname $0`/../functions.sh
. `dirname $0`/../environment.sh

prepare_environment

LOG_FILE=/dev/null
SPEC_FILE=${PROJECT_DIR}/Applications/nextspace-applications.spec

print_H1 " Building NEXTSPACE Applications package..."

APPLICATIONS_VERSION=`rpmspec -q --qf "%{version}:" ${SPEC_FILE} | awk -F: '{print $1}'`
print_H2 "===== Install nextspace-applications build dependencies..."
DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > ${LOG_FILE}
print_H2 "===== Downloading nextspace-frameworks sources..."
source /Developer/Makefiles/GNUstep.sh

print_H2 "--- Prepare Workspace sources"
cd ${PROJECT_DIR}/Applications/Workspace
#rm WM/src/wconfig.h && rm WM/configure && ./WM.configure

print_H2 "--- Creating applications source tarball"
cd ${PROJECT_DIR}/Applications && make dist
cd $CWD
mv ${PROJECT_DIR}/nextspace-applications-${APPLICATIONS_VERSION}.tar.gz ${RPM_SOURCES_DIR}
spectool -g -R ${SPEC_FILE}

print_H2 "===== Building nextspace-applications package..."
rpmbuild -bb ${SPEC_FILE}
STATUS=$?
if [ $STATUS -eq 0 ]; then 
    print_OK " Building of NEXTSPACE Applications RPM SUCCEEDED!"
    print_H2 "===== Installing nextspace-applications RPMs..."
    APPLICATIONS_VERSION=`rpm_version ${SPEC_FILE}`

    install_rpm nextspace-applications ${RPMS_DIR}/nextspace-applications-${APPLICATIONS_VERSION}.rpm
    mv ${RPMS_DIR}/nextspace-applications-${APPLICATIONS_VERSION}.rpm ${RELEASE_USR}

    install_rpm nextspace-applications-devel ${RPMS_DIR}/nextspace-applications-devel-${APPLICATIONS_VERSION}.rpm
    mv ${RPMS_DIR}/nextspace-applications-devel-${APPLICATIONS_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/nextspace-applications-debuginfo-${APPLICATIONS_VERSION}.rpm ${RELEASE_DEV}
    if [ -f ${RPMS_DIR}/nextspace-applications-debugsource-${APPLICATIONS_VERSION}.rpm ];then
        mv ${RPMS_DIR}/nextspace-applications-debugsource-${APPLICATIONS_VERSION}.rpm ${RELEASE_DEV}
    fi
else
    print_ERR " Building of NEXTSPACE Applications RPM FAILED!"
    exit $STATUS
fi
