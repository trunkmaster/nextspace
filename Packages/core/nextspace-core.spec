Name:		nextspace-core
Version:	0.8
Release:	1%{?dist}
Summary:	Meta package for NextSpace core libraries and system files.
License:	GPLv2
URL:		http://gitlab.com/
Source0:	nextspace-core-%{version}.tgz

Requires:	libdispatch >= 1.3
Requires:	libobjc2 >= 1.8.2

%description
Meta package for NextSpace core components:
- libdispatch
- libobjc2
- OS and NextSpace files (configs, resources, etc.)

%package devel
Summary:	Development header files for NextSpace core components.
Requires:	%{name}%{?_isa} = %{version}-%{release}
Requires:	libdispatch-devel
Requires:	libobjc2-devel

%description devel
Development files for libdispatch (includes kqueue and pthread_workqueue) 
and libobjc. Also contains gnustep-make-2.6.7 to build nextspace-runtime and
develop applications/tools for NextSpace and GNUstep environments.

%prep
%setup -c

%install
cd nextspace-core-%{version}
cp -vr ./* %{buildroot}
mkdir %{buildroot}/Users

%files 
/Library/ 
/etc/
/usr/share/
/usr/NextSpace/Documentation/man/man1/open*.gz
/usr/NextSpace/Documentation/man/man7/GNUstep*.gz
/usr/NextSpace/Images
/usr/NextSpace/Preferences
/usr/NextSpace/lib/
/usr/NextSpace/etc/
/usr/NextSpace/bin/GNUstepServices
/usr/NextSpace/bin/openapp

%files devel
/Developer/
/usr/NextSpace/bin/debugapp
/usr/NextSpace/bin/gnustep-config
/usr/NextSpace/bin/gnustep-tests
/usr/NextSpace/Documentation/man/man1/debugapp*
/usr/NextSpace/Documentation/man/man1/gnustep*
/usr/NextSpace/Documentation/man/man7/library-combo*

%changelog
* Wed Oct 19 2016 Sergii Stoian <stoyan255@ukr.net> 0.8-1
- Initial spec.
