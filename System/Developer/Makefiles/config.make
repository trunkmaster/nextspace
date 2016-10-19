#
#   config.make.in
#
#   The settings required by the makefile package that are determined
#   by configure and that depend on the platform.  There might be
#   multiple of those files installed in different platform-specific
#   directories.  Global settings that are common to all platforms
#   should go in config-noarch.make.in instead.
#
#   Copyright (C) 1997-2006 Free Software Foundation, Inc.
#
#   Author:  Scott Christley <scottc@net-community.com>
#   Author:  Ovidiu Predescu <ovidiu@net-community.com>
#   Author:  Nicola Pero <n.pero@mi.flashnet.it>
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

MAKE_WITH_INFO_FUNCTION = yes

#
# Binary and compile tools
#

# Ignore the default CC=cc used by GNU make when nothing is specified;
# in that case, we want to use our own default CC.
ifeq ($(origin CC), default)
  CC       = clang
endif

# If CC is already set but not from the GNU make default (ie, in the
# environment), don't override it but use the provided compiler.  This
# makes it easier to swap C/ObjC compilers on the fly.
ifeq ($(CC),)
  CC       = clang
endif

# Ignore the default CXX=g++ used by GNU make when nothing is specified;
# in that case, we want to use our own default CXX.
ifeq ($(origin CXX), default)
  CXX       = clang++
endif

# If CXX is already set but not from the GNU make default (ie, in the
# environment), don't override it but use the provided compiler.  This
# makes it easier to swap C++/ObjC++ compilers on the fly.
ifeq ($(CXX),)
  CXX       = clang++
endif

# TODO: Because of the following, OPTFLAG usually ends up being '-g
# -O2'.  The '-g' is fairly harmless as you can always use strip=yes
# which will strip the object files upon installation; still, it's not
# very elegant since -g is already added elsewhere for debug=yes, and
# it ends up appearing twice in the gcc command-line.
OPTFLAG  = -g -O2
OBJCFLAGS= 
OBJC_LIB_FLAG = 
CPPFLAGS = 
CPP      = clang -E
CCFLAGS  = -g -O2

# If the 'debug' variable is not specified on the command-line or in
# the environment, we set it to the GNUSTEP_DEFAULT_DEBUG value.  This
# is normally 'no,', but can be changed to 'yes' when gnustep-make is
# configured.
GNUSTEP_DEFAULT_DEBUG = yes

ifeq ($(OBJC_RUNTIME_LIB), gnugc)
  ifeq ($(OBJC_LIB_FLAG),)
    OBJC_LIB_FLAG = -lobjc_gc
  endif
else
  ifeq ($(OBJC_LIB_FLAG),)
    OBJC_LIB_FLAG = -lobjc
  endif
endif

EXEEXT = 
OEXT   = .o
LIBEXT = .a

LN_S = ln -s

# This is the best we can do given the current autoconf, which only
# returns LN_S
ifeq ($(LN_S), ln -s)
  HAS_LN_S = yes
else
  HAS_LN_S = no
endif

# Special case - on mingw32, autoconf sets LN_S to 'ln -s', but then
# that does a recursive copy (ie, cp -r).
ifeq (linux-gnu,mingw32)
  HAS_LN_S = no
endif

# This is used to remove an existing symlink before creating a new
# one.  We don't trust 'ln -s -f' as it's unportable so we remove
# manually the existing symlink (if any) before creating a new one.
# If symlinks are supported on the platform, RM_LN_S is just 'rm -f';
# if they are not, we assume they are copies (like cp -r) and we go
# heavy-handed with 'rm -Rf'.  Note - this code might need rechecking
# for the case where LN_S = 'ln', if that ever happens on some
# platforms (it shouldn't cause any problems, but checking is good).
ifeq ($(HAS_LN_S), yes)
  RM_LN_S = rm -f
  LN_S_RECURSIVE = $(LN_S)
  FRAMEWORK_VERSION_SUPPORT = yes
else
  RM_LN_S = rm -Rf
  # When symlinks are not available, using LN_S (which is set to 'cp -p')
  # doesn't work on directories.  So every time you want to do the
  # equivalent of 'ln -s' on directories, you need to use 
  # LN_S_RECURSIVE instead of LN_S.  
  LN_S_RECURSIVE = cp -pR
  FRAMEWORK_VERSION_SUPPORT = no
endif

LD = $(CC)
LDOUT =
LDFLAGS =  

AR      = ar
AROUT   =
ARFLAGS = rc
RANLIB  = ranlib

DLLTOOL = 

# NB: These variables are defined here only so that they can be
# overridden on the command line (so you can type 'AWK=mawk make' to
# use a different awk for that particular run of make).  We should
# *NOT* set them to the full path of these tools at configure time,
# because otherwise when you change/update the tools you would need to
# reconfigure and reinstall gnustep-make!  We can normally assume that
# typing 'awk' and 'sed' on the command line cause the preferred awk
# and sed programs on the system to be used.  Hardcoding the full path
# (or the name) of the specific awk or sed program on this sytem here
# would make it lot more inflexible.  In other words, the following
# definitions should remain like in 'AWK = awk' on all systems.
AWK             = awk
SED             = sed
YACC            = yacc
BISON           = bison
FLEX            = flex
LEX             = lex
CHOWN           = chown
STRIP           = strip

INSTALL		= /bin/install -c -p
INSTALL_PROGRAM	= ${INSTALL}
INSTALL_DATA	= ${INSTALL} -m 644
TAR		= gtar
MAKE		= gmake
MKDIRS		= $(GNUSTEP_MAKEFILES)/mkinstalldirs

LATEX2HTML      = 

# Darwin specific flags
CC_CPPPRECOMP  = yes
CC_BUNDLE      = yes
CC_GNURUNTIME  = 

# Backend bundle
BACKEND_BUNDLE=yes

#
# Do threading stuff.
#
# Warning - the base library's configure.in will extract the thread
# flags from the following line using grep/sed - so if you change the
# following lines you *need* to update the base library configure.in
# too.
#
ifndef objc_threaded
  objc_threaded:=
endif

# Any user specified libs
CONFIG_SYSTEM_INCL=
CONFIG_SYSTEM_LIBS = 
CONFIG_SYSTEM_LIB_DIR = 

#
# Whether the GCC compiler on solaris supports the -shared flag for
# linking libraries.
#
SOLARIS_SHARED = yes

#
# Whether the C/ObjC/C++ compiler supports auto-dependencies
# (generating dependencies of the object files from the include files
# used to compile them) via -MMD -MP flags
#
AUTO_DEPENDENCIES = yes

#
# Whether the ObjC compiler supports native ObjC exceptions via
# @try/@catch/@finally/@throw.
#
USE_OBJC_EXCEPTIONS = yes

#
# Whether the ObjC compiler supports -fobjc-nonfragile-abi
#
USE_NONFRAGILE_ABI = yes

#
# Whether we are using the ObjC garbage cllection library.
#
OBJC_WITH_GC = no

#
# Whether the compiler is GCC with precompiled header support
#
GCC_WITH_PRECOMPILED_HEADERS = yes

#
# Whether the install_name for dynamic libraries on darwin should
# be an absolute path.
#
GNUSTEP_ABSOLUTE_INSTALL_PATHS = 

#
# Whether to use -r or -Wl,-r when doing partial linking
#
OBJ_MERGE_CMD_FLAG = -Wl,-r
