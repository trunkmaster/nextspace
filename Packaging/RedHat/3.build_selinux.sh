#!/bin/sh
# This script uses `sudo` to install generated RPMs. Please make sure user you 
# run this script as has appropriate rights.
# Notice it always rebuilds and reinstalls packages even if they're already installed.
#

BUILD_RPM=1
. `dirname $0`/../functions.sh
. `dirname $0`/../environment.sh

prepare_redhat_environment || error_exit "Failed to setup building environment. Exiting..."

# NextSpace SELinux
`dirname $0`/build_nextspace-selinux.sh "$@" || abort_with_message

print_OK " Build and install of NEXTSPACE SELinux SUCCEEDED!"

exit 0
