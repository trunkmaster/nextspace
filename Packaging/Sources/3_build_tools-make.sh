#!/bin/bash

cd ./nextspace-make-2.7.0

export RUNTIME_VERSION="-fobjc-runtime=gnustep-1.8"
export LD=/usr/bin/ld.gold
export LDFLAGS="-fuse-ld=/usr/bin/ld.gold -Wl,-rpath,/usr/NextSpace/lib -L/usr/NextSpace/lib"

cp debian/nextspace.fsl FilesystemLayouts/nextspace

make clean
sh ./configure \
	    --prefix=/ \
	    --with-config-file=/Library/Preferences/GNUstep.conf \
	    --with-layout=nextspace \
	    --enable-native-objc-exceptions \
	    --enable-debug-by-default \
	    --with-library-combo=ng-gnu-gnu

make $MAKE_ARGS install
