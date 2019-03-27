# Components enabled if supported by target architecture:
%ifarch %ix86 x86_64
  %bcond_without gold
%else
  %bcond_with gold
%endif

Name:		llvm
Version:	3.8.0
Release:	1%{?dist}
Summary:	The Low Level Virtual Machine

License:	NCSA
URL:		http://llvm.org
Source0:	http://llvm.org/releases/%{version}/%{name}-%{version}.src.tar.xz

Source100:	llvm-config.h

# recognize s390 as SystemZ when configuring build
Patch0:		llvm-3.7.1-cmake-s390.patch

BuildRequires:	cmake3
BuildRequires:	zlib-devel
BuildRequires:  libffi-devel
BuildRequires:	python-sphinx
%if %{with gold}
BuildRequires:  binutils-devel
%endif
BuildRequires:  libstdc++-static

Requires:	%{name}-libs%{?_isa} = %{version}-%{release}

%description
LLVM is a compiler infrastructure designed for compile-time, link-time,
runtime, and idle-time optimization of programs from arbitrary programming
languages. The compiler infrastructure includes mirror sets of programming
tools as well as libraries with equivalent functionality.

%package devel
Summary:	Libraries and header files for LLVM
Requires:	%{name}%{?_isa} = %{version}-%{release}
Requires(posttrans): %{_sbindir}/alternatives
Requires(posttrans): %{_sbindir}/alternatives

%description devel
This package contains library and header files needed to develop new native
programs that use the LLVM infrastructure.

%package doc
Summary:	Documentation for LLVM
BuildArch:	noarch
Requires:	%{name} = %{version}-%{release}

%description doc
Documentation for the LLVM compiler infrastructure.

%package libs
Summary:	LLVM shared libraries

%description libs
Shared libraries for the LLVM compiler infrastructure.

%package static
Summary:	LLVM static libraries

%description static
Static libraries for the LLVM compiler infrastructure.

%prep
%setup -q -n %{name}-%{version}.src
%patch0 -p1 -b .s390

%build
mkdir -p _build
cd _build

%ifarch s390
# Decrease debuginfo verbosity to reduce memory consumption during final library linking
%global optflags %(echo %{optflags} | sed 's/-g /-g1 /')
%endif

# force off shared libs as cmake macros turns it on.
%cmake3 .. \
	-DBUILD_SHARED_LIBS:BOOL=OFF \
	-DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_SHARED_LINKER_FLAGS="-Wl,-Bsymbolic -static-libstdc++" \
%ifarch s390
	-DCMAKE_C_FLAGS_RELWITHDEBINFO="%{optflags} -DNDEBUG" \
	-DCMAKE_CXX_FLAGS_RELWITHDEBINFO="%{optflags} -DNDEBUG" \
%endif
%if 0%{?__isa_bits} == 64
	-DLLVM_LIBDIR_SUFFIX=64 \
%else
	-DLLVM_LIBDIR_SUFFIX= \
%endif
	\
	-DLLVM_TARGETS_TO_BUILD="X86;AMDGPU;NVPTX;AArch64;ARM;BPF;CppBackend" \
	-DLLVM_ENABLE_LIBCXX:BOOL=OFF \
	-DLLVM_ENABLE_ZLIB:BOOL=ON \
	-DLLVM_ENABLE_FFI:BOOL=ON \
	-DLLVM_ENABLE_RTTI:BOOL=ON \
%if %{with gold}
	-DLLVM_BINUTILS_INCDIR=%{_includedir} \
