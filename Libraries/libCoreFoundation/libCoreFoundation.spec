Name:		libCoreFoundation
Version:	5.3+
Release:	0%{?dist}
Summary:	Apple CoreFoundation framework.
License:	Apache 2.0
URL:		http://swift.org
Source0:	https://github.com/apple/swift-corelibs-foundation/archive/swift-DEVELOPMENT-SNAPSHOT-2020-11-09-a.tar.gz
Patch0:		BuildSharedOnLinux.patch

BuildRequires:	cmake
BuildRequires:	clang >= 7.0.1
BuildRequires:	libdispatch-devel
BuildRequires:	libxml2-devel
BuildRequires:	libicu-devel
BuildRequires:	libcurl-devel

Requires:	libdispatch
Requires:	libxml2
Requires:	libicu
Requires:	libcurl

%description
Apple Core Foundation framework.

%package devel
Summary: Development header files for CoreFoundation framework.
Requires: %{name}%{?_isa} = %{version}-%{release}

%description devel
Development header files for CoreFoundation framework.

%prep
%setup -n swift-corelibs-foundation-swift-DEVELOPMENT-SNAPSHOT-2020-11-09-a
%patch0 -p1
cd CoreFoundation/Base.subproj/
cp SwiftRuntime/TargetConditionals.h ./

%build
mkdir -p CoreFoundation/.build
cd CoreFoundation/.build
CF_CFLAGS="-I/usr/NextSpace/include -I. -I`pwd`/../Base.subproj -DU_SHOW_DRAFT_API -DCF_BUILDING_CF -DDEPLOYMENT_RUNTIME_C -fconstant-cfstrings -fexceptions -Wno-shorten-64-to-32 -Wno-deprecated-declarations -Wno-unreachable-code -Wno-conditional-uninitialized -Wno-unused-variable -Wno-int-conversion -Wno-unused-function -Wno-switch -D_GNU_SOURCE -DCF_CHARACTERSET_DATA_DIR=\"CharacterSets\""
cmake .. \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_C_FLAGS="$CF_CFLAGS" \
      -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/NextSpace/lib" \
      -DCF_DEPLOYMENT_SWIFT=NO \
      -DBUILD_SHARED_LIBS=YES \
      -DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
      -DCMAKE_INSTALL_LIBDIR=/usr/NextSpace/lib \
      -DCMAKE_LIBRARY_PATH=/usr/NextSpace/lib \
      -DCMAKE_BUILD_TYPE=Debug

make %{?_smp_mflags}

%install
cd CoreFoundation/.build
#make install DESTDIR=%{buildroot}
#rm -r %{buildroot}/usr/NextSpace/lib
mkdir -p %{buildroot}/usr/NextSpace/lib
cp -R CoreFoundation.framework/libCoreFoundation.so %{buildroot}/usr/NextSpace/lib
mkdir -p %{buildroot}/usr/NextSpace/include/CoreFoundation
cp CoreFoundation.framework/Headers/*.h %{buildroot}/usr/NextSpace/include/CoreFoundation

%check

%files
/usr/NextSpace/lib/libCoreFoundation.so

%files devel
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
* Wed Nov 11 2020 Sergii Stoian <stoyan255@gmail.com> SNAPSHOT
- Initial spec.
