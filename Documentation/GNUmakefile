#
# This GNUmakefile needs to build the gnustep-make documentation.
#

# The GNUmakefile itself is written using gnustep-make.  If we find an
# existing gnustep-make installation, we use it.  Otherwise, we
# configure, compile and install gnustep-make into a temporary
# subdirectory, then we use that copy.

# In the very unlikely event that gnustep-make does not even install
# on your machine, please get a pre-generated copy of the
# documentation from the internet!  Or just read the documentation in
# source format. :-)

# As a special case, if gnustep-make has been configured (GNUstep.conf exists)
# in the enclosing directory, and has not yet been installed (GNUSTEP_MAKEFILES
# is not defined), we attempt to use the uninstalled version.
# 
# As all makefile fragments in the source tree are positioned relative to
# each other in the same way they're installed, this works fine.
#
# If future changes happen to introduce different behaviour between the
# makefile fragments in the source tree and installed ones (which is not
# a trivial change), this strategy has to be reviewed.  One possible solution
# then is to install make into a temporary directory (DESTDIR?) first, then to
# use these.
#

ifeq ($(GNUSTEP_MAKEFILES),)
  ifeq ($(wildcard ../GNUstep.conf),../GNUstep.conf)
    GNUSTEP_MAKEFILES=..
  endif
endif

ifeq ($(GNUSTEP_MAKEFILES),)

# We have no gnustep-make installation to use.  We need gnustep-make
# to generate the documentation.

# To help lazy cows who want to type 'make' and have all work
# automatically without installating gnustep-make first, if we don't
# have a gnustep-make installation to use, we create a temporary one
# in the subdirectory ./tmp-installation, the run make again passing
# GNUSTEP_MAKEFILES set to point to the new makefile installation

CURRENT_DIR = $(shell pwd)

# To execute all, or clean, we first depend on a local
# temporary installation of gnustep-make; when we have it, we source
# GNUstep.sh, then we run the make command again.
all regenerate: ./tmp-installation/System/Library/Makefiles
	@echo "** Running 'make $@' using the local/temporary gnustep-make installation **"
	$(MAKE) $@ GNUSTEP_MAKEFILES="$(CURRENT_DIR)/tmp-installation/System/Library/Makefiles"
	@echo "** Finished local/temporary documentation in $(CURRENT_DIR)/tmp-installation. **"
	@echo "** Use an installed gnustep-make if you wish to install documentation. **"

clean: ./tmp-installation/System/Library/Makefiles
	$(MAKE) $@ GNUSTEP_MAKEFILES="$(CURRENT_DIR)/tmp-installation/System/Library/Makefiles"

install:
	@echo "** To install the documentation you first install/set-up gnustep-make **"

# This creates a local temporary installation of GNUstep-make
./tmp-installation/System/Library/Makefiles:
	@echo "** No gnustep-make installation found, attempting to create a local/temporary one. **"
	(mkdir tmp-build; \
	cd tmp-build; \
	../../configure --prefix="$(CURRENT_DIR)/tmp-installation" \
			--with-layout=gnustep \
	                --with-config-file="$(CURRENT_DIR)/tmp-installation/GNUstep.conf"; \
	make; \
	make install)

distclean:
	-(if [ -f ./tmp-installation/System/Library/Makefiles/common.make ]; then \
	  $(MAKE) $@ GNUSTEP_MAKEFILES="$(CURRENT_DIR)/tmp-installation/System/Library/Makefiles"; \
	fi)
	rm -Rf tmp-installation tmp-build

else

# We have a gnustep-make installation to use.  The following is a
# normal gnustep-make GNUmakefile for documentation.

# We normally install into System
GNUSTEP_INSTALLATION_DOMAIN = LOCAL

include $(GNUSTEP_MAKEFILES)/common.make

# The documents to be generated

# We should prefix everything with 'gnustep' because we generate info
# files that we then put into the standard info directories, and we
# don't want those to conflict with info files from other packages!
DOCUMENT_NAME = gnustep-howto gnustep-faq gnustep-filesystem gnustep-internals gnustep-make gnustep-userfaq

# The text documents to be generated
DOCUMENT_TEXT_NAME = INSTALL README NEWS RELEASENOTES ANNOUNCE

