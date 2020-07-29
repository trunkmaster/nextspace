#!/bin/bash

. ./versions.inc.sh

. /Developer/Makefiles/GNUstep.sh

cd ./nextspace-gui-${gnustep_gui_version} || exit 1

make clean
sh ./configure

make install
