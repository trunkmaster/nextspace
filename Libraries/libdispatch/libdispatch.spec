%global toolchain clang

Name:		libdispatch
Epoch:		1
Version:	5.9.2
Release:	1%{?dist}
Summary:	Grand Central Dispatch (GCD or libdispatch).
License:	Apache 2.0
URL:		https://github.com/apple/swift-corelibs-libdispatch
Source0:	libdispatch-%{version}.tar.gz

BuildRequires:	cmake
BuildRequires:	clang >= 7.0.1
BuildRequires:	libtool
BuildRequires:	libbsd-devel
BuildRequires:	libstdc++-devel

Requires:	glibc
Requires:	libgcc
Requires:	libstdc++
Requires:	libbsd

%description
Grand Central Dispatch (GCD or libdispatch) provides comprehensive 
support for concurrent code execution on multicore hardware.

libdispatch is currently available on all Darwin platforms. This project aims 
to make a modern version of libdispatch available on all other Swift platforms. 
To do this, we will implement as much of the portable subset of the API as 
possible, using the existing open source C implementation.

libdispatch on Darwin is a combination of logic in the xnu kernel alongside 
the user-space Library. The kernel has the most information available to 
balance workload across the entire system. As a first step, however, we believe 
it is useful to bring up the basic functionality of the library using user-space 
pthread primitives on Linux. Eventually, a Linux kernel module could be developed 
to support more informed thread scheduling.

%package devel
Summary: Development header files for libdispatch.
Requires: %{name}%{?_isa} = %{epoch}:%{version}-%{release}

%description devel
Development header files for libdispatch (includes kqueue and pthread_workqueue).

%prep
%setup -n swift-corelibs-libdispatch-swift-%{version}-RELEASE

%build
mkdir -p _build
cd _build
cmake .. \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
    -DCMAKE_INSTALL_LIBDIR=/usr/NextSpace/lib \
    -DCMAKE_INSTALL_MANDIR=/usr/NextSpace/Documentation/man \
    -DINSTALL_PRIVATE_HEADERS=YES \
    -DBUILD_TESTING=OFF \
    -DCMAKE_BUILD_TYPE=Debug

make %{?_smp_mflags}

%install
cd _build
make install DESTDIR=%{buildroot}
rm %{buildroot}/usr/NextSpace/include/Block_private.h
cd %{buildroot}/usr/NextSpace/lib
SHORT_VER=`echo %{version} | awk -F. '{print $1}'`
mv libBlocksRuntime.so libBlocksRuntime.so.%{version}
ln -sf libBlocksRuntime.so.%{version} libBlocksRuntime.so
ln -sf libBlocksRuntime.so.%{version} libBlocksRuntime.so.$SHORT_VER
mv libdispatch.so libdispatch.so.%{version}
ln -sf libdispatch.so.%{version} libdispatch.so
ln -sf libdispatch.so.%{version} libdispatch.so.$SHORT_VER

%check

%files
/usr/NextSpace/lib/*.so*

%files devel
/usr/NextSpace/include/Block.h
/usr/NextSpace/include/dispatch
/usr/NextSpace/include/os
/usr/NextSpace/Documentation/man/man3/dispatch*

%changelog
* Tue Nov 5 2024 Andres Morales <armm77@icloud.com>
  Support for CentOS 7 is being dropped.

* Wed Sep 22 2021 Sergii Stoian <stoyan255@gmail.com> - 5.4.2-1
  Install man pages into Documentaion directory.

* Tue Aug 3 2021 Sergii Stoian <stoyan255@gmail.com> - 5.4.2
  Use version 5.4.2 from Swift repo for CentOS 7.

* Wed Apr 29 2020 Sergii Stoian <stoyan255@gmail.com> - 5.1.5
- Use clang from RedHat SCL repo on CentOS 7.
- New libdispatch version 5.1.5.
- With new libdispatch version no need to patch sources against 
  '__block' usage.
- Source file should be downloaded with `spectool -g` command into
  SOURCES directory manually.
- SPEC file adopted for Fedora 31.

* Thu May 23 2019 Sergii Stoian <stoyan255@gmail.com> - 1.3.1121-3
- New build flag `INSTALL_PRIVATE_HEADERS=YES` was added.

* Thu Mar 28 2019 Sergii Stoian <stoyan255@gmail.com> - 1.3.1121-2
- Build latest version of libdispatch without libkqueue and pthread_workqueue.

* Wed Oct 12 2016 Sergii Stoian <stoyan255@gmail.com> 1.3-1
- Initial spec.
