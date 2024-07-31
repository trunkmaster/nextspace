
include $(GNUSTEP_MAKEFILES)/common.make

GNUSTEP_INSTALLATION_DOMAIN = SYSTEM

PACKAGE_NAME = libwraster
CLIBRARY_NAME = libwraster
VERSION = 7.0.1

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
	save_jpeg.c	\
	save_png.c	\
	save_xpm.c	\
	xutil.c		\
	load_ppm.c

libwraster_HEADER_FILES_INSTALL_DIR = .
libwraster_HEADER_FILES = wraster.h


-include GNUmakefile.config
ifdef USE_GIF
libwraster_C_FILES += load_gif.c
ADDITIONAL_LDFLAGS += -lgif
endif

ifdef USE_JPEG
libwraster_C_FILES += load_jpeg.c
endif

ifdef USE_PNG
libwraster_C_FILES += load_png.c
ADDITIONAL_LDFLAGS += -lpng
endif

ifdef USE_TIFF
libwraster_C_FILES += load_tiff.c
ADDITIONAL_LDFLAGS += -ltiff
endif

ifdef USE_XPM
libwraster_C_FILES += load_xpm.c
ADDITIONAL_LDFLAGS += -lXpm
else
libwraster_C_FILES += load_xpm_normalized.c
endif

ifdef USE_WEBP
libwraster_C_FILES += load_webp.c
ADDITIONAL_LDFLAGS += -lwebp
endif

ifdef USE_MAGICK
libwraster_C_FILES += load_magick.c
ADDITIONAL_CFLAGS += $(MAGICK_INCLUDES)
ADDITIONAL_LDFLAGS += $(MAGICK_LIBS) -lGraphicsMagickWand
endif

#ADDITIONAL_CFLAGS = -D_XOPEN_SOURCE=600 -D_GNU_SOURCE -Wall -Wextra -Wno-sign-compare -Wno-deprecated -Wno-deprecated-declarations -MT -MD -MP
ADDITIONAL_LDFLAGS += -ljpeg -lX11 -lXext -lXmu -lm

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/clibrary.make
-include GNUmakefile.postamble
