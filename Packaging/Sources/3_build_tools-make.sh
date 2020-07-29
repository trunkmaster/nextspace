#!/bin/bash

. ./versions.inc.sh

cp ../Debian/nextspace-make-${gnustep_make_version}/debian/nextspace.fsl ./nextspace-make-${gnustep_make_version}/FilesystemLayouts/nextspace || exit 1

cd ./nextspace-make-${gnustep_make_version}

export RUNTIME_VERSION="-fobjc-runtime=gnustep-1.8"
export LD=/usr/bin/ld.gold
export LDFLAGS="-fuse-ld=/usr/bin/ld.gold -Wl,-rpath,/usr/NextSpace/lib -L/usr/NextSpace/lib"

make clean
sh ./configure \
	    --prefix=/ \
	    --with-config-file=/Library/Preferences/GNUstep.conf \
	    --with-layout=nextspace \
	    --enable-native-objc-exceptions \
	    --enable-debug-by-default \
	    --with-library-combo=ng-gnu-gnu

make $MAKE_ARGS install
