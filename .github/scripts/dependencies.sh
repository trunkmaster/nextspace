#! /usr/bin/env sh

set -ex

install_gnustep_make() {
    echo "::group::GNUstep Make"
    cd $DEPS_PATH
    git clone -q -b ${TOOLS_MAKE_BRANCH:-master} https://github.com/gnustep/tools-make.git
    cd tools-make
    MAKE_OPTS=
    if [ -n "$HOST" ]; then
      MAKE_OPTS="$MAKE_OPTS --host=$HOST"
    fi
    if [ -n "$RUNTIME_VERSION" ]; then
      MAKE_OPTS="$MAKE_OPTS --with-runtime-abi=$RUNTIME_VERSION"
    fi
    ./configure --prefix=$INSTALL_PATH --with-library-combo=$LIBRARY_COMBO --with-libdir=$LIBDIR $MAKE_OPTS || cat config.log
    make install

    echo Objective-C build flags:
    $INSTALL_PATH/bin/gnustep-config --objc-flags
    echo "::endgroup::"
}

install_libobjc2() {
    echo "::group::libobjc2"
    cd $DEPS_PATH
    git clone -q https://github.com/gnustep/libobjc2.git
    cd libobjc2
    git submodule sync
    git submodule update --init
    mkdir build
    cd build
    cmake \
      -DTESTS=off \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DGNUSTEP_INSTALL_TYPE=NONE \
      -DCMAKE_INSTALL_PREFIX:PATH=$INSTALL_PATH \
      ../
    make install
    echo "::endgroup::"
}

install_libdispatch() {
    echo "::group::libdispatch"
    cd $DEPS_PATH
    # will reference upstream after https://github.com/apple/swift-corelibs-libdispatch/pull/534 is merged
    git clone -q -b system-blocksruntime https://github.com/ngrewe/swift-corelibs-libdispatch.git libdispatch
    mkdir libdispatch/build
    cd libdispatch/build
    # -Wno-error=void-pointer-to-int-cast to work around build error in queue.c due to -Werror
    # -Wno-error=unused-but-set-variable to work around build error in shims/yield.c due to -Werror
    cmake \
      -DBUILD_TESTING=off \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_INSTALL_PREFIX:PATH=$INSTALL_PATH \
      -DCMAKE_C_FLAGS="-Wno-error=void-pointer-to-int-cast -Wno-error=unused-but-set-variable" \
      -DINSTALL_PRIVATE_HEADERS=1 \
      -DBlocksRuntime_INCLUDE_DIR=$INSTALL_PATH/include \
      -DBlocksRuntime_LIBRARIES=$INSTALL_PATH/$LIBDIR/libobjc.so \
      ../
    make install
    echo "::endgroup::"
}

mkdir -p $DEPS_PATH

# Windows MSVC toolchain uses tools-windows-msvc scripts to install non-GNUstep dependencies;
# the MSYS2 toolchain uses Pacman to install non-GNUstep dependencies.
if [ "$LIBRARY_COMBO" = "ng-gnu-gnu" -a "$IS_WINDOWS_MSVC" != "true" -a "$IS_WINDOWS_MINGW" != "true" ]; then
    install_libobjc2
    install_libdispatch
fi

install_gnustep_make
