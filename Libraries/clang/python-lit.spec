%global srcname lit

#%if 0%{?fedora} || 0%{?rhel} > 7
%global with_python3 1
#%endif

# FIXME: Work around for rhel not having py2_build/py2_install macro.
%{!?py2_build: %global py2_build %{expand: CFLAGS="%{optflags}" %{__python2} setup.py %{?py_setup_args} build --executable="%{__python2} -s"}}
%{!?py2_install: %global py2_install %{expand: CFLAGS="%{optflags}" %{__python2} setup.py %{?py_setup_args} install -O1 --skip-build --root %{buildroot}}}

Name: python-%{srcname}
Version: 0.7.1
Release: 1%{?dist}
BuildArch: noarch

License: NCSA
Group: Development/Languages
Summary: Tool for executing llvm test suites
URL: https://pypi.python.org/pypi/lit
Source0: https://files.pythonhosted.org/packages/ee/19/89553646a07f35c49f9540f519c8d9543e8799736276756d203c697c0a13/lit-0.7.1.tar.gz

BuildRequires: python2-devel
BuildRequires: python2-setuptools
%if 0%{?with_python3}
BuildRequires: python34-devel
BuildRequires: python34-setuptools
%endif

%description
lit is a tool used by the LLVM project for executing its test suites.

%package -n python2-lit
Summary: LLVM lit test runner for Python 2
Group: Development/Languages

Requires: python2-setuptools

%if 0%{?with_python3}
%package -n python3-lit
Summary: LLVM lit test runner for Python 3
Group: Development/Languages

Requires: python34-setuptools
%endif

%description -n python2-lit
lit is a tool used by the LLVM project for executing its test suites.

%if 0%{?with_python3}
%description -n python3-lit
lit is a tool used by the LLVM project for executing its test suites.
%endif

%prep
%autosetup -n %{srcname}-%{version}%{?rc_ver:rc%{rc_ver}}

%build
%py2_build
%if 0%{?with_python3}
%py3_build
%endif

%install
%py2_install
%if 0%{?with_python3}
%py3_install
%endif

# Strip out #!/usr/bin/env python
sed -i -e '1{\@^#!/usr/bin/env python@d}' %{buildroot}%{python2_sitelib}/%{srcname}/*.py
%if 0%{?with_python3}
sed -i -e '1{\@^#!/usr/bin/env python@d}' %{buildroot}%{python3_sitelib}/%{srcname}/*.py
%endif

%check
%{__python2} setup.py test
%if 0%{?with_python3}
# FIXME: Tests fail with python3
#{__python3} setup.py test
%endif

%files -n python2-%{srcname}
%doc README.txt
%{python2_sitelib}/*
%if %{undefined with_python3}
%{_bindir}/lit
%endif

%if 0%{?with_python3}
%files -n python3-%{srcname}
%doc README.txt
%{python3_sitelib}/*
%{_bindir}/lit
%endif

%changelog
* Mon Dec 17 2018 sguelton@redhat.com - 0.7.1-1
- 7.0.1 Release

* Tue Sep 25 2018 Tom Stellard <tstellar@redhat.com> - 0.7.0-2
- Add missing dist to release tag

* Fri Sep 21 2018 Tom Stellard <tstellar@redhat.com> - 0.7.0-1
- 0.7.0 Release

* Fri Aug 31 2018 Tom Stellard <tstellar@redhat.com> - 0.7.0-0.2.rc1
- Add Requires: python[23]-setuptools

* Mon Aug 13 2018 Tom Stellard <tstellar@redhat.com> - 0.7.0-0.1.rc1
- 0.7.0 rc1

* Sat Jul 14 2018 Fedora Release Engineering <releng@fedoraproject.org> - 0.6.0-3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_29_Mass_Rebuild

* Tue Jun 19 2018 Miro Hrončok <mhroncok@redhat.com> - 0.6.0-2
- Rebuilt for Python 3.7

* Fri Feb 09 2018 Fedora Release Engineering <releng@fedoraproject.org> - 0.6.0-1
- 0.6.0 Release

* Fri Feb 09 2018 Fedora Release Engineering <releng@fedoraproject.org> - 0.6.0-0.2.rc1
- Rebuilt for https://fedoraproject.org/wiki/Fedora_28_Mass_Rebuild

* Tue Jan 23 2018 Tom Stellard <tstellar@redhat.com> - 0.6.0-0.1.rc1
- 0.6.0 rc1

* Tue Jan 23 2018 John Dulaney <jdulaney@fedoraproject.org> - 0.5.1-4
- Add a missed python3 conditional around a sed operation

* Mon Jan 15 2018 Merlin Mathesius <mmathesi@redhat.com> - 0.5.1-3
- Cleanup spec file conditionals

* Wed Dec 06 2017 Tom Stellard <tstellar@redhat.com> - 0.5.1-2
- Fix python prefix in BuildRequires

* Tue Oct 03 2017 Tom Stellard <tstellar@redhat.com> - 0.5.1-1
- Rebase to 0.5.1

* Thu Jul 27 2017 Fedora Release Engineering <releng@fedoraproject.org> - 0.5.0-2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_27_Mass_Rebuild

* Thu Mar 09 2017 Tom Stellard <tstellar@redhat.com> - 0.5.0-1
- Initial version