TOP_DOC_FILES = INSTALL README NEWS RELEASENOTES ANNOUNCE
README_FILES = README.Darwin README.MinGWOnCygwin README.Cygwin \
	README.MinGW


GNUstep-HOWTO_TEXI_FILES = version.texi
GNUstep-HOWTO_TEXT_MAIN = gnustep-howto.texi
GNUstep-HOWTO_DOC_INSTALL_DIR = User/GNUstep/

FAQ_TEXI_FILES = version.texi
FAQ_TEXT_MAIN = gnustep-faq.texi
FAQ_DOC_INSTALL_DIR = User/GNUstep/

gnustep-make_TEXI_FILES = \
gnustep-make.texi
gnustep-make_DOC_INSTALL_DIR = Developer/Make/Manual/

gnustep-faq_TEXI_FILES = \
gnustep-faq.texi \
version.texi
gnustep-faq_DOC_INSTALL_DIR = User/GNUstep/

gnustep-userfaq_TEXI_FILES = \
gnustep-userfaq.texi \
version.texi
gnustep-userfaq_DOC_INSTALL_DIR = User/GNUstep/

gnustep-filesystem_TEXI_FILES = \
gnustep-filesystem.texi
gnustep-filesystem_DOC_INSTALL_DIR = User/GNUstep/

gnustep-machines_TEXI_FILES = \
gnustep-machines.texi 
gnustep-machines_DOC_INSTALL_DIR = User/GNUstep/

gnustep-howto_TEXI_FILES = \
gnustep-howto.texi \
version.texi
gnustep-howto_DOC_INSTALL_DIR = User/GNUstep/

gnustep-internals_LATEX_FILES = \
gnustep-internals.tex
gnustep-internals_DOC_INSTALL_DIR = Developer/Make/Manual/Internals/

INSTALL_TEXI_FILES = version.texi
INSTALL_TEXT_MAIN = install.texi
INSTALL_DOC_INSTALL_DIR = Developer/Make/ReleaseNotes/$(GNUSTEP_MAKE_VERSION)

NEWS_TEXI_FILES = version.texi
NEWS_TEXT_MAIN = news.texi
NEWS_DOC_INSTALL_DIR = Developer/Make/ReleaseNotes/$(GNUSTEP_MAKE_VERSION)

RELEASENOTES_TEXI_FILES = version.texi
RELEASENOTES_TEXT_MAIN = releasenotes.texi
RELEASENOTES_DOC_INSTALL_DIR = Developer/Make/ReleaseNotes

README_TEXI_FILES = version.texi
README_TEXT_MAIN = readme.texi
README_DOC_INSTALL_DIR = Developer/Make/ReleaseNotes/$(GNUSTEP_MAKE_VERSION)

ANNOUNCE_TEXI_FILES = version.texi
ANNOUNCE_TEXT_MAIN = announce.texi
ANNOUNCE_DOC_INSTALL_DIR = Developer/Make/ReleaseNotes/$(GNUSTEP_MAKE_VERSION)

# The manpages are now installed when gnustep-make itself is installed.

include $(GNUSTEP_MAKEFILES)/documentation.make

include ../Version

# Typing 'make regenerate' should build all, then install the files
# top-level.  This is mostly for making gnustep-make releases.
regenerate: all
	mv -f $(TOP_DOC_FILES) ..

# Generate the version.texi file from the Version of gnustep-make.
version.texi: ../Version
	rm -f version.texi
	echo '@set GNUSTEP-MAKE-VERSION' $(GNUSTEP_MAKE_VERSION) \
	 > version.texi

after-install:: $(GNUSTEP_DOC)/Developer/Make/Manual $(GNUSTEP_DOC)/User/GNUstep
	$(INSTALL_DATA) DESIGN $(GNUSTEP_DOC)/Developer/Make/Manual
	for file in $(README_FILES); do \
	  $(INSTALL_DATA) $$file $(GNUSTEP_DOC)/User/GNUstep/$$file; \
	done

#  Uninstall manually man pages
after-uninstall::
	rm -f $(GNUSTEP_DOC)/Developer/Make/Manual/DESIGN

after-clean::
	rm -rf tmp-build tmp-installation

after-distclean::
	rm -f version.texi

endif
