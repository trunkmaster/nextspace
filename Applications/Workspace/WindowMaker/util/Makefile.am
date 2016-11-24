SUBDIRS = po

AUTOMAKE_OPTIONS =

pkgdatadir  = $(datadir)/@PACKAGE@

bin_PROGRAMS = wxcopy wxpaste wdwrite wdread getstyle setstyle convertfonts \
	seticons geticonset wmsetbg wmagnify wmgenmenu wmmenugen wmiv

bin_SCRIPTS = wmaker.inst wm-oldmenu2new wkdemenu.pl

EXTRA_DIST = wmaker.inst.in bughint wm-oldmenu2new wkdemenu.pl

AM_CPPFLAGS = \
	 $(DFLAGS) -I$(top_srcdir)/WINGs -I$(top_srcdir)/wrlib \
	@HEADER_SEARCH_PATH@ \
	-DETCDIR=\"sysconfdir\" -DDATADIR=\"pkgdatadir\"

liblist= @LIBRARY_SEARCH_PATH@ @INTLIBS@

wdwrite_LDADD = $(top_builddir)/WINGs/libWUtil.la $(liblist)

wdread_LDADD = $(top_builddir)/WINGs/libWUtil.la $(liblist)

wxcopy_LDADD = @XLFLAGS@ @XLIBS@ 

wxpaste_LDADD = @XLFLAGS@ @XLIBS@

getstyle_LDADD = $(top_builddir)/WINGs/libWUtil.la $(liblist)

getstyle_SOURCES = getstyle.c fontconv.c common.h

setstyle_LDADD = \
	$(top_builddir)/WINGs/libWUtil.la \
	@XLFLAGS@ @XLIBS@ $(liblist)

setstyle_SOURCES = setstyle.c fontconv.c common.h

convertfonts_LDADD = $(top_builddir)/WINGs/libWUtil.la $(liblist)

convertfonts_SOURCES = convertfonts.c fontconv.c common.h

seticons_LDADD= $(top_builddir)/WINGs/libWUtil.la $(liblist)

geticonset_LDADD= $(top_builddir)/WINGs/libWUtil.la $(liblist)

wmagnify_LDADD = \
	$(top_builddir)/WINGs/libWINGs.la \
	$(top_builddir)/WINGs/libWUtil.la \
	$(top_builddir)/wrlib/libwraster.la \
	@XLFLAGS@ @XLIBS@ @INTLIBS@

wmsetbg_LDADD = \
	$(top_builddir)/WINGs/libWINGs.la \
	$(top_builddir)/WINGs/libWUtil.la \
	$(top_builddir)/wrlib/libwraster.la \
	@XLFLAGS@ @LIBXINERAMA@ @XLIBS@ @INTLIBS@

wmgenmenu_LDADD = \
	$(top_builddir)/WINGs/libWUtil.la \
	@INTLIBS@

wmgenmenu_SOURCES = wmgenmenu.c wmgenmenu.h

wmmenugen_LDADD = \
	$(top_builddir)/WINGs/libWUtil.la \
	@INTLIBS@

wmmenugen_SOURCES = wmmenugen.c wmmenugen.h wmmenugen_misc.c \
	wmmenugen_parse_wmconfig.c \
	wmmenugen_parse_xdg.c

wmiv_LDADD = \
	$(top_builddir)/wrlib/libwraster.la \
	@XLFLAGS@ @XLIBS@ \
	@GFXLIBS@ $(PTHREAD_CFLAGS) $(PTHREAD_LIBS) $(LIBEXIF)

wmiv_SOURCES = wmiv.c wmiv.h

CLEANFILES = wmaker.inst

wmaker.inst: $(srcdir)/wmaker.inst.in ./Makefile
	$(AM_V_GEN)sed -e "s|#pkgdatadir#|$(pkgdatadir)|" \
		-e "s|#sysconfdir#|$(sysconfdir)/WindowMaker|" \
		-e "s|#version#|$(VERSION)|" \
		-e "s|#bindir#|$(bindir)|" \
			$(srcdir)/wmaker.inst.in >wmaker.inst ; \
	chmod 755 wmaker.inst
