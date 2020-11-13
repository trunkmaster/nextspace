/* WUtil.h
 *
 *  Copyright (c) 1998 scottc
 *  Copyright (c) 1999-2004 Dan Pascu
 *  Copyright (c) 1999-2000 Alfredo K. Kojima
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef _WUTIL_H_
#define _WUTIL_H_

#include <X11/Xlib.h>
#include <limits.h>
#include <sys/types.h>

#ifndef WMAX
# define WMAX(a,b)	((a)>(b) ? (a) : (b))
#endif
#ifndef WMIN
# define WMIN(a,b)	((a)<(b) ? (a) : (b))
#endif

#ifndef __GNUC__
#define  __attribute__(x)  /*NOTHING*/
#endif

#ifdef NDEBUG

#define wassertr(expr)  \
	if (!(expr)) { return; }

#define wassertrv(expr, val)  \
	if (!(expr)) { return (val); }

#else /* !NDEBUG */

#define wassertr(expr) \
    if (!(expr)) { \
        wwarning("wassertr: assertion %s failed", #expr); \
        return;\
    }

#define wassertrv(expr, val) \
    if (!(expr)) { \
        wwarning("wassertrv: assertion %s failed", #expr); \
        return (val);\
    }

#endif /* !NDEBUG */


#ifdef static_assert
# define _wutil_static_assert(check, message) static_assert(check, message)
#else
# ifdef __STDC_VERSION__
#  if __STDC_VERSION__ >= 201112L
/*
 * Ideally, we would like to include <assert.h> to have 'static_assert'
 * properly defined, but as we have to be sure about portability and
 * because we're a public header we can't count on 'configure' to tell
 * us about availability, so we use the raw C11 keyword
 */
#   define _wutil_static_assert(check, message) _Static_assert(check, message)
#  else
#   define _wutil_static_assert(check, message) /**/
#  endif
# else
#  define _wutil_static_assert(check, message) /**/
# endif
#endif


/* #ifdef __cplusplus */
/* extern "C" { */
/* #endif /\* __cplusplus *\/ */

/* Notificaions */
  
/* Arrays and bags */
enum {
    WBNotFound = INT_MIN, /* element was not found in WMBag   */
    WANotFound = -1       /* element was not found in WMArray */
};

/* extern struct W_Array WMArray; */
/* typedef struct W_Bag WMBag; */


typedef struct W_UserDefaults WMUserDefaults;

/* Some typedefs for the handler stuff */
typedef void *WMHandlerID;
typedef void WMCallback(void *data);
typedef void WMInputProc(int fd, int mask, void *clientData);

typedef void WMFreeDataProc(void *data);
typedef int WMCompareDataProc(const void *item1, const void *item2);
/* Used by WMBag or WMArray for matching data */
typedef int WMMatchDataProc(const void *item, const void *cdata);

/* ---[ Macros ]---------------------------------------------------------- */

#define wlengthof(array)                                                \
  ({                                                                    \
    _wutil_static_assert(sizeof(array) > sizeof(array[0]),              \
                         "the macro 'wlengthof' cannot be used on pointers, only on known size arrays"); \
    sizeof(array) / sizeof(array[0]);                                   \
  })


/* ---[ WINGs/error.c ]--------------------------------------------------- */

enum {
	WMESSAGE_TYPE_MESSAGE,
	WMESSAGE_TYPE_WARNING,
	WMESSAGE_TYPE_ERROR,
	WMESSAGE_TYPE_FATAL
};

/* #define wmessage(fmt, args...) __wmessage( __func__, __FILE__, __LINE__, WMESSAGE_TYPE_MESSAGE, fmt, ## args) */
#define wwarning(fmt, args...) __wmessage( __func__, __FILE__, __LINE__, WMESSAGE_TYPE_WARNING, fmt, ## args)
#define werror(fmt, args...) __wmessage( __func__, __FILE__, __LINE__, WMESSAGE_TYPE_ERROR, fmt, ## args)
#define wfatal(fmt, args...) __wmessage( __func__, __FILE__, __LINE__, WMESSAGE_TYPE_FATAL, fmt, ## args)

void __wmessage(const char *func, const char *file, int line, int type, const char *msg, ...)
	__attribute__((__format__(printf,5,6)));

/*-------------------------------------------------------------------------*/

/* Global variables */
extern int WCErrorCode;

/*-------------------------------------------------------------------------*/

/* #ifdef __cplusplus */
/* } */
/* #endif /\* __cplusplus *\/ */


#endif
