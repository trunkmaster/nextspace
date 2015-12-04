%global snapdate  2015.05.27
%global commitish b295a20

Summary:        Bleeding-edge development version of Window Maker window manager
Name:           wmaker-crm-next
Version:        %{snapdate}.g%{commitish}
Release:        1%{?dist}
License:        GPLv2+
Group:          User Interface/Desktops
URL:            http://repo.or.cz/w/wmaker-crm.git

Conflicts:      WindowMaker
Provides:       WindowMaker

# http://repo.or.cz/w/wmaker-crm.git/snapshot/refs/heads/next.tar.gz
Source0:        wmaker-crm-next-%{version}.tar.gz
Source1:        WindowMaker-xsession.desktop
Source2:        WindowMaker-application.desktop
Source3:        WindowMaker-WMRootMenu-fedora


BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-buildroot
# X BR
BuildRequires:  libICE-devel
BuildRequires:  libSM-devel
BuildRequires:  libX11-devel
BuildRequires:  libXext-devel
BuildRequires:  libXft-devel
BuildRequires:  libXinerama-devel
BuildRequires:  libXpm-devel
BuildRequires:  libXrender-devel
BuildRequires:  xorg-x11-proto-devel
BuildRequires:  libXmu-devel
BuildRequires:  libXrandr-devel
# graphic BR
BuildRequires:  libpng-devel
BuildRequires:  libjpeg-devel
BuildRequires:  libungif-devel
BuildRequires:  libtiff-devel
BuildRequires:  ImageMagick-devel
# other
BuildRequires:  zlib-devel
BuildRequires:  gettext-devel
BuildRequires:  fontconfig-devel
BuildRequires:  automake autoconf libtool
BuildRequires:  chrpath

Requires:       WINGs-next-libs = %{version}-%{release}
Requires:       desktop-backgrounds-compat

%description
Window Maker is an X11 window manager designed to give additional
integration support to the GNUstep Desktop Environment. In every way
possible, it reproduces the elegant look and feel of the NEXTSTEP GUI.
It is fast, feature rich, easy to configure, and easy to use. In
addition, Window Maker works with GNOME and KDE, making it one of the
most useful and universal window managers available.

This package contains bleeding-edge development version.

%package devel
Summary:        Development files for WindowMaker
Group:          System Environment/Libraries
Requires:       %{name} = %{version}-%{release}
Requires:       WINGs-next-devel = %{version}-%{release}

%description devel
Development files for WindowMaker.

%package -n WINGs-next-libs
Summary:        Widgets and image libraries needed for WindowMaker
Group:          System Environment/Libraries
Conflicts:      WINGs-libs
Provides:       WINGs-libs


%description -n WINGs-next-libs
Widgets and image libraries needed for WindowMaker.

%package -n WINGs-next-devel
Summary:        Development files for the WINGs library
Group:          System Environment/Libraries
Requires:       WINGs-next-libs = %{version}-%{release}
Requires:       libX11-devel
Requires:       xorg-x11-proto-devel
Requires:       libXinerama-devel
Requires:       libXrandr-devel
Requires:       libXext-devel
Requires:       libtiff-devel
Requires:       zlib-devel
Requires:       libXpm-devel
Requires:       libjpeg-devel
Requires:       libpng-devel
Requires:       libungif-devel
Requires:       libXft-devel
Requires:       fontconfig-devel
Conflicts:      WINGs-devel
Provides:       WINGs-devel

%description -n WINGs-next-devel
Development files for the WINGs library.

%prep
%setup -q -n %{name}-%{commitish}

