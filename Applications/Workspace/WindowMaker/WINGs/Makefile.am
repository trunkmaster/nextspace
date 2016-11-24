## automake input file for WINGs

AUTOMAKE_OPTIONS =

SUBDIRS = WINGs . po Documentation Resources
DIST_SUBDIRS = $(SUBDIRS) Tests Examples Extras

libWINGs_la_LDFLAGS = -version-info @WINGS_VERSION@
libWUtil_la_LDFLAGS = -version-info @WUTIL_VERSION@

dist_bin_SCRIPTS = get-wings-flags get-wutil-flags

lib_LTLIBRARIES = libWUtil.la libWINGs.la


LDADD= libWUtil.la libWINGs.la $(top_builddir)/wrlib/libwraster.la @INTLIBS@
libWINGs_la_LIBADD = libWUtil.la $(top_builddir)/wrlib/libwraster.la @XLIBS@ @XFTLIBS@ @FCLIBS@ @LIBM@ @PANGOLIBS@
libWUtil_la_LIBADD = @LIBBSD@

EXTRA_DIST = BUGS make-rgb Examples Extras Tests


# wbutton.c 
libWINGs_la_SOURCES = 	\
	configuration.c \
	dragcommon.c \
	dragdestination.c \
	dragsource.c \
	rgb.h \
	selection.c \
	wappresource.c \
	wballoon.c \
	wbox.c \
	wbrowser.c \
	wbutton.c \
	wcolor.c \
	wcolorpanel.c \
	wcolorwell.c \
	wconfig.h \
	wevent.c \
	wfilepanel.c \
	wframe.c \
	wfont.c \
	wfontpanel.c \
	widgets.c \
	winputmethod.c \
	wlabel.c \
	wlist.c \
	wmenuitem.c \
	wmisc.c \
	wpanel.c \
	wpixmap.c \
	wpopupbutton.c \
	wprogressindicator.c \
	wruler.c \
	wscroller.c \
	wscrollview.c \
	wslider.c \
	wsplitview.c \
	wtabview.c \
	wtext.c \
	wtextfield.c \
	wview.c \
	wwindow.c

libWUtil_la_SOURCES = 	\
	array.c \
	bagtree.c \
	data.c \
	error.c \
	error.h \
	findfile.c \
	handlers.c \
	hashtable.c \
	memory.c \
	menuparser.c \
	menuparser.h \
	menuparser_macros.c \
	misc.c \
	notification.c \
	proplist.c \
	string.c \
	tree.c \
	userdefaults.c \
	userdefaults.h \
	usleep.c \
	wapplication.c \
	wconfig.h \
	wutil.c


AM_CFLAGS =

AM_CPPFLAGS = -DRESOURCE_PATH=\"$(datadir)/WINGs\" \
	 -I$(top_srcdir)/WINGs/WINGs -I$(top_srcdir)/wrlib -I$(top_srcdir)/src \
	@XFTFLAGS@ @HEADER_SEARCH_PATH@

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = WINGs.pc WUtil.pc

DISTCLEANFILES = $(pkgconfig_DATA)

WINGs.pc: Makefile
	@echo "Generating $@"
	@echo 'Name: WINGs' > $@
	@echo 'Description: Small widget set with the NeXTStep(TM) look and feel' >> $@
	@echo 'Version: $(VERSION)' >> $@
	@echo 'Requires: wrlib WUtil' >> $@
	@echo 'Libs: $(lib_search_path) -lWINGs' >> $@
	@echo 'Libs.private: $(XFTLIBS) $(PANGOLIBS) $(XLIBS) -lm $(INTLIBS)' >> $@
	@echo 'Cflags: $(inc_search_path)' >> $@

WUtil.pc: Makefile
	@echo "Generating $@"
	@echo 'Name: WUtil' > $@
	@echo 'Description: Utility library for WINGs' >> $@
	@echo 'Version: $(VERSION)' >> $@
	@echo 'Libs: -L$(libdir) -lWUtil' >> $@
	@echo 'Libs.private: $(INTLIBS)' >> $@
	@echo 'Cflags: -I$(includedir)' >> $@
