#ifndef _WPROPLIST_H_
#define _WPROPLIST_H_

#include <WMcore/WMcore.h>
#include <WMcore/data.h>

typedef struct W_PropList WMPropList;

/* ---[ WINGs/proplist.c ]------------------------------------------------ */

int wmkdirhier(const char *path);
int wrmdirhier(const char *path);

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

#endif
