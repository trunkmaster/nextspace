#!/bin/sh
# This script uses `sudo` to install generated RPMs. Please make sure user you
# run this script as has appropriate rights.
# Notice it always rebuilds and reinstalls packages even if they're already installed.
#

BUILD_RPM=1
. `dirname $0`/../functions.sh
. `dirname $0`/../environment.sh

if [ $# -eq 0 ];then
    print_help
    exit 1
fi

prepare_environment
if [ $? -eq 1 ];then
    print_ERR "Failed to setup building environment. Exiting..."
    exit 1
fi

rm -rf ~/rpmbuild/SOURCES/*
rm -rf ~/rpmbuild/BUILD/*
rm -rf ~/rpmbuild/BUILDROOT/*
rm -rf $1/Packaging/RedHat/$OS_ID-$OS_VERSION/NSDeveloper/*
rm -rf $1/Packaging/RedHat/$OS_ID-$OS_VERSION/NSUser/*

`dirname $0`/0.build_libraries.sh $1
if [ $? -eq 1 ]; then
    echo "Aborting..."
    exit 1
fi
`dirname $0`/1.build_frameworks.sh $1
if [ $? -eq 1 ]; then
    echo "Aborting..."
    exit 1
fi
`dirname $0`/2.build_applications.sh $1
if [ $? -eq 1 ]; then
    echo "Aborting..."
    exit 1
fi

