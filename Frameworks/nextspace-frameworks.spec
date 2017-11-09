%define APPKIT_VERSION		0.6
%define FOUNDATION_VERSION	0.3
%define SYSTEM_VERSION		0.3


Name:           nextspace-frameworks
Version:        0.6
Release:        2%{?dist}
Summary:        NextSpace core libraries.

Group:          Libraries/NextSpace
License:        GPLv2
URL:		http://www.gitlab.com/stoyan/nextspace
Source0:	nextspace-frameworks-%{version}.tar.gz

Provides:	NXFoundation.so
Provides:	NXSystem.so
Provides:	NXAppKit.so

BuildRequires:	nextspace-gnustep-devel
# NXFoundation
BuildRequires:	file-devel
# NXSystem
BuildRequires:	libudisks2-devel
BuildRequires:	dbus-devel
BuildRequires:	upower-devel
BuildRequires:	libXrandr-devel
BuildRequires:	libxkbfile-devel

Requires:	nextspace-gnustep
# NXFoundation
Requires:	file-libs >= 5.11
# NXSystem
Requires:	udisks2
Requires:	libudisks2 >= 2.1.2
Requires:	dbus-libs >= 1.6.12
Requires:	upower >= 0.99.2
Requires:	glib2 >= 2.42.2
Requires:	libXrandr >= 1.4.2
Requires:	libxkbfile >= 1.0.9


%description
NextSpace libraries.

%package devel
Summary:	NextSpace core libraries (NXSystem, NXFoundation, NXAppKit).
Requires:	%{name}%{?_isa} = %{version}-%{release}

%description devel
Header file for NextSpace core libraries (NXSystem, NXFoundation, NXAppKit).

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

export ADDITIONAL_INCLUDE_DIRS="-I../NXFoundation/derived_src -I../NXSystem/derived_src"

cd NXFoundation
make
cd ..

cd NXSystem
make
cd ..

cd NXAppKit
#export LDFLAGS="-L../NXFoundation-%{FOUNDATION_VERSION}/NXFoundation.framework -lNXFoundation"
make messages=yes
cd ..

#
# Build install phase
#
%install
export GNUSTEP_MAKEFILES=/Developer/Makefiles
export QA_SKIP_BUILD_ROOT=1

cd NXSystem
%{make_install}
cd ..

cd NXFoundation
%{make_install}
cd ..

cd NXAppKit
%{make_install}
cd ..

#
# Files
#
%files
/usr/NextSpace/Frameworks
/usr/NextSpace/lib

%files devel
/usr/NextSpace/include

#
# Package install
#
#%pre

%post
ln -s /usr/NextSpace/Frameworks/NXAppKit.framework/Resources/Images /usr/NextSpace/Images
ln -s /usr/NextSpace/Frameworks/NXAppKit.framework/Resources/Fonts /Library/Fonts

#%preun

%postun
rm /usr/NextSpace/Images
rm /Library/Fonts

%changelog
* Fri Oct 21 2016 Sergii Stoian <stoyan255@ukr.net> 0.4-0
- Initial spec for CentOS 7.

