%define GCD_VERSION	1.3
%define OBJC_VERSION	1.8.2
%define NSFILES_VERSION	0.5

Name:		nextspace-core
Version:	%{GCD_VERSION}_%{OBJC_VERSION}
Release:	1%{?dist}
Summary:	NextSpace core libraries and system files.
License:	Apache 2.0
URL:		http://swift.org
Source0:	libdispatch-%{GCD_VERSION}.tgz
Source1:	libobjc2-%{OBJC_VERSION}.tgz
Source2:	nextspace-files-%{NSFILES_VERSION}.tgz
#Source0.1:	htps://github.com/apple/swift-corelibs-libdispatch/archive/master.zip
#Source1.1:	https://github.com/gnustep/libobjc2/archive/master.zip

BuildRequires:	autoconf
BuildRequires:	libtool
BuildRequires:	clang >= 3.8
BuildRequires:	libbsd-devel
BuildRequires:	libstdc++-devel

BuildRequires:  cmake3

Requires:	glibc
Requires:	libgcc
Requires:	libstdc++
Requires:  	libbsd

%description
Grand Central Dispatch
~~~~~~~~~~~~~~~~~~~~~~
Grand Central Dispatch (GCD or libdispatch) provides comprehensive 
support for concurrent code execution on multicore hardware.
For details see http://github.com/apple/swift-corelibs-libdispatch.

The GNUstep Objective-C runtime
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The GNUstep Objective-C runtime is designed as a drop-in replacement for the
GCC runtime. It supports both a legacy and a modern ABI, allowing code compiled
with old versions of GCC to be supported without requiring recompilation.
The modern ABI adds the following features:

* Non-fragile instance variables.
* Protocol uniquing.
* Object planes support.
* Declared property introspection.

Both ABIs support the following feature above and beyond the GCC runtime:

* The modern Objective-C runtime APIs, introduced with OS X 10.5.
* Blocks (closures).
* Low memory profile for platforms where memory usage is more important than 
  speed.
* Synthesised property accessors.
* Efficient support for @synchronized()
* Type-dependent dispatch, eliminating stack corruption from mismatched 
  selectors.
* Support for the associated reference APIs introduced with Mac OS X 10.6.
* Support for the automatic reference counting APIs introduced with Mac OS X 10.

NextSpace configs and resources
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Various system-wide configuration files (udev, X11, useradd, user homedir
skeleton, ld paths, systemd services) and resources for NextSpace environment
(fonts, images) etc.

%package devel
Summary: Development header files for NextSpace core components.
Requires: %{name}%{?_isa} = %{version}-%{release}

%description devel
Development files for libdispatch (includes kqueue and pthread_workqueue) 
and libobjc. Also contains gnustep-make-2.6.7 to build nextspace-runtime and
develop applications and tools for NextSpace and GNUstep environments.

%prep
%setup -c -n nextspace-core -a 1 -a 2

%build
# Grand Central Dispatch
cd libdispatch-%{GCD_VERSION}
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
%{make_install}
cd ..

# Obj-C 2.0 runtime
cd libobjc2-%{OBJC_VERSION}
mkdir Build
cd Build
cmake3 .. \
    -DGNUSTEP_INSTALL_TYPE=SYSTEM \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_FLAGS=-I%{buildroot}/usr/NextSpace/include \
    -DCMAKE_LIBRARY_PATH=%{buildroot}/usr/NextSpace/lib \
    -DTESTS=OFF -DCMAKE_BUILD_TYPE=Release
make

%install
export QA_SKIP_BUILD_ROOT=1

# Grand Central Dispatch
builddir=%{_builddir}/nextspace-core
cd libdispatch-%{GCD_VERSION}
%{make_install}
rm -vrf %{buildroot}/usr/NextSpace/lib/pkgconfig
cp -vr ${builddir}/libdispatch-%{GCD_VERSION}/libkqueue/include/sys \
    %{buildroot}/usr/NextSpace/include/
install -D -m 0644 ${builddir}/libdispatch-%{GCD_VERSION}/libkqueue/kqueue.2 \
    %{buildroot}/usr/NextSpace/Documentation/man/man2/kqueue.2
install -m 0644 ${builddir}/libdispatch-%{GCD_VERSION}/libpwq/include/pthread_workqueue.h \
    %{buildroot}/usr/NextSpace/include/pthread_workqueue.h
install -m 0644 ${builddir}/libdispatch-%{GCD_VERSION}/libpwq/pthread_workqueue.3 \
    %{buildroot}/usr/NextSpace/Documentation/man/man3/pthread_workqueue.3
cd ..

# Obj-C 2.0 runtime
cd libobjc2-1.8.2
cp -vr ${builddir}/libobjc2-%{OBJC_VERSION}/objc \
    %{buildroot}/usr/NextSpace/include
cp -vr ${builddir}/libobjc2-%{OBJC_VERSION}/Build/libobjc*.so* \
    %{buildroot}/usr/NextSpace/lib
rm -v %{buildroot}/usr/NextSpace/include/objc/toydispatch.h
cd ..

# Files
cd nextspace-files-%{NSFILES_VERSION}
cp -vr ./* %{buildroot}
rm -v %{buildroot}/README
mkdir %{buildroot}/Users

%files
/Library/
/etc/X11/
%config /etc/default/useradd
/etc/ld.so.conf.d/
/etc/profile.d/
/etc/udev/
/usr/share/
/usr/NextSpace/Documentation/man/man1/open*.gz
/usr/NextSpace/Documentation/man/man7/GNUstep*.gz
/usr/NextSpace/Images
/usr/NextSpace/Preferences
/usr/NextSpace/lib/*
/usr/NextSpace/etc/
/usr/NextSpace/bin/GNUstepServices
/usr/NextSpace/bin/openapp
/usr/NextSpace/bin/opentool

%files devel
/Developer/
/usr/NextSpace/include/
/usr/NextSpace/bin/debugapp
/usr/NextSpace/bin/gnustep-config
/usr/NextSpace/bin/gnustep-tests
/usr/NextSpace/Documentation/man/man1/debugapp*
/usr/NextSpace/Documentation/man/man1/gnustep*
/usr/NextSpace/Documentation/man/man2/
/usr/NextSpace/Documentation/man/man3/
/usr/NextSpace/Documentation/man/man7/library-combo*

%changelog
* Wed Oct 12 2016 Sergii Stoian <stoyan255@ukr.net> 1.3-1
- Initial spec.
