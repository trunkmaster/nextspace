#%undefine _missing_build_ids_terminate_build

# Defines
%define BASE_VERSION	1.27.0
%define GUI_VERSION	0.28.0
%define BACK_VERSION	0.28.0
%define GORM_VERSION	1.2.24
%define PC_VERSION	0.6.2

Name:           nextspace-gnustep
Version:        %{BASE_VERSION}_%{GUI_VERSION}
Release:        1%{?dist}
Summary:        GNUstep libraries.

Group:          Libraries/NextSpace
License:        GPLv3
URL:		http://www.gnustep.org
Source0:	gnustep-base-%{BASE_VERSION}.tar.gz
Source1:	gdomap.interfaces
Source2:	gdomap.service
Source3:	gdnc.service
Source4:	gdnc-local.service
Source5:	gnustep-gui-%{GUI_VERSION}.tar.gz
Source6:	gnustep-gui-images.tar.gz
Source7:	gnustep-back-%{BACK_VERSION}.tar.gz
Source8:	gpbs.service
Source9:	gorm-%{GORM_VERSION}.tar.gz
Source10:	ProjectCenter-%{PC_VERSION}.tar.gz
Source11:	projectcenter-images.tar.gz

# Build GNUstep libraries in one RPM package
# GUI
Patch0:		libs-gui_rpmbuild.patch
# Back
Patch1:		libs-back_IconImage.patch
Patch2:		libs-back_TakeFocus.patch
Patch3:		libs-back_rpmbuild.patch

Provides:	gnustep-base-%{BASE_VERSION}
Provides:	gnustep-gui-%{GUI_VERSION}
Provides:	gnustep-back-%{BACK_VERSION}
Provides:	gorm-%{GORM_VERSION}
Provides:	projectcenter-%{PC_VERSION}

Conflicts:	gnustep-base
Conflicts:	gnustep-filesystem
Conflicts:	gnustep-gui
Conflicts:	gnustep-back

BuildRequires:	clang >= 3.8.0

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
Provides:	gorm
Provides:	projectcenter

%description devel
OpenStep Application Kit, Foundation Kit and GNUstep extensions header files.
GNUstep Make installed with nextspace-core-devel package.

%prep
%setup -c -n nextspace-gnustep -a 5 -a 7 -a 9 -a 10
%patch0 -p0
%patch1 -p0
%patch2 -p0
%patch3 -p0
rm -rf %{buildroot}

#
# Build phase
#
%build
export CC=clang
export CXX=clang++
export LD_LIBRARY_PATH="%{buildroot}/Library/Libraries:/usr/NextSpace/lib"

# Foundation (relies on gnustep-make included in nextspace-core-devel)
source /Developer/Makefiles/GNUstep.sh
#export LDFLAGS="-L/usr/NextSpace/lib -lobjc -ldispatch"
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
unset GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES

# Build ART GUI backend
cd gnustep-back-%{BACK_VERSION}
export LDFLAGS+=" -lgnustep-gui"
./configure \
    --enable-server=x11 \
    --enable-graphics=art \
    --with-name=art
make
cd ..

# Build GORM
export ADDITIONAL_OBJCFLAGS="-I%{buildroot}/Developer/Headers"
export ADDITIONAL_LDFLAGS+="-L%{buildroot}/Library/Libraries -lgnustep-base -lgnustep-gui"
cd gorm-%{GORM_VERSION}
make
cd ..

# Build ProjectCenter
cd ProjectCenter-%{PC_VERSION}
make

#
# Build install phase
#
%install
export GNUSTEP_MAKEFILES=/Developer/Makefiles
export PATH+=":%{buildroot}/Library/bin:%{buildroot}/usr/NextSpace/bin"
export QA_SKIP_BUILD_ROOT=1

cd gnustep-base-%{BASE_VERSION}
%{make_install}
cd ..

cd gnustep-gui-%{GUI_VERSION}
%{make_install}
cd ..

cd gnustep-back-%{BACK_VERSION}
%{make_install} fonts=no
cd ..

# Install GORM
export GNUSTEP_INSTALLATION_DOMAIN=NETWORK
cd gorm-%{GORM_VERSION}
%{make_install}
cd ..
# Install ProjectCenter
cd ProjectCenter-%{PC_VERSION}
tar zxf %{_sourcedir}/projectcenter-images.tar.gz
%{make_install}
cd ..

