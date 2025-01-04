#!/bin/sh
# This script uses `sudo` to install generated RPMs. Please make sure user you 
# run this script as has appropriate rights.
# Notice it always rebuilds and reinstalls packages even if they're already installed.
#

BUILD_RPM=1
. `dirname $0`/../functions.sh
. `dirname $0`/../environment.sh

prepare_environment
if [ $? -eq 1 ];then
    print_ERR "Failed to setup building environment. Exiting..."
    exit 1
fi

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
`dirname $0`/build_libobjc2.sh $1
if [ $? -eq 1 ]; then
    echo "Aborting..."
    exit 1
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
