%define MAKE_VERSION    2.7.0

Name:		nextspace-core
Version:	0.95
Release:	1%{?dist}
Summary:	NextSpace filesystem hierarchy and system files.
License:	GPLv2
URL:		http://gitlab.com/stoyan/nextspace
Source0:	nextspace-os_files-%{version}.tar.gz
Source1:	gnustep-make-%{MAKE_VERSION}.tgz
Source2:	nextspace.fsl

BuildRequires:  libobjc2-devel

Requires:	libdispatch >= 1.3
Requires:	libobjc2 >= 2.0
Requires:	zsh
Requires:	plymouth-plugin-script
Requires:	plymouth-plugin-label

%description
Includes several components:
- OS configuration files (/etc: X11 font display config, paths for linker,
  user shell profile, udev rule to mount removable media under /media, 
  /etc/skel: user home dir skeleton, tuned and logind settings);
- GNUstep helper script: /usr/NextSpace/bin/gnustep-services.
- Plymouth `nextspace` theme. It should be activated manually.
- `NextsSpace` mouse cursor theme

%package devel
Summary:	Development header files for NextSpace core components.
Requires:	%{name}%{?_isa} = %{version}-%{release}
Requires:	libdispatch-devel
Requires:	libobjc2-devel
Provides:	gnustep-make

%description devel
Contains GNUstep Make to build nextspace-runtime and develop 
applications/tools for NextSpace environment.

%prep
%setup -c -n nextspace-core -a 1
cp %{_sourcedir}/nextspace.fsl %{_builddir}/%{name}/gnustep-make-%{MAKE_VERSION}/FilesystemLayouts/nextspace

%build
export CC=clang
export CXX=clang++
#export OBJCFLAGS="-fblocks -fobjc-runtime=gnustep-1.8"
export LD_LIBRARY_PATH="%{buildroot}/Library/Libraries:/usr/NextSpace/lib"

# Build gnustep-make to include in -devel package
cd gnustep-make-%{MAKE_VERSION}
./configure \
    --with-config-file=/Library/Preferences/GNUstep.conf \
    --with-layout=nextspace \
    --enable-native-objc-exceptions \
    --enable-debug-by-default \
    --with-library-combo=ng-gnu-gnu
make
cd ..

%install
cd gnustep-make-%{MAKE_VERSION}
%{make_install}
rm %{buildroot}/usr/NextSpace/bin/opentool
cd ..

cd nextspace-os_files-%{version}
cp -vr ./etc %{buildroot}
cp -vr ./usr %{buildroot}
cp -vr ./root %{buildroot}
mkdir %{buildroot}/Users

%files 
/Library
/Users
/root/Library
/root/.config
/root/.fonts
/root/.gtkrc
/root/.gtkrc-2.0
/root/fonts.conf
/etc/ld.so.conf.d
/etc/profile.d
/etc/skel
/etc/tuned
/etc/udev
/etc/X11
/etc/polkit-1/rules.d/10-udisks2.rules
/usr/lib/systemd/logind.conf.d/lidswitch.conf
/usr/NextSpace/Documentation/man/man1/open*.gz
/usr/NextSpace/etc/
/usr/NextSpace/bin/gnustep-services
/usr/NextSpace/bin/openapp
/usr/share/icons/NextSpace
/usr/share/plymouth/themes
/etc/dracut.conf.d

%files devel
/Developer
/usr/NextSpace/bin/debugapp
/usr/NextSpace/bin/gnustep-config
/usr/NextSpace/bin/gnustep-tests
/usr/NextSpace/Documentation/man/man1/debugapp*
/usr/NextSpace/Documentation/man/man1/gnustep*
/usr/NextSpace/Documentation/man/man7/GNUstep*.gz
/usr/NextSpace/Documentation/man/man7/library-combo*

%post
useradd -D -b /Users -s /bin/zsh
tuned-adm profile desktop

%preun
useradd -D -b /home -s /bin/bash
tuned-adm profile balanced

%changelog
* Fri Mar 22 2019 Sergii Stoian <stoyan255@gmail.com> 0.95-1
- added `--with-library-combo` to gnustep-make configure step

* Fri Mar 22 2019 Sergii Stoian <stoyan255@gmail.com> 0.95-0
- new GNUstep make version 2.7.0
- use new version of libobjc2 - 2.0
- new `nextspace` theme for plymouth boot screen
- new `NextSpace` mouse cursor theme

* Tue Nov 15 2016 Sergii Stoian <stoyan255@ukr.net> 0.9-1
- Defaults ~/Library/Preferences were added for the root user.
- Midnight Commander user's ini file was removed.

* Wed Oct 26 2016 Sergii Stoian <stoyan255@ukr.net> 0.8-11
- Add /Developer/Libraries into /etc/ld.so.conf.d/nextspace.conf
- Add -fblocks to OBJFLAGS

* Tue Oct 25 2016 Sergii Stoian <stoyan255@ukr.net> 0.8-10
- Remove --enable-objc-nonfragile-abi from gnustep-make configure options.

* Mon Oct 24 2016 Sergii Stoian <stoyan255@ukr.net> 0.8-7
- Remove --with-thread-lib from gnustep-make configure options.

* Wed Oct 19 2016 Sergii Stoian <stoyan255@ukr.net> 0.8-5
- Initial spec.