# Replace cursor images
cd %{buildroot}/Library/Images
tar zxf %{_sourcedir}/gnustep-gui-images.tar.gz
#cp %{_sourcedir}/common_contextualMenuCursor.tiff %{buildroot}/Library/Images
#cp %{_sourcedir}/common_copyCursor.tiff %{buildroot}/Library/Images
#cp %{_sourcedir}/common_disappearingItemCursor.tiff %{buildroot}/Library/Images
#cp %{_sourcedir}/common_greenArrowCursor.tiff %{buildroot}/Library/Images
#cp %{_sourcedir}/common_linkCursor.tiff %{buildroot}/Library/Images
#cp %{_sourcedir}/common_noCursor.tiff %{buildroot}/Library/Images
# Replace button images
#cp %{_sourcedir}/common_RadioOff.tiff %{buildroot}/Library/Images
#cp %{_sourcedir}/common_RadioOn.tiff %{buildroot}/Library/Images
#cp %{_sourcedir}/common_SwitchOff.tiff %{buildroot}/Library/Images
#cp %{_sourcedir}/common_SwitchOn.tiff %{buildroot}/Library/Images


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
# for %pre and %post $1 = 1 - installation, 2 - upgrade
#%pre
%post
if [ $1 -eq 1 ]; then
    # post-installation
    systemctl enable /usr/NextSpace/lib/systemd/gdomap.service;
    systemctl enable /usr/NextSpace/lib/systemd/gdnc.service;
    systemctl enable /usr/NextSpace/lib/systemd/gdnc-local.service;
    systemctl enable /usr/NextSpace/lib/systemd/gpbs.service;
    systemctl start gdomap gdnc gpbs;
elif [ $1 -eq 2 ]; then
    # post-upgrade
    #echo "Please restart GNUstep services manually with command:"
    #echo "# systemctl restart gdomap gdnc gpbs"
    systemctl daemon-reload;
    # systemctl restart gdomap gdnc gpbs;
fi

# for %preun and %postun $1 = 0 - uninstallation, 1 - upgrade. 
%preun
if [ $1 -eq 0 ]; then
    # prepare for uninstall
    systemctl stop gdomap gdnc gpbs;
    systemctl disable gdomap.service;
    systemctl disable gdnc.service;
    systemctl disable gdnc-local.service;
    systemctl disable gpbs.service;
elif  [ $1 -eq 1 ]; then
    # prepare for upgrade
    echo "This is an upgrade. Do nothing with GNUstep services.";
fi

#%postun

%changelog
* Mon Dec 16 2019 Sergii Stoian <stoyan255@gmail.com> - 1.27.0_0.28.0-1
- Switched to master branch of GNUstep soure code.
- Reduced number of custom patches.
- Notification center service for local notifications was added.

* Thu May 23 2019 Sergii Stoian <stoyan255@gmail.com> - 1.26.0_0.25.0-2
- Rebuild with libdispatch private headers enabled and gnustep-base last
  commit `ecbecbe`.

* Fri May 10 2019 Sergii Stoian <stoyan255@gmail.com> - 1.26.0_0.25.0-1
- Original ProjectBuilder's images were added to ProjectCenter.
- Replace some GNUstep images from tarball.

* Fri May  3 2019 Sergii Stoian <stoyan255@gmail.com> - 1.26.0_0.25.0-0
- New versions of Base, GUI, Back, GORM.
- ProjectCenter was added.
- New mouse cursor images.

* Mon Jun 12 2017 Sergii Stoian <stoyan255@gmail.com> 1.24.8_0.24.1-10
- Comments are added to patches.
- Pathes with implemented apps autolaunching are added.

* Tue Nov 1 2016 Sergii Stoian <stoyan255@gmail.com> 1.24.8_0.24.1-7
- gorm-1.2.23 was added.

* Mon Oct 31 2016 Sergii Stoian <stoyan255@gmail.com> 1.24.8_0.24.1-6
- Patch for NSWindow was updated: use common_MiniWindowTile.tiff for
  miniwindows.

* Fri Oct 28 2016 Sergii Stoian <stoyan255@gmail.com> 1.24.8_0.24.1-5
- Switch to minimum clang version 3.8.0 (libdispatch and libobjc2 built
  with this version);
- Add patch for Headers/GNUstepBase/GSConfig.h.in to silence clang-3.8
  warning about __weak and __strong redefinition (backport from 
  gnustep-base-1.24.9);
- Add patch for miniwindow font (change size from 8 to 9) default value.
- Backported from gnustep-base-1.24.9 changes to Languages/Korean.

* Thu Oct 20 2016 Sergii Stoian <stoyan255@gmail.com> 1.24.8_0.24.1-0
- Initial spec for CentOS 7.

