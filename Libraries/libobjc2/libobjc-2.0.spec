Name:		libobjc2
Version:	2.0
Release:	1%{?dist}
Summary:	GNUstep Objecttive-C 2.0 runtime library.
License:	GPL v2.0
URL:		https://github.com/gnustep/libobjc2
Source0:	libobjc2-2.0.tgz
#Source1:	https://github.com/gnustep/libobjc2/archive/master.zip

BuildRequires:	cmake3
BuildRequires:	libtool
BuildRequires:	clang >= 7.0
BuildRequires:	libdispatch-devel >= 1.3

Requires:	libdispatch >= 1.3

Provides:	libobjc.so libobjc.so.4.6
Conflicts:	libobjc.so.4

%description
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
* Low memory profile for platforms where memory usage is more important than speed.
* Synthesised property accessors.
* Efficient support for @synchronized()
* Type-dependent dispatch, eliminating stack corruption from mismatched selectors.
* Support for the associated reference APIs introduced with Mac OS X 10.6.
* Support for the automatic reference counting APIs introduced with Mac OS X 10.

%package devel
Summary: Development header files for libobjc2.
Requires: %{name}%{?_isa} = %{version}-%{release}

%description devel
Development header files for libdispatch (includes kqueue and pthread_workqueue).

%prep
%setup -q

%build
#cd libobjc2-%{version}
mkdir Build
cd Build
cmake3 .. \
    -DGNUSTEP_INSTALL_TYPE=SYSTEM \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_FLAGS=-I/usr/NextSpace/include \
    -DCMAKE_LIBRARY_PATH=/usr/NextSpace/lib \
    -DTESTS=OFF -DCMAKE_BUILD_TYPE=Release

make

%install
#cd libobjc2-%{version}
#cd Build
#make install DESTDIR=%{buildroot}
mkdir -p %{buildroot}/usr/NextSpace/include
cp -vr %{_builddir}/libobjc2-%{version}/objc %{buildroot}/usr/NextSpace/include
mkdir -p %{buildroot}/usr/NextSpace/lib
cp -vr %{_builddir}/libobjc2-%{version}/Build/libobjc*.so* %{buildroot}/usr/NextSpace/lib
rm -v %{buildroot}/usr/NextSpace/include/objc/toydispatch.h

#rm -vrf %{buildroot}/usr/NextSpace/lib/pkgconfig
#cp -vr %{_builddir}/libdispatch-1.3/libkqueue/include/sys %{buildroot}/usr/NextSpace/include/
#install -D -m 0644 %{_builddir}/libdispatch-1.3/libkqueue/kqueue.2 %{buildroot}/usr/NextSpace/Documentation/man/man2/kqueue.2
#install -m 0644 %{_builddir}/libdispatch-1.3/libpwq/include/pthread_workqueue.h %{buildroot}/usr/NextSpace/include/pthread_workqueue.h
#install -m 0644 %{_builddir}/libdispatch-1.3/libpwq/pthread_workqueue.3 %{buildroot}/usr/NextSpace/Documentation/man/man3/pthread_workqueue.3

%check
# requires lit.py from LLVM utilities
#cd _build
#make check-all

%files
/usr/NextSpace/lib/

%files devel
/usr/NextSpace/include/

%changelog
* Wed Mar 27 2019 Sergii Stoian <stoyan255@gmail.com> - 2.0-1
- Fix an issue with incorrect offsets for the first ivar.
- Rework some of the ivar offset calculations.
* Fri Mar 22 2019 Sergii Stoian <stoyan255@gmail.com> 2.0
- New 2.0 version that aimed to build by clang 7.0.
* Wed Oct 12 2016 Sergii Stoian <stoyan255@gmail.com> 1.8.2-1
- Initial spec.
