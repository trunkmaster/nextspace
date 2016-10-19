#   -*-makefile-*-
#   source-distribution.make
#
#   Makefile rules to build snapshots from cvs, source .tar.gz etc
#
#   Copyright (C) 2000, 2001 Free Software Foundation, Inc.
#
#   Author: Adam Fedor <fedor@gnu.org>
#   Author: Nicola Pero <n.pero@mi.flashnet.it>
#  
#   This file is part of the GNUstep Makefile Package.
#
#   This library is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public License
#   as published by the Free Software Foundation; either version 3
#   of the License, or (at your option) any later version.
#   
#   You should have received a copy of the GNU General Public
#   License along with this library; see the file COPYING.
#   If not, write to the Free Software Foundation,
#   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

#
# Interesting variables to define in your GNUmakefile:
#
# PACKAGE_NAME = gnustep-base
# PACKAGE_VERSION = 1.0.0
#
# For SVN exports, you may want to define something like:
#
# SVN_MODULE_NAME = base
# SVN_BASE_URL = http://svn.gna.org/svn/gnustep/libs
#
# SVN_TAG_NAME is the same as SVN_MODULE_NAME if not set and is used to
# tag and retreive a module version
#
# For CVS exports, you may want to define something like:
#
# CVS_MODULE_NAME = base
# CVS_FLAGS = -d :pserver:anoncvs@subversions.gnu.org:/cvsroot/gnustep
#
# CVS_TAG_NAME is the same as CVS_MODULE_NAME if not set and is used to
# tag and retreive a module version
#
# You can also pass/override them on the command line if you want,
# make cvs-snapshot CVS_FLAGS="-d :pserver:anoncvs@subversions.gnu.org:/cvsroot/gnustep -z9"
#
# If you set the RELEASE_DIR variable, all generated .tar.gz files will 
# be automatically moved to that directory after having being created.
# RELEASE_DIR is either an absolute path, or a relative path to the 
# current directory.
#
#
# By default, .tar.gz archives will be created for distributions.
# You can change the compression mechanism used by setting COMPRESSION
# to any of the following variables - 
#
#  none (no compression used)
#  gzip (gzip, it's the default)
#  bzip2 (bzip2)
#
# For example, 'make dist COMPRESSION=bzip2' creates a .tar.bz2 for
# distribution.
#
#
# If you want to omit some files from the distribution archive, add a
# .dist-ignore file in the top-level directory of your package, listing
# all files (/directories) you want to exclude from distribution.
# CVS and .svn files are automatically excluded.
#

ifeq ($(CVS_MODULE_NAME),)
  CVS_MODULE_NAME = $(PACKAGE_NAME)
endif
ifeq ($(CVS_TAG_NAME),)
  CVS_TAG_NAME = $(CVS_MODULE_NAME)
endif

ifeq ($(CVS_FLAGS),)
  CVS_FLAGS = -z3
endif

ifeq ($(SVN_MODULE_NAME),)
  SVN_MODULE_NAME = $(PACKAGE_NAME)
endif
ifeq ($(SVN_TAG_NAME),)
  SVN_TAG_NAME = $(SVN_MODULE_NAME)
endif


# Set the cvs command we use.  Most of the times, this is 'cvs' and
# you need to do nothing.  But you can override 'cvs' with something
# else.  Useful for example when you need cvs to go through runsocks
# you can do make cvs-snapshot CVS='runsocks cvs'
ifeq ($(CVS),)
  CVS = cvs
endif
ifeq ($(SVN),)
  SVN = svn
endif

#
# You can set COMPRESSION_PROGRAM and COMPRESSION_EXT by hand if your 
# COMPRESSION type is not listed here.
#
# Otherwise, set COMPRESSION to '' or 'gzip' (for gzip), to 'none'
# (for no compression), to 'bzip2' (for bzip2), and
# COMPRESSION_PROGRAM, COMPRESSION_EXT is set for you.
#

ifeq ($(COMPRESSION_PROGRAM),)

ifeq ($(COMPRESSION), none)
  COMPRESSION_PROGRAM = cat
  COMPRESSION_EXT =
else 
ifeq ($(COMPRESSION), bzip2)
  COMPRESSION_PROGRAM = bzip2
  COMPRESSION_EXT = .bz2
