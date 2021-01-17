/*
 * WINGs WMData function library
 *
 * Copyright (c) 1999-2003 Dan Pascu
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 */

#ifndef __WORKSPACE_WM_WDATA__
#define __WORKSPACE_WM_WDATA__

#include "util.h"

typedef struct WMData WMData;

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

#endif /* __WORKSPACE_WM_WDATA__ */
