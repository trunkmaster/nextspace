#!/bin/sh
# -*-Shell-script-*-
#

. `dirname $0`/functions

print_H1 " Build libart library"

cd $CWD/../../Libraries
if [ ! -d "libart_lgpl" ];then
    git clone https://src.fedoraproject.org/rpms/libart_lgpl.git
fi

cd libart_lgpl
cp *.patch ${SOURCES_DIR}

LIBART_VERSION=`rpm_version libart_lgpl.spec`
spectool -g -R libart_lgpl.spec
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/libart_lgpl.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS}

rpmbuild -bb libart_lgpl.spec
if [ $? -eq 0 ];then
    install_rpm libart_lgpl ${RPMS_DIR}/libart_lgpl-${LIBART_VERSION}.rpm
    mv ${RPMS_DIR}/libart_lgpl-${LIBART_VERSION}.rpm ${RELEASE_USR}
    
    install_rpm libart_lgpl-devel ${RPMS_DIR}/libart_lgpl-devel-${LIBART_VERSION}.rpm
    mv ${RPMS_DIR}/libart_lgpl-devel-${LIBART_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/libart_lgpl-debuginfo-${LIBART_VERSION}.rpm ${RELEASE_DEV}
    if [ $OS_NAME == "centos" ] && [ $OS_VERSION != "7" ];then
        mv ${RPMS_DIR}/libart_lgpl-debugsource-${LIBART_VERSION}.rpm ${RELEASE_DEV}
    fi
fi
cd $CWD
