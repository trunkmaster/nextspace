Name:		libdispatch
Version:	1.3
Release:	1%{?dist}
Summary:	Grand Central Dispatch (GCD or libdispatch).
License:	Apache 2.0
URL:		http://swift.org
Source0:	libdispatch-1.3.tgz
# Getting libdispatch sources:
# git clone https://github.com/apple/swift-corelibs-libdispatch libdispatch-1.3
# cd libdispatch-1.3
# git submodule init
# git submodule update
#Source1:	https://github.com/apple/swift-corelibs-libdispatch/archive/master.zip
Patch0:		libdispatch-dispatch.h.patch
Patch1:		libdispatch-bsdtests.c.patch

BuildRequires:	autoconf
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


#%package
#Summary: libdispatch runtime library (includes kqueue and pthread_workqueue).

#%description libs
#Runtime library for clang.

%package devel
Summary: Development header files for libdispatch.
Requires: %{name}%{?_isa} = %{version}-%{release}

%description devel
Development header files for libdispatch (includes kqueue and pthread_workqueue).

%prep
%setup -q
cd %{_builddir}
%patch0 -p0
%patch1 -p0

%build
#cd libdispatch-%{version}
./configure \
    --bindir=/usr/NextSpace/bin \
    --sbindir=/usr/NextSpace/sbin \
    --datarootdir=/usr/NextSpace/share \
    --libdir=/usr/NextSpace/lib \
    --includedir=/usr/NextSpace/include \
    --mandir=/usr/NextSpace/Documentation/man \
    --docdir=/usr/NextSpace/Documentation/doc \
    CC=clang CXX=clang++

make %{?_smp_mflags}

%install
#cd libdispatch-%{version}
make install DESTDIR=%{buildroot}
rm -vrf %{buildroot}/usr/NextSpace/lib/pkgconfig
cp -vr %{_builddir}/libdispatch-1.3/libkqueue/include/sys %{buildroot}/usr/NextSpace/include/
install -D -m 0644 %{_builddir}/libdispatch-1.3/libkqueue/kqueue.2 %{buildroot}/usr/NextSpace/Documentation/man/man2/kqueue.2
install -m 0644 %{_builddir}/libdispatch-1.3/libpwq/include/pthread_workqueue.h %{buildroot}/usr/NextSpace/include/pthread_workqueue.h
install -m 0644 %{_builddir}/libdispatch-1.3/libpwq/pthread_workqueue.3 %{buildroot}/usr/NextSpace/Documentation/man/man3/pthread_workqueue.3

%check
# requires lit.py from LLVM utilities
#cd _build
#make check-all

%files
/usr/NextSpace/lib/*.so
/usr/NextSpace/lib/*.la

%files devel
/usr/NextSpace/include/
/usr/NextSpace/Documentation/

%changelog
* Wed Oct 12 2016 Sergii Stoian <stoyan255@ukr.net> 1.3-1
- Initial spec.
