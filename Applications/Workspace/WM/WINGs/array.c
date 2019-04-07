/*
 * Dynamically Resized Array
 *
 * Authors: Alfredo K. Kojima <kojima@windowmaker.info>
 *          Dan Pascu         <dan@windowmaker.info>
 *
 * This code is released to the Public Domain, but
 * proper credit is always appreciated :)
 */

#include <stdlib.h>
#include <string.h>

#include "WUtil.h"

#define INITIAL_SIZE 8
#define RESIZE_INCREMENT 8

typedef struct W_Array {
	void **items;		/* the array data */
	int itemCount;		/* # of items in array */
	int allocSize;		/* allocated size of array */
	WMFreeDataProc *destructor;	/* the destructor to free elements */
} W_Array;

WMArray *WMCreateArray(int initialSize)
{
	return WMCreateArrayWithDestructor(initialSize, NULL);
}

WMArray *WMCreateArrayWithDestructor(int initialSize, WMFreeDataProc * destructor)
{
	WMArray *array;

	array = wmalloc(sizeof(WMArray));

	if (initialSize <= 0) {
		initialSize = INITIAL_SIZE;
	}

	array->items = wmalloc(sizeof(void *) * initialSize);

	array->itemCount = 0;
	array->allocSize = initialSize;
	array->destructor = destructor;

	return array;
}

WMArray *WMCreateArrayWithArray(WMArray * array)
{
	WMArray *newArray;

	newArray = wmalloc(sizeof(WMArray));

	newArray->items = wmalloc(sizeof(void *) * array->allocSize);
	memcpy(newArray->items, array->items, sizeof(void *) * array->itemCount);

	newArray->itemCount = array->itemCount;
	newArray->allocSize = array->allocSize;
	newArray->destructor = NULL;

	return newArray;
}

void WMEmptyArray(WMArray * array)
{
	if (array->destructor) {
		while (array->itemCount > 0) {
			array->itemCount--;
			array->destructor(array->items[array->itemCount]);
		}
	}
	/*memset(array->items, 0, array->itemCount * sizeof(void*)); */
	array->itemCount = 0;
}

void WMFreeArray(WMArray * array)
{
	if (array == NULL)
		return;

	WMEmptyArray(array);
	wfree(array->items);
	wfree(array);
}

int WMGetArrayItemCount(WMArray * array)
{
	if (array == NULL)
		return 0;

	return array->itemCount;
}

void WMAppendArray(WMArray * array, WMArray * other)
{
	if (array == NULL || other == NULL)
		return;

	if (other->itemCount == 0)
		return;

	if (array->itemCount + other->itemCount > array->allocSize) {
		array->allocSize += other->allocSize;
		array->items = wrealloc(array->items, sizeof(void *) * array->allocSize);
	}

	memcpy(array->items + array->itemCount, other->items, sizeof(void *) * other->itemCount);
	array->itemCount += other->itemCount;
}

void WMAddToArray(WMArray * array, void *item)
{
	if (array == NULL)
		return;

	if (array->itemCount >= array->allocSize) {
		array->allocSize += RESIZE_INCREMENT;
		array->items = wrealloc(array->items, sizeof(void *) * array->allocSize);
	}
	array->items[array->itemCount] = item;

	array->itemCount++;
}

void WMInsertInArray(WMArray * array, int index, void *item)
{
	if (array == NULL)
		return;

	wassertr(index >= 0 && index <= array->itemCount);

	if (array->itemCount >= array->allocSize) {
		array->allocSize += RESIZE_INCREMENT;
		array->items = wrealloc(array->items, sizeof(void *) * array->allocSize);
	}
	if (index < array->itemCount) {
		memmove(array->items + index + 1, array->items + index,
			sizeof(void *) * (array->itemCount - index));
	}
	array->items[index] = item;

	array->itemCount++;
}

void *WMReplaceInArray(WMArray * array, int index, void *item)
{
	void *old;

	if (array == NULL)
		return NULL;

	wassertrv(index >= 0 && index <= array->itemCount, NULL);

	/* is it really useful to perform append if index == array->itemCount ? -Dan */
	if (index == array->itemCount) {
		WMAddToArray(array, item);
		return NULL;
	}

	old = array->items[index];
	array->items[index] = item;

	return old;
}

