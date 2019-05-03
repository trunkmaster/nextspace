Name:		libobjc2
Version:	2.0
Release:	3%{?dist}
Summary:	GNUstep Objecttive-C 2.0 runtime library.
License:	GPL v2.0
URL:		https://github.com/gnustep/libobjc2
Source0:	libobjc2-2.0.tar.gz
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
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_FLAGS=-I/usr/NextSpace/include \
    -DCMAKE_LIBRARY_PATH=/usr/NextSpace/lib \
    -DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
    -DTESTS=OFF -DCMAKE_BUILD_TYPE=Release

make

%install
#cd libobjc2-%{version}
cd Build
make install DESTDIR=%{buildroot}
mv -v %{buildroot}/usr/NextSpace/include/Block.h %{buildroot}/usr/NextSpace/include/Block-libobjc.h 

%check
# requires lit.py from LLVM utilities
#cd _build
#make check-all

%files
/usr/NextSpace/lib/

%files devel
/usr/NextSpace/include/

%pre
mv -v /usr/NextSpace/include/Block.h /usr/NextSpace/include/Block-libdispatch.h
ln -sv /usr/NextSpace/include/Block-libobjc.h /usr/NextSpace/include/Block.h

%postun
rm -v /usr/NextSpace/include/Block.h
mv -v /usr/NextSpace/include/Block-libdispatch.h /usr/NextSpace/include/Block.h

%changelog
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
