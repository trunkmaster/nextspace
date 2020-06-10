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

print_H1 " Build libart library"

cd $CWD/../../Libraries
if [ ! -d "libart_lgpl" ];then
    git clone https://src.fedoraproject.org/rpms/libart_lgpl.git
fi
cd libart_lgpl
#git checkout imports/c7/libart_lgpl-2.3.21-10.el7
cp *.patch ${SOURCES_DIR}
cp libart_lgpl.spec ${SPECS_DIR}
spectool -g -R ${SPECS_DIR}/libart_lgpl.spec
DEPS=`rpmspec -q --buildrequires ${SPECS_DIR}/libart_lgpl.spec | awk -c '{print $1}'`
sudo yum -y install ${DEPS}
rpmbuild -bb ${SPECS_DIR}/libart_lgpl.spec
if [ $? -eq 0 ];then
    yum -y install ${RPMS_DIR}/libart_lgpl-2.3.21-23.el8.x86_64.rpm \
        ${RPMS_DIR}/libart_lgpl-devel-2.3.21-23.el8.x86_64.rpm
fi
cd $CWD