int WMDeleteFromArray(WMArray * array, int index)
{
	if (array == NULL)
		return 0;

	wassertrv(index >= 0 && index < array->itemCount, 0);

	if (array->destructor) {
		array->destructor(array->items[index]);
	}

	if (index < array->itemCount - 1) {
		memmove(array->items + index, array->items + index + 1,
			sizeof(void *) * (array->itemCount - index - 1));
	}

	array->itemCount--;

	return 1;
}

int WMRemoveFromArrayMatching(WMArray * array, WMMatchDataProc * match, void *cdata)
{
	int i;

	if (array == NULL)
		return 1;

	if (match != NULL) {
		for (i = 0; i < array->itemCount; i++) {
			if ((*match) (array->items[i], cdata)) {
				WMDeleteFromArray(array, i);
				return 1;
			}
		}
	} else {
		for (i = 0; i < array->itemCount; i++) {
			if (array->items[i] == cdata) {
				WMDeleteFromArray(array, i);
				return 1;
			}
		}
	}

	return 0;
}

void *WMGetFromArray(WMArray * array, int index)
{
	if (index < 0 || array == NULL || index >= array->itemCount)
		return NULL;

	return array->items[index];
}

void *WMPopFromArray(WMArray * array)
{
	if (array == NULL || array->itemCount <= 0)
		return NULL;

	array->itemCount--;

	return array->items[array->itemCount];
}

int WMFindInArray(WMArray * array, WMMatchDataProc * match, void *cdata)
{
	int i;

	if (array == NULL)
		return WANotFound;

	if (match != NULL) {
		for (i = 0; i < array->itemCount; i++) {
			if ((*match) (array->items[i], cdata))
				return i;
		}
	} else {
		for (i = 0; i < array->itemCount; i++) {
			if (array->items[i] == cdata)
				return i;
		}
	}

	return WANotFound;
}

int WMCountInArray(WMArray * array, void *item)
{
	int i, count;

	if (array == NULL)
		return 0;

	for (i = 0, count = 0; i < array->itemCount; i++) {
		if (array->items[i] == item)
			count++;
	}

	return count;
}

void WMSortArray(WMArray * array, WMCompareDataProc * comparer)
{
	if (array == NULL)
		return;

	if (array->itemCount > 1) {	/* Don't sort empty or single element arrays */
		qsort(array->items, array->itemCount, sizeof(void *), comparer);
	}
}

void WMMapArray(WMArray * array, void (*function) (void *, void *), void *data)
{
	int i;

	if (array == NULL)
		return;

	for (i = 0; i < array->itemCount; i++) {
		(*function) (array->items[i], data);
	}
}

WMArray *WMGetSubarrayWithRange(WMArray * array, WMRange aRange)
{
	WMArray *newArray;

	if (aRange.count <= 0 || array == NULL)
		return WMCreateArray(0);

	if (aRange.position < 0)
		aRange.position = 0;
	if (aRange.position >= array->itemCount)
		aRange.position = array->itemCount - 1;
	if (aRange.position + aRange.count > array->itemCount)
		aRange.count = array->itemCount - aRange.position;

	newArray = WMCreateArray(aRange.count);
	memcpy(newArray->items, array->items + aRange.position, sizeof(void *) * aRange.count);
	newArray->itemCount = aRange.count;

	return newArray;
}

void *WMArrayFirst(WMArray * array, WMArrayIterator * iter)
{
	if (array == NULL || array->itemCount == 0) {
		*iter = WANotFound;
		return NULL;
	} else {
		*iter = 0;
		return array->items[0];
	}
}

void *WMArrayLast(WMArray * array, WMArrayIterator * iter)
{
	if (array == NULL || array->itemCount == 0) {
		*iter = WANotFound;
		return NULL;
	} else {
		*iter = array->itemCount - 1;
		return array->items[*iter];
	}
}

void *WMArrayNext(WMArray * array, WMArrayIterator * iter)
{
	if (array == NULL) {
		*iter = WANotFound;
		return NULL;
	}

	if (*iter >= 0 && *iter < array->itemCount - 1) {
		return array->items[++(*iter)];
	} else {
		*iter = WANotFound;
		return NULL;
	}
}

void *WMArrayPrevious(WMArray * array, WMArrayIterator * iter)
{
	if (array == NULL) {
		*iter = WANotFound;
		return NULL;
	}

	if (*iter > 0 && *iter < array->itemCount) {
		return array->items[--(*iter)];
	} else {
		*iter = WANotFound;
		return NULL;
	}
}
