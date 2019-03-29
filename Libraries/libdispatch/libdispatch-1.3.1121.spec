Name:		libdispatch
Version:	1.3.1121
Release:	2%{?dist}
Summary:	Grand Central Dispatch (GCD or libdispatch).
License:	Apache 2.0
URL:		http://swift.org
Source0:	libdispatch-1.3.1121.tar.gz
Source1:	https://github.com/apple/swift-corelibs-libdispatch/archive/master.zip
Patch0:		libdispatch_redhat_unistd.patch

BuildRequires:	libtool
BuildRequires:	clang >= 3.8
BuildRequires:	libbsd-devel
BuildRequires:	libstdc++-devel

Requires:	glibc
Requires:	libgcc
Requires:	libstdc++
Requires:  	libbsd

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
Requires: %{name}%{?_isa} = %{version}-%{release}

%description devel
Development header files for libdispatch (includes kqueue and pthread_workqueue).

%prep
%setup -q
cd %{_builddir}
%patch0 -p0

%build
#cd libdispatch-%{version}
mkdir -p _build
cd _build
cmake3 .. \
       -DCMAKE_C_COMPILER=clang \
       -DCMAKE_CXX_COMPILER=clang++ \
       -DCMAKE_INSTALL_PREFIX=/usr/NextSpace

make %{?_smp_mflags}

%install
#cd libdispatch-%{version}
cd _build
make install DESTDIR=%{buildroot}

%check
# requires lit.py from LLVM utilities
#cd _build
#make check-all

%files
/usr/NextSpace/lib/*.so

%files devel
/usr/NextSpace/include/
/usr/NextSpace/share/man/

%changelog
* Thu Mar 28 2019 Sergii Stoian <stoyan255@gmail.com> - 1.3-2
- Build latest version of libdispatch without libkqueue and pthread_workqueue.

* Wed Oct 12 2016 Sergii Stoian <stoyan255@gmail.com> 1.3-1
- Initial spec.
