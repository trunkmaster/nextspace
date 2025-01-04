%global toolchain clang

%define GS_REPO       https://github.com/gnustep
%if 0%{?fedora} && 0%{?fedora} > 40
%define BASE_VERSION  master
%define BASE_TAG      master
%else
%define BASE_VERSION  1.30.0
%define BASE_TAG      base-1_30_0
%endif
%define GUI_VERSION   0.31.0
%define GUI_TAG       gui-0_31_0
%define BACK_VERSION  nextspace
%define GORM_TAG      gorm-1_4_0
%define PC_TAG        projectcenter-0_7_0

Name:       nextspace-gnustep
Version:    %{BASE_VERSION}_%{GUI_VERSION}
Release:    1%{?dist}
Summary:    GNUstep libraries.

Group:      Libraries/NextSpace
License:    GPLv3
URL:        http://www.gnustep.org
Source0:    %{GS_REPO}/libs-base/archive/%{BASE_TAG}.tar.gz
Source1:    %{GS_REPO}/libs-gui/archive/%{GUI_TAG}.tar.gz
Source2:    back-art.tar.gz
Source3:    %{GS_REPO}/apps-gorm/archive/%{GORM_TAG}.tar.gz
Source4:    %{GS_REPO}/apps-projectcenter/archive/%{PC_TAG}.tar.gz
Source5:    gdomap.interfaces
Source6:    gdomap.service
Source7:    gdnc.service
Source8:    gdnc-local.service
Source9:    gpbs.service
Source10:   projectcenter-images.tar.gz
Source11:   gorm-images.tar.gz
Source12:   gnustep-gui-images.tar.gz
Source13:   gnustep-gui-panels.tar.gz

Patch0:     gorm.patch
Patch1:     pc.patch
Patch2:     libs-gui_NSApplication.patch
Patch3:     libs-gui_NSPopUpButton.patch
Patch4:     libs-gui_GSThemeDrawing.patch

# Build GNUstep libraries in one RPM package
Provides:   gnustep-base-%{BASE_TAG}
Provides:   gnustep-gui-%{GUI_TAG}
Provides:   gnustep-back-%{BACK_VERSION}
Provides:   gorm-%{GORM_TAG}
Provides:   projectcenter-%{PC_TAG}

Conflicts:  gnustep-base
Conflicts:  gnustep-filesystem
Conflicts:  gnustep-gui
Conflicts:  gnustep-back

BuildRequires:  clang >= 7.0.1

# gnustep-base
BuildRequires:  libffi-devel
BuildRequires:  libobjc2-devel
BuildRequires:  gnutls-devel
BuildRequires:  openssl-devel
BuildRequires:  libicu-devel
BuildRequires:  libxml2-devel
BuildRequires:  libxslt-devel
#
Requires:   libffi >= 3.0.13
Requires:   libobjc2 >= 1.8.2
Requires:   gnutls >= 3.3.8
Requires:   openssl-libs >= 1.0.1e
Requires:   libicu >= 50.1.2
Requires:   libxml2 >= 2.9.1
Requires:   libxslt >= 1.1.28

# gnustep-gui
BuildRequires:  giflib-devel
BuildRequires:  libjpeg-turbo-devel
BuildRequires:  libpng-devel
BuildRequires:  libtiff-devel
BuildRequires:  libao-devel
BuildRequires:  libsndfile-devel
#
Requires:   giflib >= 4.1.6
Requires:   libjpeg-turbo >= 1.2.90
Requires:   libpng >= 1.5.13
Requires:   libtiff >= 4.0.3
Requires:   libao
Requires:   libsndfile

## /Library/Bundles/GSPrinting/GSCUPS.bundle
BuildRequires:  cups-devel
BuildRequires:  nss-softokn-freebl-devel
BuildRequires:  xz-devel
#
Requires:   cups-libs >= 1.6.3
Requires:   nss-softokn-freebl >= 3.16.2
Requires:   xz-libs >= 1.5.2

# gnustep-back art
BuildRequires:  libart_lgpl-devel
BuildRequires:  freetype-devel
BuildRequires:  mesa-libGL-devel
BuildRequires:  libX11-devel
BuildRequires:  libXcursor-devel
BuildRequires:  libXext-devel
BuildRequires:  libXfixes-devel
BuildRequires:  libXmu-devel
BuildRequires:  libXt-devel
BuildRequires:  libXrandr-devel
#
Requires:   libart_lgpl
Requires:   freetype
Requires:   mesa-libGL >= 10.6.5
Requires:   libX11 >= 1.6.3
Requires:   libXcursor >= 1.1.14
Requires:   libXext >= 1.3.3
Requires:   libXfixes >= 5.0.1
Requires:   libXmu >= 1.1.2
Requires:   libXt >= 1.1.4
Requires:   libXrandr >= 1.5
# projectcenter
Requires:   gdb

%description
GNUstep libraries - implementation of OpenStep (AppKit, Foundation).

%package devel
Summary:    OpenStep Application Kit, Foundation Kit and GNUstep extensions header files.
Requires:   %{name}%{?_isa} = %{version}-%{release}
Provides:   gnustep-base-devel
Provides:   gnustep-gui-devel
Provides:   gnustep-back-devel
Provides:   gorm
Provides:   projectcenter

%description devel
OpenStep Application Kit, Foundation Kit and GNUstep extensions header files.
GNUstep Make installed with nextspace-core-devel package.

