#!/bin/sh
# -*-Shell-script-*-
#

. `dirname $0`/functions

#export CWD=`pwd`
#export SOURCES_DIR=~/rpmbuild/SOURCES
#export SPECS_DIR=~/rpmbuild/SPECS
#export RPMS_DIR=~/rpmbuild/RPMS/x86_64
#export RELEASE_USR="$CWD/CentOS-8/NSUser"
#export RELEASE_DEV="$CWD/CentOS-8/NSDeveloper"

print_H1 " Prepare build environment for CentOS 8"
print_H2 "========== Install RPM build tools... =========================================="
rpm -q rpm-build 2>&1 > /dev/null
if [ $? -eq 1 ]; then BUILD_TOOLS+=" rpm-build"; fi
rpm -q rpmdevtools 2>&1 > /dev/null
if [ $? -eq 1 ]; then BUILD_TOOLS+=" rpmdevtools"; fi
rpm -q make 2>&1 > /dev/null
if [ $? -eq 1 ]; then BUILD_TOOLS+=" make"; fi
rpm -q patch 2>&1 > /dev/null
if [ $? -eq 1 ]; then BUILD_TOOLS+=" patch"; fi

yum config-manager --set-enabled PowerTools
rpm -q epel-release 2>&1 > /dev/null
if [ $? -eq 1 ]; then BUILD_TOOLS+=" epel-release"; fi
rpm -q dnf-plugins-core 2>&1 > /dev/null
if [ $? -eq 1 ]; then BUILD_TOOLS+=" dnf-plugins-core"; fi

if [ "${BUILD_TOOLS}" != "" ]; then
    sudo yum -y install ${BUILD_TOOLS}
fi

print_H2 "========== Creating package directories..."
mkdir -p ${SOURCES_DIR}
mkdir -p ${SPECS_DIR}
mkdir -p ${RELEASE_USR}
mkdir -p ${RELEASE_DEV}

rpm -q git 2>&1 > /dev/null
if [ $? -eq 1 ]; then
    print_H2 "========== Installing git..."
    yum -y install git
fi

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
    mv ${RPMS_DIR}/libart_lgpl-2.3.21-23.el8.x86_64.rpm ${RELEASE_USR}
    mv ${RPMS_DIR}/libart_lgpl-devel-2.3.21-23.el8.x86_64.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/libart_lgpl-debuginfo-2.3.21-23.el8.x86_64.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/libart_lgpl-debugsource-2.3.21-23.el8.x86_64.rpm ${RELEASE_DEV}
fi
