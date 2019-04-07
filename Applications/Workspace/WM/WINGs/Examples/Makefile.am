## automake input file for WINGs - Examples

AUTOMAKE_OPTIONS =


noinst_PROGRAMS = fontl puzzle colorpick


LDADD= $(top_builddir)/WINGs/libWINGs.la $(top_builddir)/wrlib/libwraster.la \
	$(top_builddir)/WINGs/libWUtil.la \
	@XFTLIBS@ @INTLIBS@ @XLIBS@

colorpick_DEPENDENCIES = $(top_builddir)/WINGs/libWINGs.la

fontl_DEPENDENCIES = $(top_builddir)/WINGs/libWINGs.la

puzzle_DEPENDENCIES = $(top_builddir)/WINGs/libWINGs.la


AM_CPPFLAGS = -I$(top_srcdir)/WINGs -I$(top_srcdir)/wrlib -I$(top_srcdir)/src \
	-DRESOURCE_PATH=\"$(datadir)/WINGs\" @HEADER_SEARCH_PATH@
