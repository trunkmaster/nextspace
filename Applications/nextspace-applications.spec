Name:           nextspace-applications
Version:        0.91
Release:        0%{?dist}
Summary:        NextSpace desktop core applications.

Group:          Libraries/NextSpace
License:        GPLv2
URL:		http://www.github.com/trunkmaster/nextspace
Source0:	nextspace-applications-%{version}.tar.gz

%if 0%{?el7}
BuildRequires:  cmake3
%define CMAKE cmake3
BuildRequires:  llvm-toolset-7.0-clang >= 7.0.1
%else
BuildRequires:  cmake
%define CMAKE cmake
BuildRequires:  clang >= 7.0.1
%endif
BuildRequires:	nextspace-frameworks-devel
# Preferences
# BuildRequires:
# Login
BuildRequires:	pam-devel
# Workspace
BuildRequires:	libcorefoundation-devel
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
#
Requires:	nextspace-frameworks
Requires:	libcorefoundation
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
Requires:	xorg-x11-server-Xorg
%if 0%{?el7}
Requires:	xorg-x11-drv-keyboard
Requires:	xorg-x11-drv-mouse
%endif
%if 0%{?rhel} || 0%{?fedora} < 34
Requires:	xorg-x11-xkb-utils
Requires:	xorg-x11-server-utils
%else
Requires:	xrdb
%endif
Requires:	xorg-x11-fonts-100dpi
Requires:	xorg-x11-fonts-misc
Requires:	mesa-dri-drivers

%description
NextSpace desktop core applications.

%package devel
Summary:	NextSpace desktop core applications headers (Preferences, Workspace).
Requires:	%{name}%{?_isa} = %{version}-%{release}
Requires:	setxkbmap
Requires:	xrandr
Requires:	xwininfo
Requires:	xprop

%description devel
Header file for NextSpace core applications (Preferences, Workspace).

%prep
%setup

#
# Build phase
#
%build
%if 0%{?el7}
source /opt/rh/llvm-toolset-7.0/enable
%endif
source /Developer/Makefiles/GNUstep.sh
export CC=clang
export CXX=clang++
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"%{buildroot}/Library/Libraries:/usr/NextSpace/lib"
export ADDITIONAL_INCLUDE_DIRS="-I%{buildroot}/Developer/Headers"
export ADDITIONAL_LIB_DIRS=" -L%{buildroot}/Library/Libraries"
export CMAKE=%{CMAKE}
make

#
# Build install phase
#
%install
export GNUSTEP_MAKEFILES=/Developer/Makefiles
export QA_SKIP_BUILD_ROOT=1
export CMAKE=%{CMAKE}
%{make_install}

#
# Files
#
%files
/Applications
/Library
/usr/NextSpace

%files devel
/usr/NextSpace/include/apps

#
# Package install
#
#%pre

%post
if [ $1 -eq 1 ]; then
    # post-installation
    systemctl enable /usr/NextSpace/Apps/Login.app/Resources/loginwindow.service
    systemctl set-default graphical.target
    ldconfig
elif [ $1 -eq 2 ]; then
    # post-upgrade
    systemctl daemon-reload;
    # systemctl restart loginwindow;
fi


%preun
if [ $1 -eq 0 ]; then
   systemctl disable loginwindow.service
   systemctl set-default multi-user.target
fi

#%postun

%changelog
* Fri Jan 15 2021  Sergii Stoian <stoyan255@gmail.com> - 0.91-0
- added libfoundation dependency.
- autotools dependecies were removed (in favour of cmake).
- use CMAKE variable to build Workspace.

* Sun Jun  9 2019  Sergii Stoian <stoyan255@gmail.com> - 0.85-3
- fixed %post script.

* Sun Jun  9 2019  Sergii Stoian <stoyan255@gmail.com> - 0.85-2
- fixed library names;
- run ldconfig in %post.

* Fri May 24 2019 Sergii Stoian <stoyan255@gmail.com>  - 0.85-1
- Fixed more .gorm files due to framewrks refactoring.
- set default `graphical.target` to systemd.

* Sat May  4 2019 Sergii Stoian <stoyan255@gmail.com> - 0.85-0
- Prepare for 0.85 release.

* Fri Oct 21 2016 Sergii Stoian <stoyan255@gmail.com> 0.4-0
- Initial spec for CentOS 7.

