
include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

PACKAGE_NAME = libwraster
CLIBRARY_NAME = libwraster
VERSION = 5.0.0

libwraster_C_FILES =	\
	raster.c 	\
	alpha_combine.c \
	draw.c		\
	color.c		\
	load.c 		\
	save.c		\
	gradient.c 	\
	xpixmap.c	\
	convert.c 	\
	context.c 	\
	misc.c 		\
	scale.c		\
	rotate.c	\
	flip.c		\
	convolve.c	\
	save_xpm.c	\
	xutil.c		\
	load_ppm.c

libwraster_HEADER_FILES_INSTALL_DIR = .
libwraster_HEADER_FILES = wraster.h

#if USE_GIF
libwraster_C_FILES += load_gif.c
#endif

#if USE_JPEG
libwraster_C_FILES += load_jpeg.c
#endif

#if USE_PNG
libwraster_C_FILES += load_png.c
#endif

#if USE_TIFF
libwraster_C_FILES += load_tiff.c
#endif

#if USE_XPM
libwraster_C_FILES += load_xpm.c
#else
#libwraster_C_FILES += load_xpm_normalized.c
#endif

#if USE_WEBP
#libwraster_C_FILES += load_webp.c
#endif

#if USE_MAGICK
#libwraster_C_FILES += load_magick.c
#endif

#ADDITIONAL_CFLAGS = -D_XOPEN_SOURCE=600 -D_GNU_SOURCE -Wall -Wextra -Wno-sign-compare -Wno-deprecated -Wno-deprecated-declarations -MT -MD -MP
ADDITIONAL_LDFLAGS = -lXpm -lpng -ljpeg -lgif -ltiff -lX11 -lXext -lXmu -lm

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/clibrary.make
-include GNUmakefile.postamble

before-all::
	@ cd cmake; ${CMAKE} . -DCMAKE_C_COMPILER=clang

after-clean::
	@ rm -rf cmake/CMakeFiles
	@ rm -f cmake/CMakeCache.txt
	@ rm -f cmake/Makefile
	@ rm -f cmake/cmake_install.cmake
	@ rm -f config.h
