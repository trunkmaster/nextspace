#!/bin/sh
# -*-Shell-script-*-

. `dirname $0`/functions

if [ $# -eq 0 ];then
    print_help
    exit 1
fi

REPO_DIR=$1
SPEC_FILE=${REPO_DIR}/Libraries/selinux/nextspace-selinux.spec

print_H1 " Building of NEXTSPACE SELinux components (nextspace-selinux) RPM..."

print_H2 "===== Install nextspace-selinux build dependencies..."
DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > /dev/null

print_H2 "===== Downloading NEXTSPACE SELinux sources..."
SELINUX_VERSION=`rpmspec -q --qf "%{version}:" ${SPEC_FILE} | awk -F: '{print $1}'`
cp ${REPO_DIR}/Libraries/selinux/ns-Login.fc ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/selinux/ns-Login.if ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/selinux/ns-Login.te ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/selinux/ns-core.fc ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/selinux/ns-core.if ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/selinux/ns-core.te ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/selinux/ns-gdnc.fc ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/selinux/ns-gdnc.if ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/selinux/ns-gdnc.te ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/selinux/ns-gdomap.fc ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/selinux/ns-gdomap.if ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/selinux/ns-gdomap.te ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/selinux/ns-gpbs.fc ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/selinux/ns-gpbs.if ${SOURCES_DIR}
cp ${REPO_DIR}/Libraries/selinux/ns-gpbs.te ${SOURCES_DIR}

SELINUX_VERSION=`rpm_version ${SPEC_FILE}`
spectool -g -R ${SPEC_FILE}

print_H2 "===== Building NEXTSPACE SELinux components (nextspace-selinux) RPM..."
rpmbuild -bb ${SPEC_FILE}
STATUS=$?
if [ $STATUS -eq 0 ]; then 
    print_OK " Building of NEXTSPACE SELinux RPM SUCCEEDED!"
    install_rpm nextspace-selinux ${RPMS_DIR}/nextspace-selinux-${SELINUX_VERSION}.rpm
    mv ${RPMS_DIR}/nextspace-selinux-${SELINUX_VERSION}.rpm ${RELEASE_USR}
else
    print_ERR " Building of NEXTSPACE SELinux RPM FAILED!"
    exit $STATUS
fi
