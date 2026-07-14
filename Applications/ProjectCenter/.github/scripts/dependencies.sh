#! /usr/bin/env sh

set -ex

DEP_SRC=$HOME/dependency_source/
DEP_ROOT=$HOME/staging

install_prerequisites() {
    sudo apt-get -qq update
    sudo apt-get install -y cmake pkg-config libgnutls28-dev libgmp-dev libffi-dev libicu-dev \
	 libxml2-dev libxslt1-dev libssl-dev libavahi-client-dev zlib1g-dev

    if [ $LIBRARY_COMBO = 'gnu-gnu-gnu' ];
    then
	if [ $CC = 'gcc' ];
	then
	  sudo apt-get install -y gobjc;
	fi;
        sudo apt-get install -y libobjc-8-dev libblocksruntime-dev;
    else
	curl -s -o - https://apt.llvm.org/llvm-snapshot.gpg.key|sudo apt-key add -;
        sudo apt-add-repository "deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-9 main" && sudo apt-get update -qq;
	sudo apt-get install -y clang-9 libkqueue-dev libpthread-workqueue-dev;
	sudo update-alternatives   --install /usr/bin/clang   clang   /usr/bin/clang-9   10 \
             --slave   /usr/bin/clang++ clang++ /usr/bin/clang++-9;
	export PATH=$(echo "$PATH" | sed -e 's/:\/usr\/local\/clang-7.0.0\/bin//');
        if [ "$RUNTIME_VERSION" = "gnustep-2.0" ];
	then
            sudo update-alternatives --install "/usr/bin/ld" "ld" "/usr/bin/ld.gold" 10;
	fi;
    fi;
    if [ $LIBRARY_COMBO = 'ng-gnu-gnu' ];
    then
	curl -LO https://cmake.org/files/v3.15/cmake-3.15.5-Linux-x86_64.tar.gz;
	tar xf cmake-3.15.5-Linux-x86_64.tar.gz;
	mv cmake-3.15.5-Linux-x86_64 $HOME/cmake;
	export PATH=$HOME/cmake/:$HOME/cmake/bin:$PATH
    fi;
}

install_gnustep_make() {
    cd $DEP_SRC
    git clone https://github.com/gnustep/tools-make.git
    cd tools-make
    if [ -n "$RUNTIME_VERSION" ]
    then
        WITH_RUNTIME_ABI="--with-runtime-abi=${RUNTIME_VERSION}"
    else
        WITH_RUNTIME_ABI=""
    fi
    ./configure --prefix=$DEP_ROOT --with-library-combo=$LIBRARY_COMBO $WITH_RUNTIME_ABI
    make install
    echo Objective-C build flags: `$HOME/staging/bin/gnustep-config --objc-flags`
}

install_ng_runtime() {
    cd $DEP_SRC
    git clone https://github.com/gnustep/libobjc2.git
    cd libobjc2
    git submodule init
    git submodule sync
    git submodule update
    cd ..
    mkdir libobjc2/build
    cd libobjc2/build
    export CC="clang"
    export CXX="clang++"
    export CXXFLAGS="-std=c++11"
    cmake -DTESTS=off -DCMAKE_BUILD_TYPE=RelWithDebInfo -DGNUSTEP_INSTALL_TYPE=NONE -DCMAKE_INSTALL_PREFIX:PATH=$DEP_ROOT ../
    make install
}

install_libdispatch() {
    cd $DEP_SRC
    # will reference upstream after https://github.com/apple/swift-corelibs-libdispatch/pull/534 is merged
    git clone -b system-blocksruntime https://github.com/ngrewe/swift-corelibs-libdispatch.git
    mkdir swift-corelibs-libdispatch/build
    cd swift-corelibs-libdispatch/build
    export CC="clang"
    export CXX="clang++"
    export LIBRARY_PATH=$DEP_ROOT/lib;
    export LD_LIBRARY_PATH=$DEP_ROOT/lib:$LD_LIBRARY_PATH;
    export CPATH=$DEP_ROOT/include;
    cmake -DBUILD_TESTING=off -DCMAKE_BUILD_TYPE=RelWithDebInfo  -DCMAKE_INSTALL_PREFIX:PATH=$HOME/staging -DINSTALL_PRIVATE_HEADERS=1 -DBlocksRuntime_INCLUDE_DIR=$DEP_ROOT/include -DBlocksRuntime_LIBRARIES=$DEP_ROOT/lib/libobjc.so ../
    make install
}

install_gnustep_base() {
    export GNUSTEP_MAKEFILES=$HOME/staging/share/GNUstep/Makefiles
    . $HOME/staging/share/GNUstep/Makefiles/GNUstep.sh

    cd $DEP_SRC
    git clone https://github.com/gnustep/libs-base.git
    cd libs-base
    ./configure
    make
    make install
}

install_gnustep_gui() {
    export GNUSTEP_MAKEFILES=$HOME/staging/share/GNUstep/Makefiles
    . $HOME/staging/share/GNUstep/Makefiles/GNUstep.sh

    cd $DEP_SRC
    git clone https://github.com/gnustep/libs-gui.git
    cd libs-gui
    ./configure
    make
    make install
}

install_gnustep_back() {
    export GNUSTEP_MAKEFILES=$HOME/staging/share/GNUstep/Makefiles
    . $HOME/staging/share/GNUstep/Makefiles/GNUstep.sh

    cd $DEP_SRC
    git clone https://github.com/gnustep/libs-back.git
    cd libs-back
    ./configure
    make
    make install
}

mkdir -p $DEP_SRC
if [ "$LIBRARY_COMBO" = 'ng-gnu-gnu' ]
then
    install_ng_runtime
    install_libdispatch
fi

install_prerequisites
install_gnustep_make
install_gnustep_base
install_gnustep_gui
install_gnustep_back
