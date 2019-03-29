#!/bin/sh

BASE_VERSION=1.26.0

printf "========== Extract and patch Base ${BASE_VERSION} ==========\n"
rm -rf gnustep-base-${BASE_VERSION}
tar zxf gnustep-base-${BASE_VERSION}.tar.gz

#cat gnustep-base-*.patch | patch -p0
if [ $? -eq 0 ]; then
    printf "========== CONFIGURE Base ${BASE_VERSION} ==========\n"
    cd gnustep-base-${BASE_VERSION}
    ./configure --disable-mixedabi
fi

if [ $? -eq 0 ]; then
    printf "========== BUILD Base ${BASE_VERSION} ==========\n"
    make
fi
