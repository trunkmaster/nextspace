#!/bin/bash

. ./versions.inc.sh

cp ../Debian/nextspace-make-${gnustep_make_version}/debian/nextspace.fsl ./nextspace-make-${gnustep_make_version}/FilesystemLayouts/nextspace || exit 1

cd ./nextspace-make-${gnustep_make_version}

export RUNTIME_VERSION="-fobjc-runtime=gnustep-1.8"

$MAKE_CMD clean
./configure \
	    --prefix=/ \
	    --with-config-file=/Library/Preferences/GNUstep.conf \
	    --with-layout=nextspace \
	    --enable-native-objc-exceptions \
	    --enable-debug-by-default \
	    --with-library-combo=ng-gnu-gnu

$MAKE_CMD install