else 
ifeq ($(COMPRESSION),)
  COMPRESSION_PROGRAM = gzip
  COMPRESSION_EXT = .gz
else 
ifeq ($(COMPRESSION), gzip)
  COMPRESSION_PROGRAM = gzip
  COMPRESSION_EXT = .gz
else
  $(warning "Unrecognized COMPRESSION - available are 'none', 'gzip', 'bzip2'")
  $(warning "Unrecognized COMPRESSION - using gzip")
  COMPRESSION_PROGRAM = gzip
  COMPRESSION_EXT = .gz
endif
endif
endif
endif

endif # COMPRESSION

# Due to peculiarities of some packaging systems or package distribution
# systems, we may want to permit customization of tarball version string.

ifeq ($(TARBALL_VERSION), )
TARBALL_VERSION := $(PACKAGE_VERSION)
endif

ifeq ($(TARBALL_VERSION_INCLUDE_SVN_REVISION), yes)
# Revision; potentially expensive so expand when used.
SVN_REVISION = $(shell svn info . | sed -ne 's/^Revision: //p')
TARBALL_VERSION := $(TARBALL_VERSION)~svn$(SVN_REVISION)
endif

ifeq ($(TARBALL_VERSION_INCLUDE_DATE_TIME), yes)
# Expand immediately; it should be constant in the script.
DATE_TIME_VERSION := $(shell date +%Y%m%d%H%M)
TARBALL_VERSION := $(TARBALL_VERSION)~date$(DATE_TIME_VERSION)
endif

VERSION_NAME = $(PACKAGE_NAME)-$(TARBALL_VERSION)

ARCHIVE_FILE = $(VERSION_NAME).tar$(COMPRESSION_EXT)

VERTAG = $(subst .,_,$(PACKAGE_VERSION))

.PHONY: dist cvs-tag cvs-dist cvs-snapshot internal-cvs-export svn-tag svn-tag-stable svn-dist svn-bugfix internal-svn-export svn-snapshot

#
# Build a .tar.gz with the whole directory tree
#
dist: distclean
	$(ECHO_NOTHING)echo "Generating $(ARCHIVE_FILE) in the parent directory..."; \
	SNAPSHOT_DIR=`basename $$(pwd)`; \
	if [ "$$SNAPSHOT_DIR" != "$(VERSION_NAME)" ]; then \
	  if [ -d "../$(VERSION_NAME)" ]; then \
	    echo "$(VERSION_NAME) already exists in parent directory (?):"; \
	    echo "Saving old version in $(VERSION_NAME)~"; \
	    mv ../$(VERSION_NAME) ../$(VERSION_NAME)~; \
	  fi; \
	  mkdir ../$(VERSION_NAME); \
	  $(TAR) cfX -  $(GNUSTEP_MAKEFILES)/tar-exclude-list . | (cd ../$(VERSION_NAME); $(TAR) xf -); \
	fi; \
	cd ..; \
	if [ -f $(ARCHIVE_FILE) ]; then             \
	  echo "$(ARCHIVE_FILE) already exists:";    \
	  echo "Saving old version in $(ARCHIVE_FILE)~"; \
	  mv $(ARCHIVE_FILE) $(ARCHIVE_FILE)~;    \
	fi; \
	if [ -f $(VERSION_NAME)/.dist-ignore ]; then \
	  $(TAR) cfX - $(VERSION_NAME)/.dist-ignore $(VERSION_NAME) \
	      | $(COMPRESSION_PROGRAM) > $(ARCHIVE_FILE); \
	else \
	  $(TAR) cf - $(VERSION_NAME) \
	      | $(COMPRESSION_PROGRAM) > $(ARCHIVE_FILE); \
	fi; \
	if [ "$$SNAPSHOT_DIR" != "$(VERSION_NAME)" ]; then \
	  rm -rf $(VERSION_NAME);               \
        fi; \
	if [ ! -f $(ARCHIVE_FILE) ]; then \
	  echo "*Error* creating .tar$(COMPRESSION_EXT) archive"; \
	  exit 1; \
	fi;$(END_ECHO)