# cleanup menu entries
for i in WindowMaker/*menu*; do
echo $i
sed -i.old -e 's:/usr/local/:%{_prefix}/:g' \
  -e 's:/home/mawa:$(HOME):g' \
  -e 's:GNUstep/Applications/WPrefs.app:bin:g' $i
done

for i in util/wmgenmenu.c WindowMaker/Defaults/WindowMaker.in WPrefs.app/Paths.c; do
echo $i
sed -i.old -e  's:/usr/local/:%{_prefix}/:g'  $i
done

# fix utf8 issues
iconv -f iso8859-1 -t utf-8 ChangeLog > ChangeLog.conv && mv -f ChangeLog.conv ChangeLog

for i in doc/cs/geticonset.1x doc/cs/seticons.1x doc/cs/wdwrite.1x doc/cs/wmaker.1x \
 doc/cs/wmsetbg.1x doc doc/cs/wxcopy.1x doc/cs/wxpaste.1x doc/sk/geticonset.1x \
 doc/sk/seticons.1x doc/sk/wdwrite.1x doc/sk/wmaker.1x doc/sk/wmsetbg.1x \
 doc/sk/wxcopy.1x doc/sk/wxpaste.1x; do
echo $i
iconv -f iso8859-1 -t utf-8 $i > $i.conv && mv -f $i.conv $i
done

autoreconf -vfi -I m4

%build
CFLAGS="$RPM_OPT_FLAGS -DNEWAPPICON"
LINGUAS=`(cd po ; echo *.po | sed 's/.po//g')`
NLSDIR="%{_datadir}/locale"

export CFLAGS LINGUAS NLSDIR

%configure \
 --disable-static \
 --enable-modelock \
 --enable-randr \
 --enable-xinerama \
 --enable-usermenu \
 --x-includes=%{_includedir} \
 --x-libraries=%{_libdir}

make %{?_smp_mflags}

%install
rm -rf $RPM_BUILD_ROOT
make DESTDIR=$RPM_BUILD_ROOT NLSDIR=%{_datadir}/locale install

%find_lang '\(WPrefs\|WindowMaker\|WINGs\|wmgenmenu\)'

install -D -m0644 -p %{SOURCE1} \
%{buildroot}%{_datadir}/xsessions/WindowMaker.desktop
install -D -m0644 -p %{SOURCE2} \
%{buildroot}%{_datadir}/applications/WindowMaker.desktop

# make first login fedora specific
install -D -m0644 -p %{SOURCE3} \
%{buildroot}%{_sysconfdir}/WindowMaker/WMRootMenu
sed -i \
  -e 's:WorkspaceBack = (solid:WorkspaceBack = (mpixmap, "/usr/share/backgrounds/default.png":' \
  %{buildroot}%{_sysconfdir}/WindowMaker/WindowMaker

find %{buildroot} -type f -name "*.la" -exec rm -f {} ';'

chmod 755 %{buildroot}%{_datadir}/WindowMaker/{autostart.sh,exitscript.sh}
chmod 644 util/wmiv.{c,h}

# remove rpath
for f in wmaker wdwrite wdread getstyle setstyle convertfonts seticons \
geticonset wmsetbg wmagnify wmgenmenu wmmenugen WPrefs ; do
chrpath --delete %{buildroot}%{_bindir}/$f
done

chrpath --delete %{buildroot}%{_libdir}/libWINGs.so.3.1.0

%clean
rm -rf $RPM_BUILD_ROOT

%post -p /sbin/ldconfig

%postun -p /sbin/ldconfig

%post -n WINGs-next-libs -p /sbin/ldconfig

%postun -n WINGs-next-libs -p /sbin/ldconfig

%files -f '\(WPrefs\|WindowMaker\|WINGs\|wmgenmenu\)'.lang
%defattr(-,root,root,-)
%doc AUTHORS ChangeLog NEWS FAQ* README* COPYING*
%dir %{_sysconfdir}/WindowMaker
%config(noreplace) %{_sysconfdir}/WindowMaker/*
%{_bindir}/wmaker
%{_bindir}/wdwrite
%{_bindir}/wdread
%{_bindir}/getstyle
%{_bindir}/setstyle
%{_bindir}/convertfonts
%{_bindir}/seticons
%{_bindir}/geticonset
%{_bindir}/wmsetbg
%{_bindir}/wmagnify
%{_bindir}/wmgenmenu
%{_bindir}/wmmenugen
%{_bindir}/WPrefs
%{_bindir}/wkdemenu.pl
%{_bindir}/wm-oldmenu2new
%{_bindir}/wmaker.inst
%{_bindir}/wxcopy
%{_bindir}/wxpaste
%{_bindir}/wmiv
%{_libdir}/libWMaker.so.*
%{_datadir}/xsessions/WindowMaker.desktop
%{_datadir}/applications/WindowMaker.desktop
%dir %{_datadir}/WindowMaker
%{_datadir}/WindowMaker/appearance.menu
%{_datadir}/WindowMaker/autostart.sh
%{_datadir}/WindowMaker/background.menu
%{_datadir}/WindowMaker/exitscript.sh
%{_datadir}/WindowMaker/menu*
%{_datadir}/WindowMaker/plmenu*
%{_datadir}/WindowMaker/README*
%{_datadir}/WindowMaker/wmmacros
%{_datadir}/WindowMaker/Backgrounds/
%{_datadir}/WindowMaker/IconSets/
%{_datadir}/WindowMaker/Pixmaps/
%{_datadir}/WindowMaker/Styles/
# these are shared with -extra
%dir %{_datadir}/WindowMaker/Icons
%{_datadir}/WindowMaker/Icons/BitchX.*
%{_datadir}/WindowMaker/Icons/clip.*
%{_datadir}/WindowMaker/Icons/defaultAppIcon.*
%{_datadir}/WindowMaker/Icons/defaultterm.*
%{_datadir}/WindowMaker/Icons/draw.*
%{_datadir}/WindowMaker/Icons/Drawer.*
%{_datadir}/WindowMaker/Icons/Ear.png
%{_datadir}/WindowMaker/Icons/Ftp.png
%{_datadir}/WindowMaker/Icons/GNUstep3D.*
%{_datadir}/WindowMaker/Icons/GNUstepGlow.*
%{_datadir}/WindowMaker/Icons/GNUstep.*
%{_datadir}/WindowMaker/Icons/GNUterm.*
%{_datadir}/WindowMaker/Icons/GreenWilber.png
%{_datadir}/WindowMaker/Icons/ICQ.png
%{_datadir}/WindowMaker/Icons/Jabber.png
%{_datadir}/WindowMaker/Icons/linuxterm.*
%{_datadir}/WindowMaker/Icons/Magnify.*
%{_datadir}/WindowMaker/Icons/mixer.*
%{_datadir}/WindowMaker/Icons/Mouth.png
%{_datadir}/WindowMaker/Icons/Mozilla.png
%{_datadir}/WindowMaker/Icons/notepad.*
%{_datadir}/WindowMaker/Icons/pdf.*
%{_datadir}/WindowMaker/Icons/Pencil.png
%{_datadir}/WindowMaker/Icons/Pen.png
%{_datadir}/WindowMaker/Icons/ps.*
%{_datadir}/WindowMaker/Icons/README
%{_datadir}/WindowMaker/Icons/Real.png
%{_datadir}/WindowMaker/Icons/real.*
%{_datadir}/WindowMaker/Icons/sgiterm.*
%{_datadir}/WindowMaker/Icons/Shell.png
%{_datadir}/WindowMaker/Icons/Speaker.png
%{_datadir}/WindowMaker/Icons/staroffice2.*
%{_datadir}/WindowMaker/Icons/TerminalGNUstep.*
%{_datadir}/WindowMaker/Icons/TerminalLinux.*
%{_datadir}/WindowMaker/Icons/Terminal.*
%{_datadir}/WindowMaker/Icons/timer.*
%{_datadir}/WindowMaker/Icons/wilber.*
%{_datadir}/WindowMaker/Icons/Wine.png
%{_datadir}/WindowMaker/Icons/write.*
%{_datadir}/WindowMaker/Icons/XChat.png
%{_datadir}/WindowMaker/Icons/xdvi.*
%{_datadir}/WindowMaker/Icons/xv.*
%dir %{_datadir}/WindowMaker/Themes
%{_datadir}/WindowMaker/Themes/Blau.style
%{_datadir}/WindowMaker/Themes/Default.style
%{_datadir}/WindowMaker/Themes/OpenStep.style
%{_datadir}/WindowMaker/Themes/Pastel.style
%{_datadir}/WindowMaker/Themes/SteelBlueSilk.style
%{_datadir}/WPrefs/
%{_mandir}/man1/*.1*
%exclude %{_mandir}/man1/get-wings-flags*
%exclude %{_mandir}/man1/get-wraster-flags*
%exclude %{_mandir}/man1/get-wutil-flags*
%{_mandir}/man8/upgrade-windowmaker-defaults*
%lang(cs) %{_mandir}/cs/man1/*.1*
%lang(sk) %{_mandir}/sk/man1/*.1*
%lang(ru) %{_mandir}/ru/man1/*.1*

%files devel
%defattr(-,root,root,-)
%{_libdir}/libWMaker.so
%{_includedir}/WMaker.h

%files -n WINGs-next-libs
%defattr(-,root,root,-)
%doc WINGs/BUGS WINGs/ChangeLog WINGs/NEWS WINGs/README WINGs/TODO
%{_libdir}/libWINGs.so.*
%{_libdir}/libwraster.so.*
%{_libdir}/libWUtil.so.*
%{_datadir}/WINGs/

%files -n WINGs-next-devel
%defattr(-,root,root,-)
%{_bindir}/get-wings-flags
%{_bindir}/get-wraster-flags
%{_bindir}/get-wutil-flags
%{_libdir}/libWINGs.so
%{_libdir}/libWUtil.so
%{_libdir}/libwraster.so
%{_libdir}/pkgconfig/WINGs.pc
%{_libdir}/pkgconfig/WUtil.pc
%{_libdir}/pkgconfig/wrlib.pc
%{_includedir}/WINGs/
%{_includedir}/wraster.h
%{_mandir}/man1/get-wings-flags*
%{_mandir}/man1/get-wraster-flags*
%{_mandir}/man1/get-wutil-flags*

%changelog
* Wed May 27 2015 Alexey I. Froloff <raorn@raorn.name> - 2015.05.27.gb295a20-1
- Initial package for the "next" branch of wmaker-crm repo
- Snapshot 2015.05.27

* Tue Oct 14 2014 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- 0.95.6-2
- make system config in /etc noreplace
- add fedora specific WMRootMenu in /etc
- set current fedora background as default background (via desktop-backgrounds-compat)
- fix bogus date in changelog
- utf8 cleanup

* Tue Oct 14 2014 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- 0.95.6-1
- version upgrade (rhbz#1138296)

* Fri Aug 15 2014 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 0.95.5-3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_21_22_Mass_Rebuild

* Fri Jun 06 2014 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 0.95.5-2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_21_Mass_Rebuild

* Sat Aug 31 2013 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- 0.95.5-1
- version upgrade
- do some more /usr/local/ replacement so that WindowMaker-extra is detected correctly

* Sat Aug 03 2013 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 0.95.4-6
- Rebuilt for https://fedoraproject.org/wiki/Fedora_20_Mass_Rebuild

* Sun Feb 10 2013 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- 0.95.4-5
- add proplist menu code from git

* Fri Jan 18 2013 Adam Tkac <atkac redhat com> - 0.95.4-4
- rebuild due to "jpeg8-ABI" feature drop

* Tue Jan 08 2013 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- 0.95.4-3
- more fsf fixes from wmaker-crm git

* Mon Jan 07 2013 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- 0.95.4-2
- fix incorrect fsf address
- submit extra package for review so this is not updated each time we update
  windowmaker

* Mon Jan 07 2013 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- 0.95.4-1
- version upgrade
- readd windowmaker extra stuff

* Mon Jan 07 2013 Adam Tkac <atkac redhat com> - 0.95.3-4
- rebuild against new libjpeg

* Wed Jul 18 2012 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 0.95.3-3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_18_Mass_Rebuild

* Thu May 31 2012 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- 0.95.3-2
- fix description

* Mon May 28 2012 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- 0.95.3-1
- version upgrade (rhbz#824670)

* Wed Feb 15 2012 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- 0.95.2-1
- version upgrade

* Thu Jan 12 2012 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 0.95.0-0.3.crm.a9e136ec41118f8842f7aa1457b2db83dbde6b7f
- Rebuilt for https://fedoraproject.org/wiki/Fedora_17_Mass_Rebuild

* Sat Dec 17 2011 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- 0.95.0-0.2.crm.a9e136ec41118f8842f7aa1457b2db83dbde6b7f
- fix requires

* Sat Dec 10 2011 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- 0.95.0-0.1.crm.a9e136ec41118f8842f7aa1457b2db83dbde6b7f
- build git snapshot
- cleanup spec file
- obsolete WindowMaker-devel package

* Tue Dec 06 2011 Adam Jackson <ajax@redhat.com> - 0.92.0-23
- Rebuild for new libpng

* Mon Feb 07 2011 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 0.92.0-22
- Rebuilt for https://fedoraproject.org/wiki/Fedora_15_Mass_Rebuild

* Wed Dec 08 2010 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- 0.92.0-21
- add -lfontconfig to WPrefs (fixes #660950)

* Fri Jul 24 2009 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 0.92.0-20
- Rebuilt for https://fedoraproject.org/wiki/Fedora_12_Mass_Rebuild

* Mon Feb 23 2009 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 0.92.0-19
- Rebuilt for https://fedoraproject.org/wiki/Fedora_11_Mass_Rebuild

* Wed Sep 24 2008 Tom "spot" Callaway <tcallawa@redhat.com> - 0.92.0-18
- fix patches to apply without fuzz
- adjust URL/Source to new website

* Mon Feb 11 2008 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de> - 0.92.0-17
- Rebuilt for gcc43

* Thu Jan 03 2008 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- 0.92.0-16
- fix #427430

* Sun Dec 09 2007 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- 0.92.0-15
- add patches from #267041 for less wakeup calls
- fix multilib stuff #343431

* Thu Aug 23 2007 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- 0.92.0-14
- new license tag
- rebuild for buildid

* Sun Jun 03 2007 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
0.92.0-13
- fix a menu bug for WPrefs
- clean up menu path

* Thu Apr 26 2007 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
0.92.0-12
- apply some changes from Patrice Dumas
- fix requires

* Sun Mar 04 2007 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
0.92.0-11
- fix install location of WPrefs (#228346)
- fix menu modification sniplet
- split into sub packages to fix multilib issues (#228346)
- mark sh files executable

* Sat Nov 04 2006 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
0.92.0-10
- fix #185579: bouncing animation will respect animations off setting
- fix #211263: missing dependencies in devel package

* Fri Sep 15 2006 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
0.92.0-9
- FE6 rebuild

* Thu Mar 02 2006 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
0.92.0-8
- fix gdm detection

* Sun Feb 26 2006 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
0.92.0-7
- fix #181981
- go to new cvs snapshot (which includes qt fix)
- add patches from altlinuxs rpm (suggested by Andrew Zabolotny)
- get rid of static libs (finally)
- tune configure
- add uk translation
- finally add extras source
- fix stack-smash while reading workspace names

* Thu Feb 16 2006 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
0.92.0-6
- Rebuild for Fedora Extras 5

* Fri Nov 25 2005 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
0.92.0-5
- modular xorg integration

* Thu Nov 17 2005 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
0.92.0-4
- add menu fix from Rudol Kastel (#173329)

* Mon Aug 22 2005 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
0.92.0-3
- add gcc4/x86_64 patch from cvs

* Tue Aug 09 2005 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
0.92.0-2
- try to fix x86_64 build

* Tue Aug 09 2005 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
0.92.0-1
- upgrade to new version 
- use dist tag
- use smp_mflags
- fix #163459

* Tue May 31 2005 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
- add disttag fc3<fc4

* Tue May 31 2005 Andreas Bierfert <andreas.bierfert[AT]lowlatency.de>
0.91.0-1
- upgrade to 0.91.0

* Thu Apr 7 2005 Michael Schwendt <mschwendt[AT]users.sf.net>
- rebuilt

* Fri Nov 28 2003 Dams <anvil[AT]livna.org> - 0:0.80.2-0.fdr.6
- exclude -> rm
- Added patch to fix gtk2 apps handling and other focus things

* Wed Sep 17 2003 Dams <anvil[AT]livna.org> 0:0.80.2-0.fdr.5
- Shortened files section
- Fixed tarball permissions (now a+r)

* Wed Sep 17 2003 Dams <anvil[AT]livna.org> 0:0.80.2-0.fdr.4
- Header files were installed in the wrong directory. Fixed. Slovak
  man pages installation fixed same way.
- WindowWaker-libs is now obsolete.

* Tue Aug 12 2003 Dams <anvil[AT]livna.org> 0:0.80.2-0.fdr.3
- buildroot -> RPM_BUILD_ROOT
- New devel package
- No more libs package

* Thu Apr 10 2003 Dams <anvil[AT]livna.org> 0:0.80.2-0.fdr.2
- Added missing Require: for gettext

* Tue Apr  8 2003 Dams <anvil[AT]livna.org>
- Initial build.
