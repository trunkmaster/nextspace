%global selinux_variants mls targeted
%global selinux_modules ns-core ns-gdomap ns-gpbs ns-gdnc ns-Login

Name:		nextspace-selinux
Version:	0.91
Release:	0%{?dist}
Summary:	SELinux policies for NEXTSPACE components.

Group:		Libraries/NextSpace
License:	GPLv3

# SELinux modules
BuildRequires:	checkpolicy
BuildRequires:	selinux-policy-devel
BuildRequires:	hardlink
%if "%{%_selinux_policy_version}" != ""
Requires:	selinux-policy >= %{%_selinux_policy_version}
%endif
Requires:	policycoreutils
Requires:	nextspace-gnustep
Requires:	nextspace-applications

%description
GNUstep libraries - implementation of OpenStep (AppKit, Foundation).

%prep
rm -rf %{buildroot}
rm -rf %{_builddir}/%{name}
mkdir %{_builddir}/%{name}
cp %{_sourcedir}/*.fc %{_builddir}/%{name}
cp %{_sourcedir}/*.if %{_builddir}/%{name}
cp %{_sourcedir}/*.te %{_builddir}/%{name}

#
# Build phase
#
%build
# Build SELinux modules
cd %{_builddir}/%{name}
for selinuxvariant in %{selinux_variants}
do
    make NAME=${selinuxvariant} -f /usr/share/selinux/devel/Makefile
    for module in %{selinux_modules}
    do
        mv ${module}.pp ${module}.pp.${selinuxvariant}
    done
    make NAME=${selinuxvariant} -f /usr/share/selinux/devel/Makefile clean
done
cd -

# Build install phase
%install
cd %{_builddir}/%{name}
for selinuxvariant in %{selinux_variants}
do
    install -d %{buildroot}%{_datadir}/selinux/${selinuxvariant}/%{name}
    for module in %{selinux_modules}
    do
        install -p -m 644 ${module}.pp.${selinuxvariant} \
		%{buildroot}%{_datadir}/selinux/${selinuxvariant}/%{name}/${module}.pp
    done
done
cd -

/usr/sbin/hardlink -cv %{buildroot}%{_datadir}/selinux

#
# Files
#
%files
%{_datadir}/selinux/targeted/%{name}
%{_datadir}/selinux/mls/%{name}

#
# Package install
#
# for %pre and %post $1 = 1 - installation, 2 - upgrade
#%pre
%post
# SELinux installation of modules in the supported policies
for selinuxvariant in %{selinux_variants}
do
    install -d %{_datadir}/selinux/${selinuxvariant}/nextspace
    for module in %{selinux_modules}
    do	
	/usr/sbin/semodule -s ${selinuxvariant} -i \
			   %{_datadir}/selinux/${selinuxvariant}/%{name}/${module}.pp &> /dev/null || :
    done
done
/sbin/fixfiles -R nextspace-gnustep restore || :
/sbin/fixfiles -R nextspace-applications restore || :

#
# Package uninstall
#
# for %preun and %postun $1 = 0 - uninstallation, 1 - upgrade. 
#%preun
%postun
# Remove SELinux modules
if [ $1 -eq 0 ] ; then
    for selinuxvariant in %{selinux_variants}
    do
	for module in %{selinux_modules}
	do
	    /usr/sbin/semodule -s ${selinuxvariant} -r ${module} &> /dev/null || :
	done
    done
fi

%changelog
* Tue Aug 18 2020 Sergii Stoian <stoyan255@gmail.com> - 0.91
- Initial version of SELinux policies by Frederico Muñoz (@fsmunoz).