ifneq ($(RELEASE_DIR),)
	$(ECHO_NOTHING)echo "Moving $(ARCHIVE_FILE) to $(RELEASE_DIR)..."; \
	if [ ! -d $(RELEASE_DIR) ]; then \
	  $(MKDIRS) $(RELEASE_DIR); \
	fi; \
	if [ -f $(RELEASE_DIR)/$(ARCHIVE_FILE) ]; then \
	  echo "$(RELEASE_DIR)/$(ARCHIVE_FILE) already exists:";    \
	  echo "Saving old version in $(RELEASE_DIR)/$(ARCHIVE_FILE)~";\
	  mv $(RELEASE_DIR)/$(ARCHIVE_FILE) \
	     $(RELEASE_DIR)/$(ARCHIVE_FILE)~;\
	fi; \
	mv ../$(ARCHIVE_FILE) $(RELEASE_DIR)$(END_ECHO)
endif

#
# Tag the SVN source with the $(SVN_TAG_NAME)-$(VERTAG) tag
#
svn-tag-stable:
	$(SVN) copy $(SVN_BASE_URL)/$(SVN_MODULE_NAME)/branches/stable $(SVN_BASE_URL)/$(SVN_MODULE_NAME)/tags/$(SVN_TAG_NAME)-$(VERTAG) -m "Tag version $(VERTAG)"

svn-tag:
	$(SVN) copy $(SVN_BASE_URL)/$(SVN_MODULE_NAME)/trunk $(SVN_BASE_URL)/$(SVN_MODULE_NAME)/tags/$(SVN_TAG_NAME)-$(VERTAG) -m "Tag version $(VERTAG)"

#
# Build a .tar.gz from the SVN sources using revision/tag 
# $(SVN_TAG_NAME)-$(VERTAG) as for a new release of the package.
#
svn-dist: EXPORT_SVN_URL = $(SVN_BASE_URL)/$(SVN_MODULE_NAME)/tags/$(SVN_TAG_NAME)-$(VERTAG) 
svn-dist: internal-svn-export

#
# Build a .tar.gz from the SVN source from the stable branch
# as a bugfix release.
#
svn-bugfix: EXPORT_SVN_URL = $(SVN_BASE_URL)/$(SVN_MODULE_NAME)/branches/stable
svn-bugfix: internal-svn-export

#
# Build a .tar.gz from the SVN source as they are now
#
svn-snapshot: EXPORT_SVN_URL = $(SVN_BASE_URL)/$(SVN_MODULE_NAME)/trunk
svn-snapshot: internal-svn-export

#
# Build a .tar.gz from the local SVN tree
#
svn-export: EXPORT_SVN_URL = .
svn-export: internal-svn-export

internal-svn-export:
	$(ECHO_NOTHING)echo "Exporting from module $(SVN_MODULE_NAME) on SVN..."; \
	if [ -e $(VERSION_NAME) ]; then \
	  echo "*Error* cannot export: $(VERSION_NAME) already exists"; \
	  exit 1; \
	fi; \
	$(SVN) export $(EXPORT_SVN_URL) $(VERSION_NAME); \
	echo "Generating $(ARCHIVE_FILE)"; \
	if [ -f $(ARCHIVE_FILE) ]; then            \
	  echo "$(ARCHIVE_FILE) already exists:";   \
	  echo "Saving old version in $(ARCHIVE_FILE)~"; \
	  mv $(ARCHIVE_FILE) $(ARCHIVE_FILE)~;    \
	fi; \
	if [ -f $(VERSION_NAME)/.dist-ignore ]; then \
	  $(TAR) cfX - $(VERSION_NAME)/.dist-ignore $(VERSION_NAME) \
	      | $(COMPRESSION_PROGRAM) > $(ARCHIVE_FILE); \
	else \
	  $(TAR) cf - $(VERSION_NAME) \
	      | $(COMPRESSION_PROGRAM) > $(ARCHIVE_FILE); \
	fi; \
	rm -rf $(VERSION_NAME);                  \
	if [ ! -f $(ARCHIVE_FILE) ]; then \
	  echo "*Error* creating .tar$(COMPRESSION_EXT) archive"; \
	  exit 1; \
	fi;$(END_ECHO)
