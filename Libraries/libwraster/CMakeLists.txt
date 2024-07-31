cmake_minimum_required(VERSION 3.15)

project(libwraster
  VERSION 7.0.1
  LANGUAGES C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# source directory is a cmake subdir - TODO
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake/modules/")

include(CheckIncludeFiles)
include(CheckFunctionExists)
include(CheckSymbolExists)

check_include_files("math.h" HAVE_MATH_H)
if (HAVE_MATH_H)
  set(CMAKE_REQUIRED_LIBRARIES "-lm")
  check_function_exists(atan HAVE_ATAN) # -lm
  check_function_exists(sqrt HAVE_SQRT) # -lm
  check_function_exists(cosf HAVE_COSF) # -lm
  check_function_exists(sinf HAVE_SINF) # -lm
  check_function_exists(powf HAVE_POWF) # -lm
  if (HAVE_ATAN AND HAVE_SQRT AND HAVE_COSF AND HAVE_SINF AND HAVE_POWF)
    set(HAVE_FLOAT_MATHFUNC 1)
  endif()
  check_symbol_exists(M_PI "math.h" HAVE_M_PI)
  if (HAVE_M_PI)
    set(WM_PI 1)
    set(M_PI_VALUE "(M_PI)")
  endif()
endif()

check_include_files("stdnoreturn.h" HAVE_STDNORETURN)

check_include_files("stdio.h;jpeglib.h" USE_JPEG)

find_package(GraphicsMagick COMPONENTS MagickWand)
if (GraphicsMagick_FOUND)
  set(USE_MAGICK 1)
  set(MAGICK_INCLUDES -I${GraphicsMagick_INCLUDE_DIRS})
  set(MAGICK_LIBS -l${GraphicsMagick_LIBRARIES})
endif()

check_include_files("png.h" USE_PNG)

check_include_files("gif_lib.h" HAVE_GIF)
if (HAVE_GIF)
  set(CMAKE_REQUIRED_LIBRARIES "-lgif")
  check_function_exists(DGifOpenFileName USE_GIF)
endif()

check_include_files("tiff.h;tiffio.h" HAVE_TIFF)
if (HAVE_TIFF)
  set(CMAKE_REQUIRED_LIBRARIES "-ltiff")
  check_function_exists(TIFFOpen USE_TIFF)
endif()

check_include_files("webp/decode.h" USE_WEBP)

check_include_files("X11/Xlib.h;X11/extensions/XShm.h" HAVE_XSHM)
if (HAVE_XSHM)
  set(CMAKE_REQUIRED_LIBRARIES "-lX11 -lXext")
  check_function_exists(XShmAttach USE_XSHM)
endif()
check_include_files("X11/xpm.h" USE_XPM)

configure_file(cmake/config.h.in ../config.h)
configure_file(cmake/GNUmakefile.config.in ../GNUmakefile.config @ONLY)
