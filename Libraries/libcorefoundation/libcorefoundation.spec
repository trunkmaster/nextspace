%global toolchain clang
%define CFNET_VERSION 129.20

Name:       libcorefoundation
Version:    5.9.2
Epoch:      0
Release:    1%{?dist}
Summary:    Apple CoreFoundation framework.
License:    Apache 2.0
URL:        https://github.com/trunkmaster/apple-corefoundation
Source0:    libcorefoundation-%{version}-1.tar.gz

BuildRequires:  cmake
BuildRequires:  clang >= 7.0.1
BuildRequires:  libdispatch-devel
BuildRequires:  libxml2-devel
BuildRequires:  libicu-devel
BuildRequires:  libcurl-devel
BuildRequires:  libuuid-devel
BuildRequires:  avahi-compat-libdns_sd-devel

Requires:   libdispatch
Requires:   libxml2
Requires:   libicu
Requires:   libcurl
Requires:   libuuid

%description
Apple Core Foundation framework.

%package devel
Summary: Development header files for CoreFoundation framework.
Requires: %{name}%{?_isa} = %{epoch}:%{version}-%{release}

%description devel
Development header files for CoreFoundation framework.

%prep
%setup -n apple-corefoundation-%{version}-1
git clone --depth 1 https://github.com/trunkmaster/apple-cfnetwork CFNetwork

%build
unset CFLAGS
unset LDFLAGS
mkdir -p .build
cd .build
cmake .. \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_C_FLAGS="-I/usr/NextSpace/include -Wno-switch" \
      -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/NextSpace/lib -luuid" \
      -DCF_DEPLOYMENT_SWIFT=NO \
      -DBUILD_SHARED_LIBS=YES \
      -DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
      -DCMAKE_INSTALL_LIBDIR=/usr/NextSpace/lib \
      -DCMAKE_LIBRARY_PATH=/usr/NextSpace/lib \
      -DCMAKE_BUILD_TYPE=Debug

make %{?_smp_mflags}

cd ../CFNetwork
mkdir -p .build
cd .build
CFN_CFLAGS="-F../../${CF_PKG_NAME}/.build -I/usr/NextSpace/include"
CFN_LD_FLAGS="-L/usr/NextSpace/lib -L../../${CF_PKG_NAME}/.build/CoreFoundation.framework"
cmake .. \
      -DCMAKE_C_COMPILER=clang \
      -DCMAKE_CXX_COMPILER=clang++ \
      -DCFNETWORK_CFLAGS="${CFN_CFLAGS}" \
      -DCFNETWORK_LDLAGS="${CFN_LD_FLAGS}" \
      -DBUILD_SHARED_LIBS=YES \
      -DCMAKE_INSTALL_PREFIX=/usr/NextSpace \
      -DCMAKE_INSTALL_LIBDIR=/usr/NextSpace/lib \
      \
      -DCMAKE_SKIP_RPATH=ON \
      -DCMAKE_BUILD_TYPE=Debug
make

%install
cd .build
# Make GNUstep frameworks
mkdir -p %{buildroot}/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/%{version}
mkdir -p %{buildroot}/usr/NextSpace/lib
# framework
cd CoreFoundation.framework
cp -R Headers %{buildroot}/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/%{version}
cp -R libCoreFoundation.so* %{buildroot}/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/%{version}
#
cd %{buildroot}/usr/NextSpace/Frameworks/CoreFoundation.framework
ln -s Versions/Current/Headers Headers
cd Versions
ln -s %{version} Current
cd ..
# lib
ln -s Versions/Current/libCoreFoundation.so.%{version} libCoreFoundation.so
ln -s Versions/Current/libCoreFoundation.so.%{version} CoreFoundation
cd %{buildroot}/usr/NextSpace/lib
ln -s ../Frameworks/CoreFoundation.framework/Versions/%{version}/libCoreFoundation.so* ./
# include
#mkdir -p %{buildroot}/usr/NextSpace/include
#cd %{buildroot}/usr/NextSpace/include
#ln -s ../Frameworks/CoreFoundation.framework/Headers CoreFoundation

# CFNetwork
CFNET_VERSION=129.20
cd %{_builddir}/apple-corefoundation-%{version}-1/CFNetwork/.build/CFNetwork.framework
mkdir -p %{buildroot}/usr/NextSpace/Frameworks/CFNetwork.framework/Versions/${CFNET_VERSION}
cp -R Headers %{buildroot}/usr/NextSpace/Frameworks/CFNetwork.framework/Versions/${CFNET_VERSION}
cp -R libCFNetwork.so* %{buildroot}/usr/NextSpace/Frameworks/CFNetwork.framework/Versions/${CFNET_VERSION}

cd %{buildroot}/usr/NextSpace/Frameworks/CFNetwork.framework 
ln -s Versions/Current/Headers Headers
cd Versions
ln -s ${CFNET_VERSION} Current
cd ..
# lib
ln -s Versions/Current/libCFNetwork.so.${CFNET_VERSION} libCFNetwork.so
ln -s Versions/Current/libCFNetwork.so.${CFNET_VERSION} CFNetwork
cd %{buildroot}/usr/NextSpace/lib
ln -s ../Frameworks/CFNetwork.framework/Versions/${CFNET_VERSION}/libCFNetwork.so* ./

%check

%files
/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/%{version}/libCoreFoundation.so*
/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/Current
/usr/NextSpace/Frameworks/CoreFoundation.framework/CoreFoundation
/usr/NextSpace/Frameworks/CoreFoundation.framework/libCoreFoundation.so*
/usr/NextSpace/Frameworks/CFNetwork.framework/Versions/%{CFNET_VERSION}/libCFNetwork.so*
/usr/NextSpace/Frameworks/CFNetwork.framework/Versions/Current
/usr/NextSpace/Frameworks/CFNetwork.framework/CFNetwork
/usr/NextSpace/Frameworks/CFNetwork.framework/libCFNetwork.so
/usr/NextSpace/lib/libCoreFoundation.so*
/usr/NextSpace/lib/libCFNetwork.so*

%files devel
/usr/NextSpace/Frameworks/CoreFoundation.framework/Versions/%{version}/Headers
/usr/NextSpace/Frameworks/CoreFoundation.framework/Headers
#/usr/NextSpace/include/CoreFoundation
/usr/NextSpace/Frameworks/CFNetwork.framework/Versions/%{CFNET_VERSION}/Headers
/usr/NextSpace/Frameworks/CFNetwork.framework/Headers

%postun
/bin/rm -rf /usr/NextSpace/Frameworks/CoreFoundation.framework
/bin/rm -rf /usr/NextSpace/Frameworks/CFNetwork.framework

%changelog
* Tue Nov 5 2024 Andres Morales <armm77@icloud.com>
  Support for CentOS 7 is being dropped.

* Tue Apr 9 2024 Sergii Stoian <stoyan255@gmail.com>
- Leave only Fedora 39+ code here.

* Tue Jan 18 2022 Sergii Stoian <stoyan255@gmail.com>
- Renamed to libcorefoundation to not interfere with libfoundation
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
