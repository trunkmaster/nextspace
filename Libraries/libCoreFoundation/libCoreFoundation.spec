%define GIT_TAG main

%if 0%{?el7}
%global debug_package %{nil}
%endif

Name:		libCoreFoundation
Version:	5.3.1
Release:	0%{?dist}
Summary:	Apple CoreFoundation framework.
License:	Apache 2.0
URL:		http://swift.org
Source0:	https://github.com/apple/swift-corelibs-foundation/archive/%{GIT_TAG}.tar.gz
Source1:	CFNotificationCenter.c
Patch0:		BuildSharedOnLinux.patch
%if 0%{?el7}
Patch1:		BuildOnCentOS7.patch
%endif

%if 0%{?el7}
BuildRequires:	cmake3
BuildRequires:	llvm-toolset-7.0-clang >= 7.0.1
%else
BuildRequires:	cmake
BuildRequires:	clang >= 7.0.1
%endif
BuildRequires:	libdispatch-devel
BuildRequires:	libxml2-devel
BuildRequires:	libicu-devel
BuildRequires:	libcurl-devel
BuildRequires:	libuuid-devel

Requires:	libdispatch
Requires:	libxml2
Requires:	libicu
Requires:	libcurl
Requires:	libuuid

%description
Apple Core Foundation framework.

%package devel
Summary: Development header files for CoreFoundation framework.
Requires: %{name}%{?_isa} = %{version}-%{release}

%description devel
Development header files for CoreFoundation framework.

%prep
%setup -n swift-corelibs-foundation-%{GIT_TAG}
%patch0 -p1
%if 0%{?el7}
cd CoreFoundation
%patch1 -p1
cd ..
%endif
cp %{_sourcedir}/CFNotificationCenter.c CoreFoundation/AppServices.subproj/
cd CoreFoundation/Base.subproj/
cp SwiftRuntime/TargetConditionals.h ./

%build
mkdir -p CoreFoundation/.build
cd CoreFoundation/.build
#CF_CFLAGS="-I/usr/NextSpace/include -I. -I`pwd`/../Base.subproj -DU_SHOW_DRAFT_API -DCF_BUILDING_CF -DDEPLOYMENT_RUNTIME_C -fconstant-cfstrings -fexceptions -Wno-switch -D_GNU_SOURCE -DCF_CHARACTERSET_DATA_DIR=\"CharacterSets\""
CF_CFLAGS="-I/usr/NextSpace/include -Wno-implicit-const-int-float-conversion -Wno-switch"
%if 0%{?el7}
cmake3 .. \
%else
cmake .. \
%endif
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_C_FLAGS="$CF_CFLAGS" \
      -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/NextSpace/lib -luuid" \
      -DCF_DEPLOYMENT_SWIFT=NO \
      -DBUILD_SHARED_LIBS=YES \
      -DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
      -DCMAKE_INSTALL_LIBDIR=/usr/NextSpace/lib \
      -DCMAKE_LIBRARY_PATH=/usr/NextSpace/lib \
%if 0%{?el7}
      -DCMAKE_BUILD_TYPE=Release
%else
      -DCMAKE_BUILD_TYPE=Debug
%endif

make %{?_smp_mflags}

%install
cd CoreFoundation/.build
# Make GNUstep framework
# Frameworks
mkdir -p %{buildroot}/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/%{version}
cp -R CoreFoundation.framework/Headers %{buildroot}/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/%{version}
cp -R CoreFoundation.framework/libCoreFoundation.so %{buildroot}/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/%{version}/libCoreFoundation.so.%{version}
cd %{buildroot}/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions
ln -s %{version} Current
cd ..
ln -s Versions/Current/Headers Headers
ln -s Versions/Current/libCoreFoundation.so.%{version} libCoreFoundation.so
# lib
 mkdir -p %{buildroot}/usr/NextSpace/lib
cd %{buildroot}/usr/NextSpace/lib
ln -s ../Frameworks/CoreFoundation.framework/libCoreFoundation.so libCoreFoundation.so
# include
mkdir -p %{buildroot}/usr/NextSpace/include
cd %{buildroot}/usr/NextSpace/include
ln -s ../Frameworks/CoreFoundation.framework/Headers CoreFoundation

%check

%files
/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/%{version}/libCoreFoundation.so.%{version}
/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/Current
/usr/NextSpace/Frameworks/CoreFoundation.framework/libCoreFoundation.so
/usr/NextSpace/lib/libCoreFoundation.so

%files devel
/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/%{version}/Headers
/usr/NextSpace/Frameworks/CoreFoundation.framework/Headers
/usr/NextSpace/include/CoreFoundation

#
# Package install
#
# for %pre and %post $1 = 1 - installation, 2 - upgrade
#%pre
#%post
#if [ $1 -eq 1 ]; then
#    ln -s /usr/NextSpace/Frameworks/CoreFoundation.framework/libCoreFoundation.so /usr/NextSpace/lib/libCoreFoundation.so
#fi
#%post devel
#if [ $1 -eq 1 ]; then
#    ln -s /usr/NextSpace/Frameworks/CoreFoundation.framework/Headers /usr/NextSpace/include/CoreFoundation
#fi

# for %preun and %postun $1 = 0 - uninstallation, 1 - upgrade.
#%preun
#if [ $1 -eq 0 ]; then
#    rm /usr/NextSpace/lib/libCoreFoundation.so
#fi
#%preun devel
#if [ $1 -eq 0 ]; then
#    rm /usr/NextSpace/include/CoreFoundation
#fi

#%postun

%changelog
* Sat Nov 21 2020 Sergii Stoian <stoyan255@gmail.com>
- Fixed building on CentOS 7.

* Tue Nov 17 2020 Sergii Stoian <stoyan255@gmail.com>
- Include implementation of CFNotificationCenter.
- Make installation of library as GNUstep framework.

* Wed Nov 11 2020 Sergii Stoian <stoyan255@gmail.com>
- Initial spec.
