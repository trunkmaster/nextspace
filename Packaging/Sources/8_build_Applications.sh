#!/bin/bash

. ./versions.inc.sh

. /Developer/Makefiles/GNUstep.sh

CWD="$PWD"

cd ./Applications/ || exit 1

make clean
make install
ldconfig

cd $CWD/nextspace-gorm.app-${gorm_version} || exit 1

make clean
make install
ldconfig

cd $CWD/nextspace-projectcenter.app-${projectcenter_version} || exit 1

make clean
make install
ldconfig
