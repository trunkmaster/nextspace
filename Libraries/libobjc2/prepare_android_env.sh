#!/bin/sh

export ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/24.0.8215888
export TOOLCHAIN=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/darwin-x86_64
export CCPREFIX=$TOOLCHAIN/bin/aarch64-linux-android24
export CC="$CCPREFIX-clang"
export CXX="$CCPREFIX-clang++"
export OBJC="$CCPREFIX-clang"
export OBJCXX="$CCPREFIX-clang++"
export AS="$CCPREFIX-clang"
export LD="$TOOLCHAIN/bin/ld.lld"
export AR="$TOOLCHAIN/bin/llvm-ar"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"
export NM="$TOOLCHAIN/bin/llvm-nm"
export OBJDUMP="$TOOLCHAIN/bin/llvm-objdump"
export LDFLAGS="-fuse-ld=lld"
export LIBS="-lc++_shared"

cmake -B build \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_NDK=$ANDROID_NDK_HOME \
  -DANDROID_STL=c++_shared \
  -DCMAKE_FIND_USE_CMAKE_PATH=false \
  -DCMAKE_C_COMPILER=$CC \
  -DCMAKE_CXX_COMPILER=$CXX \
  -DCMAKE_ASM_COMPILER=$AS \
  -DCMAKE_BUILD_TYPE=Debug \
  -DTESTS=ON \
  -DANDROID_PLATFORM=android-24 \
  -G Ninja
