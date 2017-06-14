/* config.h.  Generated from config.h.in by configure.  */
/* config.h.in.  Generated from configure.ac by autoheader.  */

/* Define to 1 if you have the <bsd/string.h> header file. */
/* #undef HAVE_BSD_STRING_H */

/* Define to 1 if you have the <ctype.h> header file. */
#define HAVE_CTYPE_H 1

/* Define to 1 if you have the `dgettext' function. */
/* #undef HAVE_DGETTEXT */

/* Define to 1 if you have the <dlfcn.h> header file. */
#define HAVE_DLFCN_H 1

/* Define to 1 if you don't have `vprintf' but do have `_doprnt.' */
/* #undef HAVE_DOPRNT */

/* Define if EXIF can be used */
#define HAVE_EXIF 1

/* Define to 1 if you have the <fcntl.h> header file. */
#define HAVE_FCNTL_H 1

/* Defined if the 'float'-typed math function are available (sinf, cosf) */
#define HAVE_FLOAT_MATHFUNC 1

/* Define to 1 if you have the `gethostname' function. */
#define HAVE_GETHOSTNAME 1

/* Define to 1 if you have the `gettext' function. */
/* #undef HAVE_GETTEXT */

/* Check for inotify */
#define HAVE_INOTIFY 1

/* Define to 1 if you have the <inttypes.h> header file. */
#define HAVE_INTTYPES_H 1

/* Define to 1 if you have the <libintl.h> header file. */
#define HAVE_LIBINTL_H 1

/* Define to 1 if you have the <limits.h> header file. */
#define HAVE_LIMITS_H 1

/* Define to 1 if you have the `mallinfo' function. */
#define HAVE_MALLINFO 1

/* Define to 1 if you have the <malloc.h> header file. */
#define HAVE_MALLOC_H 1

/* Define to 1 if you have the <memory.h> header file. */
#define HAVE_MEMORY_H 1

/* Define to 1 if you have the `mkstemp' function. */
#define HAVE_MKSTEMP 1

/* Define to 1 if you have the `poll' function. */
#define HAVE_POLL 1

/* Define to 1 if you have the <poll.h> header file. */
#define HAVE_POLL_H 1

/* Define if you have POSIX threads libraries and header files. */
#define HAVE_PTHREAD 1

/* Have PTHREAD_PRIO_INHERIT. */
#define HAVE_PTHREAD_PRIO_INHERIT 1

/* defined when GNU's secure_getenv function is available */
#define HAVE_SECURE_GETENV 1

/* Define to 1 if you have the `select' function. */
#define HAVE_SELECT 1

/* Define to 1 if you have the `setsid' function. */
#define HAVE_SETSID 1

/* Define to 1 if you have the <stdint.h> header file. */
#define HAVE_STDINT_H 1

/* Define to 1 if you have the <stdlib.h> header file. */
#define HAVE_STDLIB_H 1

/* Defined if header "stdnoreturn.h" exists, it defines ISO C11 attribute
   'noreturn' and it works */
#define HAVE_STDNORETURN 1

/* Define to 1 if you have the `strcasecmp' function. */
#define HAVE_STRCASECMP 1

/* Define to 1 if you have the <strings.h> header file. */
#define HAVE_STRINGS_H 1

/* Define to 1 if you have the <string.h> header file. */
#define HAVE_STRING_H 1

/* Define if strlcpy is available */
/* #undef HAVE_STRLCAT */

/* Define to 1 if you have the `strncasecmp' function. */
#define HAVE_STRNCASECMP 1

/* Define to 1 if you have the `sysconf' function. */
#define HAVE_SYSCONF 1

/* Check for syslog */
#define HAVE_SYSLOG 1

/* Define to 1 if you have the <syslog.h> header file. */
#define HAVE_SYSLOG_H 1

/* Define to 1 if you have the <sys/inotify.h> header file. */
#define HAVE_SYS_INOTIFY_H 1

/* Define to 1 if you have the <sys/ioctl.h> header file. */
#define HAVE_SYS_IOCTL_H 1

/* Define to 1 if you have the <sys/stat.h> header file. */
#define HAVE_SYS_STAT_H 1

/* Define to 1 if you have the <sys/types.h> header file. */
#define HAVE_SYS_TYPES_H 1

/* Define to 1 if you have <sys/wait.h> that is POSIX.1 compatible. */
#define HAVE_SYS_WAIT_H 1

/* Define to 1 if you have the <unistd.h> header file. */
#define HAVE_UNISTD_H 1

