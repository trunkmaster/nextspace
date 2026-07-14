/* 
   nsimage-tiff.h 

   Functions for dealing with tiff images

   Copyright (C) 1996-2024 Free Software Foundation, Inc.
   
   Written by:  Adam Fedor <fedor@gnu.org>
   Date: Feb 1996
   
   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/ 

/*
    Warning:  This header file should not be used for reading and
    writing tiff files.  You should use the NSImage and NSBitmapImageRep
    classes for general reading/writing of tiff files.
*/

#ifndef _NSIMAGE_TIFF_H
#define _NSIMAGE_TIFF_H

#include <tiffio.h>
#include <inttypes.h>

/* Structure to store common information about a tiff. */
typedef struct
{
  uint16_t  numImages;	      /* number of images in tiff */
  uint16_t  imageNumber;      /* number of current image */
  uint32_t  subfileType;
  uint32_t  width;
  uint32_t  height;
  uint16_t  bitsPerSample;    /* number of bits per data channel */
  uint16_t  samplesPerPixel;  /* number of channels per pixel */
  uint16_t  planarConfig;     /* meshed or separate */
  uint16_t  photoInterp;      /* photometric interpretation of bitmap data, */
  uint16_t  compression;
  uint16_t  extraSamples;     /* Alpha */
  int       assocAlpha;
  int       quality;	      /* compression quality (for jpeg) 1 to 255 */
  int       error;
  float     xdpi;
  float     ydpi;
  char      isBigEndian;      /* meaningful only for 16 & 32 bit depths */
  char      is16Bit;
  char      is32Bit;
} NSTiffInfo; 

typedef struct
{
  uint32_t size;
  uint16_t *red;
  uint16_t *green;
  uint16_t *blue;
} NSTiffColormap;

typedef char* realloc_data_callback(char* data, long size);

extern TIFF* NSTiffOpenDataRead(const char* data, long size);
extern TIFF* NSTiffOpenDataWrite(char **data, long *size);
extern int   NSTiffClose(TIFF* image);

extern int   NSTiffGetImageCount(TIFF* image);
extern int   NSTiffWrite(TIFF *image, NSTiffInfo *info, unsigned char *data);
extern int   NSTiffRead(TIFF *image, NSTiffInfo *info, unsigned char *data);
extern NSTiffInfo* NSTiffGetInfo(int imageNumber, TIFF* image);

extern NSTiffColormap* NSTiffGetColormap(TIFF* image);

extern int NSTiffIsCodecConfigured(unsigned int codec);

#endif // _NSIMAGE_TIFF_H

