## Process this file with automake to produce Makefile.in

AUTOMAKE_OPTIONS =

BUILT_SOURCES = config-paths.h

DISTCLEANFILES = config-paths.h

config.h: config-paths.h

config-paths.h: Makefile
	@echo "Generating $@"
	@echo '/* this is a generated file - do not edit */' > $@
	@echo '' >> $@
	@echo '/* define where the translations are stored */' >> $@
	@echo '#define LOCALEDIR "$(localedir)"' >> $@
	@echo '' >> $@
	@echo '/* define an extra path for pixmaps */' >> $@
	@echo '#define PIXMAPDIR "$(pixmapdir)"' >> $@
	@echo '' >> $@
	@echo '/* where shared data is stored */' >> $@
	@echo '#define PKGDATADIR "$(datadir)/WindowMaker"' >> $@
	@echo '' >> $@
	@echo '/* where the configuration is stored */' >> $@
	@echo '#define SYSCONFDIR "$(sysconfdir)"' >> $@

ACLOCAL_AMFLAGS = -I m4

# Improve coverage in 'make distcheck' by checking that translations work
AM_DISTCHECK_CONFIGURE_FLAGS = --enable-silent-rules LINGUAS='*'


SUBDIRS = wrlib WINGs src util po WindowMaker wmlib WPrefs.app doc
DIST_SUBDIRS = $(SUBDIRS) test

EXTRA_DIST = TODO BUGS BUGFORM FAQ INSTALL \
	INSTALL-WMAKER README.i18n README.definable-cursor \
	The-perfect-Window-Maker-patch.txt \
	README COPYING.WTFPL autogen.sh \
	email-clients.txt checkpatch.pl update-changelog.pl \
	script/check-cmdline-options-doc.sh \
	script/check-translation-sources.sh \
	script/check-wmaker-loaddef-callbacks.sh \
	script/generate-mapfile-from-header.sh \
	script/generate-po-from-template.sh \
	script/generate-txt-from-texi.sh \
	script/nested-func-to-macro.sh \
	script/replace-ac-keywords.sh


.PHONY:	coverage-reset coverage

if USE_LCOV
coverage-reset:
	find . -type f -name '*.gcda' -exec rm -f '{}' ';'
	lcov --directory . --zerocounters

coverage:
	rm -rf coverage @lcov_output_directory@
	-mkdir -p coverage @lcov_output_directory@
	lcov --compat-libtool --capture --directory . --output-file coverage/coverage.info
	genhtml --output-directory @lcov_output_directory@ coverage/coverage.info
endif

# make update-lang PO=<lang>
# ==========================
# Update the PO files against the POT file in all the translation sub-directories
#
# We do not use an automatic recursive target from Automake (AM_EXTRA_RECURSIVE_TARGETS)
# because we want to check only once that the variable PO was defined; the added bonus
# being that we do not process all directories but only the related ones, which is
# faster and a lot less verbose

update-lang:
if HAVE_XGETTEXT
	@if echo "$(PO)" | grep -v '^[a-z][a-z]\(_[A-Z][A-Z]\)\?$$' > /dev/null ; then \
	  echo "Error: invalid value \"$(PO)\" for update-lang, use PO=<lang>" >&2 ; exit 1 ; \
	fi ; \
	for subdir in $(SUBDIRS_PO); do \
	  ($(am__cd) $$subdir && $(MAKE) $(AM_MAKEFLAGS) update-lang || exit $$?); \
	done

SUBDIRS_PO = WINGs/po po util/po WPrefs.app/po
else
	@echo "Error: the program 'xgettext' was not found by configure, it is mandatory for this operation" >&2 ; exit 1
endif

.PHONY: update-lang

# Create a 'silent-rule' for our make check the same way automake does
AM_V_CHKOPTS = $(am__v_CHKOPTS_$(V))
am__v_CHKOPTS_  = $(am__v_CHKOPTS_$(AM_DEFAULT_VERBOSITY))
am__v_CHKOPTS_0 = @echo "  CHK      $@" ;
am__v_CHKOPTS_1 =

check-local: configure-documentation

configure-documentation:
	$(AM_V_CHKOPTS)$(top_srcdir)/script/check-cmdline-options-doc.sh \
		--program "$(top_srcdir)/configure" --text-doc "$(top_srcdir)/INSTALL-WMAKER" \
		--ignore-prg 'with-PACKAGE,without-PACKAGE # only template names from Autoconf' \
		--ignore-prg 'program-prefix,program-suffix,program-transform-name # in INSTALL' \
		--ignore-prg 'version,quiet,srcdir,build,host,cache-file,no-create # in INSTALL' \
		--ignore-prg 'enable-silent-rules,disable-silent-rules # should be in INSTALL' \
		--ignore-prg 'enable-dependency-tracking,disable-dependency-tracking # in INSTALL' \
		--ignore-prg 'enable-shared,enable-static # should be in INSTALL' \
		--ignore-prg 'disable-option-checking,enable-fast-install # should be in INSTALL' \
		--ignore-prg 'disable-libtool-lock,with-pic,with-gnu-ld,with-sysroot # for libtool' \
		--ignore-prg 'with-x # no use, it would not work without X'

.PHONY: configure-documentation
