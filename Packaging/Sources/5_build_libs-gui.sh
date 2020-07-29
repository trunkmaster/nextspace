#!/bin/bash

. ./versions.inc.sh

. /Developer/Makefiles/GNUstep.sh

cd ./nextspace-gui-${gnustep_gui_version} || exit 1

$MAKE_CMD clean
./configure

$MAKE_CMD install
