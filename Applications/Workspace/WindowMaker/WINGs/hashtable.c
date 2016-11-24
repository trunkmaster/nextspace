#include <config.h>

#include <sys/types.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#include "WUtil.h"

#define INITIAL_CAPACITY	23


typedef struct HashItem {
	const void *key;
	const void *data;

	struct HashItem *next;	/* collided item list */
} HashItem;

typedef struct W_HashTable {
	WMHashTableCallbacks callbacks;

	unsigned itemCount;
	unsigned size;		/* table size */

	HashItem **table;
} HashTable;

#define HASH(table, key)  (((table)->callbacks.hash ? \
    (*(table)->callbacks.hash)(key) : hashPtr(key)) % (table)->size)

#define DUPKEY(table, key) ((table)->callbacks.retainKey ? \
    (*(table)->callbacks.retainKey)(key) : (key))

#define RELKEY(table, key) if ((table)->callbacks.releaseKey) \
    (*(table)->callbacks.releaseKey)(key)

static inline unsigned hashString(const void *param)
{
	const char *key = param;
	unsigned ret = 0;
	unsigned ctr = 0;

	while (*key) {
		ret ^= *key++ << ctr;
		ctr = (ctr + 1) % sizeof(char *);
	}

	return ret;
}

static inline unsigned hashPtr(const void *key)
{
	return ((size_t) key / sizeof(char *));
}

static void rellocateItem(WMHashTable * table, HashItem * item)
{
	unsigned h;

	h = HASH(table, item->key);

	item->next = table->table[h];
	table->table[h] = item;
}

static void rebuildTable(WMHashTable * table)
{
	HashItem *next;
	HashItem **oldArray;
	int i;
	int oldSize;
	int newSize;

	oldArray = table->table;
	oldSize = table->size;

	newSize = table->size * 2;

	table->table = wmalloc(sizeof(char *) * newSize);
	table->size = newSize;

	for (i = 0; i < oldSize; i++) {
		while (oldArray[i] != NULL) {
			next = oldArray[i]->next;
			rellocateItem(table, oldArray[i]);
			oldArray[i] = next;
		}
	}
	wfree(oldArray);
}

WMHashTable *WMCreateHashTable(const WMHashTableCallbacks callbacks)
{
	HashTable *table;

	table = wmalloc(sizeof(HashTable));

	table->callbacks = callbacks;

	table->size = INITIAL_CAPACITY;

	table->table = wmalloc(sizeof(HashItem *) * table->size);

	return table;
}

void WMResetHashTable(WMHashTable * table)
{
	HashItem *item, *tmp;
	int i;

	for (i = 0; i < table->size; i++) {
		item = table->table[i];
		while (item) {
			tmp = item->next;
			RELKEY(table, item->key);
			wfree(item);
			item = tmp;
		}
	}

	table->itemCount = 0;

	if (table->size > INITIAL_CAPACITY) {
		wfree(table->table);
		table->size = INITIAL_CAPACITY;
		table->table = wmalloc(sizeof(HashItem *) * table->size);
	} else {
		memset(table->table, 0, sizeof(HashItem *) * table->size);
	}
}

void WMFreeHashTable(WMHashTable * table)
{
	HashItem *item, *tmp;
	int i;

	for (i = 0; i < table->size; i++) {
		item = table->table[i];
		while (item) {
			tmp = item->next;
			RELKEY(table, item->key);
			wfree(item);
			item = tmp;
		}
	}
	wfree(table->table);
	wfree(table);
}

unsigned WMCountHashTable(WMHashTable * table)
{
	return table->itemCount;
}

static HashItem *hashGetItem(WMHashTable *table, const void *key)
{
	unsigned h;
	HashItem *item;

	h = HASH(table, key);
	item = table->table[h];

	if (table->callbacks.keyIsEqual) {
		while (item) {
			if ((*table->callbacks.keyIsEqual) (key, item->key)) {
				break;
			}
			item = item->next;
		}
	} else {
		while (item) {
			if (key == item->key) {
				break;
			}
			item = item->next;
		}
	}
	return item;
}

void *WMHashGet(WMHashTable * table, const void *key)
{
	HashItem *item;

	item = hashGetItem(table, key);
	if (!item)
		return NULL;
	return (void *)item->data;
}

Bool WMHashGetItemAndKey(WMHashTable * table, const void *key, void **retItem, void **retKey)
{
	HashItem *item;

	item = hashGetItem(table, key);
	if (!item)
		return False;

	if (retKey)
		*retKey = (void *)item->key;
	if (retItem)
		*retItem = (void *)item->data;
	return True;
}

