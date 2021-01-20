/*
 *  Workspace window manager
 *  Copyright (c) 2015-2021 Sergii Stoian
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

#include "WM.h"

#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <time.h>

#ifdef HAVE_STDNORETURN
#include <stdnoreturn.h>
#endif

#include <CoreFoundation/CoreFoundation.h>
#include <CoreFoundation/CFLogUtilities.h>

#include "util.h"
#include "log_utils.h"
#include "wscreen.h"
#include "whashtable.h"

/* ---[ emergency exit ]------------------------------------------------------*/
typedef void waborthandler(int);
waborthandler *wsetabort(waborthandler* handler);

static void defaultHandler(int bla)
{
  if (bla)
    kill(getpid(), SIGABRT);
  else
    exit(1);
}

static waborthandler *aborthandler = defaultHandler;

static inline noreturn void wAbort(int bla)
{
  (*aborthandler)(bla);
  exit(-1);
}

waborthandler *wsetabort(waborthandler *handler)
{
  waborthandler *old = aborthandler;

  aborthandler = handler;

  return old;
}

/* ---[ memory handling ]-----------------------------------------------------*/

/* if we're in the middle of an emergency exit */
static int Aborting = 0;
static WMHashTable *table = NULL;
void *wmalloc(size_t size)
{
  void *tmp;

  assert(size > 0);

  tmp = malloc(size);

  if (tmp == NULL) {
    WMLogWarning("malloc() failed. Retrying after 2s.");
    sleep(2);
    tmp = malloc(size);
    if (tmp == NULL) {
      if (Aborting) {
        fputs("Really Bad Error: recursive malloc() failure.", stderr);
        exit(-1);
      } else {
        WMLogCritical("virtual memory exhausted");
        Aborting = 1;
        wAbort(False);
      }
    }
  }
  memset(tmp, 0, size);
  return tmp;
}
void *wrealloc(void *ptr, size_t newsize)
{
  void *nptr;

  if (!ptr) {
    nptr = wmalloc(newsize);
  } else if (newsize == 0) {
    wfree(ptr);
    nptr = NULL;
  } else {
    nptr = realloc(ptr, newsize);
    if (nptr == NULL) {
      WMLogWarning("realloc() failed. Retrying after 2s.");
      sleep(2);
      nptr = realloc(ptr, newsize);
      if (nptr == NULL) {
        if (Aborting) {
          fputs("Really Bad Error: recursive realloc() failure.", stderr);
          exit(-1);
        } else {
          WMLogCritical("virtual memory exhausted");
          Aborting = 1;
          wAbort(False);
        }
      }
    }
  }
  return nptr;
}
void *wretain(void *ptr)
{
  int *refcount;

  if (!table) {
    table = WMCreateHashTable(WMIntHashCallbacks);
  }

  refcount = WMHashGet(table, ptr);
  if (!refcount) {
    refcount = wmalloc(sizeof(int));
    *refcount = 1;
    WMHashInsert(table, ptr, refcount);
#ifdef VERBOSE
    printf("== %i (%p)\n", *refcount, ptr);
#endif
  } else {
    (*refcount)++;
#ifdef VERBOSE
    printf("+ %i (%p)\n", *refcount, ptr);
#endif
  }

  return ptr;
}
void wrelease(void *ptr)
{
  int *refcount;

  refcount = WMHashGet(table, ptr);
  if (!refcount) {
    WMLogWarning("trying to release unexisting data %p", ptr);
  } else {
    (*refcount)--;
    if (*refcount < 1) {
#ifdef VERBOSE
      printf("RELEASING %p\n", ptr);
#endif
      WMHashRemove(table, ptr);
      wfree(refcount);
      wfree(ptr);
    }
#ifdef VERBOSE
    else {
      printf("- %i (%p)\n", *refcount, ptr);
    }
#endif
  }
}
void wfree(void *ptr)
{
  if (ptr)
    free(ptr);
  ptr = NULL;
}

void wusleep(unsigned int usec)
{
  struct timespec tm;

  /* An arbitrary limit of 10 minutes -- in WM, if
   * somethings wants to sleep anything even close to
   * this, it's most likely an error.
   */
  if (usec > 600000000)
    return;

  tm.tv_sec = usec / 1000000;
  tm.tv_nsec = (usec % 1000000) * 1000;

  while (nanosleep(&tm, &tm) == -1 && errno == EINTR)
    ;

}
