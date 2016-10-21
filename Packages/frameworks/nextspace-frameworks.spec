%define APPKIT_VERSION		0.6
%define FOUNDATION_VERSION	0.3
%define SYSTEM_VERSION		0.3


Name:           nextspace-frameworks
Version:        0.4
Release:        0%{?dist}
Summary:        NextSpace core libraries.

Group:          Libraries/NextSpace
License:        GPLv2
URL:		http://www.gitlab.com/stoyan/nextspace
Source0:	NXAppKit-%{APPKIT_VERSION}.tar.gz
Source1:	NXFoundation-%{FOUNDATION_VERSION}.tar.gz
Source2:	NXSystem-%{SYSTEM_VERSION}.tar.gz

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

Requires:	nextspace-gnustep
# NXFoundation
Requires:	file-libs >= 5.11
# NXSystem
#Requires:	udisks2 
Requires:	libudisks2 >= 2.1.2
Requires:	dbus-libs >= 1.6.12
Requires:	upower >= 0.99.2
Requires:	glib2 >= 2.42.2
Requires:	libXrandr >= 1.4.2


%description
NextSpace libraries.

%package devel
Summary:	NextSpace core libraries (NXSystem, NXFoundation, NXAppKit).
Requires:	%{name}%{?_isa} = %{version}-%{release}

%description devel
Header file for NextSpace core libraries (NXSystem, NXFoundation, NXAppKit).

%prep
%setup -c nextspace-frameworks -a 1 -a 2

#
# Build phase
#
%build
export CC=clang
export CXX=clang++
export GNUSTEP_MAKEFILES=/Developer/Makefiles
export PATH+=":/usr/NextSpace/bin"

export ADDITIONAL_INCLUDE_DIRS="-I../NXFoundation-%{FOUNDATION_VERSION}/derived_src -I../NXSystem-%{SYSTEM_VERSION}/derived_src"

cd NXFoundation-%{FOUNDATION_VERSION}
make
cd ..

cd NXSystem-%{SYSTEM_VERSION}
make
cd ..

cd NXAppKit-%{APPKIT_VERSION}
#export LDFLAGS="-L../NXFoundation-%{FOUNDATION_VERSION}/NXFoundation.framework -lNXFoundation"
make
cd ..

#
# Build install phase
#
%install
export GNUSTEP_MAKEFILES=/Developer/Makefiles
export QA_SKIP_BUILD_ROOT=1

cd NXSystem-%{SYSTEM_VERSION}
%{make_install}
cd ..

cd NXFoundation-%{FOUNDATION_VERSION}
%{make_install}
cd ..

cd NXAppKit-%{APPKIT_VERSION}
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

