# Defines
%define	MAKE_VERSION	2.6.7
%define BASE_VERSION	1.24.9
%define GUI_VERSION	0.24.1
%define BACK_VERSION	0.24.1

Name:           nextspace-runtime
Version:        %{BASE_VERSION}_%{GUI_VERSION}
Release:        0%{?dist}
Summary:        GNUstep libraries.

Group:          Libraries/NextSpace
License:        GPLv3
URL:		http://www.gnustep.org
Source0:	gnustep-make-%{MAKE_VERSION}.tar.gz
Source1:	gnustep-base-%{BASE_VERSION}.tar.gz
Source2:	gnustep-gui-%{GUI_VERSION}.tar.gz
Source3:	gnustep-back-%{BACK_VERSION}.tar.gz
Patch0:         gnustep-back-art_ReadRect.m.patch
Patch1:		gnustep-back-x11_XGServerWindow.m.patch
Patch2:		gnustep-gui-Model_GNUmakefile.patch
Patch3:		gnustep-back-art_GNUmakefile.preamble.patch
Patch4:		gnustep-back-gsc_GNUmakefile.preamble.patch
#Provides:	
#Provides:	

# gnustep-base
BuildRequires:	libffi-devel
BuildRequires:	libobjc2-devel
BuildRequires:	gnutls-devel
BuildRequires:	openssl-devel
BuildRequires:	libicu-devel
BuildRequires:	libxml2-devel
BuildRequires:	libxslt-devel
#
Requires:	libffi >= 3.0.13
Requires:	libobjc2 >= 1.8.2
Requires:	gnutls >= 3.3.8
Requires:	openssl-libs >= 1.0.1e
Requires:	libicu >= 50.1.2
Requires:	libxml2 >= 2.9.1
Requires:	libxslt >= 1.1.28

# gnustep-gui
BuildRequires:	giflib-devel
BuildRequires:	libjpeg-turbo-devel
BuildRequires:	libpng-devel
BuildRequires:	libtiff-devel
#
Requires:	giflib >= 4.1.6
Requires:	libjpeg-turbo >= 1.2.90
Requires:	libpng >= 1.5.13
Requires:	libtiff >= 4.0.3

## /Library/Bundles/GSPrinting/GSCUPS.bundle
BuildRequires:	cups-devel
BuildRequires:	nss-softokn-freebl-devel
BuildRequires:	xz-devel
#
Requires:	cups-libs >= 1.6.3
Requires:	nss-softokn-freebl >= 3.16.2
Requires:	xz-libs >= 1.5.2

# gnustep-back art
BuildRequires:	libart_lgpl-devel
BuildRequires:	freetype-devel
BuildRequires:	mesa-libGL-devel
BuildRequires:	libX11-devel
BuildRequires:	libXcursor-devel
BuildRequires:	libXext-devel
BuildRequires:	libXfixes-devel
BuildRequires:	libXmu-devel
BuildRequires:	libXt-devel
#
Requires:	libart_lgpl
Requires:	freetype
Requires:	mesa-libGL >= 10.6.5
Requires:	libX11 >= 1.6.3
Requires:	libXcursor >= 1.1.14
Requires:	libXex >= 1.3.3
Requires:	libXfixes >= 5.0.1
Requires:	libXmu >= 1.1.2
Requires:	libXt >= 1.1.4

%description
GNUstep libraries for NextSpace environment.

%package devel
Summary: GNUstep Make and header files for GNUstep libraries.
Requires: %{name}%{?_isa} = %{version}-%{release}

%description devel
GNUstep Make and header files for GNUstep libraries.

#%pre

%prep
%setup -c -n nextspace-runtime -a 1 -a 2 -a 3
%patch0 -p0
%patch1 -p0
%patch2 -p0
%patch3 -p0
%patch4 -p0


%build
export CC=clang
export CXX=clang++
export LD_LIBRARY_PATH="%{buildroot}/Library/Libraries:/usr/NextSpace/lib"

# Build gnustep-make to include in -devel package
cd gnustep-make-%{MAKE_VERSION}
./configure \
    --with-config-file=/Library/Preferences/GNUstep.conf \
    --enable-importing-config-file \
    --enable-native-objc-exceptions \
    --with-thread-lib=-lpthread \
    --enable-objc-nonfragile-abi \
    --enable-debug-by-default
make
%{make_install}
cd ..

# Build Foundation (relies on installed gnustep-make)
export LDFLAGS="-L/usr/NextSpace/lib -lobjc -ldispatch"
cd gnustep-base-%{BASE_VERSION}
./configure --disable-mixedabi
make
%{make_install}
cd ..

export ADDITIONAL_INCLUDE_DIRS="-I%{buildroot}/Developer/Headers"

# Build AppKit
cd gnustep-gui-%{GUI_VERSION}
export LDFLAGS+=" -L%{buildroot}/Library/Libraries -lgnustep-base"
./configure
make
%{make_install}
cd ..

# GUI backend
cd gnustep-back-%{BACK_VERSION}
export LDFLAGS+=" -lgnustep-gui"
export PATH+=":%{buildroot}/Library/bin"
./configure \
    --enable-server=x11 \
    --enable-graphics=art \
    --with-name=art
make
#%{make_install} fonts=no


%install
cd gnustep-make-%{MAKE_VERSION}
%{make_install}
cd ..

cd gnustep-base-%{BASE_VERSION}
%{make_install}
cd ..

cd gnustep-gui-%{GUI_VERSION}
%{make_install}
cd ..

cd gnustep-back-%{BACK_VERSION}
%{make_install}
rm -rf %{buildroot}/Library/Fonts
cd ..

#%post

#%preun

#%postun

%files 
/Library
/usr/NextSpace

%files devel
/Developer

#%changelog
#* Oct 7 2016 Sergii Stoian <stoyan255@ukr.net>
#- Initial spec for CentOS 7.

