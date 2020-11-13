/*
 *  Window Maker miscelaneous function library
 *
 *  Copyright (c) 1997-2003 Alfredo K. Kojima
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

#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <signal.h>

#include "wconfig.h"
#include "WMcore.h"
#include "memory.h"
#include "hashtable.h"

#ifdef HAVE_STDNORETURN
#include <stdnoreturn.h>
#endif

#ifndef False
# define False 0
#endif
#ifndef True
# define True 1
#endif

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

static int Aborting = 0;	/* if we're in the middle of an emergency exit */

static WMHashTable *table = NULL;

void *wmalloc(size_t size)
{
  void *tmp;

  assert(size > 0);

  tmp = malloc(size);

  if (tmp == NULL) {
    wwarning("malloc() failed. Retrying after 2s.");
    sleep(2);
    tmp = malloc(size);
    if (tmp == NULL) {
      if (Aborting) {
        fputs("Really Bad Error: recursive malloc() failure.", stderr);
        exit(-1);
      } else {
        wfatal("virtual memory exhausted");
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
      wwarning("realloc() failed. Retrying after 2s.");
      sleep(2);
      nptr = realloc(ptr, newsize);
      if (nptr == NULL) {
        if (Aborting) {
          fputs("Really Bad Error: recursive realloc() failure.", stderr);
          exit(-1);
        } else {
          wfatal("virtual memory exhausted");
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

void wfree(void *ptr)
{
  if (ptr)
    free(ptr);
  ptr = NULL;
}

void wrelease(void *ptr)
{
  int *refcount;

  refcount = WMHashGet(table, ptr);
  if (!refcount) {
    wwarning("trying to release unexisting data %p", ptr);
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
