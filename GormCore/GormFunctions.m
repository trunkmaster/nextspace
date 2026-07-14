/* GormFunctions.m
 *
 * Copyright (C) 2004 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2004
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

#include "GormFunctions.h"
#include "GormViewEditor.h"
#include "GormClassPanelController.h"

// find all subitems for the given items...
void findAllWithArray(id item, NSMutableArray *array)
{
  [array addObject: item];
  if([item isKindOfClass: [NSMenuItem class]])
    {
      if([item hasSubmenu])
	{
	  NSMenu *submenu = [item submenu];
	  NSArray *items = [submenu itemArray];
	  NSEnumerator *e = [items objectEnumerator];
	  id i = nil;

	  [array addObject: submenu];
	  while((i = [e nextObject]) != nil)
	    {
	      findAllWithArray(i, array);
	    }
	}
    } 
}

// find all sub items for the selections...
NSArray* findAllSubmenus(NSArray *array)
{
  NSEnumerator *e = [array objectEnumerator];
  id i = nil;
  NSMutableArray *results = [[NSMutableArray alloc] init];

  while((i = [e nextObject]) != nil)
    {
      findAllWithArray(i, results);
    }

  return results;
}

NSArray* findAll(NSMenu *menu)
{
  NSArray *items = [menu itemArray];
  return findAllSubmenus(items);
}

void subviewsForView(NSView *view, NSMutableArray *array)
{
  if(view != nil)
    {
      NSArray *subviews = [view subviews];
      NSEnumerator *en = [subviews objectEnumerator];
      NSView *aView = nil;

      // if it's not me and it's not and editor, include it in the list of
      // things to be deleted from the document.
      if(![view isKindOfClass: [GormViewEditor class]]) 
	{
	  [array addObject: view];
	}

      while((aView = [en nextObject]) != nil)
	{
	  subviewsForView( aView, array );
	}
    }
}

NSArray *allSubviews(NSView *view)
{
  NSMutableArray *views = [NSMutableArray array];
  subviewsForView( view, views );
  [views removeObject: view];
  return views;
}

// cut the text...  code taken from GWorkspace, by Enrico Sersale
static inline NSString *cutText(NSString *filename, id label, NSInteger lenght)
{
  NSString *cutname = nil;
  NSString *reststr = nil;
  NSString *dots;
  NSFont *labfont;
  NSDictionary *attr;
  float w, cw, dotslenght;
  NSInteger i;
  
  cw = 0;
  labfont = [label font];
  
  attr = [NSDictionary dictionaryWithObjectsAndKeys: 
			 labfont, NSFontAttributeName, nil];  
  
  dots = @"...";  
  dotslenght = [dots sizeWithAttributes: attr].width;  
  w = [filename sizeWithAttributes: attr].width;
  
  if (w > lenght) 
    {
      i = 0;
      while (cw <= (lenght - dotslenght)) 
	{
	  if (i == [filename cStringLength]) 
	    {
	      break;
	    }
	  cutname = [filename substringToIndex: i];
	  reststr = [filename substringFromIndex: i];
	  cw = [cutname sizeWithAttributes: attr].width;
	  i++;
	}	
      if ([cutname isEqual: filename] == NO) 
	{      
	  if ([reststr cStringLength] <= 3) 
	    { 
	      return filename;
	    } 
	  else 
	    {
	      cutname = [cutname stringByAppendingString: dots];
	    }
	} 
      else 
	{
	  return filename;
	}	
    } 
  else 
    {
      return filename;
    }
  
  return cutname;
}

NSString *cutFileLabelText(NSString *filename, id label, NSInteger length)
{
  if (length > 0) 
    {
      return cutText(filename, label, length);
    }
  return filename;
}

NSSize defaultCellSize()
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults]; 
  NSInteger width = [defaults integerForKey: @"CellSizeWidth"];
  NSSize size = NSMakeSize(width, 72);
  return size;
}

NSColor *colorFromDict(NSDictionary *dict)
{
  if(dict != nil)
    {
      return [NSColor colorWithCalibratedRed: [[dict objectForKey: @"red"] floatValue]
		      green: [[dict objectForKey: @"green"] floatValue]
		      blue: [[dict objectForKey: @"blue"] floatValue]
		      alpha: [[dict objectForKey: @"alpha"] floatValue]];
    }
  return nil;
}

NSDictionary *colorToDict(NSColor *color)
{
  if(color != nil)
    {
      NSMutableDictionary *dict = [NSMutableDictionary dictionary];
      CGFloat red, green, blue, alpha;
      NSNumber *fred = nil;
      NSNumber *fgreen = nil;
      NSNumber *fblue = nil;
      NSNumber *falpha = nil;
      
      [color getRed: &red
	     green: &green
	     blue: &blue
	     alpha: &alpha];
      
      fred   = [NSNumber numberWithFloat: red];
      fgreen = [NSNumber numberWithFloat: green];
      fblue  = [NSNumber numberWithFloat: blue];
      falpha = [NSNumber numberWithFloat: alpha];
      
      [dict setObject: fred   forKey: @"red"];
      [dict setObject: fgreen forKey: @"green"];
      [dict setObject: fblue  forKey: @"blue"];
      [dict setObject: falpha forKey: @"alpha"];
      
      return dict;
    }
  return nil;
}

NSArray *systemImagesList()
{
  NSString *lib = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) lastObject];

  NSString *path = [lib stringByAppendingPathComponent: @"Images"];
  NSArray *contents = [[NSFileManager defaultManager] directoryContentsAtPath: path];
  NSEnumerator *en = [contents objectEnumerator];
  NSMutableArray *result = [NSMutableArray array];
  id obj;
  NSArray *fileTypes = [NSImage imageFileTypes];

  while((obj = [en nextObject]) != nil)
    {
      if([fileTypes containsObject: [obj pathExtension]])
	{
	  NSString *pathString = [path stringByAppendingPathComponent: obj];
	  [result addObject: pathString];
	}
    }

  return result;
}

NSArray *systemSoundsList()
{
  NSString *lib = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES) lastObject];
  NSString *path = [lib stringByAppendingPathComponent: @"Sounds"];
  NSArray *contents = [[NSFileManager defaultManager] directoryContentsAtPath: path];
  NSEnumerator *en = [contents objectEnumerator];
  NSMutableArray *result = [NSMutableArray array];
  id obj;
  NSArray *fileTypes = [NSSound soundUnfilteredFileTypes];

  while((obj = [en nextObject]) != nil)
    {
      if([fileTypes containsObject: [obj pathExtension]])
	{
	  NSString *pathString = [path stringByAppendingPathComponent: obj];
	  [result addObject: pathString];
	}
    }

  return result;
}

int appVersion(long a, long b, long c)
{
  return (((a) << 16)+((b) << 8) + (c));
}

NSString *promptForClassName(NSString *title, NSArray *classes)
{
  GormClassPanelController *cpc = AUTORELEASE([[GormClassPanelController alloc] initWithTitle: title classList: classes]);
  return [cpc runModal];
}

NSString *identifierString(NSString *str)
{
  NSCharacterSet  *illegal = [[NSCharacterSet 
				characterSetWithCharactersInString: 
				  @"_0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"] 
			       invertedSet];
  NSCharacterSet  *numeric = [NSCharacterSet 
			       characterSetWithCharactersInString:
				 @"0123456789"];
  NSCharacterSet  *white = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSRange	  r;
  NSMutableString *result;
  
  if (str == nil)
    {
      return nil;
    }

  result = [NSMutableString stringWithString: str];
  r = [result rangeOfCharacterFromSet: illegal];
  while (r.length > 0)
    {
      [result deleteCharactersInRange: r];
      r = [result rangeOfCharacterFromSet: illegal];
    }
  r = [result rangeOfCharacterFromSet: numeric];
  while (r.length > 0 && r.location == 0)
    {
      [result deleteCharactersInRange: r];
      r = [result rangeOfCharacterFromSet: numeric];
    }
  r = [result rangeOfCharacterFromSet: white];
  while (r.length > 0 && r.location == 0)
    {
      [result deleteCharactersInRange: r];
      r = [result rangeOfCharacterFromSet: white];
    }

  // check the result's length.
  if([result length] == 0)
    {
      result = [@"dummyIdentifier" mutableCopy];
    }

  return result;
}

NSString *formatAction(NSString *action)
{
  NSString *temp = identifierString(action);
  NSString *identifier = [temp stringByAppendingString: @":"];
  return identifier;
}

NSString *formatOutlet(NSString *outlet)
{
  NSString *identifier = identifierString(outlet);
  return identifier;
}

/**
 * This method returns an array listing the names of all the
 * instance methods available to obj, whether they
 * belong to the class of obj or one of its superclasses.<br />
 * If obj is a class, this returns the class methods.<br />
 * Returns nil if obj is nil.
 */
NSArray *_GSObjCMethodNamesForClass(Class class, BOOL collect)
{
  if (class == nil)
    {
      return nil;
    }
  return GSObjCMethodNames((id)&class, collect);
}

/**
 * This method returns an array listing the names of all the
 * instance variables present in the instance obj, whether they
 * belong to the class of obj or one of its superclasses.<br />
 * Returns nil if obj is nil.
 */
NSArray *_GSObjCVariableNames(Class class, BOOL collect)
{
  if (class == nil)
    {
      return nil;
    }
  return GSObjCVariableNames((id)&class, collect);
}


NSRect minimalContainerFrame(NSArray *views)
{
  NSEnumerator *en = [views objectEnumerator];
  id o = nil;
  float w = 0.0;
  float h = 0.0;

  while((o = [en nextObject]) != nil)
    {
      NSRect frame = [o frame];
      float nw = frame.origin.x + frame.size.width;
      float nh = frame.origin.y + frame.size.height;

      if(nw > w)
	w = nw;

      if(nh > h)
	h = nh;
    }

  return NSMakeRect(0,0,w,h);
}
