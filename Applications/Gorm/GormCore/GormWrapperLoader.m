/* GormWrapperLoader
 *
 * These classes handle loading different formats into the
 * document's data structures.
 *
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author:      Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:        2006
 *
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <GormCore/GormWrapperLoader.h>
#include <GormCore/GormDocument.h>
#include <GormCore/GormPrivate.h>
#include <GormCore/GormSound.h>
#include <GormCore/GormImage.h>

static NSMutableDictionary *_wrapperLoaderMap = nil;
static GormWrapperLoaderFactory *_sharedWrapperLoaderFactory = nil;

@implementation GormWrapperLoader
+ (NSString *) fileType
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void) saveSCMDirectory: (NSDictionary *) fileWrappers
{
  [document setSCMWrapper: [fileWrappers objectForKey: @".svn"]];
  if([document scmWrapper] == nil)
    {
      [document setSCMWrapper: [fileWrappers objectForKey: @"CVS"]];
    }
}

- (BOOL) loadFileWrapper: (NSFileWrapper *)wrapper withDocument: (GormDocument *)doc
{
  NS_DURING
    {
      NSMutableArray *images = [NSMutableArray array];
      NSMutableArray *sounds = [NSMutableArray array];
      NSArray *imageFileTypes = [NSImage imageFileTypes];
      NSArray *soundFileTypes = [NSSound soundUnfilteredFileTypes];

      document = doc; // don't retain...
      if ([wrapper isDirectory])
	{
	  NSDictionary *fileWrappers = nil;
	  NSString *key = nil;
	  NSEnumerator *enumerator = nil;
	  
	  key = nil;
	  fileWrappers = [wrapper fileWrappers];
	  
	  [self saveSCMDirectory: fileWrappers];
	  
	  enumerator = [fileWrappers keyEnumerator];
	  while((key = [enumerator nextObject]) != nil)
	    {
	      NSFileWrapper *fw = [fileWrappers objectForKey: key];

	      //
	      // Images with .info can be loaded, but we have a file
	      // called data.info which is metadata for Gorm.  Don't load it.
	      //
	      if ( [key isEqualToString: @"data.info"] == YES )
		{
		  continue;
		}
	      
	      if([fw isRegularFile])
		{
		  NSData *fileData = [fw regularFileContents];
		  if ([imageFileTypes containsObject: [key pathExtension]])
		    {
		      [images addObject: [GormImage imageForData: fileData 
						    withFileName: key 
						    inWrapper: YES]];
		    }
		  else if ([soundFileTypes containsObject: [key pathExtension]])
		    {
		      [sounds addObject: [GormSound soundForData: fileData 
						    withFileName: key 
						    inWrapper: YES]];
		    }
		}
	    }
	}
      else if ([wrapper isRegularFile]) // handle wrappers which are just plain files...
        {
          
        }
      else
        {
          NSLog(@"Unsupported wrapper type");
        }

      // fill in the images and sounds arrays...
      [document setSounds: sounds];
      [document setImages: images];
    }
  NS_HANDLER
    {
      return NO;
    }
  NS_ENDHANDLER;

  return YES;
}
@end

@implementation GormWrapperLoaderFactory 
+ (void) initialize
{
  NSArray *classes = GSObjCAllSubclassesOfClass([GormWrapperLoader class]);
  NSEnumerator *en = [classes objectEnumerator];
  Class cls = nil;
  
  while((cls = [en nextObject]) != nil)
    {
      [self registerWrapperLoaderClass: cls];
    }
}

+ (void) registerWrapperLoaderClass: (Class)aClass
{
  if(_wrapperLoaderMap == nil)
    {
      _wrapperLoaderMap = [[NSMutableDictionary alloc] initWithCapacity: 5];
    }

  [_wrapperLoaderMap setObject: aClass forKey: (NSString *)[aClass fileType]];
}

+ (GormWrapperLoaderFactory *) sharedWrapperLoaderFactory
{
  if(_sharedWrapperLoaderFactory == nil)
    {
      _sharedWrapperLoaderFactory = [[self alloc] init];
    }
  return _sharedWrapperLoaderFactory;
}

- (id) init
{
  if((self = [super init]) != nil)
    {
      if(_sharedWrapperLoaderFactory == nil)
	{
	  _sharedWrapperLoaderFactory = self;
	}
    }
  return self;
}

- (id<GormWrapperLoader>) wrapperLoaderForType: (NSString *) type
{
  Class cls = [_wrapperLoaderMap objectForKey: type];
  id<GormWrapperLoader> obj = AUTORELEASE([[cls alloc] init]);
  return obj;
}
@end

