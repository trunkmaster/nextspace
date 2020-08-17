#!/bin/bash

. ./versions.inc.sh

. /Developer/Makefiles/GNUstep.sh

cd ./Frameworks || exit 1

$MAKE_CMD clean
$MAKE_CMD install
ldconfig
