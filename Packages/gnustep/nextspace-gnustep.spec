# Defines
%define	MAKE_VERSION	2.6.7
%define BASE_VERSION	1.24.9
%define GUI_VERSION	0.24.1
%define BACK_VERSION	0.24.1

Name:           nextspace-gnustep
Version:        %{BASE_VERSION}_%{GUI_VERSION}
Release:        0%{?dist}
Summary:        GNUstep libraries.

Group:          Libraries/NextSpace
License:        GPLv3
URL:		http://www.gnustep.org
#Source0:	gnustep-make-%{MAKE_VERSION}.tar.gz
Source0:	gnustep-base-%{BASE_VERSION}.tar.gz
Source1:	gnustep-gui-%{GUI_VERSION}.tar.gz
Source2:	gnustep-back-%{BACK_VERSION}.tar.gz
Source3:	gdomap.interfaces
Source4:	gdomap.service
Source5:	gdnc.service
Source6:	gpbs.service

Patch0:		gnustep-gui-Model_GNUmakefile.patch
Patch1:         gnustep-back-art_ReadRect.m.patch
Patch2:		gnustep-back-art_GNUmakefile.preamble.patch
Patch3:		gnustep-back-x11_XGServerWindow.m.patch
Patch4:		gnustep-back-gsc_GNUmakefile.preamble.patch

Provides:	gnustep-base-%{BASE_VERSION}
Provides:	gnustep-gui-%{GUI_VERSION}
Provides:	gnustep-back-%{BACK_VERSION}

BuildRequires:	gnustep-make

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
BuildRequires:	libao-devel
BuildRequires:	libsndfile-devel
#
Requires:	giflib >= 4.1.6
Requires:	libjpeg-turbo >= 1.2.90
Requires:	libpng >= 1.5.13
Requires:	libtiff >= 4.0.3
Requires:	libao
Requires:	libsndfile

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
Requires:	libXext >= 1.3.3
Requires:	libXfixes >= 5.0.1
Requires:	libXmu >= 1.1.2
Requires:	libXt >= 1.1.4

%description
GNUstep libraries - implementation of OpenStep (AppKit, Foundation).

%package devel
Summary:	OpenStep Application Kit, Foundation Kit and GNUstep extensions header files.
Requires:	%{name}%{?_isa} = %{version}-%{release}
Provides:	gnustep-base-devel
Provides:	gnustep-gui-devel
Provides:	gnustep-back-devel

%description devel
OpenStep Application Kit, Foundation Kit and GNUstep extensions header files.
GNUstep Make installed with nextspace-core-devel package.

%prep
%setup -c -n nextspace-gnustep -a 1 -a 2
%patch0 -p0
%patch1 -p0
%patch2 -p0
%patch3 -p0
%patch4 -p0
rm -rf %{buildroot}

#
# Build phase
#
%build
export CC=clang
export CXX=clang++
export LD_LIBRARY_PATH="%{buildroot}/Library/Libraries:/usr/NextSpace/lib"

# Build gnustep-make to include in -devel package
#cd gnustep-make-%{MAKE_VERSION}
#./configure \
#    --with-config-file=/Library/Preferences/GNUstep.conf \
#    --enable-importing-config-file \
#    --enable-native-objc-exceptions \
#    --with-thread-lib=-lpthread \
#    --enable-objc-nonfragile-abi \
#    --enable-debug-by-default
#make
#%{make_install}
#cd ..

# Foundation (relies on gnustep-make included in nextspace-core-devel)
source /Developer/Makefiles/GNUstep.sh
export LDFLAGS="-L/usr/NextSpace/lib -lobjc -ldispatch"
cd gnustep-base-%{BASE_VERSION}
./configure --disable-mixedabi
make
%{make_install}
cd ..

export ADDITIONAL_INCLUDE_DIRS="-I%{buildroot}/Developer/Headers"
export PATH+=":%{buildroot}/Library/bin:%{buildroot}/usr/NextSpace/bin"

# Application Kit
cd gnustep-gui-%{GUI_VERSION}
export LDFLAGS+=" -L%{buildroot}/Library/Libraries -lgnustep-base"
./configure
make
%{make_install}
cd ..

# Build ART GUI backend
cd gnustep-back-%{BACK_VERSION}
export LDFLAGS+=" -lgnustep-gui"
./configure \
    --enable-server=x11 \
    --enable-graphics=art \
    --with-name=art
make

#
# Build install phase
#
%install
export GNUSTEP_MAKEFILES=/Developer/Makefiles
export PATH+=":%{buildroot}/Library/bin:%{buildroot}/usr/NextSpace/bin"
export QA_SKIP_BUILD_ROOT=1

#cd gnustep-make-%{MAKE_VERSION}
#%{make_install}
#cd ..

cd gnustep-base-%{BASE_VERSION}
%{make_install}
cd ..

cd gnustep-gui-%{GUI_VERSION}
%{make_install}
cd ..

cd gnustep-back-%{BACK_VERSION}
%{make_install} fonts=no
cd ..

# systemd service files and config of gdomap
mkdir -p %{buildroot}/usr/NextSpace/etc
cp %{_sourcedir}/gdomap.interfaces %{buildroot}/usr/NextSpace/etc/
mkdir -p %{buildroot}/usr/NextSpace/lib/systemd
cp %{_sourcedir}/*.service %{buildroot}/usr/NextSpace/lib/systemd


#
# Files
#
%files
/Library/
/usr/NextSpace/

%files devel
/Developer/

#
# Package install
#
#%pre

%post
systemctl enable /usr/NextSpace/lib/systemd/gdomap.service
systemctl enable /usr/NextSpace/lib/systemd/gdnc.service
systemctl enable /usr/NextSpace/lib/systemd/gpbs.service

%preun
systemctl disable /usr/NextSpace/lib/systemd/gdomap.service
systemctl disable /usr/NextSpace/lib/systemd/gdnc.service
systemctl disable /usr/NextSpace/lib/systemd/gpbs.service

#%postun
systemctl disable /usr/NextSpace/lib/systemd/gdomap.service
systemctl disable /usr/NextSpace/lib/systemd/gdnc.service
systemctl disable /usr/NextSpace/lib/systemd/gpbs.service

%changelog
* Thu Oct 20 2016 Sergii Stoian <stoyan255@ukr.net> 1.24.9_0.24.1-0
- Initial spec for CentOS 7.

