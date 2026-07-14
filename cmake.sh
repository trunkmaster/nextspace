cmake .. \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_C_FLAGS="-I/usr/NextSpace/include" \
        -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/local/lib -L/usr/NextSpace/lib -luuid" \
        -DCF_DEPLOYMENT_SWIFT=NO \
        -DBUILD_SHARED_LIBS=YES \
        -DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
        -DCMAKE_INSTALL_LIBDIR=/usr/NextSpace/lib \
        -DCMAKE_LIBRARY_PATH=/usr/NextSpace/lib \
        \
        -DCMAKE_SKIP_RPATH=ON \
        -DCMAKE_BUILD_TYPE=Debug
