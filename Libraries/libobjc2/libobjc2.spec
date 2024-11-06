%global toolchain clang

Name:	libobjc2
Version:  2.2.1
Release:  0%{?dist}
Summary:  GNUstep Objecttive-C runtime library.
License:  GPL v2.0
URL:      https://github.com/gnustep/libobjc2
Source0:  https://github.com/gnustep/libobjc2/archive/v%{version}.tar.gz
Source1:  https://github.com/Tessil/robin-map/archive/v1.2.1.tar.gz

BuildRequires:	cmake
BuildRequires:	clang >= 7.0.1
BuildRequires:	libtool
BuildRequires:	libdispatch-devel >= 1.3

Requires:	libdispatch >= 1.3

Provides:	libobjc.so 
Provides:	libobjc.so.4.6
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
%setup -n libobjc2-%{version} -a 1

%build
CMAKE_CMD=cmake

${CMAKE_CMD} \
	-DCMAKE_CXX_COMPILER=clang++ \
	-B%{_builddir}/%{name}-%{version}/robin-map-1.2.1 \
	-S%{_builddir}/%{name}-%{version}/robin-map-1.2.1
${CMAKE_CMD} --build robin-map-1.2.1

mkdir .build
cd .build

COMPILER_FLAGS="-I/usr/NextSpace/include -g -Wno-gnu-folding-constant"
${CMAKE_CMD} .. \
	-Dtsl-robin-map_DIR=%{_builddir}/%{name}-%{version}/robin-map-1.2.1 \
	-DCMAKE_C_COMPILER=clang \
	-DCMAKE_CXX_COMPILER=clang++ \
	-DGNUSTEP_INSTALL_TYPE=NONE \
	-DCMAKE_C_FLAGS="${COMPILER_FLAGS}" \
	-DCMAKE_CXX_FLAGS="${COMPILER_FLAGS}" \
	-DCMAKE_OBJC_FLAGS="${COMPILER_FLAGS}" \
	-DCMAKE_LIBRARY_PATH=/usr/NextSpace/lib \
	-DCMAKE_INSTALL_LIBDIR=lib \
	-DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
	-DCMAKE_MODULE_LINKER_FLAGS="-fuse-ld=/usr/bin/ld.gold -Wl,-rpath,/usr/NextSpace/lib" \
	-DCMAKE_SKIP_RPATH=ON \
	-DTESTS=OFF \
	-DCMAKE_BUILD_TYPE=Release

make

%install
cd .build
make install DESTDIR=%{buildroot}
mv -v %{buildroot}/usr/NextSpace/include/Block.h %{buildroot}/usr/NextSpace/include/Block-libobjc.h 

%files
/usr/NextSpace/lib/libobjc.so*
/usr/NextSpace/lib/pkgconfig

%files devel
/usr/NextSpace/include/objc
/usr/NextSpace/include/Block-libobjc.h
/usr/NextSpace/include/Block_private.h

%pre devel
if [ -f /usr/NextSpace/include/Block.h ];then
	mv -v /usr/NextSpace/include/Block.h /usr/NextSpace/include/Block-libdispatch.h
	ln -sv /usr/NextSpace/include/Block-libobjc.h /usr/NextSpace/include/Block.h
fi

%postun devel
if [ -f /usr/NextSpace/include/Block-libdispatch.h ];then
	mv /usr/NextSpace/include/Block-libdispatch.h /usr/NextSpace/include/Block.h
	rm /usr/NextSpace/include/Block.h
fi

%changelog
* Tue Nov 5 2024 Andres Morales <armm77@icloud.com>
  Support for CentOS 7 is being dropped.

* Thu Aug 27 2020 Sergii Stoian <stoyan255@gmail.com> - 2.1-0
- Switch to new ObjC library realease - 2.1

* Wed Apr 29 2020 Sergii Stoian <stoyan255@gmail.com> - 2.0-4
- Use clang from RedHat SCL repo on CentOS 7.
- Source file should be downloaded with `spectool -g` command into
  SOURCES directory manually.
- SPEC file adopted for Fedora 31.

* Thu May  2 2019 Sergii Stoian <stoyan255@gmail.com> - 2.0-3
- build with released 2.0 verion of libobjc2

* Fri Mar 29 2019 Sergii Stoian <stoyan255@gmail.com> - 2.0-2
- now library can be build without GNUstep Make installed
- switch to libobjc2 installation routines

* Wed Mar 27 2019 Sergii Stoian <stoyan255@gmail.com> - 2.0-1
- Fix an issue with incorrect offsets for the first ivar.
- Rework some of the ivar offset calculations.

* Fri Mar 22 2019 Sergii Stoian <stoyan255@gmail.com> 2.0
- New 2.0 version that aimed to build by clang 7.0.

* Wed Oct 12 2016 Sergii Stoian <stoyan255@gmail.com> 1.8.2-1
- Initial spec.
