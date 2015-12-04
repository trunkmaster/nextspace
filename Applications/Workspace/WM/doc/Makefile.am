## Process this file with automake to produce Makefile.in

SUBDIRS = build @MANLANGDIRS@
DIST_SUBDIRS = build cs ru sk

dist_man_MANS = \
	geticonset.1 \
	getstyle.1 \
	get-wings-flags.1 \
	get-wraster-flags.1 \
	get-wutil-flags.1 \
	seticons.1 \
	setstyle.1 \
	upgrade-windowmaker-defaults.8 \
	wdread.1 \
	wdwrite.1 \
	WindowMaker.1 \
	wmagnify.1 \
	wmgenmenu.1 \
	wmiv.1 \
	wmmenugen.1 \
	WPrefs.1 \
	wxcopy.1 \
	wxpaste.1

man_MANS = \
	wmaker.1 \
	wmsetbg.1

MOSTLYCLEANFILES = wmaker.1 wmsetbg.1

EXTRA_DIST = wmaker.in wmsetbg.in

wmaker.1: wmaker.in Makefile $(top_builddir)/config.h
	$(AM_V_GEN)$(top_srcdir)/script/replace-ac-keywords.sh \
		--header "$(top_builddir)/config.h" --filter "HAVE_INOTIFY" \
		--filter "USE_ICCCM_WMREPLACE" \
		-D"sysconfdir=$(sysconfdir)" --replace "sysconfdir" \
		-D"pkgdatadir=$(pkgdatadir)" --replace "pkgdatadir" \
		-o "wmaker.1"  "$(srcdir)/wmaker.in"

wmsetbg.1: wmsetbg.in Makefile $(top_builddir)/config.h
	$(AM_V_GEN)$(top_srcdir)/script/replace-ac-keywords.sh \
		--header "$(top_builddir)/config.h" --filter "USE_XINERAMA" \
		-o "wmsetbg.1"  "$(srcdir)/wmsetbg.in"

# Create a 'silent rule' for our make check the same way automake does
AM_V_CHKOPTS = $(am__v_CHKOPTS_$(V))
am__v_CHKOPTS_  = $(am__v_CHKOPTS_$(AM_DEFAULT_VERBOSITY))
am__v_CHKOPTS_0 = @echo "  CHK      $@" ;
am__v_CHKOPTS_1 =

check-local: wmaker-args WPrefs-args wmagnify-args geticonset-args getstyle-args seticons-args setstyle-args \
	wdread-args wdwrite-args wmgenmenu-args wmiv-args wmmenugen-args wmsetbg-args wxcopy-args wxpaste-args

wmaker-args:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-cmdline-options-doc.sh \
		--program "$(top_builddir)/src/wmaker" --man-page "wmaker.1"

WPrefs-args:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-cmdline-options-doc.sh \
		--program "$(top_builddir)/WPrefs.app/WPrefs" --man-page "$(top_srcdir)/doc/WPrefs.1"

wmagnify-args:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-cmdline-options-doc.sh \
		--program "$(top_builddir)/util/wmagnify" --man-page "$(top_srcdir)/doc/wmagnify.1"

geticonset-args:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-cmdline-options-doc.sh \
		--program "$(top_builddir)/util/geticonset" --man-page "$(top_srcdir)/doc/geticonset.1"

getstyle-args:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-cmdline-options-doc.sh \
		--program "$(top_builddir)/util/getstyle" --man-page "$(top_srcdir)/doc/getstyle.1"

seticons-args:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-cmdline-options-doc.sh \
		--program "$(top_builddir)/util/seticons" --man-page "$(top_srcdir)/doc/seticons.1"

setstyle-args:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-cmdline-options-doc.sh \
		--program "$(top_builddir)/util/setstyle" --man-page "$(top_srcdir)/doc/setstyle.1"

wdread-args:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-cmdline-options-doc.sh \
		--program "$(top_builddir)/util/wdread" --man-page "$(top_srcdir)/doc/wdread.1"

wdwrite-args:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-cmdline-options-doc.sh \
		--program "$(top_builddir)/util/wdwrite" --man-page "$(top_srcdir)/doc/wdwrite.1"

wmgenmenu-args:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-cmdline-options-doc.sh \
		--program "$(top_builddir)/util/wmgenmenu" --man-page "$(top_srcdir)/doc/wmgenmenu.1"

wmiv-args:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-cmdline-options-doc.sh \
		--program "$(top_builddir)/util/wmiv" --man-page "$(top_srcdir)/doc/wmiv.1"

wmmenugen-args:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-cmdline-options-doc.sh \
		--program "$(top_builddir)/util/wmmenugen" --man-page "$(top_srcdir)/doc/wmmenugen.1"

wmsetbg-args:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-cmdline-options-doc.sh \
		--program "$(top_builddir)/util/wmsetbg" --man-page "wmsetbg.1"

wxcopy-args:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-cmdline-options-doc.sh \
		--program "$(top_builddir)/util/wxcopy" --man-page "$(top_srcdir)/doc/wxcopy.1"

wxpaste-args:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-cmdline-options-doc.sh \
		--program "$(top_builddir)/util/wxpaste" --man-page "$(top_srcdir)/doc/wxpaste.1"

.PHONY: wmaker-args WPrefs-args wmagnify-args geticonset-args getstyle-args seticons-args setstyle-args \
	wdread-args wdwrite-args wmgenmenu-args wmiv-args wmmenugen-args wmsetbg-args wxcopy-args wxpaste-args
