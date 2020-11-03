#!/bin/sh
# -*-Shell-script-*-
#

. `dirname $0`/functions

SPEC_FILE=libart_lgpl.spec

print_H1 " Build libart library"

cd `dirname $0`/../../Libraries
if [ ! -d "libart_lgpl" ];then
    git clone https://src.fedoraproject.org/rpms/libart_lgpl.git
fi

cd libart_lgpl
cp *.patch ${SOURCES_DIR}

LIBART_VERSION=`rpm_version ${SPEC_FILE}`
spectool -g -R ${SPEC_FILE}
DEPS=`rpmspec -q --buildrequires ${SPEC_FILE} | awk -c '{print $1}'`
sudo yum -y install ${DEPS}

rpmbuild -bb libart_lgpl.spec
if [ $? -eq 0 ];then
    install_rpm libart_lgpl-${LIBART_VERSION} ${RPMS_DIR}/libart_lgpl-${LIBART_VERSION}.rpm
    mv ${RPMS_DIR}/libart_lgpl-${LIBART_VERSION}.rpm ${RELEASE_USR}
    
    install_rpm libart_lgpl-devel-${LIBART_VERSION} ${RPMS_DIR}/libart_lgpl-devel-${LIBART_VERSION}.rpm
    mv ${RPMS_DIR}/libart_lgpl-devel-${LIBART_VERSION}.rpm ${RELEASE_DEV}
    mv ${RPMS_DIR}/libart_lgpl-debuginfo-${LIBART_VERSION}.rpm ${RELEASE_DEV}
    if [ $OS_NAME == "centos" ] && [ $OS_VERSION != "7" ];then
        mv ${RPMS_DIR}/libart_lgpl-debugsource-${LIBART_VERSION}.rpm ${RELEASE_DEV}
    fi
fi
cd $CWD