%prep
%setup -c -n nextspace-gnustep -a 0 -a 1 -a 2 -a 3 -a 4
cp %{_sourcedir}/gorm.patch %{_builddir}/nextspace-gnustep/apps-gorm-%{GORM_TAG}/
cd %{_builddir}/nextspace-gnustep/apps-gorm-%{GORM_TAG}/
%patch -P0 -p1
cp %{_sourcedir}/pc.patch %{_builddir}/nextspace-gnustep/apps-projectcenter-%{PC_TAG}/
cd %{_builddir}/nextspace-gnustep/apps-projectcenter-%{PC_TAG}/
%patch -P1 -p1
cp %{_sourcedir}/libs-gui_NSApplication.patch %{_builddir}/nextspace-gnustep/libs-gui-%{GUI_TAG}/
cp %{_sourcedir}/libs-gui_NSPopUpButton.patch %{_builddir}/nextspace-gnustep/libs-gui-%{GUI_TAG}/
cd %{_builddir}/nextspace-gnustep/libs-gui-%{GUI_TAG}/
%patch -P2 -p1
%patch -P3 -p1
%patch -P4 -p1

rm -rf %{buildroot}

#
# Build phase
#
%build
source /Developer/Makefiles/GNUstep.sh
export CC=clang
export CXX=clang++
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"%{buildroot}/Library/Libraries:/usr/NextSpace/lib"
unset CFLAGS

# Foundation (relies on gnustep-make included in nextspace-core-devel)
cd libs-base-%{BASE_TAG}
./configure
make
%{make_install}
cd ..

export ADDITIONAL_INCLUDE_DIRS="-I%{buildroot}/Developer/Headers"
export ADDITIONAL_LIB_DIRS=" -L%{buildroot}/Library/Libraries"
export PATH+=":%{buildroot}/Library/bin:%{buildroot}/usr/NextSpace/bin"

# Application Kit
cd libs-gui-%{GUI_TAG}
tar xzf %{_sourcedir}/gnustep-gui-panels.tar.gz
sudo cp %{buildroot}/Developer/Makefiles/Additional/base.make /Developer/Makefiles/Additional/
./configure
make
%{make_install}
sudo rm /Developer/Makefiles/Additional/base.make
cd ..

# Build ART GUI backend
cd back-art
export ADDITIONAL_TOOL_LIBS="-lgnustep-gui -lgnustep-base"
./configure \
    --enable-server=x11 \
    --enable-graphics=art \
    --with-name=art
make
unset ADDITIONAL_TOOL_LIBS
cd ..

# Build GORM
export ADDITIONAL_OBJCFLAGS="-I%{buildroot}/Developer/Headers"
export ADDITIONAL_LDFLAGS+="-L%{buildroot}/Library/Libraries -lgnustep-base -lgnustep-gui"
cd apps-gorm-%{GORM_TAG}
tar zxf %{_sourcedir}/gorm-images.tar.gz
make
cd ..

# Build ProjectCenter
cd apps-projectcenter-%{PC_TAG}
tar zxf %{_sourcedir}/projectcenter-images.tar.gz
make
cd ..

#
# Build install phase
#
%install
export GNUSTEP_MAKEFILES=/Developer/Makefiles
export PATH+=":%{buildroot}/Library/bin:%{buildroot}/usr/NextSpace/bin"
export QA_SKIP_BUILD_ROOT=1
# Install Base
cd libs-base-%{BASE_TAG}
%{make_install}
cd ..
# Install GUI
cd libs-gui-%{GUI_TAG}
%{make_install}
cd ..
# Install Back
cd back-art
%{make_install} fonts=no
cd ..
# Install GORM
export GNUSTEP_INSTALLATION_DOMAIN=NETWORK
cd apps-gorm-%{GORM_TAG}
%{make_install}
cd ..
# Install ProjectCenter
cd apps-projectcenter-%{PC_TAG}
%{make_install}
cd ..

# Replace cursor images
cd %{buildroot}/Library/Images
tar zxf %{_sourcedir}/gnustep-gui-images.tar.gz

# systemd service files and config of gdomap
mkdir -p %{buildroot}/usr/NextSpace/etc
cp %{_sourcedir}/gdomap.interfaces %{buildroot}/usr/NextSpace/etc/
mkdir -p %{buildroot}/usr/NextSpace/lib/systemd
cp %{_sourcedir}/*.service %{buildroot}/usr/NextSpace/lib/systemd
cd ..

#
# Files
#
%files
/Library
/usr/NextSpace

%files devel
/Developer

#
# Package install
#
# for %pre and %post $1 = 1 - installation, 2 - upgrade
#%pre
%post
ldconfig
if [ $1 -eq 1 ]; then
    # post-installation
    systemctl enable /usr/NextSpace/lib/systemd/gdomap.service;
    systemctl enable /usr/NextSpace/lib/systemd/gdnc.service;
    systemctl enable /usr/NextSpace/lib/systemd/gdnc-local.service;
    systemctl enable /usr/NextSpace/lib/systemd/gpbs.service;
    systemctl start gdomap gdnc gpbs;
elif [ $1 -eq 2 ]; then
    # post-upgrade
    systemctl daemon-reload;
    systemctl restart gdomap gdnc gpbs;
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

%postun
if [ -d /usr/NextSpace/Preferences ]; then
  rm -rf /usr/NextSpace/Preferences
fi

%changelog
* Tue Nov 5 2024 Andres Morales <armm77@icloud.com>
  Support for CentOS 7 is being dropped.

* Thu Apr 30 2020 Sergii Stoian <stoyan255@gmail.com> - 1_27_0_nextspace-1
- Switched to usage of RedHat Software Collection clang 7.0.
- Source file should be downloaded with `spectool -g` command into
  SOURCES directory manually.
- Removed patching of GNUstep GUI and Back sources - use `gnustep-*-nextspace`
  git branch.
- Removed obsolete `--disable-mixedabi` configure option of GNUstep Base.

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

