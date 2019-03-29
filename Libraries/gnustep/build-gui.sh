#!/bin/sh

GUI_VERSION=0.24.1

printf "========== Extract and patch GUI ${GUI_VERSION} ==========\n"
rm -rf gnustep-gui-${GUI_VERSION}
tar zxf gnustep-gui-${GUI_VERSION}.tar.gz
cat gnustep-gui-*.patch | patch -p0
if [ $? -eq 0 ]; then
    printf "========== CONFIGURE GUI ${GUI_VERSION} ==========\n"
    cd gnustep-gui-${GUI_VERSION}
    ./configure
fi

if [ $? -eq 0 ]; then
    printf "========== BUILD Base ${GUI_VERSION} ==========\n"
    make
fi
