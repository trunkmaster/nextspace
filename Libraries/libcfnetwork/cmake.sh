CFN_CFLAGS="-F/usr/NextSpace/Frameworks -I/usr/NextSpace/include"
CFN_LD_FLAGS="-L/usr/NextSpace/lib"
cmake -B.build -S. \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DCFNETWORK_CFLAGS="${CFN_CFLAGS}" \
        -DCFNETWORK_LDLAGS="${CFN_LD_FLAGS}" \
        -DBUILD_SHARED_LIBS=YES \
        -DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
        -DCMAKE_INSTALL_LIBDIR=/usr/NextSpace/lib \
        \
        -DCMAKE_SKIP_RPATH=ON \
        -DCMAKE_BUILD_TYPE=Debug
