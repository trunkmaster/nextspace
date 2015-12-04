DOMAIN = WINGs

CATALOGS = @WINGSMOFILES@

CLEANFILES = $(CATALOGS) $(DOMAIN).pot

EXTRA_DIST = bg.po ca.po cs.po de.po fr.po fy.po hu.po nl.po sk.po

# WUtil files:
POTFILES  = \
	$(top_srcdir)/WINGs/array.c \
	$(top_srcdir)/WINGs/bagtree.c \
	$(top_srcdir)/WINGs/data.c \
	$(top_srcdir)/WINGs/error.c \
	$(top_srcdir)/WINGs/findfile.c \
	$(top_srcdir)/WINGs/handlers.c \
	$(top_srcdir)/WINGs/hashtable.c \
	$(top_srcdir)/WINGs/memory.c \
	$(top_srcdir)/WINGs/menuparser.c \
	$(top_srcdir)/WINGs/menuparser_macros.c \
	$(top_srcdir)/WINGs/misc.c \
	$(top_srcdir)/WINGs/notification.c \
	$(top_srcdir)/WINGs/proplist.c \
	$(top_srcdir)/WINGs/string.c \
	$(top_srcdir)/WINGs/tree.c \
	$(top_srcdir)/WINGs/userdefaults.c \
	$(top_srcdir)/WINGs/usleep.c \
	$(top_srcdir)/WINGs/wapplication.c \
	$(top_srcdir)/WINGs/wutil.c

# WINGs files:
POTFILES += \
	$(top_srcdir)/WINGs/configuration.c \
	$(top_srcdir)/WINGs/dragcommon.c \
	$(top_srcdir)/WINGs/dragdestination.c \
	$(top_srcdir)/WINGs/dragsource.c \
	$(top_srcdir)/WINGs/selection.c \
	$(top_srcdir)/WINGs/wappresource.c \
	$(top_srcdir)/WINGs/wballoon.c \
	$(top_srcdir)/WINGs/wbox.c \
	$(top_srcdir)/WINGs/wbrowser.c \
	$(top_srcdir)/WINGs/wbutton.c \
	$(top_srcdir)/WINGs/wcolor.c \
	$(top_srcdir)/WINGs/wcolorpanel.c \
	$(top_srcdir)/WINGs/wcolorwell.c \
	$(top_srcdir)/WINGs/wevent.c \
	$(top_srcdir)/WINGs/wfilepanel.c \
	$(top_srcdir)/WINGs/wframe.c \
	$(top_srcdir)/WINGs/wfont.c \
	$(top_srcdir)/WINGs/wfontpanel.c \
	$(top_srcdir)/WINGs/widgets.c \
	$(top_srcdir)/WINGs/winputmethod.c \
	$(top_srcdir)/WINGs/wlabel.c \
	$(top_srcdir)/WINGs/wlist.c \
	$(top_srcdir)/WINGs/wmenuitem.c \
	$(top_srcdir)/WINGs/wmisc.c \
	$(top_srcdir)/WINGs/wpanel.c \
	$(top_srcdir)/WINGs/wpixmap.c \
	$(top_srcdir)/WINGs/wpopupbutton.c \
	$(top_srcdir)/WINGs/wprogressindicator.c \
	$(top_srcdir)/WINGs/wruler.c \
	$(top_srcdir)/WINGs/wscroller.c \
	$(top_srcdir)/WINGs/wscrollview.c \
	$(top_srcdir)/WINGs/wslider.c \
	$(top_srcdir)/WINGs/wsplitview.c \
	$(top_srcdir)/WINGs/wtabview.c \
	$(top_srcdir)/WINGs/wtext.c \
	$(top_srcdir)/WINGs/wtextfield.c \
	$(top_srcdir)/WINGs/wview.c \
	$(top_srcdir)/WINGs/wwindow.c

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
		"$(srcdir)" -s "$(top_srcdir)/WINGs/Makefile.am"
