#!/bin/sh
# -*-Shell-script-*-

BUILD_RPM=1
. `dirname $0`/../functions.sh
. `dirname $0`/../environment.sh
. /Developer/Makefiles/GNUstep.sh
. /etc/profile.d/nextspace.sh

SPEC_FILE=${PROJECT_DIR}/Libraries/selinux/nextspace-selinux.spec

print_H1 " Building of NEXTSPACE SELinux components (nextspace-selinux) RPM..."

print_H2 "===== Install nextspace-selinux build dependencies..."
DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
sudo yum -y install ${DEPS} 2>&1 > /dev/null

print_H2 "===== Downloading NEXTSPACE SELinux sources..."
SELINUX_VERSION=`rpmspec -q --qf "%{version}:" ${SPEC_FILE} | awk -F: '{print $1}'`
cp ${PROJECT_DIR}/Libraries/selinux/ns-Login.fc ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/selinux/ns-Login.if ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/selinux/ns-Login.te ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/selinux/ns-core.fc ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/selinux/ns-core.if ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/selinux/ns-core.te ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/selinux/ns-gdnc.fc ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/selinux/ns-gdnc.if ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/selinux/ns-gdnc.te ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/selinux/ns-gdomap.fc ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/selinux/ns-gdomap.if ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/selinux/ns-gdomap.te ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/selinux/ns-gpbs.fc ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/selinux/ns-gpbs.if ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/selinux/ns-gpbs.te ${RPM_SOURCES_DIR}

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
