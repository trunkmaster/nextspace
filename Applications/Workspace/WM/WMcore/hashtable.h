/* ---[ WINGs/hashtable.c ]----------------------------------------------- */

#ifndef _WHASHTABLE_H_
#define _WHASHTABLE_H_

#include <X11/Xlib.h>

/* DO NOT ACCESS THE CONTENTS OF THIS STRUCT */
typedef struct {
    void *table;
    void *nextItem;
    int index;
} WMHashEnumerator;

typedef struct W_HashTable WMHashTable;

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

#endif
