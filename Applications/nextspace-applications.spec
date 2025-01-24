%global toolchain clang

Name:           nextspace-applications
Version:        0.95
Release:        0%{?dist}
Summary:        NextSpace desktop core applications.

Group:          Libraries/NextSpace
License:        GPLv2
URL:		http://www.github.com/trunkmaster/nextspace
Source0:	nextspace-applications-%{version}.tar.gz

BuildRequires:  cmake
%define CMAKE cmake
BuildRequires:  clang >= 7.0.1
BuildRequires:	nextspace-frameworks-devel
# Preferences
# BuildRequires:
# Login
BuildRequires:	pam-devel
# Workspace
BuildRequires:	libcorefoundation-devel
BuildRequires:  libbsd-devel
BuildRequires:	fontconfig-devel
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
BuildRequires:	libXcomposite-devel
BuildRequires:	libXrender-devel
BuildRequires:	libXdamage-devel
#
Requires:	nextspace-frameworks
Requires:	libcorefoundation
Requires:	fontconfig
Requires:	libXft
Requires:	libXinerama
Requires:	libXpm
Requires:	libXmu
Requires:	libXfixes
Requires:	libXcomposite
Requires:	libXrender
Requires:	libXdamage
Requires:	libexif
Requires:	xkbcomp
Requires:	xorg-x11-drivers
Requires:	xorg-x11-drv-evdev
Requires:	xorg-x11-drv-synaptics
Requires:	xorg-x11-server-Xorg
%if 0%{?el9}
Requires:	xorg-x11-server-utils
%endif
Requires:	xrdb
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
    systemctl enable /usr/NextSpace/lib/systemd/loginwindow.service
    systemctl set-default graphical.target
    ldconfig
elif [ $1 -eq 2 ]; then
    # post-upgrade
    systemctl daemon-reload;
    systemctl restart loginwindow;
fi


%preun
if [ $1 -eq 0 ]; then
    systemctl stop loginwindow.service
    systemctl disable loginwindow.service
    systemctl set-default multi-user.target
    chvt 02
fi

%postun
if [ -f /usr/NextSpace/Preferences/Login ]; then
    rm /usr/NextSpace/Preferences/Login
fi

%changelog
* Tue Nov 5 2024 Andres Morales <armm77@icloud.com>
  Support for CentOS 7 is being dropped.

* Wed Jun 12 2024  Sergii Stoian <stoyan255@gmail.com> - 0.95-0
- bump package version to 0.95 release.

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

