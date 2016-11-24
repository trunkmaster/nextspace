/* WUtil.h
 *
 *  Copyright (c) 1998 scottc
 *  Copyright (c) 1999-2004 Dan Pascu
 *  Copyright (c) 1999-2000 Alfredo K. Kojima
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

#ifndef _WUTIL_H_
#define _WUTIL_H_

#include <X11/Xlib.h>
#include <limits.h>
#include <sys/types.h>

/* SunOS 4.x Blargh.... */
#ifndef NULL
#define NULL ((void*)0)
#endif


#ifndef WMAX
# define WMAX(a,b)	((a)>(b) ? (a) : (b))
#endif
#ifndef WMIN
# define WMIN(a,b)	((a)<(b) ? (a) : (b))
#endif


#ifndef __GNUC__
#define  __attribute__(x)  /*NOTHING*/
#endif

#ifdef NDEBUG

#define wassertr(expr)  \
	if (!(expr)) { return; }

#define wassertrv(expr, val)  \
	if (!(expr)) { return (val); }

#else /* !NDEBUG */

#define wassertr(expr) \
    if (!(expr)) { \
        wwarning("wassertr: assertion %s failed", #expr); \
        return;\
    }

#define wassertrv(expr, val) \
    if (!(expr)) { \
        wwarning("wassertrv: assertion %s failed", #expr); \
        return (val);\
    }

#endif /* !NDEBUG */


#ifdef static_assert
# define _wutil_static_assert(check, message) static_assert(check, message)
#else
# ifdef __STDC_VERSION__
#  if __STDC_VERSION__ >= 201112L
/*
 * Ideally, we would like to include <assert.h> to have 'static_assert'
 * properly defined, but as we have to be sure about portability and
 * because we're a public header we can't count on 'configure' to tell
 * us about availability, so we use the raw C11 keyword
 */
#   define _wutil_static_assert(check, message) _Static_assert(check, message)
#  else
#   define _wutil_static_assert(check, message) /**/
#  endif
# else
#  define _wutil_static_assert(check, message) /**/
# endif
#endif


#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */


typedef enum {
    WMPostWhenIdle = 1,
    WMPostASAP = 2,
    WMPostNow = 3
} WMPostingStyle;


typedef enum {
    WNCNone = 0,
    WNCOnName = 1,
    WNCOnSender = 2
} WMNotificationCoalescing;



enum {
    WBNotFound = INT_MIN, /* element was not found in WMBag   */
    WANotFound = -1       /* element was not found in WMArray */
};


typedef struct W_Array WMArray;
typedef struct W_Bag WMBag;
typedef struct W_Data WMData;
typedef struct W_TreeNode WMTreeNode;
typedef struct W_HashTable WMHashTable;
typedef struct W_UserDefaults WMUserDefaults;
typedef struct W_Notification WMNotification;
typedef struct W_NotificationQueue WMNotificationQueue;
typedef struct W_Host WMHost;
typedef struct W_Connection WMConnection;
typedef struct W_PropList WMPropList;



/* Some typedefs for the handler stuff */
typedef void *WMHandlerID;

typedef void WMCallback(void *data);

typedef void WMInputProc(int fd, int mask, void *clientData);



typedef int WMCompareDataProc(const void *item1, const void *item2);
typedef void WMTreeWalkProc(WMTreeNode *aNode, void *data);

typedef void WMFreeDataProc(void *data);

/* Used by WMBag or WMArray for matching data */
typedef int WMMatchDataProc(const void *item, const void *cdata);



typedef struct {
    int position;
    int count;
} WMRange;



/* DO NOT ACCESS THE CONTENTS OF THIS STRUCT */
typedef struct {
    void *table;
    void *nextItem;
    int index;
} WMHashEnumerator;


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


typedef int WMArrayIterator;
typedef void *WMBagIterator;


typedef void WMNotificationObserverAction(void *observerData,
                                          WMNotification *notification);


/* ---[ Macros ]---------------------------------------------------------- */

#define wlengthof(array)  \
	({   \
		_wutil_static_assert(sizeof(array) > sizeof(array[0]),   \
		                     "the macro 'wlengthof' cannot be used on pointers, only on known size arrays");   \
		sizeof(array) / sizeof(array[0]);   \
	})


/* ---[ WINGs/memory.c ]-------------------------------------------------- */

void* wmalloc(size_t size);
void* wrealloc(void *ptr, size_t newsize);
void wfree(void *ptr);

void wrelease(void *ptr);
void* wretain(void *ptr);

typedef void waborthandler(int);

waborthandler* wsetabort(waborthandler* handler);

/* ---[ WINGs/error.c ]--------------------------------------------------- */

enum {
	WMESSAGE_TYPE_MESSAGE,
	WMESSAGE_TYPE_WARNING,
	WMESSAGE_TYPE_ERROR,
	WMESSAGE_TYPE_FATAL
};

#define wmessage(fmt, args...) __wmessage( __func__, __FILE__, __LINE__, WMESSAGE_TYPE_MESSAGE, fmt, ## args)
#define wwarning(fmt, args...) __wmessage( __func__, __FILE__, __LINE__, WMESSAGE_TYPE_WARNING, fmt, ## args)
#define werror(fmt, args...) __wmessage( __func__, __FILE__, __LINE__, WMESSAGE_TYPE_ERROR, fmt, ## args)
#define wfatal(fmt, args...) __wmessage( __func__, __FILE__, __LINE__, WMESSAGE_TYPE_FATAL, fmt, ## args)

void __wmessage(const char *func, const char *file, int line, int type, const char *msg, ...)
	__attribute__((__format__(printf,5,6)));

/* ---[ WINGs/findfile.c ]------------------------------------------------ */

/* For the 4 function below, you have to free the returned string when you no longer need it */

char* wfindfile(const char *paths, const char *file);

char* wfindfileinlist(char *const *path_list, const char *file);

char* wfindfileinarray(WMPropList* array, const char *file);

char* wexpandpath(const char *path);

int wcopy_file(const char *toPath, const char *srcFile, const char *destFile);

/* don't free the returned string */
char* wgethomedir(void);

/* ---[ WINGs/proplist.c ]------------------------------------------------ */

int wmkdirhier(const char *path);
int wrmdirhier(const char *path);

/* ---[ WINGs/string.c ]-------------------------------------------------- */

char *wstrdup(const char *str);
char* wstrndup(const char *str, size_t len);

/* Concatenate str1 with str2 and return that in a newly malloc'ed string.
 * str1 and str2 can be any strings including static and constant strings.
 * str1 and str2 will not be modified.
 * Free the returned string when you're done with it. */
char* wstrconcat(const char *str1, const char *str2);

/* This will append src to dst, and return dst. dst MUST be either NULL
 * or a string that was a result of a dynamic allocation (malloc, realloc
 * wmalloc, wrealloc, ...). dst CANNOT be a static or a constant string!
 * Modifies dst (no new string is created except if dst==NULL in which case
 * it is equivalent to calling wstrdup(src) ).
 * The returned address may be different from the original address of dst,
 * so always assign the returned address to avoid dangling pointers. */
char* wstrappend(char *dst, const char *src);

size_t wstrlcpy(char *, const char *, size_t);
size_t wstrlcat(char *, const char *, size_t);


void wtokensplit(char *command, char ***argv, int *argc);

char* wtokennext(char *word, char **next);

char* wtokenjoin(char **list, int count);

void wtokenfree(char **tokens, int count);

char* wtrimspace(const char *s);

/* transform `s' so that the result is safe to pass to the shell as an argument.
 * returns a newly allocated string.
 * with very heavy inspirations from NetBSD's shquote(3).
 */
char *wshellquote(const char *s);

/* ---[ WINGs/misc.c ]--------------------------------------------------- */

WMRange wmkrange(int start, int count);

/* An application must call this function before exiting, to let WUtil do some internal cleanup */
void wutil_shutdown(void);


/* ---[ WINGs/usleep.c ]-------------------------------------------------- */

void wusleep(unsigned int usec);

/* ---[ WINGs/handlers.c ]------------------------------------------------ */

/* Event handlers: timer, idle, input */

WMHandlerID WMAddTimerHandler(int milliseconds, WMCallback *callback,
                              void *cdata);

WMHandlerID WMAddPersistentTimerHandler(int milliseconds, WMCallback *callback,
                                        void *cdata);

void WMDeleteTimerWithClientData(void *cdata);

void WMDeleteTimerHandler(WMHandlerID handlerID);

WMHandlerID WMAddIdleHandler(WMCallback *callback, void *cdata);

void WMDeleteIdleHandler(WMHandlerID handlerID);

WMHandlerID WMAddInputHandler(int fd, int condition, WMInputProc *proc,
                              void *clientData);

void WMDeleteInputHandler(WMHandlerID handlerID);


/* This function is used _only_ if you create a non-GUI program.
 * For GUI based programs use WMNextEvent()/WMHandleEvent() instead.
 * This function will handle all input/timer/idle events, then return.
 */

void WHandleEvents(void);

/* ---[ WINGs/hashtable.c ]----------------------------------------------- */


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


/* ---[ WINGs/array.c ]--------------------------------------------------- */

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

/* ---[ WINGs/bagtree.c ]------------------------------------------------- */

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



/* ---[ WINGs/data.c ]---------------------------------------------------- */

/* WMData handling */

/* Creating/destroying data */

WMData* WMCreateDataWithCapacity(unsigned capacity);

WMData* WMCreateDataWithLength(unsigned length);

WMData* WMCreateDataWithBytes(const void *bytes, unsigned length);

/* destructor is a function called to free the data when releasing the data
 * object, or NULL if no freeing of data is necesary. */
WMData* WMCreateDataWithBytesNoCopy(void *bytes, unsigned length,
                                    WMFreeDataProc *destructor);

WMData* WMCreateDataWithData(WMData *aData);

WMData* WMRetainData(WMData *aData);

void WMReleaseData(WMData *aData);

/* Adjusting capacity */

void WMSetDataCapacity(WMData *aData, unsigned capacity);

void WMSetDataLength(WMData *aData, unsigned length);

void WMIncreaseDataLengthBy(WMData *aData, unsigned extraLength);

/* Accessing data */

const void* WMDataBytes(WMData *aData);

void WMGetDataBytes(WMData *aData, void *buffer);

void WMGetDataBytesWithLength(WMData *aData, void *buffer, unsigned length);

void WMGetDataBytesWithRange(WMData *aData, void *buffer, WMRange aRange);

WMData* WMGetSubdataWithRange(WMData *aData, WMRange aRange);

/* Testing data */

Bool WMIsDataEqualToData(WMData *aData, WMData *anotherData);

unsigned WMGetDataLength(WMData *aData);

/* Adding data */

void WMAppendDataBytes(WMData *aData, const void *bytes, unsigned length);

void WMAppendData(WMData *aData, WMData *anotherData);

/* Modifying data */

void WMReplaceDataBytesInRange(WMData *aData, WMRange aRange, const void *bytes);

void WMResetDataBytesInRange(WMData *aData, WMRange aRange);

void WMSetData(WMData *aData, WMData *anotherData);


void WMSetDataFormat(WMData *aData, unsigned format);

unsigned WMGetDataFormat(WMData *aData);
/* Storing data */

/* ---[ WINGs/tree.c ]---------------------------------------------------- */

/* Generic Tree and TreeNode */

WMTreeNode* WMCreateTreeNode(void *data);

WMTreeNode* WMCreateTreeNodeWithDestructor(void *data, WMFreeDataProc *destructor);

WMTreeNode* WMInsertItemInTree(WMTreeNode *parent, int index, void *item);

#define WMAddItemToTree(parent, item)  WMInsertItemInTree(parent, -1, item)

WMTreeNode* WMInsertNodeInTree(WMTreeNode *parent, int index, WMTreeNode *aNode);

#define WMAddNodeToTree(parent, aNode)  WMInsertNodeInTree(parent, -1, aNode)

void WMDestroyTreeNode(WMTreeNode *aNode);

void WMDeleteLeafForTreeNode(WMTreeNode *aNode, int index);

void WMRemoveLeafForTreeNode(WMTreeNode *aNode, void *leaf);

void* WMReplaceDataForTreeNode(WMTreeNode *aNode, void *newData);

void* WMGetDataForTreeNode(WMTreeNode *aNode);

int WMGetTreeNodeDepth(WMTreeNode *aNode);

WMTreeNode* WMGetParentForTreeNode(WMTreeNode *aNode);

/* Sort only the leaves of the passed node */
void WMSortLeavesForTreeNode(WMTreeNode *aNode, WMCompareDataProc *comparer);

/* Sort all tree recursively starting from the passed node */
void WMSortTree(WMTreeNode *aNode, WMCompareDataProc *comparer);

/* Returns the first node which matches node's data with cdata by 'match' */
WMTreeNode* WMFindInTree(WMTreeNode *aTree, WMMatchDataProc *match, void *cdata);

/* Returns the first node where node's data matches cdata by 'match' and node is
 * at most `limit' depths down from `aTree'. */
WMTreeNode *WMFindInTreeWithDepthLimit(WMTreeNode * aTree, WMMatchDataProc * match, void *cdata, int limit);

/* Returns first tree node that has data == cdata */
#define WMGetFirstInTree(aTree, cdata) WMFindInTree(aTree, NULL, cdata)

/* Walk every node of aNode with `walk' */
void WMTreeWalk(WMTreeNode *aNode, WMTreeWalkProc * walk, void *data, Bool DepthFirst);

/* ---[ WINGs/data.c ]---------------------------------------------------- */


WMNotification* WMCreateNotification(const char *name, void *object, void *clientData);

void WMReleaseNotification(WMNotification *notification);

WMNotification* WMRetainNotification(WMNotification *notification);

void* WMGetNotificationClientData(WMNotification *notification);

void* WMGetNotificationObject(WMNotification *notification);

const char* WMGetNotificationName(WMNotification *notification);


void WMAddNotificationObserver(WMNotificationObserverAction *observerAction,
                               void *observer, const char *name, void *object);

void WMPostNotification(WMNotification *notification);

void WMRemoveNotificationObserver(void *observer);

void WMRemoveNotificationObserverWithName(void *observer, const char *name,
                                          void *object);

void WMPostNotificationName(const char *name, void *object, void *clientData);

WMNotificationQueue* WMGetDefaultNotificationQueue(void);

WMNotificationQueue* WMCreateNotificationQueue(void);

void WMDequeueNotificationMatching(WMNotificationQueue *queue,
                                   WMNotification *notification,
                                   unsigned mask);

void WMEnqueueNotification(WMNotificationQueue *queue,
                           WMNotification *notification,
                           WMPostingStyle postingStyle);

void WMEnqueueCoalesceNotification(WMNotificationQueue *queue,
                                   WMNotification *notification,
                                   WMPostingStyle postingStyle,
                                   unsigned coalesceMask);


/* ---[ WINGs/proplist.c ]------------------------------------------------ */

/* Property Lists handling */

void WMPLSetCaseSensitive(Bool caseSensitive);

WMPropList* WMCreatePLString(const char *str);

WMPropList* WMCreatePLData(WMData *data);

WMPropList* WMCreatePLDataWithBytes(const unsigned char *bytes, unsigned int length);

WMPropList* WMCreatePLDataWithBytesNoCopy(unsigned char *bytes,
                                          unsigned int length,
                                          WMFreeDataProc *destructor);

WMPropList* WMCreatePLArray(WMPropList *elem, ...);

WMPropList* WMCreatePLDictionary(WMPropList *key, WMPropList *value, ...);

WMPropList* WMRetainPropList(WMPropList *plist);

void WMReleasePropList(WMPropList *plist);

/* Objects inserted in arrays and dictionaries will be retained,
 * so you can safely release them after insertion.
 * For dictionaries both the key and value are retained.
 * Objects removed from arrays or dictionaries are released */
void WMInsertInPLArray(WMPropList *plist, int index, WMPropList *item);

void WMAddToPLArray(WMPropList *plist, WMPropList *item);

void WMDeleteFromPLArray(WMPropList *plist, int index);

void WMRemoveFromPLArray(WMPropList *plist, WMPropList *item);

void WMPutInPLDictionary(WMPropList *plist, WMPropList *key, WMPropList *value);

void WMRemoveFromPLDictionary(WMPropList *plist, WMPropList *key);

/* It will insert all key/value pairs from source into dest, overwriting
 * the values with the same keys from dest, keeping all values with keys
 * only present in dest unchanged */
WMPropList* WMMergePLDictionaries(WMPropList *dest, WMPropList *source,
                                  Bool recursive);

/* It will remove all key/value pairs from dest for which there is an
 * identical key/value present in source. Entires only present in dest, or
 * which have different values in dest than in source will be preserved. */
WMPropList* WMSubtractPLDictionaries(WMPropList *dest, WMPropList *source,
                                     Bool recursive);

int WMGetPropListItemCount(WMPropList *plist);

Bool WMIsPLString(WMPropList *plist);

Bool WMIsPLData(WMPropList *plist);

Bool WMIsPLArray(WMPropList *plist);

Bool WMIsPLDictionary(WMPropList *plist);

Bool WMIsPropListEqualTo(WMPropList *plist, WMPropList *other);

/* Returns a reference. Do not free it! */
char* WMGetFromPLString(WMPropList *plist);

/* Returns a reference. Do not free it! */
WMData* WMGetFromPLData(WMPropList *plist);

/* Returns a reference. Do not free it! */
const unsigned char* WMGetPLDataBytes(WMPropList *plist);

int WMGetPLDataLength(WMPropList *plist);

/* Returns a reference. */
WMPropList* WMGetFromPLArray(WMPropList *plist, int index);

/* Returns a reference. */
WMPropList* WMGetFromPLDictionary(WMPropList *plist, WMPropList *key);

/* Returns a PropList array with all the dictionary keys. Release it when
 * you're done. Keys in array are retained from the original dictionary
 * not copied and need NOT to be released individually. */
WMPropList* WMGetPLDictionaryKeys(WMPropList *plist);

/* Creates only the first level deep object. All the elements inside are
 * retained from the original */
WMPropList* WMShallowCopyPropList(WMPropList *plist);

/* Makes a completely separate replica of the original proplist */
WMPropList* WMDeepCopyPropList(WMPropList *plist);

WMPropList* WMCreatePropListFromDescription(const char *desc);

/* Free the returned string when you no longer need it */
char* WMGetPropListDescription(WMPropList *plist, Bool indented);

WMPropList* WMReadPropListFromFile(const char *file);

WMPropList* WMReadPropListFromPipe(const char *command);

Bool WMWritePropListToFile(WMPropList *plist, const char *path);

/* ---[ WINGs/userdefaults.c ]-------------------------------------------- */

/* don't free the returned string */
const char* wusergnusteppath(void);

/* Free the returned string when you no longer need it */
char* wdefaultspathfordomain(const char *domain);

/* Free the returned string when you no longer need it */
char* wglobaldefaultspathfordomain(const char *domain);

WMUserDefaults* WMGetStandardUserDefaults(void);

WMUserDefaults* WMGetDefaultsFromPath(const char *path);

void WMSynchronizeUserDefaults(WMUserDefaults *database);

void WMSaveUserDefaults(WMUserDefaults *database);

void WMEnableUDPeriodicSynchronization(WMUserDefaults *database, Bool enable);

/* Returns a WMPropList array with all the keys in the user defaults database.
 * Free the array with WMReleasePropList() when no longer needed.
 * Keys in array are just retained references to the original keys */
WMPropList* WMGetUDKeys(WMUserDefaults *database);

WMPropList* WMGetUDObjectForKey(WMUserDefaults *database, const char *defaultName);

void WMSetUDObjectForKey(WMUserDefaults *database, WMPropList *object,
                         const char *defaultName);

void WMRemoveUDObjectForKey(WMUserDefaults *database, const char *defaultName);

/* Returns a reference. Do not free it! */
char* WMGetUDStringForKey(WMUserDefaults *database, const char *defaultName);

int WMGetUDIntegerForKey(WMUserDefaults *database, const char *defaultName);

float WMGetUDFloatForKey(WMUserDefaults *database, const char *defaultName);

Bool WMGetUDBoolForKey(WMUserDefaults *database, const char *defaultName);

void WMSetUDStringForKey(WMUserDefaults *database, const char *value,
                         const char *defaultName);

void WMSetUDIntegerForKey(WMUserDefaults *database, int value,
                          const char *defaultName);

void WMSetUDFloatForKey(WMUserDefaults *database, float value,
                        const char *defaultName);

void WMSetUDBoolForKey(WMUserDefaults *database, Bool value,
                       const char *defaultName);

WMPropList* WMGetUDSearchList(WMUserDefaults *database);

void WMSetUDSearchList(WMUserDefaults *database, WMPropList *list);

extern char *WMUserDefaultsDidChangeNotification;


/* ---[ WINGs/menuparser.c ]---------------------------------------------- */


typedef struct w_menu_parser *WMenuParser;


WMenuParser WMenuParserCreate(const char *file_name, void *file, const char *include_default_paths);

void WMenuParserRegisterSimpleMacro(WMenuParser parser, const char *name, const char *value);

void WMenuParserError(WMenuParser parser, const char *msg, ...)
	__attribute__ ((format (printf, 2, 3)));

const char *WMenuParserGetFilename(WMenuParser parser);

Bool WMenuParserGetLine(WMenuParser parser, char **title, char **command, char **parameter, char **shortcut);

void WMenuParserDelete(WMenuParser parser);


/*-------------------------------------------------------------------------*/

/* Global variables */

extern int WCErrorCode;


/*-------------------------------------------------------------------------*/

#ifdef __cplusplus
}
#endif /* __cplusplus */


#endif
