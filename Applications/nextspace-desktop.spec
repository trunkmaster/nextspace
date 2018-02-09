%define PREFERENCES_VERSION	0.5
%define LOGIN_VERSION		0.8
%define WORKSPACE_VERSION	0.8


Name:           nextspace-desktop
Version:        0.8
Release:        0%{?dist}
Summary:        NextSpace desktop core applications (Login, Preferences, Workspace).

Group:          Libraries/NextSpace
License:        GPLv2
URL:		http://www.gitlab.com/stoyan/nextspace
Source0:	Preferences-%{PREFERENCES_VERSION}.tar.gz
Source1:	Login-%{LOGIN_VERSION}.tar.gz
Source2:	Workspace-%{WORKSPACE_VERSION}.tar.gz

#Provides:	Preferences
#Provides:	Login
#Provides:	Workspace

BuildRequires:	nextspace-frameworks-devel
# Preferences
#BuildRequires:	
# Login
BuildRequires:	pam-devel
# Workspace & WindowMaker
BuildRequires:	giflib-devel
BuildRequires:	libjpeg-turbo-devel
BuildRequires:	libpng-devel
BuildRequires:	libtiff-devel
BuildRequires:	libXinerama-devel
BuildRequires:	libXft-devel
BuildRequires:	libXpm-devel
BuildRequires:	libXmu-devel
BuildRequires:	libexif-devel
BuildRequires:	libXfixes-devel
BuildRequires:	fontconfig-devel
BuildRequires:	autoconf
BuildRequires:	automake
BuildRequires:	libtool
#
Requires:	nextspace-frameworks
Requires:	fontconfig
Requires:	libXft
Requires:	libXinerama
Requires:	libXpm
Requires:	libXmu
Requires:	libXfixes
Requires:	libexif
Requires:	xorg-x11-drv-evdev
Requires:	xorg-x11-drv-intel
Requires:	xorg-x11-drv-vesa
Requires:	xorg-x11-drv-synaptics
Requires:	xorg-x11-drv-keyboard
Requires:	xorg-x11-drv-mouse
Requires:	xorg-x11-server-Xorg
Requires:	xorg-x11-server-utils
Requires:	xorg-x11-xkb-utils
Requires:	xorg-x11-fonts-100dpi
Requires:	xorg-x11-fonts-misc
Requires:	mesa-dri-drivers


%description
NextSpace desktop core applications (Login, Preferences, Workspace).

%package devel
Summary:	NextSpace desktop core applications (Login, Preferences, Workspace)..
Requires:	%{name}%{?_isa} = %{version}-%{release}

%description devel
Header file for NextSpace core applications (Preferences, Workspace).

%prep
%setup -c nextspace-desktop -a 1 -a 2

#
# Build phase
#
%build
export GNUSTEP_MAKEFILES=/Developer/Makefiles
. /etc/profile.d/nextspace.sh

cd Preferences-%{PREFERENCES_VERSION}
make
cd ..

cd Login-%{LOGIN_VERSION}
export ADDITIONAL_INCLUDE_DIRS="-I../../Preferences-%{PREFERENCES_VERSION}"
make
unset ADDITIONAL_INCLUDE_DIRS
cd ..

cd Workspace-%{WORKSPACE_VERSION}
./WM.configure
make
cd ..

#
# Build install phase
#
%install
export GNUSTEP_MAKEFILES=/Developer/Makefiles
export QA_SKIP_BUILD_ROOT=1

cd Preferences-%{PREFERENCES_VERSION}
%{make_install}
cd ..

cd Login-%{LOGIN_VERSION}
%{make_install}
cd ..

cd Workspace-%{WORKSPACE_VERSION}
%{make_install}
cd ..

#
# Files
#
%files
/Applications
/Library
/usr/NextSpace

%files devel
/usr/NextSpace/include

#
# Package install
#
#%pre

%post
systemctl enable /usr/NextSpace/Apps/Login.app/Resources/loginwindow.service

%preun
systemctl disable loginwindow.service

#%postun

%changelog
* Fri Oct 21 2016 Sergii Stoian <stoyan255@ukr.net> 0.4-0
- Initial spec for CentOS 7.