/* Define to 1 if you have the `vprintf' function. */
#define HAVE_VPRINTF 1

/* define if your X server has XConvertCase() (set by configure) */
#define HAVE_XCONVERTCASE 1

/* define if your X server has XInternAtoms() (set by configure) */
#define HAVE_XINTERNATOMS 1

/* Internationalization (I18N) support (set by configure) */
/* #undef I18N */

/* Define to the sub-directory in which libtool stores uninstalled libraries.
   */
#define LT_OBJDIR ".libs/"

/* gettext domain to be used for menu translations */
/* #undef MENU_TEXTDOMAIN */

/* defined by configure if the attribute is not defined on your platform */
/* #undef O_NOFOLLOW */

/* Name of package */
#define PACKAGE "WindowMaker"

/* Define to the address where bug reports for this package should be sent. */
#define PACKAGE_BUGREPORT "wmaker-dev@lists.windowmaker.org"

/* Define to the full name of this package. */
#define PACKAGE_NAME "WindowMaker"

/* Define to the full name and version of this package. */
#define PACKAGE_STRING "WindowMaker 0.95.7"

/* Define to the one symbol short name of this package. */
#define PACKAGE_TARNAME "WindowMaker"

/* Define to the home page for this package. */
#define PACKAGE_URL "http://www.windowmaker.org/"

/* Define to the version of this package. */
#define PACKAGE_VERSION "0.95.7"

/* Define to necessary symbol if this constant uses a non-standard name on
   your system. */
/* #undef PTHREAD_CREATE_JOINABLE */

/* Define as the return type of signal handlers (`int' or `void') */
#define RETSIGTYPE void

/* defined when the Solaris Xinerama extension was detected */
/* #undef SOLARIS_XINERAMA */

/* Define to 1 if you have the ANSI C header files. */
#define STDC_HEADERS 1

/* Define to 1 if you can safely include both <sys/time.h> and <time.h>. */
#define TIME_WITH_SYS_TIME 1

/* define if you want user defined menus for applications */
/* #undef USER_MENU */

/* Defined when user did not request to disable animations */
#define USE_ANIMATIONS 1

/* Define if Boehm GC is to be used */
/* #undef USE_BOEHM_GC */

/* whether Drag-and-Drop on the dock should be enabled */
#define USE_DOCK_XDND 1

/* defined when valid GIF library with header was found */
#define USE_GIF 4

/* define to support ICCCM protocol for window manager replacement */
/* #undef USE_ICCCM_WMREPLACE */

/* defined when valid JPEG library with header was found */
#define USE_JPEG 1

/* defined when MagickWand library with header was found */
/* #undef USE_MAGICK */

/* Defined when used did not request to disable Motif WM hints */
#define USE_MWM_HINTS 1

/* Define if Pango is to be used */
/* #undef USE_PANGO */

/* defined when valid PNG library with header was found */
#define USE_PNG 1

/* defined when valid RandR library with header was found */
#define USE_RANDR 1

/* defined when valid TIFF library with header was found */
#define USE_TIFF 1

/* defined when valid Webp library with header was found */
/* #undef USE_WEBP */

/* defined when usable Xinerama library with header was found */
#define USE_XINERAMA 1

/* defined when valid XPM library with header was found */
#define USE_XPM 1

/* defined when valid XShape library with header was found */
#define USE_XSHAPE 1

/* defined when valid XShm library with header was found */
#define USE_XSHM 1

/* Version number of package */
#define VERSION "0.95.7"

/* Defines how to access the value of Pi */
#define WM_PI (M_PI)

/* whether XKB language MODELOCK should be enabled */
/* #undef XKB_MODELOCK */

/* Define to 1 if the X Window System is missing or not being used. */
/* #undef X_DISPLAY_MISSING */

/* defined if the locale is initialized by X window */
/* #undef X_LOCALE */

/* Define to empty if `const' does not conform to ANSI C. */
/* #undef const */

/* Define to `__inline__' or `__inline' if that's what the C compiler
   calls it, or to nothing if 'inline' is not supported under any name.  */
#ifndef __cplusplus
/* #undef inline */
#endif

/* Defines the attribute to tell the compiler that a function never returns,
   if the ISO C11 attribute does not work */
/* #undef noreturn */

/* Define to `int' if <sys/types.h> does not define. */
/* #undef pid_t */

/* Define to `unsigned int' if <sys/types.h> does not define. */
/* #undef size_t */

#include "config-paths.h"
