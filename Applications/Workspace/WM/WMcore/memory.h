#ifndef _WMEMORY_H_
#define _WMEMORY_H_

#include <sys/types.h>

/* ---[ WINGs/memory.c ]-------------------------------------------------- */

void *wmalloc(size_t size);
void *wrealloc(void *ptr, size_t newsize);
void wfree(void *ptr);

void wrelease(void *ptr);
void *wretain(void *ptr);

typedef void waborthandler(int);

waborthandler *wsetabort(waborthandler* handler);

#endif
