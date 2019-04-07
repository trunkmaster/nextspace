## automake input file for WINGs

AUTOMAKE_OPTIONS =

# is this a kluge? if so, how should i do it?
includedir = @includedir@/WINGs

include_HEADERS = wtableview.h wtabledelegates.h 


lib_LTLIBRARIES = libExtraWINGs.la

noinst_PROGRAMS = test

EXTRA_DIST = 

libExtraWINGs_la_SOURCES = 	\
	wtableview.c \
	wtabledelegates.c \
	wtableview.h \
	wtabledelegates.h 

AM_CPPFLAGS = -I$(top_srcdir)/wrlib -I$(top_srcdir)/WINGs \
	-DRESOURCE_PATH=\"$(datadir)/WINGs\" @HEADER_SEARCH_PATH@

LDADD= $(top_builddir)/WINGs/libWINGs.la $(top_builddir)/wrlib/libwraster.la \
	$(top_builddir)/WINGs/libWUtil.la \
	@XFTLIBS@ @INTLIBS@

test_LDADD = wtableview.o wtabledelegates.o $(LDADD)
