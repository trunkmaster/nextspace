/*
 *  Workspace window manager
 *  Copyright (c) 2015- Sergii Stoian
 *
 *  WINGs library (Window Maker)
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
 *  Copyright (c) 2001 Dan Pascu
 *  Copyright (c) 2014 Window Maker Team
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
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 *  MA 02110-1301, USA.
 */

#ifndef __WORKSPACE_WM_CORE_UTIL__
#define __WORKSPACE_WM_CORE_UTIL__

#include <sys/types.h>

#ifdef HAVE_SYSLOG_H
/* Function to cleanly close the syslog stuff, called by wutil_shutdown from user side */
void w_syslog_close(void);
#endif

/* ---[ WINGs/memory.c ]-------------------------------------------------- */

void *wmalloc(size_t size);
void *wrealloc(void *ptr, size_t newsize);
void *wretain(void *ptr);
void wrelease(void *ptr);
void wfree(void *ptr);

/* ---[ WINGs/error.c ]--------------------------------------------------- */
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFLogUtilities.h>

enum {
  WMESSAGE_TYPE_MESSAGE,
  WMESSAGE_TYPE_WARNING,
  WMESSAGE_TYPE_ERROR,
  WMESSAGE_TYPE_FATAL
};

/* #define wmessage(fmt, args...) __wmessage( __func__, __FILE__, __LINE__, WMESSAGE_TYPE_MESSAGE, fmt, ## args) */
/* #define wwarning(fmt, args...) __wmessage( __func__, __FILE__, __LINE__, WMESSAGE_TYPE_WARNING, fmt, ## args) */
/* #define werror(fmt, args...) __wmessage( __func__, __FILE__, __LINE__, WMESSAGE_TYPE_ERROR, fmt, ## args) */
/* #define wfatal(fmt, args...) __wmessage( __func__, __FILE__, __LINE__, WMESSAGE_TYPE_FATAL, fmt, ## args) */
/* void __wmessage(const char *func, const char *file, int line, int type, const char *msg, ...) __attribute__((__format__(printf,5,6))); */

#define wwarning(fmt, args...) CFLog(kCFLogLevelWarning, CFSTR(fmt), ## args)
#define werror(fmt, args...) CFLog(kCFLogLevelError, CFSTR(fmt), ## args)
/* #define werror(fmt, args...) \ */
/*   CFLog(kCFLogLevelError, CFSTR("** [%s:%s] %s"), __FILE__, __LINE__, fmt, ## args) */

#define wfatal(fmt, args...) CFLog(kCFLogLevelCritical, CFSTR(fmt), ## args)

/* An application must call this function before exiting, to let WUtil do some internal cleanup */
void wutil_shutdown(void);

/* ---[ WINGs/usleep.c ]-------------------------------------------------- */

void wusleep(unsigned int usec);

#endif /* __WORKSPACE_WM_CORE_UTIL__ */