ifneq ($(RELEASE_DIR),)
	$(ECHO_NOTHING)echo "Moving $(ARCHIVE_FILE) to $(RELEASE_DIR)..."; \
	if [ ! -d $(RELEASE_DIR) ]; then \
	  $(MKDIRS) $(RELEASE_DIR); \
	fi; \
	if [ -f $(RELEASE_DIR)/$(ARCHIVE_FILE) ]; then \
	  echo "$(RELEASE_DIR)/$(ARCHIVE_FILE) already exists:";    \
	  echo "Saving old version in $(RELEASE_DIR)/$(ARCHIVE_FILE)~";\
	  mv $(RELEASE_DIR)/$(ARCHIVE_FILE) \
	     $(RELEASE_DIR)/$(ARCHIVE_FILE)~;\
	fi; \
	mv $(ARCHIVE_FILE) $(RELEASE_DIR)$(END_ECHO)
endif

#
# Tag the CVS source with the $(CVS_TAG_NAME)-$(VERTAG) tag
#
cvs-tag:
	$(CVS) $(CVS_FLAGS) rtag $(CVS_TAG_NAME)-$(VERTAG) $(CVS_MODULE_NAME)

#
# Build a .tar.gz from the CVS sources using revision/tag 
# $(CVS_TAG_NAME)-$(VERTAG)
#
cvs-dist: EXPORT_CVS_FLAGS = -r $(CVS_TAG_NAME)-$(VERTAG) 
cvs-dist: internal-cvs-export

#
# Build a .tar.gz from the CVS source as they are now
#
cvs-snapshot: EXPORT_CVS_FLAGS = -D now
cvs-snapshot: internal-cvs-export

internal-cvs-export:
	$(ECHO_NOTHING)echo "Exporting from module $(CVS_MODULE_NAME) on CVS..."; \
	if [ -e $(CVS_MODULE_NAME) ]; then \
	  echo "*Error* cannot export: $(CVS_MODULE_NAME) already exists"; \
	  exit 1; \
	fi; \
	$(CVS) $(CVS_FLAGS) export $(EXPORT_CVS_FLAGS) $(CVS_MODULE_NAME); \
	echo "Generating $(ARCHIVE_FILE)"; \
	mv $(CVS_MODULE_NAME) $(VERSION_NAME); \
	if [ -f $(ARCHIVE_FILE) ]; then            \
	  echo "$(ARCHIVE_FILE) already exists:";   \
	  echo "Saving old version in $(ARCHIVE_FILE)~"; \
	  mv $(ARCHIVE_FILE) $(ARCHIVE_FILE)~;    \
	fi; \
	if [ -f $(VERSION_NAME)/.dist-ignore ]; then \
	  $(TAR) cfX - $(VERSION_NAME)/.dist-ignore $(VERSION_NAME) \
	      | $(COMPRESSION_PROGRAM) > $(ARCHIVE_FILE); \
	else \
	  $(TAR) cf - $(VERSION_NAME) \
	      | $(COMPRESSION_PROGRAM) > $(ARCHIVE_FILE); \
	fi; \
	rm -rf $(VERSION_NAME);                  \
	if [ ! -f $(ARCHIVE_FILE) ]; then \
	  echo "*Error* creating .tar$(COMPRESSION_EXT) archive"; \
	  exit 1; \
	fi;$(END_ECHO)
ifneq ($(RELEASE_DIR),)
	$(ECHO_NOTHING)echo "Moving $(ARCHIVE_FILE) to $(RELEASE_DIR)..."; \
	if [ ! -d $(RELEASE_DIR) ]; then \
	  $(MKDIRS) $(RELEASE_DIR); \
	fi; \
	if [ -f $(RELEASE_DIR)/$(ARCHIVE_FILE) ]; then \
	  echo "$(RELEASE_DIR)/$(ARCHIVE_FILE) already exists:";    \
	  echo "Saving old version in $(RELEASE_DIR)/$(ARCHIVE_FILE)~";\
	  mv $(RELEASE_DIR)/$(ARCHIVE_FILE) \
	     $(RELEASE_DIR)/$(ARCHIVE_FILE)~;\
	fi; \
	mv $(ARCHIVE_FILE) $(RELEASE_DIR)$(END_ECHO)
endif
