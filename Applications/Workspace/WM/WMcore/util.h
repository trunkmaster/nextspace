/* WUtil / error.h
 *
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
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
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

/* ---[ WINGs/misc.c ]--------------------------------------------------- */
typedef struct {
    int position;
    int count;
} WMRange;

WMRange wmkrange(int start, int count);

/* An application must call this function before exiting, to let WUtil do some internal cleanup */
void wutil_shutdown(void);
/* ---[ WINGs/usleep.c ]-------------------------------------------------- */

void wusleep(unsigned int usec);

#endif
