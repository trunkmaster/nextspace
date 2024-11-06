%global toolchain clang

Name:           nextspace-frameworks
Version:        0.95
Release:        0%{?dist}
Summary:        NextSpace core libraries.
Group:          Libraries/NextSpace
License:        GPLv2
URL:		http://www.github.com/trunkmaster/nextspace
Source0:	nextspace-frameworks-%{version}.tar.gz

Provides:	DesktopKit.so
Provides:	SystemKit.so
Provides:	SoundKit.so

BuildRequires:	clang >= 7.0.1
BuildRequires:	nextspace-gnustep-devel
# SystemKit
BuildRequires:	file-devel
BuildRequires:	libudisks2-devel
BuildRequires:	dbus-devel
BuildRequires:	upower-devel
BuildRequires:	libXrandr-devel
BuildRequires:	libxkbfile-devel
BuildRequires:	libXcursor-devel
# SoundKit
BuildRequires:	pulseaudio-libs-devel >= 10.0

Requires:	nextspace-gnustep
# SystemKit
Requires:	file-libs >= 5.11
Requires:	udisks2
Requires:	libudisks2 >= 2.1.2
Requires:	dbus-libs >= 1.6.12
Requires:	upower >= 0.99.2
Requires:	glib2 >= 2.42.2
Requires:	libXrandr >= 1.4.2
Requires:	libxkbfile >= 1.0.9
Requires:	libXcursor >= 1.1.14
# SoundKit
Requires:	pulseaudio-libs >= 10.0
#Requires:	pulseaudio >= 10.0


%description
NextSpace libraries.

%package devel
Summary:	NextSpace core libraries (SystemKit, DesktopKit, SoundKit).
Requires:	%{name}%{?_isa} = %{version}-%{release}

%description devel
Header files for NextSpace core libraries (SystemKit, DesktopKit, SoundKit).

%prep
%setup

#
# Build phase
#
%build
export CC=clang
export CXX=clang++
export GNUSTEP_MAKEFILES=/Developer/Makefiles
export PATH+=":/usr/NextSpace/bin"
export ADDITIONAL_INCLUDE_DIRS="-I../SystemKit/derived_src"

cd SystemKit
make
cd ..

cd DesktopKit
make
cd ..

cd SoundKit
make
cd ..

#
# Build install phase
#
%install
export GNUSTEP_MAKEFILES=/Developer/Makefiles
export QA_SKIP_BUILD_ROOT=1

cd SystemKit
%{make_install}
cd ..

cd DesktopKit
%{make_install}
cd ..

cd SoundKit
%{make_install}
cd ..

#
# Files
#
%files
/Library/Fonts
/usr/NextSpace/Frameworks
/usr/NextSpace/lib
/usr/NextSpace/Fonts
/usr/NextSpace/Images
/usr/NextSpace/Sounds

%files devel
/usr/NextSpace/include/SystemKit
/usr/NextSpace/include/DesktopKit
/usr/NextSpace/include/SoundKit

#
# Package install
#
#%pre

%post
if [ ! -f /etc/fonts/conf.d/25-nextspace-fonts.conf ];then
  /bin/ln -s /usr/NextSpace/Frameworks/DesktopKit.framework/Resources/25-nextspace-fonts.conf /etc/fonts/conf.d/25-nextspace-fonts.conf
fi
/sbin/ldconfig

#
# Package removal
#
#%preun

%postun
/bin/rm -rf /usr/NextSpace/Frameworks/DesktopKit.framework
/bin/rm /etc/fonts/conf.d/25-nextspace-fonts.conf
/sbin/ldconfig

%changelog
* Tue Nov 5 2024 Andres Morales <armm77@icloud.com>
  Support for CentOS 7 is being dropped.

* Wed Jun 12 2024  Sergii Stoian <stoyan255@gmail.com> - 0.95-0
- bump package version to 0.95 release.

* Fri May 22 2020 Sergii Stoian <stoyan255@gmail.com> - 0.90-2
- new dependency "google-roboto-mono-fonts" - RobotoMono.nfont
  use files from this package.

* Sun May 17 2020 Sergii Stoian <stoyan255@gmail.com> - 0.90-1
- remove lines with sybmbolic links creation and removal - it is
  managed by DisktopKit makefiles.
- run `ldconfig` in %postun.

* Sun May 3 2020 Sergii Stoian <stoyan255@gmail.com> - 0.90-0
- Use clang from RedHat SCL repo on CentOS 7.
- SPEC file adopted for non-CentOS 7 distributions.
- Set /Library/Fonts as symbolic link to NextSpace fonts.

* Sun Jun  9 2019  <me@localhost.localdomain> - 0.85-2
- run `ldconfig` in %post.

* Fri May 24 2019 Sergii Stoian <stoyan255@gmail.com> - 0.85-1
- Fixed SystemBeep.snd link creation in DesktopKit makefile.
- PulseAudio was added as "Requires".
- Changed library names in "Provides" fields according to frameworks refactoring.

* Fri May  3 2019 Sergii Stoian <stoyan255@gmail.com> - 0.85-0
- Build with nextspace-gnustep-1.26.0_0.25.0.

* Fri Mar 01 2019 Sergii Stoian <stoyan255@gmail.com> 0.7-0
- SoundKit was added.
- Sounds were added into NXAppKit framework.

* Fri Oct 21 2016 Sergii Stoian <stoyan255@gmail.com> 0.4-0
- Initial spec for CentOS 7.
