Name:		libdispatch
%if 0%{?el7}
Version:	5.1.5
%else
Epoch:		2
Version:	5.4.2
%endif
Release:	0%{?dist}
Summary:	Grand Central Dispatch (GCD or libdispatch).
License:	Apache 2.0
URL:		http://swift.org
Source0:	https://github.com/apple/swift-corelibs-libdispatch/archive/swift-%{version}-RELEASE.tar.gz
%if 0%{?el7}
Patch0:		libdispatch-dispatch.h.patch
%endif

%if 0%{?el7}
BuildRequires:	cmake3
BuildRequires:	llvm-toolset-7.0-clang >= 7.0.1
%else
BuildRequires:	cmake
BuildRequires:	clang >= 7.0.1
%endif
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
%if 0%{?el7}
Requires: %{name}%{?_isa} = %{version}-%{release}
%else
Requires: %{name}%{?_isa} = %{epoch}:%{version}-%{release}
%endif

%description devel
Development header files for libdispatch (includes kqueue and pthread_workqueue).

%prep
%setup -n swift-corelibs-libdispatch-swift-%{version}-RELEASE
%if 0%{?el7}
%patch0 -p1
%endif

%build
mkdir -p _build
cd _build
%if 0%{?el7}
source /opt/rh/llvm-toolset-7.0/enable
cmake3 .. \
%else
cmake .. \
%endif
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
    -DCMAKE_INSTALL_LIBDIR=/usr/NextSpace/lib \
    -DINSTALL_PRIVATE_HEADERS=YES \
%if 0%{?el7}
    -DENABLE_TESTING=OFF \
%endif
    -DCMAKE_BUILD_TYPE=Debug

make %{?_smp_mflags}

%install
cd _build
make install DESTDIR=%{buildroot}
rm %{buildroot}/usr/NextSpace/include/Block_private.h

%check

%files
/usr/NextSpace/lib/*.so

%files devel
/usr/NextSpace/include/
/usr/NextSpace/share/man/

%changelog
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
