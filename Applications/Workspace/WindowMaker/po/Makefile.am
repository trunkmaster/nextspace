DOMAIN = WindowMaker

CATALOGS = @WMAKERMOFILES@

CLEANFILES = $(CATALOGS) $(DOMAIN).pot

# Please keep this sorted in alphabetic order!
EXTRA_DIST = be.po bg.po bs.po ca.po cs.po da.po de.po el.po es.po et.po \
	fi.po fr.po fy.po gl.po hr.po hu.po hy.po it.po ja.po ko.po ms.po nl.po \
	no.po pl.po pt.po ro.po ru.po sk.po sv.po tr.po uk.po zh_CN.po zh_TW.po

POTFILES  = \
	$(top_srcdir)/src/actions.c \
	$(top_srcdir)/src/appicon.c \
	$(top_srcdir)/src/application.c \
	$(top_srcdir)/src/appmenu.c \
	$(top_srcdir)/src/balloon.c \
	$(top_srcdir)/src/client.c \
	$(top_srcdir)/src/colormap.c \
	$(top_srcdir)/src/cycling.c \
	$(top_srcdir)/src/defaults.c \
	$(top_srcdir)/src/dialog.c \
	$(top_srcdir)/src/dock.c \
	$(top_srcdir)/src/dockedapp.c \
	$(top_srcdir)/src/event.c \
	$(top_srcdir)/src/framewin.c \
	$(top_srcdir)/src/geomview.c \
	$(top_srcdir)/src/icon.c \
	$(top_srcdir)/src/main.c \
	$(top_srcdir)/src/menu.c \
	$(top_srcdir)/src/misc.c \
	$(top_srcdir)/src/monitor.c \
	$(top_srcdir)/src/motif.c \
	$(top_srcdir)/src/moveres.c \
	$(top_srcdir)/src/osdep_bsd.c \
	$(top_srcdir)/src/osdep_darwin.c \
	$(top_srcdir)/src/osdep_linux.c \
	$(top_srcdir)/src/osdep_stub.c \
	$(top_srcdir)/src/pixmap.c \
	$(top_srcdir)/src/placement.c \
	$(top_srcdir)/src/properties.c \
	$(top_srcdir)/src/resources.c \
	$(top_srcdir)/src/rootmenu.c \
	$(top_srcdir)/src/screen.c \
	$(top_srcdir)/src/session.c \
	$(top_srcdir)/src/shutdown.c \
	$(top_srcdir)/src/stacking.c \
	$(top_srcdir)/src/startup.c \
	$(top_srcdir)/src/superfluous.c \
	$(top_srcdir)/src/switchpanel.c \
	$(top_srcdir)/src/switchmenu.c \
	$(top_srcdir)/src/texture.c \
	$(top_srcdir)/src/usermenu.c \
	$(top_srcdir)/src/wcore.c \
	$(top_srcdir)/src/wdefaults.c \
	$(top_srcdir)/src/window.c \
	$(top_srcdir)/src/winmenu.c \
	$(top_srcdir)/src/winspector.c \
	$(top_srcdir)/src/wmspec.c \
	$(top_srcdir)/src/workspace.c \
	$(top_srcdir)/src/wsmap.c \
	$(top_srcdir)/src/xdnd.c \
	$(top_srcdir)/src/xinerama.c \
	$(top_srcdir)/src/xmodifier.c \
	$(top_srcdir)/src/xutil.c

SUFFIXES = .po .mo

.po.mo: 
	$(AM_V_GEN)$(MSGFMT) -c -o $@ $<


all-local: $(CATALOGS)


.PHONY: update-lang

if HAVE_XGETTEXT
update-lang: $(DOMAIN).pot
	$(AM_V_GEN)$(top_srcdir)/script/generate-po-from-template.sh \
	    -n "$(PACKAGE_NAME)" -v "$(PACKAGE_VERSION)" -b "$(PACKAGE_BUGREPORT)" \
	    -t "$(DOMAIN).pot"  "$(srcdir)/$(PO).po"

$(DOMAIN).pot: $(POTFILES)
	$(AM_V_GEN)$(XGETTEXT) --default-domain=$(DOMAIN) \
	    --add-comments --keyword=_ --keyword=N_ $(POTFILES)
	@if cmp -s $(DOMAIN).po $(DOMAIN).pot; then \
	    rm -f $(DOMAIN).po; \
	else \
	    mv -f $(DOMAIN).po $(DOMAIN).pot; \
	fi
endif


install-data-local:  $(CATALOGS)
	$(mkinstalldirs) $(DESTDIR)$(localedir)
	for n in $(CATALOGS) __DuMmY ; do \
		if test "$$n" -a "$$n" != "__DuMmY" ; then \
			l=`basename $$n .mo`; \
			$(mkinstalldirs) $(DESTDIR)$(localedir)/$$l/LC_MESSAGES; \
			$(INSTALL_DATA) -m 644 $$n $(DESTDIR)$(localedir)/$$l/LC_MESSAGES/$(DOMAIN).mo; \
		fi; \
	done

uninstall-local:
	for n in $(CATALOGS) ; do \
		l=`basename $$n .mo`; \
		rm -f $(DESTDIR)$(localedir)/$$l/LC_MESSAGES/$(DOMAIN).mo; \
	done

# Create a 'silent rule' for our make check the same way automake does
AM_V_CHKTRANS = $(am__v_CHKTRANS_$(V))
am__v_CHKTRANS_ = $(am__v_CHKTRANS_$(AM_DEFAULT_VERBOSITY))
am__v_CHKTRANS_0 = @echo "  CHK     translations" ;
am__v_CHKTRANS_1 =

# 'make check' will make sure the tranlation sources are in line with the compiled source
check-local:
	$(AM_V_CHKTRANS)$(top_srcdir)/script/check-translation-sources.sh \
		"$(srcdir)" -s "$(top_srcdir)/src/Makefile.am" -v wmaker_SOURCES
