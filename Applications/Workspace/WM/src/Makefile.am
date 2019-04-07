AUTOMAKE_OPTIONS =

BUILT_SOURCES = wconfig.h

bin_PROGRAMS = wmaker

EXTRA_DIST = 

wmaker_SOURCES = 	\
	GNUstep.h \
	WindowMaker.h \
	actions.c \
	actions.h \
	appicon.c \
	appicon.h \
	application.c \
	application.h \
	appmenu.c \
	appmenu.h \
	balloon.c \
	balloon.h \
	client.c \
	client.h \
	colormap.c \
	colormap.h \
	cycling.c \
	cycling.h \
	def_pixmaps.h \
	defaults.c \
	defaults.h \
	dialog.c \
	dialog.h \
	dock.c \
	dockedapp.c \
	dockedapp.h \
	dock.h \
	event.c \
	event.h \
	extend_pixmaps.h \
	framewin.c \
	framewin.h \
	geomview.c \
	geomview.h \
	osdep.h \
	icon.c \
	icon.h \
	keybind.h \
	main.c \
	main.h \
	menu.c \
	menu.h \
	misc.h \
	monitor.c \
	monitor.h \
	moveres.c \
	pixmap.c \
	pixmap.h \
	placement.c \
	placement.h \
	properties.c \
	properties.h \
	resources.c \
	resources.h \
	rootmenu.c \
	rootmenu.h \
	screen.c \
	screen.h \
	session.h \
	session.c \
	shutdown.h \
	shutdown.c \
	switchpanel.c \
	switchpanel.h \
	stacking.c \
	stacking.h \
	startup.c \
	startup.h \
	superfluous.c \
	superfluous.h \
	switchmenu.c \
	switchmenu.h \
	texture.c \
	texture.h \
	usermenu.c \
	usermenu.h \
	xdnd.h \
	xinerama.h \
	xinerama.c \
	xmodifier.h \
	xutil.c \
	xutil.h \
	wconfig.h \
	wcore.c \
	wcore.h \
	wdefaults.c \
	wdefaults.h \
	window.c \
	window.h \
	winmenu.c \
	winmenu.h \
	winspector.h \
	winspector.c \
	wmspec.h \
	wmspec.c \
	workspace.c \
	workspace.h \
	wsmap.c \
	wsmap.h

if USE_DOCK_XDND
wmaker_SOURCES += xdnd.c
endif
if USE_MWM_HINTS
wmaker_SOURCES += motif.h motif.c
endif

if WM_OSDEP_BSD
wmaker_SOURCES += osdep_bsd.c
endif
if WM_OSDEP_DARWIN
wmaker_SOURCES += osdep_darwin.c
endif
if WM_OSDEP_LINUX
wmaker_SOURCES += osdep_linux.c
endif
if WM_OSDEP_GENERIC
wmaker_SOURCES += osdep_stub.c
endif

if USE_NESTED_FUNC
wmaker_SOURCES += misc.c \
	xmodifier.c
else
nodist_wmaker_SOURCES = misc.hack_nf.c \
	xmodifier.hack_nf.c

CLEANFILES = $(nodist_wmaker_SOURCES)

misc.hack_nf.c: misc.c $(top_srcdir)/script/nested-func-to-macro.sh
	$(AM_V_GEN)$(top_srcdir)/script/nested-func-to-macro.sh \
		$(srcdir)/misc.c -o $(builddir)/misc.hack_nf.c \
		-f "append_string" -f "append_modifier"

xmodifier.hack_nf.c: xmodifier.c $(top_srcdir)/script/nested-func-to-macro.sh
	$(AM_V_GEN)$(top_srcdir)/script/nested-func-to-macro.sh \
		$(srcdir)/xmodifier.c -o $(builddir)/xmodifier.hack_nf.c \
		-f "modwarn" -f "modbarf" -f "check_modifier" -f "store_modifier"
endif


AM_CFLAGS =

AM_CPPFLAGS = $(DFLAGS) \
	-I$(top_srcdir)/wrlib \
	-I$(top_srcdir)/WINGs @HEADER_SEARCH_PATH@ 


wmaker_LDADD = \
	$(top_builddir)/WINGs/libWINGs.la\
	$(top_builddir)/WINGs/libWUtil.la\
	$(top_builddir)/wrlib/libwraster.la\
	@XLFLAGS@ \
	@LIBXRANDR@ \
	@LIBXINERAMA@ \
	@XLIBS@ \
	@LIBM@ \
	@INTLIBS@

######################################################################

# Create a 'silent rule' for our make check the same way automake does
AM_V_CHKOPTS = $(am__v_CHKOPTS_$(V))
am__v_CHKOPTS_  = $(am__v_CHKOPTS_$(AM_DEFAULT_VERBOSITY))
am__v_CHKOPTS_0 = @echo "  CHK      $@" ;
am__v_CHKOPTS_1 =

check-local: defaults-callbacks-static defaults-callbacks-dynamic

# Check that the callback functions used to load the configuration match
# the type of the variable where the value will be stored
defaults-callbacks-static:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-wmaker-loaddef-callbacks.sh  \
		--source "$(srcdir)/defaults.c" --structure "staticOptionList"  \
		--field-value-ptr 4 --field-callback 5  \
		--struct-def "wPreferences=$(srcdir)/WindowMaker.h"  \
		--callback "getBool=char, getEnum=char, getInt=int"  \
		--callback "getModMask=int"

defaults-callbacks-dynamic:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-wmaker-loaddef-callbacks.sh  \
		--source "$(srcdir)/defaults.c" --structure "optionList"  \
		--field-value-ptr 4 --field-callback 5  \
		--struct-def "wPreferences=$(srcdir)/WindowMaker.h"  \
		--struct-def "legacy_minipreview_config=$(srcdir)/defaults.c"  \
		--callback "getBool=char, getEnum=char, getInt=int"  \
		--callback "getPathList=char*, getCoord=WCoord"