void *WMHashInsert(WMHashTable * table, const void *key, const void *data)
{
	unsigned h;
	HashItem *item;
	int replacing = 0;

	h = HASH(table, key);
	/* look for the entry */
	item = table->table[h];
	if (table->callbacks.keyIsEqual) {
		while (item) {
			if ((*table->callbacks.keyIsEqual) (key, item->key)) {
				replacing = 1;
				break;
			}
			item = item->next;
		}
	} else {
		while (item) {
			if (key == item->key) {
				replacing = 1;
				break;
			}
			item = item->next;
		}
	}

	if (replacing) {
		const void *old;

		old = item->data;
		item->data = data;
		RELKEY(table, item->key);
		item->key = DUPKEY(table, key);

		return (void *)old;
	} else {
		HashItem *nitem;

		nitem = wmalloc(sizeof(HashItem));
		nitem->key = DUPKEY(table, key);
		nitem->data = data;
		nitem->next = table->table[h];
		table->table[h] = nitem;

		table->itemCount++;
	}

	/* OPTIMIZE: put this in an idle handler. */
	if (table->itemCount > table->size) {
#ifdef DEBUG0
		printf("rebuilding hash table...\n");
#endif
		rebuildTable(table);
#ifdef DEBUG0
		printf("finished rebuild.\n");
#endif
	}

	return NULL;
}

static HashItem *deleteFromList(HashTable * table, HashItem * item, const void *key)
{
	HashItem *next;

	if (item == NULL)
		return NULL;

	if ((table->callbacks.keyIsEqual && (*table->callbacks.keyIsEqual) (key, item->key))
	    || (!table->callbacks.keyIsEqual && key == item->key)) {

		next = item->next;
		RELKEY(table, item->key);
		wfree(item);

		table->itemCount--;

		return next;
	}

	item->next = deleteFromList(table, item->next, key);

	return item;
}

void WMHashRemove(WMHashTable * table, const void *key)
{
	unsigned h;

	h = HASH(table, key);

	table->table[h] = deleteFromList(table, table->table[h], key);
}

WMHashEnumerator WMEnumerateHashTable(WMHashTable * table)
{
	WMHashEnumerator enumerator;

	enumerator.table = table;
	enumerator.index = 0;
	enumerator.nextItem = table->table[0];

	return enumerator;
}

void *WMNextHashEnumeratorItem(WMHashEnumerator * enumerator)
{
	const void *data = NULL;

	/* this assumes the table doesn't change between
	 * WMEnumerateHashTable() and WMNextHashEnumeratorItem() calls */

	if (enumerator->nextItem == NULL) {
		HashTable *table = enumerator->table;
		while (++enumerator->index < table->size) {
			if (table->table[enumerator->index] != NULL) {
				enumerator->nextItem = table->table[enumerator->index];
				break;
			}
		}
	}

	if (enumerator->nextItem) {
		data = ((HashItem *) enumerator->nextItem)->data;
		enumerator->nextItem = ((HashItem *) enumerator->nextItem)->next;
	}

	return (void *)data;
}

void *WMNextHashEnumeratorKey(WMHashEnumerator * enumerator)
{
	const void *key = NULL;

	/* this assumes the table doesn't change between
	 * WMEnumerateHashTable() and WMNextHashEnumeratorKey() calls */

	if (enumerator->nextItem == NULL) {
		HashTable *table = enumerator->table;
		while (++enumerator->index < table->size) {
			if (table->table[enumerator->index] != NULL) {
				enumerator->nextItem = table->table[enumerator->index];
				break;
			}
		}
	}

	if (enumerator->nextItem) {
		key = ((HashItem *) enumerator->nextItem)->key;
		enumerator->nextItem = ((HashItem *) enumerator->nextItem)->next;
	}

	return (void *)key;
}

Bool WMNextHashEnumeratorItemAndKey(WMHashEnumerator * enumerator, void **item, void **key)
{
	/* this assumes the table doesn't change between
	 * WMEnumerateHashTable() and WMNextHashEnumeratorItemAndKey() calls */

	if (enumerator->nextItem == NULL) {
		HashTable *table = enumerator->table;
		while (++enumerator->index < table->size) {
			if (table->table[enumerator->index] != NULL) {
				enumerator->nextItem = table->table[enumerator->index];
				break;
			}
		}
	}

	if (enumerator->nextItem) {
		if (item)
			*item = (void *)((HashItem *) enumerator->nextItem)->data;
		if (key)
			*key = (void *)((HashItem *) enumerator->nextItem)->key;
		enumerator->nextItem = ((HashItem *) enumerator->nextItem)->next;

		return True;
	}

	return False;
}

static Bool compareStrings(const void *param1, const void *param2)
{
	const char *key1 = param1;
	const char *key2 = param2;

	return strcmp(key1, key2) == 0;
}

typedef void *(*retainFunc) (const void *);
typedef void (*releaseFunc) (const void *);

const WMHashTableCallbacks WMIntHashCallbacks = {
	NULL,
	NULL,
	NULL,
	NULL
};

const WMHashTableCallbacks WMStringHashCallbacks = {
	hashString,
	compareStrings,
	(retainFunc) wstrdup,
	(releaseFunc) wfree
};

const WMHashTableCallbacks WMStringPointerHashCallbacks = {
	hashString,
	compareStrings,
	NULL,
	NULL
};
