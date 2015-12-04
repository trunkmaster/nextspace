# http://etoileos.com/news/archive/2011/08/14/1206/
#
#./configure --prefix=/ --enable-objc-nonfragile-abi --enable-native-objc-exceptions --with-layout=gnustep --enable-debug-by-default CC=clang CXX=clang++

./configure \
--with-config-file=/Library/Preferences/GNUstep.conf \
--enable-importing-config-file \
--enable-native-objc-exceptions \
--with-thread-lib=-lpthread \
--enable-objc-nonfragile-abi \
--enable-debug-by-default \
CC=clang CXX=clang++
