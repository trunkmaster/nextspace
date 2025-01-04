#!/bin/sh
# -*-Shell-script-*-

BUILD_RPM=1
. `dirname $0`/../functions.sh
. `dirname $0`/../environment.sh
. /Developer/Makefiles/GNUstep.sh
. /etc/profile.d/nextspace.sh

SPEC_FILE=${PROJECT_DIR}/Libraries/gnustep/nextspace-gnustep.spec
GNUSTEP_VERSION=`rpm_version ${SPEC_FILE}`

print_H1 " Building NEXTSPACE GNUstep (nextspace-gnustep) package..."
cp ${PROJECT_DIR}/Libraries/gnustep/gdnc-local.service ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/gnustep/gdnc.service ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/gnustep/gdomap.interfaces ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/gnustep/gdomap.service ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/gnustep/gpbs.service ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/gnustep/gnustep-gui-images.tar.gz ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/gnustep/gnustep-gui-panels.tar.gz ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/gnustep/gorm-images.tar.gz ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/gnustep/projectcenter-images.tar.gz ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/gnustep/pc.patch ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/gnustep/gorm.patch ${RPM_SOURCES_DIR}
cp ${PROJECT_DIR}/Libraries/gnustep/libs-gui_* ${RPM_SOURCES_DIR}

print_H1 " Downloading Local GNUstep Back..."
tar zcf ${RPM_SOURCES_DIR}/back-art.tar.gz -C ${PROJECT_DIR}/Libraries/gnustep back-art

print_H2 "===== Install GNUstep build dependencies..."
DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
sudo yum -y install ${DEPS}

print_H2 "===== Downloading GNUstep sources..."
spectool -g -R ${SPEC_FILE}

print_H2 "===== Building GNUstep package..."
rpmbuild -bb ${SPEC_FILE}
STATUS=$?
if [ $STATUS -eq 0 ]; then 
    print_OK " Building of NEXTSPACE GNUstep RPM SUCCEEDED!"

    install_rpm nextspace-gnustep ${RPMS_DIR}/nextspace-gnustep-${GNUSTEP_VERSION}.rpm
    mv ${RPMS_DIR}/nextspace-gnustep-${GNUSTEP_VERSION}.rpm ${RELEASE_USR}

    install_rpm nextspace-gnustep-devel ${RPMS_DIR}/nextspace-gnustep-devel-${GNUSTEP_VERSION}.rpm
    mv ${RPMS_DIR}/nextspace-gnustep-devel-${GNUSTEP_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/nextspace-gnustep-debuginfo-${GNUSTEP_VERSION}.rpm ${RELEASE_DEV}
    if [ -f ${RPMS_DIR}/nextspace-gnustep-debugsource-${GNUSTEP_VERSION}.rpm ];then
        mv ${RPMS_DIR}/nextspace-gnustep-devel-debuginfo-${GNUSTEP_VERSION}.rpm ${RELEASE_DEV}
    fi
    if [ -f ${RPMS_DIR}/nextspace-gnustep-debugsource-${GNUSTEP_VERSION}.rpm ];then
        mv ${RPMS_DIR}/nextspace-gnustep-debugsource-${GNUSTEP_VERSION}.rpm ${RELEASE_DEV}
    fi
else
    print_ERR " Building of NEXTSPACE GNUstep RPM FAILED!"
    exit $STATUS
fi
