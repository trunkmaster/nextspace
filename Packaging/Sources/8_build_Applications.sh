#!/bin/bash

. ./versions.inc.sh

. /Developer/Makefiles/GNUstep.sh

CWD="$PWD"

cd ./Applications/ || exit 1

$MAKE_CMD clean
$MAKE_CMD install || exit 1
ldconfig

cd $CWD/nextspace-gorm.app-${gorm_version} || exit 1

$MAKE_CMD clean
$MAKE_CMD install || exit 1
ldconfig

cd $CWD/nextspace-projectcenter.app-${projectcenter_version} || exit 1

$MAKE_CMD clean
$MAKE_CMD install || exit 1
ldconfig
