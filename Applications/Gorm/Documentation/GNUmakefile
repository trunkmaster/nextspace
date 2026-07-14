PACKAGE_NAME = gorm
include $(GNUSTEP_MAKEFILES)/common.make

include ../Version

# The application to be compiled
DOCUMENT_NAME = Gorm

DOCUMENT_TEXT_NAME = README NEWS INSTALL ANNOUNCE

# The texinfo source files to be used
Gorm_TEXI_FILES = install.texi news.texi Gorm.texi announce.texi

ANNOUNCE_TEXI_FILES = version.texi
ANNOUNCE_TEXT_MAIN = announce.texi

README_TEXI_FILES = version.texi
README_TEXT_MAIN = readme.texi

INSTALL_TEXI_FILES = version.texi
INSTALL_TEXT_MAIN = install.texi

NEWS_TEXI_FILES = version.texi
NEWS_TEXT_MAIN = news.texi

-include Makefile.preamble

-include GNUmakefile.local

include $(GNUSTEP_MAKEFILES)/documentation.make

-include Makefile.postamble