%endif
	\
	-DLLVM_BUILD_RUNTIME:BOOL=ON \
	\
	-DLLVM_INCLUDE_TOOLS:BOOL=ON \
	-DLLVM_BUILD_TOOLS:BOOL=ON \
	\
	-DLLVM_INCLUDE_TESTS:BOOL=OFF \
	-DLLVM_BUILD_TESTS:BOOL=OFF \
	\
	-DLLVM_INCLUDE_EXAMPLES:BOOL=ON \
	-DLLVM_BUILD_EXAMPLES:BOOL=OFF \
	\
	-DLLVM_INCLUDE_UTILS:BOOL=ON \
	-DLLVM_INSTALL_UTILS:BOOL=OFF \
	\
	-DLLVM_INCLUDE_DOCS:BOOL=ON \
	-DLLVM_BUILD_DOCS:BOOL=ON \
	-DLLVM_ENABLE_SPHINX:BOOL=ON \
	-DLLVM_ENABLE_DOXYGEN:BOOL=OFF \
	\
	-DLLVM_BUILD_LLVM_DYLIB:BOOL=ON \
	-DLLVM_DYLIB_EXPORT_ALL:BOOL=ON \
	-DLLVM_LINK_LLVM_DYLIB:BOOL=ON \
	-DLLVM_BUILD_EXTERNAL_COMPILER_RT:BOOL=ON \
	-DLLVM_INSTALL_TOOLCHAIN_ONLY:BOOL=OFF \
	\
	-DSPHINX_EXECUTABLE=%{_bindir}/sphinx-build

make %{?_smp_mflags}

%install
cd _build
make install DESTDIR=%{buildroot}

# fix multi-lib
mv -v %{buildroot}%{_bindir}/llvm-config{,-%{__isa_bits}}
mv -v %{buildroot}%{_includedir}/llvm/Config/llvm-config{,-%{__isa_bits}}.h
install -m 0644 %{SOURCE100} %{buildroot}%{_includedir}/llvm/Config/llvm-config.h

%check
cd _build
make check-all || :

%post libs -p /sbin/ldconfig
%postun libs -p /sbin/ldconfig

%post devel
%{_sbindir}/update-alternatives --install %{_bindir}/llvm-config llvm-config %{_bindir}/llvm-config-%{__isa_bits} %{__isa_bits}

%postun devel
[ $1 -eq 0 ] && %{_sbindir}/update-alternatives --remove llvm-config %{_bindir}/llvm-config-%{__isa_bits}

%files
%{_bindir}/*
%{_mandir}/man1/*.1.*
%exclude %{_bindir}/llvm-config-%{__isa_bits}
%exclude %{_mandir}/man1/llvm-config.1.*

%files libs
%{_libdir}/*.so*

%files devel
%{_bindir}/llvm-config-%{__isa_bits}
%{_mandir}/man1/llvm-config.1.*
%{_includedir}/llvm
%{_includedir}/llvm-c
%{_libdir}/*.so
%{_datadir}/llvm/cmake

%files doc
%doc /usr/share/doc/llvm/html

%files static
%{_libdir}/*.a

%changelog
* Thu Mar 10 2016 Dave Airlie <airlied@redhat.com> 3.8.0-1
- llvm 3.8.0 release

* Wed Mar 09 2016 Dan Horák <dan[at][danny.cz> 3.8.0-0.3
- install back memory consumption workaround for s390

* Thu Mar 03 2016 Dave Airlie <airlied@redhat.com> 3.8.0-0.2
- llvm 3.8.0 rc3 release

* Fri Feb 19 2016 Dave Airlie <airlied@redhat.com> 3.8.0-0.1
- llvm 3.8.0 rc2 release

* Tue Feb 16 2016 Dan Horák <dan[at][danny.cz> 3.7.1-7
- recognize s390 as SystemZ when configuring build

* Sat Feb 13 2016 Dave Airlie <airlied@redhat.com> 3.7.1-6
- export C++ API for mesa.

* Sat Feb 13 2016 Dave Airlie <airlied@redhat.com> 3.7.1-5
- reintroduce llvm-static, clang needs it currently.

* Fri Feb 12 2016 Dave Airlie <airlied@redhat.com> 3.7.1-4
- jump back to single llvm library, the split libs aren't working very well.

* Fri Feb 05 2016 Dave Airlie <airlied@redhat.com> 3.7.1-3
- add missing obsoletes (#1303497)

* Thu Feb 04 2016 Fedora Release Engineering <releng@fedoraproject.org> - 3.7.1-2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_24_Mass_Rebuild

* Thu Jan 07 2016 Jan Vcelak <jvcelak@fedoraproject.org> 3.7.1-1
- new upstream release
- enable gold linker

* Wed Nov 04 2015 Jan Vcelak <jvcelak@fedoraproject.org> 3.7.0-100
- fix Requires for subpackages on the main package

* Tue Oct 06 2015 Jan Vcelak <jvcelak@fedoraproject.org> 3.7.0-100
- initial version using cmake build system
