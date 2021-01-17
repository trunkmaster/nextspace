/*
 *  Workspace window manager
 *  Copyright (c) 2015- Sergii Stoian
 *
 *  WINGs library (Window Maker)
 *  Copyright (c) 1998 scottc
 *  Copyright (c) 1999-2004 Dan Pascu
 *  Copyright (c) 1999-2000 Alfredo K. Kojima
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

#ifndef __WORKSPACE_WM_WHASHTABLE__
#define __WORKSPACE_WM_WHASHTABLE__

#include <X11/Xlib.h>

/* DO NOT ACCESS THE CONTENTS OF THIS STRUCT */
typedef struct {
  void *table;
  void *nextItem;
  int  index;
} WMHashEnumerator;

typedef struct WMHashTable WMHashTable;

typedef struct {
  /* NULL is pointer hash */
  unsigned 	(*hash)(const void *);
  /* NULL is pointer compare */
  Bool	(*keyIsEqual)(const void *, const void *);
  /* NULL does nothing */
  void*	(*retainKey)(const void *);
  /* NULL does nothing */
  void	(*releaseKey)(const void *);
} WMHashTableCallbacks;

WMHashTable* WMCreateHashTable(const WMHashTableCallbacks callbacks);

void WMFreeHashTable(WMHashTable *table);

void WMResetHashTable(WMHashTable *table);

unsigned WMCountHashTable(WMHashTable *table);

void* WMHashGet(WMHashTable *table, const void *key);

/* Returns True if there is a value associated with <key> in the table, in
 * which case <retKey> and <retItem> will contain the item's internal key
 * address and the item's value respectively.
 * If there is no value associated with <key> it will return False and in
 * this case <retKey> and <retItem> will be undefined.
 * Use this when you need to perform your own custom retain/release mechanism
 * which requires access to the keys too.
 */
Bool WMHashGetItemAndKey(WMHashTable *table, const void *key,
                         void **retItem, void **retKey);

/* put data in table, replacing already existing data and returning
 * the old value */
void* WMHashInsert(WMHashTable *table, const void *key, const void *data);

void WMHashRemove(WMHashTable *table, const void *key);

/* warning: do not manipulate the table while using the enumerator functions */
WMHashEnumerator WMEnumerateHashTable(WMHashTable *table);

void* WMNextHashEnumeratorItem(WMHashEnumerator *enumerator);

void* WMNextHashEnumeratorKey(WMHashEnumerator *enumerator);

/* Returns True if there is a next element, in which case key and item
 * will contain the next element's key and value respectively.
 * If there is no next element available it will return False and in this
 * case key and item will be undefined.
 */
Bool WMNextHashEnumeratorItemAndKey(WMHashEnumerator *enumerator,
                                    void **item, void **key);

/* some predefined callback sets */

extern const WMHashTableCallbacks WMIntHashCallbacks;
/* sizeof(keys) are <= sizeof(void*) */

extern const WMHashTableCallbacks WMStringHashCallbacks;
/* keys are strings. Strings will be copied with wstrdup()
 * and freed with wfree() */

extern const WMHashTableCallbacks WMStringPointerHashCallbacks;
/* keys are strings, but they are not copied */

#endif /* __WORKSPACE_WM_WHASHTABLE__ */
