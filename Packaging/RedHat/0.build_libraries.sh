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

if [ "$OS_NAME" == "Rocky Linux" ] || [ "$OS_NAME" == "AlmaLinux" ] && [ $OS_VERSION = "8.8" ];then
    dnf -y install epel-release
    dnf config-manager --set-enabled powertools
fi

REPO_DIR=$1

# Apple Grand Central Dispatch
`dirname $0`/build_libdispatch.sh $1
if [ $? -eq 1 ]; then
    echo "Aborting..."
    exit 1
fi

# Apple Core Foundation
`dirname $0`/build_libcorefoundation.sh $1
if [ $? -eq 1 ]; then
    echo "Aborting..."
    exit 1
fi

# GNUstep Objective-C runtime
if [ "$OS_NAME" == "Rocky Linux" ] || [ "$OS_NAME" == "AlmaLinux" ];then
    `dirname $0`/build_libobjc2.sh $1
    if [ $? -eq 1 ]; then
        echo "Aborting..."
        exit 1
    fi
fi

# NextSpace Core
`dirname $0`/build_nextspace-core.sh $1
if [ $? -eq 1 ]; then
    echo "Aborting..."
    exit 1
fi

# Raster graphics manipulation
`dirname $0`/build_libwraster.sh $1
if [ $? -eq 1 ]; then
    echo "Aborting..."
    exit 1
fi

# GNUstep libraries
`dirname $0`/build_nextspace-gnustep.sh $1
if [ $? -eq 1 ]; then
    echo "Aborting..."
    exit 1
fi

print_OK " Build and install of NEXTSPACE Libraries SUCCEEDED!"

exit 0
