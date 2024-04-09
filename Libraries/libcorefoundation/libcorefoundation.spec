Name:     libcorefoundation
Version:  5.9.2
Epoch:		0
Release:	0%{?dist}
Summary:	Apple CoreFoundation framework.
License:	Apache 2.0
URL:      https://github.com/trunkmaster/apple-corefoundation
Source0:  libcorefoundation-%{version}.tar.gz

BuildRequires:	cmake
BuildRequires:	clang >= 7.0.1
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
Requires: %{name}%{?_isa} = %{epoch}:%{version}-%{release}

%description devel
Development header files for CoreFoundation framework.

%prep
%setup -n apple-corefoundation-%{version}

%build
mkdir -p .build
cd .build
CF_CFLAGS="-I/usr/NextSpace/include -Wno-switch"
cmake .. \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_C_FLAGS="$CF_CFLAGS" \
      -DCMAKE_C_FLAGS_DEBUG="$CF_CFLAGS -g" \
      -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/NextSpace/lib -luuid" \
      -DCF_DEPLOYMENT_SWIFT=NO \
      -DBUILD_SHARED_LIBS=YES \
      -DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
      -DCMAKE_INSTALL_LIBDIR=/usr/NextSpace/lib \
      -DCMAKE_LIBRARY_PATH=/usr/NextSpace/lib \
      -DCMAKE_BUILD_TYPE=Debug

make %{?_smp_mflags}

%install
cd .build
# Make GNUstep framework
# Frameworks
mkdir -p %{buildroot}/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/%{version}
cp -R CoreFoundation.framework/Headers %{buildroot}/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/%{version}
cp -R CoreFoundation.framework/libCoreFoundation.so.* %{buildroot}/usr/NextSpace/Frameworks/CoreFoundation.framework
cd %{buildroot}/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions
ln -s %{version} Current
cd ..
ln -s Versions/Current/Headers Headers
#ln -s Versions/Current/libCoreFoundation.so.%{version} libCoreFoundation.so
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
/usr/NextSpace/Frameworks/CoreFoundation.framework/libCoreFoundation.so.*
/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions
/usr/NextSpace/lib/libCoreFoundation.so

%files devel
/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/%{version}/Headers
/usr/NextSpace/Frameworks/CoreFoundation.framework/Headers
/usr/NextSpace/include/CoreFoundation

%postun
/bin/rm -rf /usr/NextSpace/Frameworks/CoreFoundation.framework

%changelog
* Tue Jan 18 2022 flatpak-session-helper
Renamed to libcorefoundation to not interfere with libfoundation
on Fedora.

* Tue Dec 1 2020 Sergii Stoian <stoyan255@gmail.com>
- CFFileDescriptor was added to the build.

* Sat Nov 21 2020 Sergii Stoian <stoyan255@gmail.com>
- Fixed building on CentOS 7.

* Tue Nov 17 2020 Sergii Stoian <stoyan255@gmail.com>
- Include implementation of CFNotificationCenter.
- Make installation of library as GNUstep framework.

* Wed Nov 11 2020 Sergii Stoian <stoyan255@gmail.com>
- Initial spec.
