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

#include <string.h>

#include "WMcore.h"
#include "util.h"
#include "data.h"

typedef struct W_Data {
  unsigned length;	/* How many bytes we have */
  unsigned capacity;	/* How many bytes it can hold */
  unsigned growth;	/* How much to grow */
  void *bytes;		/* Actual data */
  unsigned retainCount;
  WMFreeDataProc *destructor;
  int format;		/* 0, 8, 16 or 32 */
} W_Data;

/* Creating and destroying data objects */

WMData *WMCreateDataWithBytesNoCopy(void *bytes, unsigned length, WMFreeDataProc *destructor)
{
  WMData *aData;

  aData = (WMData *) wmalloc(sizeof(WMData));
  aData->length = length;
  aData->capacity = length;
  aData->growth = length / 2 > 0 ? length / 2 : 1;
  aData->bytes = bytes;
  aData->retainCount = 1;
  aData->format = 0;
  aData->destructor = destructor;

  return aData;
}

WMData *WMRetainData(WMData *aData)
{
  aData->retainCount++;
  return aData;
}

void WMReleaseData(WMData *aData)
{
  aData->retainCount--;
  if (aData->retainCount > 0)
    return;
  if (aData->bytes != NULL && aData->destructor != NULL) {
    aData->destructor(aData->bytes);
  }
  wfree(aData);
}

/* Accessing data */

const void *WMDataBytes(WMData *aData)
{
  return aData->bytes;
}

/* Testing data */

unsigned WMGetDataLength(WMData *aData)
{
  return aData->length;
}

/* Modifying data */

void WMSetDataFormat(WMData *aData, unsigned format)
{
  aData->format = format;
}

unsigned WMGetDataFormat(WMData *aData)
{
  return aData->format;
}
