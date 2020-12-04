/*
 * WMArray use an array to store the elements.
 * Item indexes may be only positive integer numbers.
 * The array cannot contain holes in it.
 *
 * Pros:
 * Fast [O(1)] access to elements
 * Fast [O(1)] push/pop
 *
 * Cons:
 * A little slower [O(n)] for insertion/deletion of elements that
 * 	aren't in the end
 */

#ifndef _WARRAY_H_
#define _WARRAY_H_

#include <WMcore/WMcore.h>
#include <WMcore/util.h>

typedef struct W_Array WMArray;

typedef int WMArrayIterator;

WMArray* WMCreateArray(int initialSize);

WMArray* WMCreateArrayWithDestructor(int initialSize, WMFreeDataProc *destructor);

WMArray* WMCreateArrayWithArray(WMArray *array);

#define WMDuplicateArray(array) WMCreateArrayWithArray(array)

void WMEmptyArray(WMArray *array);

void WMFreeArray(WMArray *array);

int WMGetArrayItemCount(WMArray *array);

/* appends other to array. other remains unchanged */
void WMAppendArray(WMArray *array, WMArray *other);

/* add will place the element at the end of the array */
void WMAddToArray(WMArray *array, void *item);

/* insert will increment the index of elements after it by 1 */
void WMInsertInArray(WMArray *array, int index, void *item);

/* replace and set will return the old item WITHOUT calling the
 * destructor on it even if its available. Free the returned item yourself.
 */
void* WMReplaceInArray(WMArray *array, int index, void *item);

#define WMSetInArray(array, index, item) WMReplaceInArray(array, index, item)

/* delete and remove will remove the elements and cause the elements
 * after them to decrement their indexes by 1. Also will call the
 * destructor on the deleted element if there's one available.
 */
int WMDeleteFromArray(WMArray *array, int index);

#define WMRemoveFromArray(array, item) WMRemoveFromArrayMatching(array, NULL, item)

int WMRemoveFromArrayMatching(WMArray *array, WMMatchDataProc *match, void *cdata);

void* WMGetFromArray(WMArray *array, int index);

#define WMGetFirstInArray(array, item) WMFindInArray(array, NULL, item)

/* pop will return the last element from the array, also removing it
 * from the array. The destructor is NOT called, even if available.
 * Free the returned element if needed by yourself
 */
void* WMPopFromArray(WMArray *array);

int WMFindInArray(WMArray *array, WMMatchDataProc *match, void *cdata);

int WMCountInArray(WMArray *array, void *item);

/* comparer must return:
 * < 0 if a < b
 * > 0 if a > b
 * = 0 if a = b
 */
void WMSortArray(WMArray *array, WMCompareDataProc *comparer);

void WMMapArray(WMArray *array, void (*function)(void*, void*), void *data);

WMArray* WMGetSubarrayWithRange(WMArray* array, WMRange aRange);

void* WMArrayFirst(WMArray *array, WMArrayIterator *iter);

void* WMArrayLast(WMArray *array, WMArrayIterator *iter);

/* The following 2 functions assume that the array doesn't change between calls */
void* WMArrayNext(WMArray *array, WMArrayIterator *iter);

void* WMArrayPrevious(WMArray *array, WMArrayIterator *iter);


/* The following 2 macros assume that the array doesn't change in the for loop */
#define WM_ITERATE_ARRAY(array, var, i) \
    for (var = WMArrayFirst(array, &(i)); (i) != WANotFound; \
    var = WMArrayNext(array, &(i)))

#define WM_ETARETI_ARRAY(array, var, i) \
    for (var = WMArrayLast(array, &(i)); (i) != WANotFound; \
    var = WMArrayPrevious(array, &(i)))

#endif
