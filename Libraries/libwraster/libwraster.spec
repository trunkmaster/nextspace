%global toolchain clang
%define WRASTER_VERSION 7.0.1

Name:           libwraster
Version:        %{WRASTER_VERSION}
Release:        0%{?dist}
Summary:        Raster graphics library.
Group:          Libraries/NextSpace
License:        GPLv3
URL:            https://github.com/trunkmaster/nextspace
Source0:        libwraster-%{WRASTER_VERSION}.tar.gz

BuildRequires:	cmake
%define CMAKE cmake
BuildRequires:	clang >= 7.0.1
BuildRequires:	nextspace-core-devel >= 0.95
BuildRequires:	giflib-devel
BuildRequires:	libjpeg-turbo-devel
BuildRequires:	libpng-devel
BuildRequires:	libtiff-devel
BuildRequires:	libwebp-devel
BuildRequires:	libXpm-devel
BuildRequires:	libXmu-devel
BuildRequires:	libXext-devel
BuildRequires:	libX11-devel

Provides:	libwraster.so
Provides:	libwraster.so.7
Provides:	libwraster.so.%{WRASTER_VERSION}

Requires:	giflib >= 4.1.6
Requires:	libjpeg-turbo >= 1.2.90
Requires:	libpng >= 1.5.13
Requires:	libtiff >= 4.0.3
Requires:	libwebp >= 0.3.0
Requires:	libXpm >= 3.5.12
Requires:	libX11 >= 1.6.3
Requires:	libXext >= 1.3.3
Requires:	libXmu >= 1.1.2

%description
This library is used to manipulate images and convert them to a format that can 
be displayed through the X window system.

%package devel
Summary:	WindowMaker raster library header files.
Requires:	%{name}%{?_isa} = %{version}-%{release}
Requires:	giflib-devel
Requires:	libjpeg-turbo-devel
Requires:	libpng-devel
Requires:	libtiff-devel
Requires:	libwebp-devel
Requires:	libXpm-devel
Requires:	libXmu-devel
Requires:	libXext-devel
Requires:	libX11-devel

%description devel
WindowMaker raster library header files.

%prep
%setup -q
rm -rf %{buildroot}

#
# Build phase
#
%build
export CC=clang
export CMAKE=%{CMAKE}
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"%{buildroot}/Library/Libraries:/usr/NextSpace/lib"
export CFLAGS=""
source /Developer/Makefiles/GNUstep.sh
make

#
# Build install phase
#
%install
source /Developer/Makefiles/GNUstep.sh
export PATH+=":%{buildroot}/Library/bin:%{buildroot}/usr/NextSpace/bin"
export QA_SKIP_BUILD_ROOT=1
export CMAKE=%{CMAKE}

%{make_install}

#
# Files
#
%files
/usr/NextSpace/lib/libwraster.so
/usr/NextSpace/lib/libwraster.so.7
/usr/NextSpace/lib/libwraster.so.7.0.1

%files devel
/usr/NextSpace/include/wraster.h

%changelog
* Tue Nov 5 2024 Andres Morales <armm77@icloud.com>
  Support for CentOS 7 is being dropped.

* Sun Apr 2 2023 Andres Morales <armm77@icloud.com> 7.0.1
- Version update of libwraster 7.0.1

* Fri May 1 2020 Sergii Stoian <stoyan255@gmail.com> 5.0.0
- Initial spec for CentOS 7.
