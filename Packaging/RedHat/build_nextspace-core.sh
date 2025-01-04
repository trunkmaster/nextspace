#!/bin/sh
# -*-Shell-script-*-

BUILD_RPM=1
. `dirname $0`/../functions.sh
. `dirname $0`/../environment.sh

SPEC_FILE=${PROJECT_DIR}/Core/nextspace-core.spec

print_H1 " Building of NEXTSPACE core components (nextspace-core) RPM..."
print_H2 "===== Install nextspace-core build dependencies..."
DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > /dev/null

print_H2 "===== Downloading NEXTSPACE Core sources..."
CORE_VERSION=`rpmspec -q --qf "%{version}:" ${SPEC_FILE} | awk -F: '{print $1}'`
cd /tmp 
rm -rf ./nextspace-os_files-${CORE_VERSION}
mkdir -p /tmp/nextspace-os_files-${CORE_VERSION}
cp -R ${PROJECT_DIR}/Core/os_files/* ./nextspace-os_files-${CORE_VERSION}/
rm ./nextspace-os_files-${CORE_VERSION}/GNUmakefile
tar zcf ${RPM_SOURCES_DIR}/nextspace-os_files-${CORE_VERSION}.tar.gz nextspace-os_files-${CORE_VERSION}
cd $CWD

CORE_VERSION=`rpm_version ${SPEC_FILE}`
cp ${PROJECT_DIR}/Core/nextspace.fsl ${RPM_SOURCES_DIR}
spectool -g -R ${SPEC_FILE}

print_H2 "===== Building NEXTSPACE core components (nextspace-core) RPM..."
rpmbuild -bb ${SPEC_FILE}
STATUS=$?
if [ $STATUS -eq 0 ]; then 
    print_OK " Building of NEXTSPACE Core RPM SUCCEEDED!"
    install_rpm nextspace-core ${RPMS_DIR}/nextspace-core-${CORE_VERSION}.rpm
    mv ${RPMS_DIR}/nextspace-core-${CORE_VERSION}.rpm ${RELEASE_USR}

    install_rpm nextspace-core-devel ${RPMS_DIR}/nextspace-core-devel-${CORE_VERSION}.rpm
    mv ${RPMS_DIR}/nextspace-core-devel-${CORE_VERSION}.rpm ${RELEASE_DEV}
else
    print_ERR " Building of NEXTSPACE Core RPM FAILED!"
    exit $STATUS
fi
