#!/bin/bash

. /Developer/Makefiles/GNUstep.sh

CWD="$PWD"

cd ./Applications/ || exit 1

make clean
make install
ldconfig

cd $CWD/nextspace-gorm.app-1.2.26 || exit 1

make clean
make install
ldconfig

cd $CWD/nextspace-projectcenter.app-0.6.2 || exit 1

make clean
make install
ldconfig
