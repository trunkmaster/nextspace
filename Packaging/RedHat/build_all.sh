#!/bin/sh
# This script uses `sudo` to install generated RPMs. Please make sure user you
# run this script as has appropriate rights.
# Notice it always rebuilds and reinstalls packages even if they're already installed.
#

BUILD_RPM=1
. `dirname $0`/../functions.sh
. `dirname $0`/../environment.sh

NEXTSPACE_DIR="$(cd "$(dirname "$0")/../.."; pwd)"

test -d "${NEXTSPACE_DIR}" || errorExit "Invalid NEXTSPACE directory: '${NEXTSPACE_DIR}'."
prepare_redhat_environment || error_exit "Failed to setup building environment. Exiting..."

rm -rf ~/rpmbuild/SOURCES/*
rm -rf ~/rpmbuild/BUILD/*
rm -rf ~/rpmbuild/BUILDROOT/*
rm -rf "${NEXTSPACE_DIR}/Packaging/RedHat/$OS_ID-$OS_VERSION/NSDeveloper"/*
rm -rf "${NEXTSPACE_DIR}/Packaging/RedHat/$OS_ID-$OS_VERSION/NSUser"/*

`dirname $0`/0.build_libraries.sh "$@" || abort_with_message
`dirname $0`/1.build_frameworks.sh "$@" || abort_with_message
`dirname $0`/2.build_applications.sh "$@" || abort_with_message

