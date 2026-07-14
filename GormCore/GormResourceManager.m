/* GormViewResourceManager.m
 *
 * Copyright (C) 2005 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2005
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

#include <InterfaceBuilder/InterfaceBuilder.h>

#include "GormSound.h"
#include "GormImage.h"
#include "GormClassManager.h"
#include "GormResourceManager.h"
#include "GormGenericEditor.h"
#include "GormDocument.h"
#include "GormObjectEditor.h"

@implementation GormResourceManager

- (NSArray *) resourcePasteboardTypes
{
  return [NSArray arrayWithObjects: IBWindowPboardType, IBViewPboardType, IBMenuPboardType,
	 			    NSFilenamesPboardType, GormLinkPboardType,
				    nil];
}

- (BOOL) acceptsResourcesFromPasteboard:(NSPasteboard *)pb
{
  NSArray *types = [pb types];
  NSArray *acceptedTypes = [self resourcePasteboardTypes];
  BOOL flag = YES;
  NSInteger i;
  NSInteger c = [types count];

  if (c == 0) return NO; 
  
  flag = ([acceptedTypes firstObjectCommonWithArray:types] != nil);
  
  for (i = 0; flag && i < c; i++)
    {
      id type = [types objectAtIndex:i];

      if ([type isEqual:NSFilenamesPboardType])
        {
	  NSArray *files = [pb propertyListForType:type];
	  NSArray *acceptedFiles = [self resourceFileTypes]; 
	  NSInteger j, d;
  
	  if (!files)
	    {
	      files = [NSUnarchiver unarchiveObjectWithData:
			 [pb dataForType: NSFilenamesPboardType]];
	    }
	  for (j = 0, d = [files count]; j < d; j++)
	    {
	      NSString *ext = [[files objectAtIndex:j] pathExtension];
	      flag = [acceptedFiles containsObject:ext];
	    }
        }
      else if ([type isEqual:GormLinkPboardType])
        {
	  [(GormDocument *)document changeToViewWithTag:0];
	  return NO;
        }
    }
  return flag;
}

- (void) addResourcesFromPasteboard:(NSPasteboard *)pb
{
  NSArray *types = [pb types];
  NSArray *soundTypes = [NSSound soundUnfilteredFileTypes];
  NSArray *imageTypes = [NSImage imageFileTypes];
  NSInteger i;
  NSInteger c = [types count];
  BOOL found = NO;
  
  for (i = 0; i < c; i++)
    {
      id type = [types objectAtIndex:i];
      
      if ([type isEqual:NSFilenamesPboardType])
        {
	  NSInteger j, d;
	  NSArray *files = [pb propertyListForType:type];
	  found = YES;
	  if (!files)
	    {
	      files = [NSUnarchiver unarchiveObjectWithData:
			 [pb dataForType: NSFilenamesPboardType]];
	    }

	  for (j = 0, d = [files count]; j < d; j++)
	    {
	      NSString *file = [files objectAtIndex:j];
	      NSString *ext = [file pathExtension];
	      if ([ext isEqual:@"h"])
	        {
		  GormDocument *doc = (GormDocument *)document;
		  GormClassManager *classManager = [doc classManager];
                  NS_DURING
                    {
                      if (![classManager parseHeader: file])
                        {
                          NSString *fileName = [file lastPathComponent];
                          NSString *message;

			  message = [NSString stringWithFormat:
                                      _(@"Unable to parse class in %@"), fileName];

                          NSRunAlertPanel(_(@"Problem parsing class"),
	                                  message,
        	                          nil, nil, nil);
                    	}

		      [doc changeToViewWithTag:3];
                    }
                  NS_HANDLER
                    {
                      NSString *message = [localException reason];
                      NSRunAlertPanel(_(@"Problem parsing class"),
                                      message,
                                      nil, nil, nil);
                    }
                  NS_ENDHANDLER;
	        }
	      else if ([imageTypes containsObject:ext])
	        {
		  GormDocument *doc = (GormDocument *)document;
		  [(GormGenericEditor *)[doc viewWithTag:1]
			  addObject:[GormImage imageForPath:file]]; 
		  [doc changeToViewWithTag:1];
		}
	      else if ([soundTypes containsObject:ext])
	        {
		  GormDocument *doc = (GormDocument *)document;
		  [(GormGenericEditor *)[doc viewWithTag:2]
			  addObject:[GormSound soundForPath:file]]; 
		  [doc changeToViewWithTag:2];
	        }
	    }
	}
    }
  
  if (!found)
    {
      [super addResourcesFromPasteboard:pb];
    }
}

- (NSArray *) resourceFileTypes
{
  NSArray *types = [NSSound soundUnfilteredFileTypes];

  types = [types arrayByAddingObjectsFromArray:[NSImage imageFileTypes]];

  types = [types arrayByAddingObject:@"h"];

  return types;
}

@end
