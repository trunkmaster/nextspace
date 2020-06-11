#!/bin/sh
# -*-Shell-script-*-

. `dirname $0`/functions

if [ $# -eq 0 ];then
    print_help
    exit 1
fi

REPO_DIR=$1
SPEC_FILE=${REPO_DIR}/Libraries/core/nextspace-core.spec

print_H1 " Building of NEXTSPACE core components (nextspace-core) RPM...\n Build log: nextspace-core_build.log"

print_H2 "===== Install nextspace-core build dependencies..."
DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > nextspace-core_build.log

print_H2 "===== Downloading NEXTSPACE Core sources..."
CORE_VERSION=`rpmspec -q --qf "%{version}:" ${SPEC_FILE} | awk -F: '{print $1}'`
cd /tmp 
rm -rf ./nextspace-os_files-${CORE_VERSION}
mkdir -p /tmp/nextspace-os_files-${CORE_VERSION}
cp -R ${REPO_DIR}/System/* ./nextspace-os_files-${CORE_VERSION}/
rm ./nextspace-os_files-${CORE_VERSION}/GNUmakefile
tar zcf ${SOURCES_DIR}/nextspace-os_files-${CORE_VERSION}.tar.gz nextspace-os_files-${CORE_VERSION}
cd $CWD

CORE_VERSION=`rpm_version ${SPEC_FILE}`
cp ${REPO_DIR}/Libraries/core/nextspace.fsl ${SOURCES_DIR}
spectool -g -R ${SPEC_FILE}

print_H2 "===== Building NEXTSPACE core components (nextspace-core) RPM..."
rpmbuild -bb ${SPEC_FILE} 2>&1 >> nextspace-core_build.log
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
#rm ${SOURCES_DIR}/nextspace-os_files-${CORE_VERSION}.tar.gz
