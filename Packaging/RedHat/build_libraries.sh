#!/bin/sh
# This script uses `sudo` to install generated RPMs. Please make sure user you 
# run this script as has appropriate rights.
# Notice it always rebuilds and reinstalls packages even if they're already installed.
#

. `dirname $0`/functions

if [ $# -eq 0 ];then
    print_help
    exit 1
fi

prepare_environment
if [ $? -eq 1 ];then
    print_ERR "Failed to setup building environment. Exiting..."
    exit 1
fi

# Build missed libraries for CentOS 8: libudisks2-devel and libart_lgpl
if [ $OS_NAME == "centos" ] && [ $OS_VERSION == "8" ];then
    rpm -q libart_lgpl 2>&1 > /dev/null
    if [ $? -eq 1 ]; then
        `dirname $0`/el8_build_libart.sh
    fi
    rpm -q libudisks-devel 2>&1 > /dev/null
    if [ $? -eq 1 ]; then
        `dirname $0`/el8_build_udisks2.sh
    fi
fi

REPO_DIR=$1

# libdispatch
`dirname $0`/build_libdispatch.sh $1
if [ $? -eq 1 ]; then
    echo "Aborting..."
    exit 1
fi

# libobjc2
`dirname $0`/build_libobjc2.sh $1
if [ $? -eq 1 ]; then
    echo "Aborting..."
    exit 1
fi

# nextspace-core
`dirname $0`/build_nextspace_core.sh $1
if [ $? -eq 1 ]; then
    echo "Aborting..."
    exit 1
fi

# libwraster
`dirname $0`/build_libwraster.sh $1
if [ $? -eq 1 ]; then
    echo "Aborting..."
    exit 1
fi

# GNUstep
`dirname $0`/build_nextspace_gnustep.sh $1
if [ $? -eq 1 ]; then
    echo "Aborting..."
    exit 1
fi

print_OK " Build and install of NEXTSPACE Libraries SUCCEEDED!"

exit 0
