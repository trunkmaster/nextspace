/** <title>GormImage</title>

   <abstract>This class is a placeholder for a real image.</abstract>
   
   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: Dec 2004
   
   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/ 

#ifndef INCLUDED_GormImage_h
#define INCLUDED_GormImage_h

#include <Foundation/Foundation.h>

#include <GormCore/GormResource.h>

@class NSString, NSImage;

@interface GormImage : GormResource
{
  NSImage  *image;
  NSImage  *smallImage;
}

/**
 * Initialize with image data located at path.
 */
+ (GormImage *) imageForPath: (NSString *)path;

/**
 * Initialize with image data located at path.  Mark it as in the
 * wrapper depending on the value of flag.
 */
+ (GormImage *) imageForPath: (NSString *)path inWrapper: (BOOL)flag;

/**
 * Initialize with image data.  Mark it as in the
 * wrapper depending on the value of flag.
 */
+ (GormImage*)imageForData: (NSData *)aData withFileName: (NSString *)aName inWrapper: (BOOL)flag;

/**
 * A thumbnail of the image.
 */
- (NSImage *)image;

/**
 * The full sized image.
 */
- (NSImage *)normalImage;
@end

/*
 * A category which will allow us to set whether or not 
 * an image is archived by reference, or directly.
 */
@interface NSImage (GormNSImageAddition)
/**
 * Set to YES, if the image should be archived by name only, NO otherwise.
 */
- (void) setArchiveByName: (BOOL) archiveByName;

/**
 * Returns YES, if the image should be archived by name only, NO otherwise.
 */
- (BOOL) archiveByName;
@end

#endif
