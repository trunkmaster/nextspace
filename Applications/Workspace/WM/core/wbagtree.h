/*
 * Tree bags use a red-black tree for storage.
 * Item indexes may be any integer number.
 *
 * Pros:
 * O(lg n) insertion/deletion/search
 * Good for large numbers of elements with sparse indexes
 *
 * Cons:
 * O(lg n) insertion/deletion/search
 * Slow for storing small numbers of elements
 */

#ifndef __WORKSPACE_WM_WBAGTREE__
#define __WORKSPACE_WM_WBAGTREE__

#include <core/wdata.h>

extern int WMNotFound;

typedef struct W_Bag WMBag;

typedef void *WMBagIterator;

#define WMCreateBag(size) WMCreateTreeBag()

#define WMCreateBagWithDestructor(size, d) WMCreateTreeBagWithDestructor(d)

WMBag* WMCreateTreeBag(void);

WMBag* WMCreateTreeBagWithDestructor(WMFreeDataProc *destructor);

int WMGetBagItemCount(WMBag *bag);

void WMAppendBag(WMBag *bag, WMBag *other);

void WMPutInBag(WMBag *bag, void *item);

/* insert will increment the index of elements after it by 1 */
void WMInsertInBag(WMBag *bag, int index, void *item);

/* erase will remove the element from the bag,
 * but will keep the index of the other elements unchanged */
int WMEraseFromBag(WMBag *bag, int index);

/* delete and remove will remove the elements and cause the elements
 * after them to decrement their indexes by 1 */
int WMDeleteFromBag(WMBag *bag, int index);

int WMRemoveFromBag(WMBag *bag, void *item);

void* WMGetFromBag(WMBag *bag, int index);

void* WMReplaceInBag(WMBag *bag, int index, void *item);

#define WMSetInBag(bag, index, item) WMReplaceInBag(bag, index, item)

/* comparer must return:
 * < 0 if a < b
 * > 0 if a > b
 * = 0 if a = b
 */
void WMSortBag(WMBag *bag, WMCompareDataProc *comparer);

void WMEmptyBag(WMBag *bag);

void WMFreeBag(WMBag *bag);

void WMMapBag(WMBag *bag, void (*function)(void*, void*), void *data);

int WMGetFirstInBag(WMBag *bag, void *item);

int WMCountInBag(WMBag *bag, void *item);

int WMFindInBag(WMBag *bag, WMMatchDataProc *match, void *cdata);

void* WMBagFirst(WMBag *bag, WMBagIterator *ptr);

void* WMBagLast(WMBag *bag, WMBagIterator *ptr);

/* The following 4 functions assume that the bag doesn't change between calls */
void* WMBagNext(WMBag *bag, WMBagIterator *ptr);

void* WMBagPrevious(WMBag *bag, WMBagIterator *ptr);

void* WMBagIteratorAtIndex(WMBag *bag, int index, WMBagIterator *ptr);

int WMBagIndexForIterator(WMBag *bag, WMBagIterator ptr);


/* The following 2 macros assume that the bag doesn't change in the for loop */
#define WM_ITERATE_BAG(bag, var, i) \
    for (var = WMBagFirst(bag, &(i)); (i) != NULL; \
    var = WMBagNext(bag, &(i)))

#define WM_ETARETI_BAG(bag, var, i) \
    for (var = WMBagLast(bag, &(i)); (i) != NULL; \
    var = WMBagPrevious(bag, &(i)))

#endif // _W_BAGTREE_H_
