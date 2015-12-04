DOMAIN = WPrefs

CATALOGS = @WPREFSMOFILES@

CLEANFILES = $(DOMAIN).pot $(CATALOGS)

EXTRA_DIST = bg.po ca.po cs.po de.po es.po et.po fi.po fr.po fy.po hr.po hu.po \
	it.po ja.po ko.po nl.po pt.po ru.po sk.po uk.po zh_CN.po zh_TW.po

POTFILES  = \
	$(top_srcdir)/WPrefs.app/Appearance.c \
	$(top_srcdir)/WPrefs.app/Configurations.c \
	$(top_srcdir)/WPrefs.app/Docks.c \
	$(top_srcdir)/WPrefs.app/Expert.c \
	$(top_srcdir)/WPrefs.app/Focus.c \
	$(top_srcdir)/WPrefs.app/FontSimple.c \
	$(top_srcdir)/WPrefs.app/Icons.c \
	$(top_srcdir)/WPrefs.app/KeyboardShortcuts.c \
	$(top_srcdir)/WPrefs.app/Menu.c \
	$(top_srcdir)/WPrefs.app/MenuPreferences.c \
	$(top_srcdir)/WPrefs.app/MouseSettings.c \
	$(top_srcdir)/WPrefs.app/Paths.c \
	$(top_srcdir)/WPrefs.app/Preferences.c \
	$(top_srcdir)/WPrefs.app/TexturePanel.c \
	$(top_srcdir)/WPrefs.app/WPrefs.c \
	$(top_srcdir)/WPrefs.app/WindowHandling.c \
	$(top_srcdir)/WPrefs.app/Workspace.c \
	$(top_srcdir)/WPrefs.app/double.c \
	$(top_srcdir)/WPrefs.app/editmenu.c \
	$(top_srcdir)/WPrefs.app/main.c \
	$(top_srcdir)/WPrefs.app/xmodifier.c

# not_yet_fully_implemented
#	$(top_srcdir)/WPrefs.app/KeyboardSettings.c \
#	$(top_srcdir)/WPrefs.app/Themes.c \
#

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
		"$(srcdir)" -s "$(top_srcdir)/WPrefs.app/Makefile.am"
