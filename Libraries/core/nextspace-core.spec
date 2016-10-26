%define MAKE_VERSION    2.6.8

Name:		nextspace-core
Version:	0.8
Release:	14%{?dist}
Summary:	NextSpace filesystem hierarchy and system files.
License:	GPLv2
URL:		http://gitlab.com/stoyan/nextspace
Source0:	nextspace-os_files-%{version}.tar.gz
Source1:	gnustep-make-%{MAKE_VERSION}.tar.gz
Source2:	nextspace.fsl

BuildRequires:  libobjc2-devel

Requires:	libdispatch >= 1.3
Requires:	libobjc2 >= 1.8.2
Requires:	zsh

%description
Includes several components:
- gnustep-make-2.6.8 (/Developer, /Library/Preferences/GNUstep.conf, 
  /usr/NextSpace/Documentation, /usr/NextSpace/bin);
- OS configuration files (/etc: X11 font display config, paths for linker,
  user shell profile, udev rule to mount removable media under /media, 
  /etc/skel: user home dir skeleton, tuned and logind settings);
- GNUstep helper script: /usr/NextSpace/bin/gnustep-services.

%package devel
Summary:	Development header files for NextSpace core components.
Requires:	%{name}%{?_isa} = %{version}-%{release}
Requires:	libdispatch-devel
Requires:	libobjc2-devel
Provides:	gnustep-make

%description devel
Development files for libdispatch (includes kqueue and pthread_workqueue) 
and libobjc. Also contains gnustep-make-2.6.7 to build nextspace-runtime and
develop applications/tools for NextSpace environment.

%prep
%setup -c -n nextspace-core -a 1
cp %{_sourcedir}/nextspace.fsl %{_builddir}/%{name}/gnustep-make-%{MAKE_VERSION}/FilesystemLayouts/nextspace

%build
export CC=clang
export CXX=clang++
export OBJCFLAGS="-fblocks -fobjc-runtime=gnustep-1.8"
export LD_LIBRARY_PATH="%{buildroot}/Library/Libraries:/usr/NextSpace/lib"

# Build gnustep-make to include in -devel package
cd gnustep-make-%{MAKE_VERSION}
./configure \
    --with-config-file=/Library/Preferences/GNUstep.conf \
    --with-layout=nextspace \
    --enable-native-objc-exceptions \
    --enable-objc-nonfragile-abi \
    --enable-debug-by-default
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
mkdir %{buildroot}/Users

%files 
/Library
/Users
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
* Wed Oct 26 2016 Sergii Stoian <stoyan255@ukr.net> 0.8-11
- Add /Developer/Libraries into /etc/ld.so.conf.d/nextspace.conf
- Add -fblocks to OBJFLAGS

* Tue Oct 25 2016 Sergii Stoian <stoyan255@ukr.net> 0.8-10
- Remove --enable-objc-nonfragile-abi from gnustep-make configure options.

* Mon Oct 24 2016 Sergii Stoian <stoyan255@ukr.net> 0.8-7
- Remove --with-thread-lib from gnustep-make configure options.

* Wed Oct 19 2016 Sergii Stoian <stoyan255@ukr.net> 0.8-5
- Initial spec.
