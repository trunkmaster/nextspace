#!/bin/sh

main () {
  # first argument is the build directory
  local BUILD_DIR=$1
  # second argument is the android ndk sysroot
  local ANDROID_NDK_SYSROOT=$2
  # third argument is the target triple
  # e.g. arm-linux-androideabi, aarch64-linux-android, x86_64-linux-android
  local TARGET_TRIPLE=$3

  if [ ! -d "$BUILD_DIR" ]
  then
      echo "Build directory argument not found"
      exit 1
  fi
  if [ ! -d "$ANDROID_NDK_SYSROOT" ]
  then
      echo "Android NDK sysroot argument not found"
      exit 1
  fi
  if [ -z "$TARGET_TRIPLE" ]
  then
      echo "Target triple argument not found"
      exit 1
  fi
  
  # We need to run the emulator with root permissions
  # This is needed to run the tests
  adb root

  local TEMP_DIR=$(mktemp -d)

  # Copy libobjc.so and test binaries to temporary directory
  cp $BUILD_DIR/libobjc.so* $TEMP_DIR
  cp $BUILD_DIR/Test/* $TEMP_DIR

  for file in $TEMP_DIR/*; do
    # Check if file is a binary
    if ! file $file | grep -q "ELF"
    then
      rm $file
      continue
    fi

    # Set runtime path to ORIGIN
    patchelf --set-rpath '$ORIGIN' $file
  done

  # Copy libc++_shared.so (required by libobjc2)
  cp $ANDROID_NDK_SYSROOT/usr/lib/$TARGET_TRIPLE/libc++_shared.so $TEMP_DIR

  adb shell rm -rf /data/local/tmp/libobjc2_tests
  adb push $TEMP_DIR /data/local/tmp/libobjc2_tests
  
  # Copy android_test_driver.sh to device
  adb push $BUILD_DIR/../.github/scripts/android_test_driver.sh /data/local/tmp/libobjc2_tests

  # Run the tests
  adb shell "cd /data/local/tmp/libobjc2_tests && sh android_test_driver.sh"
}

main "$@"
