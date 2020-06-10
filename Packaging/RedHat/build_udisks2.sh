#!/bin/sh
# -*-Shell-script-*-
#

. `dirname $0`/functions

cd `dirname $0`/../../Libraries
mkdir -p UDisks
cd UDisks
export CWD=`pwd`

build_libbytesize()
{
    print_H1 " Build libbytesize package"
    if [ ! -d "libbytesize" ];then
        git clone https://git.centos.org/rpms/libbytesize.git
    fi
    cd libbytesize
    git checkout imports/c8/libbytesize-1.4-1.el8

    cp SOURCES/*.patch ${SOURCES_DIR}
    cp SPECS/*.spec ${SPECS_DIR}
    curl -L https://github.com/storaged-project/libbytesize/releases/download/1.4/libbytesize-1.4.tar.gz \
	 -o ${SOURCES_DIR}/libbytesize-1.4.tar.gz
    DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/libbytesize.spec | awk -c '{print $1}'`
    sudo yum -y install ${DEPS}
    rpmbuild -bb ${SPECS_DIR}/libbytesize.spec
    cd $CWD
}

build_libblockdev()
{
    print_H1 " Build libblockdev package"
    if [ ! -d "libblockdev" ];then
        git clone https://git.centos.org/rpms/libblockdev.git
    fi
    cd libblockdev
    git checkout imports/c8/libblockdev-2.19-9.el8

    cp SOURCES/*.patch ${SOURCES_DIR}
    cp SPECS/*.spec ${SPECS_DIR}
    curl -L https://github.com/storaged-project/libblockdev/releases/download/2.19-1/libblockdev-2.19.tar.gz \
	 -o ${SOURCES_DIR}/libblockdev-2.19.tar.gz
    DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/libblockdev.spec | awk -c '{print $1}'`
    sudo yum -y install ${DEPS}
    rpmbuild -bb ${SPECS_DIR}/libblockdev.spec
    cd $CWD
}

build_iscsi_initiator_utils()
{
    print_H1 " Build iscsi-initiator-utils package"
    if [ ! -d "iscsi-initiator-utils" ];then
        git clone https://git.centos.org/rpms/iscsi-initiator-utils.git
    fi
    cd iscsi-initiator-utils
    git checkout imports/c8/iscsi-initiator-utils-6.2.0.877-1.gitf71581b.el8

    cp SOURCES/* ${SOURCES_DIR}
    cp SPECS/*.spec ${SPECS_DIR}
    spectool -g -R ${SPECS_DIR}/iscsi-initiator-utils.spec
    DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/iscsi-initiator-utils.spec | awk -c '{print $1}'`
    sudo yum -y install ${DEPS}
    rpmbuild -bb ${SPECS_DIR}/iscsi-initiator-utils.spec
    cd $CWD
}

build_libstoragemgmt()
{
    print_H1 " Build libstoragemgmt package"
    if [ ! -d "libstoragemgmt" ];then
        git clone https://git.centos.org/rpms/libstoragemgmt.git
    fi
    cd libstoragemgmt
    git checkout imports/c8/libstoragemgmt-1.8.1-2.el8

    cp SOURCES/* ${SOURCES_DIR}
    cp SPECS/*.spec ${SPECS_DIR}
    spectool -g -R ${SPECS_DIR}/libstoragemgmt.spec
    DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/libstoragemgmt.spec | awk -c '{print $1}'`
    sudo yum -y install ${DEPS}
    rpmbuild -bb ${SPECS_DIR}/libstoragemgmt.spec
    cd $CWD
}


build_udisks_dev()
{
    print_H1 " Build udisks-dev package"

    if [ ! -d "udisks2" ];then
        git clone https://git.centos.org/rpms/udisks2.git
    fi
    cd udisks2
    git checkout imports/c8/udisks2-2.8.3-2.el8

    cp SOURCES/*.patch ${SOURCES_DIR}
    cp SPECS/*.spec ${SPECS_DIR}
    spectool -g -R ${SPECS_DIR}/udisks2.spec
    DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/udisks2.spec | awk -c '{print $1}'`
    sudo yum -y install ${DEPS}
    rpmbuild -bb ${SPECS_DIR}/udisks2.spec
    cd $CWD
}

mkdir -p ${RELEASE_USR}
mkdir -p ${RELEASE_DEV}

rpm -q libbytesize-devel 2>&1 > /dev/null
if [ $? -eq 1 ]; then
    build_libbytesize
    if [ $? -eq 0 ];then
	yum -y install ${RPMS_DIR}/libbytesize-devel-1.4-1.el8.x86_64.rpm
	mv ${RPMS_DIR}/libbytesize-devel-1.4-1.el8.x86_64.rpm ${RELEASE_DEV}
    fi
fi

rpm -q libblockdev-devel 2>&1 > /dev/null
if [ $? -eq 1 ];then
    build_libblockdev
    if [ $? -eq 0 ];then
	yum -y install \
	    ${RPMS_DIR}/libblockdev-devel-2.19-9.el8.x86_64.rpm \
            ${RPMS_DIR}/libblockdev-utils-devel-2.19-9.el8.x86_64.rpm \
	    ${RPMS_DIR}/libblockdev-crypto-devel-2.19-9.el8.x86_64.rpm \
	    ${RPMS_DIR}/libblockdev-fs-devel-2.19-9.el8.x86_64.rpm \
	    ${RPMS_DIR}/libblockdev-kbd-devel-2.19-9.el8.x86_64.rpm \
	    ${RPMS_DIR}/libblockdev-loop-devel-2.19-9.el8.x86_64.rpm \
	    ${RPMS_DIR}/libblockdev-lvm-devel-2.19-9.el8.x86_64.rpm \
	    ${RPMS_DIR}/libblockdev-mdraid-devel-2.19-9.el8.x86_64.rpm \
	    ${RPMS_DIR}/libblockdev-part-devel-2.19-9.el8.x86_64.rpm \
	    ${RPMS_DIR}/libblockdev-swap-devel-2.19-9.el8.x86_64.rpm \
	    ${RPMS_DIR}/libblockdev-swap-devel-2.19-9.el8.x86_64.rpm \
            ${RPMS_DIR}/libblockdev-vdo-devel-2.19-9.el8.x86_64.rpm
    fi
fi

rpm -q iscsi-initiator-utils-devel 2>&1 > /dev/null
if [ $? -eq 1 ];then
    build_iscsi_initiator_utils
    if [ $? -eq 0 ];then
	yum -y install ${RPMS_DIR}/iscsi-initiator-utils-devel-6.2.0.877-1.gitf71581b.el8.x86_64.rpm
    fi
fi

rpm -q libstoragemgmt-devel 2>&1 > /dev/null
if [ $? -eq 1 ];then
    build_libstoragemgmt
    if [ $? -eq 0 ];then
	yum -y install ${RPMS_DIR}/libstoragemgmt-devel-1.8.1-2.el8.x86_64.rpm
    fi
fi

rpm -q libudisks2-devel 2>&1 > /dev/null
if [ $? -eq 1 ];then
    build_udisks_dev
    if [ $? -eq 0 ];then
	yum -y install ${RPMS_DIR}/libudisks2-devel-2.8.3-2.el8.x86_64.rpm
        mv ${RPMS_DIR}/libudisks2-devel-2.8.3-2.el8.x86_64.rpm ${RELEASE_DEV}
    fi
fi
