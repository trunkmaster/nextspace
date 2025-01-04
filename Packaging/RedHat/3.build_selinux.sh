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

REPO_DIR=$1

# NextSpace SELinux
`dirname $0`/build_nextspace-selinux.sh $1
if [ $? -eq 1 ]; then
    echo "Aborting..."
    exit 1
fi

print_OK " Build and install of NEXTSPACE SELinux SUCCEEDED!"

exit 0
