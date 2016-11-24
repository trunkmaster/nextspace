## automake input file for wrlib

AUTOMAKE_OPTIONS =

noinst_PROGRAMS = testdraw testgrad testrot view

EXTRA_DIST = test.png tile.xpm ballot_box.xpm 

AM_CPPFLAGS = -I$(srcdir)/.. $(DFLAGS) @HEADER_SEARCH_PATH@

LIBLIST = $(top_builddir)/wrlib/libwraster.la @XLIBS@

testdraw_SOURCES = testdraw.c
testdraw_LDADD = $(LIBLIST)

testgrad_SOURCES = testgrad.c
testgrad_LDADD = $(LIBLIST)

testrot_SOURCES = testrot.c
testrot_LDADD = $(LIBLIST)

view_SOURCES= view.c
view_LDADD = $(LIBLIST)
