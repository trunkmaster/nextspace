#!/bin/sh
# This script uses `sudo` to install generated RPMs. Please make sure user you 
# run this script as has appropriate rights.
# Notice it always rebuilds and reinstalls packages even if they're already installed.
#

BUILD_RPM=1
. `dirname $0`/../functions.sh
. `dirname $0`/../environment.sh

prepare_redhat_environment || error_exit "Failed to setup building environment. Exiting..."

# Apple Grand Central Dispatch
`dirname $0`/build_libdispatch.sh "$@" || abort_with_message

# Apple Core Foundation
`dirname $0`/build_libcorefoundation.sh "$@" || abort_with_message

# GNUstep Objective-C runtime
`dirname $0`/build_libobjc2.sh "$@" || abort_with_message

# NextSpace Core
`dirname $0`/build_nextspace-core.sh "$@" || abort_with_message

# Raster graphics manipulation
`dirname $0`/build_libwraster.sh "$@" || abort_with_message

# GNUstep libraries
`dirname $0`/build_nextspace-gnustep.sh "$@" || abort_with_message

print_OK " Build and install of NEXTSPACE Libraries SUCCEEDED!"

exit 0
