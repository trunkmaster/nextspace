
AUTOMAKE_OPTIONS = no-dependencies

libWMaker_la_LDFLAGS = -version-info 1:1:0
lib_LTLIBRARIES = libWMaker.la

include_HEADERS = WMaker.h

AM_CPPFLAGS = $(DFLAGS) @XCFLAGS@

libWMaker_la_LIBADD = -lX11

libWMaker_la_SOURCES = 	\
	menu.c 		\
	app.c 		\
	event.c 	\
	command.c	\
	app.h		\
	menu.h	

DISTCLEANFILES = wmlib.pc

install-exec-local:
	@$(NORMAL_INSTALL)
	$(mkinstalldirs) $(DESTDIR)$(libdir)/pkgconfig
	@list='wmlib.pc'; for p in $$list; do \
	  if test -f $$p; then \
	    echo "$(INSTALL_DATA) $$p $(DESTDIR)$(libdir)/pkgconfig/"; \
	    $(INSTALL_DATA) $$p $(DESTDIR)$(libdir)/pkgconfig/; \
	  else :; fi; \
	done
