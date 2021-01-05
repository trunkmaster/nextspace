#ifndef __WORKSPACE_WM_WDATA__
#define __WORKSPACE_WM_WDATA__

#include <WMcore/util.h>

typedef struct W_Data WMData;

typedef void WMFreeDataProc(void *data);
typedef int WMCompareDataProc(const void *item1, const void *item2);
typedef int WMMatchDataProc(const void *item, const void *cdata);

/* Creating/destroying data */

/* destructor is a function called to free the data when releasing the data
 * object, or NULL if no freeing of data is necesary. */
WMData* WMCreateDataWithBytesNoCopy(void *bytes, unsigned length, WMFreeDataProc *destructor);
WMData* WMRetainData(WMData *aData);
void WMReleaseData(WMData *aData);

/* Accessing data */

const void* WMDataBytes(WMData *aData);

/* Testing data */

unsigned WMGetDataLength(WMData *aData);

/* Modifying data */

void WMSetDataFormat(WMData *aData, unsigned format);
unsigned WMGetDataFormat(WMData *aData);

#endif
