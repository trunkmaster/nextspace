/* main.m

   Copyright (C) 1999 Free Software Foundation, Inc.

   Author:  Laurent Julliard <laurent@julliard-online.org>
   Date: Nov 2001
   
   This file is part of GNUstep.
   
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
*/

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>
#include <GormCore/GormCore.h>

/* -----------------------------------------------------------
 * Some additions to the NSNumberFormatter Class specific to Gorm
 * -----------------------------------------------------------*/
NSArray *predefinedNumberFormats;
int defaultNumberFormatIndex = 0;

@implementation NSNumberFormatter (GormAdditions)

+ (int) formatCount
{
  return [predefinedNumberFormats count];
}

+ (NSString *) formatAtIndex: (int)i
{
  return [[predefinedNumberFormats objectAtIndex:i] objectAtIndex:0];
}

+ (NSString *) positiveFormatAtIndex: (int)i
{
  NSString *fmt =[[predefinedNumberFormats objectAtIndex:i] objectAtIndex:0];
  
  return [ [fmt componentsSeparatedByString:@";"] objectAtIndex:0];
}

+ (NSString *) zeroFormatAtIndex: (int)i
{
  NSString *fmt =[[predefinedNumberFormats objectAtIndex:i] objectAtIndex:0];
  
  return [ [fmt componentsSeparatedByString:@";"] objectAtIndex:1];
}

+ (NSString *) negativeFormatAtIndex: (int)i
{
  NSString *fmt =[[predefinedNumberFormats objectAtIndex:i] objectAtIndex:0];
  
  return [ [fmt componentsSeparatedByString:@";"] objectAtIndex:2];
}

+ (NSDecimalNumber *) positiveValueAtIndex: (int)i
{
   return [NSDecimalNumber decimalNumberWithString:
                [[predefinedNumberFormats objectAtIndex:i] objectAtIndex:1] ];
}

+ (NSDecimalNumber *) negativeValueAtIndex: (int)i
{
   return [NSDecimalNumber decimalNumberWithString:
                [[predefinedNumberFormats objectAtIndex:i] objectAtIndex:2] ];
}

+ (NSInteger) indexOfFormat: (NSString *) format
{
  int i;
  NSString *fmt;
  int count = [predefinedNumberFormats count];

  for (i=0;i<count;i++)
    {
      fmt = [[predefinedNumberFormats objectAtIndex:i] objectAtIndex:0];
      if ([fmt isEqualToString: format])
        {
          return i;
        }
    }
  
  return NSNotFound;
}

+ (NSString *) defaultFormat
{
  return [NSNumberFormatter formatAtIndex:defaultNumberFormatIndex];
}


+ (id) defaultFormatValue
{
  return [NSNumberFormatter positiveValueAtIndex:defaultNumberFormatIndex];
}

- (NSString *) zeroFormat
{
  NSArray *fmts = [[self format] componentsSeparatedByString:@";"];

  if ([fmts count] != 3)
    return @"";
  else
    return [fmts objectAtIndex:1];
}

@end

/* -----------------------------------------------------------
 * Some additions to the NSDateFormatter Class specific to Gorm
 * -----------------------------------------------------------*/
NSArray *predefinedDateFormats;
int defaultDateFormatIndex = 3;

@implementation NSDateFormatter (GormAdditions)

+ (int) formatCount
{
  return [predefinedDateFormats count];
}

+ (NSString *) formatAtIndex: (int)index
{
  return [predefinedDateFormats objectAtIndex: index];
}

+ (NSInteger) indexOfFormat: (NSString *) format
{
  return [predefinedDateFormats indexOfObject: format];
}

+ (NSString *) defaultFormat
{
  return [NSDateFormatter formatAtIndex:defaultDateFormatIndex]; 
}

+ (id) defaultFormatValue
{
  return [NSCalendarDate calendarDate];
}

@end

/* -----------------------------------------------------------
 * The Data Palette (Scroll Text View, formatters, Combo box,...)
 *
 * -----------------------------------------------------------*/
@interface DataPalette: IBPalette <IBViewResourceDraggingDelegates>
@end

@implementation DataPalette

+ (void) initialize
{
  predefinedNumberFormats = [[NSArray alloc] initWithObjects:
       [NSArray arrayWithObjects: @"$#,##0.00;0.00;-$#,##0.00",@"9999.99",@"-9999.99",nil],
       [NSArray arrayWithObjects: @"$#,##0.00;0.00;[Red]($#,##0.00)",@"9999.99",@"-9999.99",nil],
       [NSArray arrayWithObjects: @"0.00;0.00;-0.00",@"9999.99",@"-9999.99",nil],
       [NSArray arrayWithObjects: @"0;0;-0",@"100",@"-100",nil],
       [NSArray arrayWithObjects: @"00000;00000;-00000",@"100",@"-100",nil],
       [NSArray arrayWithObjects: @"0%;0%;-0%",@"100",@"-100",nil],
       [NSArray arrayWithObjects: @"0.00%;0.00%;-0.00%",@"99.99",@"-99.99",nil],
       nil];

  predefinedDateFormats = [[NSArray alloc] initWithObjects: @"%c",@"%A, %B %e, %Y",
                         @"%B %e, %Y", @"%e %B %Y", @"%m/%d/%y",
                         @"%b %d, %Y", @"%B %H", @"%d %b %Y",
                         @"%H:%M:%S", @"%I:%M",nil];
}

- (id) init
{
  if((self = [super init]) != nil)
    {
      // Make ourselves a delegate, so that when the formatter is dragged in, 
      // this code is called...
      [NSView registerViewResourceDraggingDelegate: self];

      // subscribe to the notification...      
      [[NSNotificationCenter defaultCenter]
	addObserver: self
	selector: @selector(willInspectObject:)
	name: IBWillInspectObjectNotification
	object: nil];
      
    }
  
  return self;
}

- (void) dealloc
{
  [NSView unregisterViewResourceDraggingDelegate: self];
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  [super dealloc];
}

- (void) finishInstantiate
{ 

  NSView	*contents;
  NSTextView	*tv;
  id		v;
  NSNumberFormatter *nf;
  NSDateFormatter *df;
  NSRect rect;
  

  originalWindow = [[NSWindow alloc] initWithContentRect: 
				       NSMakeRect(0, 0, 272, 192)
				       styleMask: NSBorderlessWindowMask 
					 backing: NSBackingStoreRetained
					   defer: NO];
  [originalWindow setTitle: @"Data Views"];
  contents = [originalWindow contentView];

/*******************/
/* First Column... */
/*******************/


  // NSScrollView
  v = [[NSScrollView alloc] initWithFrame: NSMakeRect(20, 22, 113, 150)];
  [v setHasVerticalScroller: YES];
  [v setHasHorizontalScroller: NO];
  [[(NSScrollView *)v contentView] setAutoresizingMask: NSViewHeightSizable 
        		    | NSViewWidthSizable];
  [[(NSScrollView *)v contentView] setAutoresizesSubviews:YES];
  [v setBorderType: NSBezelBorder];

  rect = [[(NSScrollView *)v contentView] frame];

  tv = [[NSTextView alloc] initWithFrame: rect];
  [tv setMinSize: NSMakeSize(108.0, 143.0)];
  [tv setMaxSize: NSMakeSize(1.0E7,1.0E7)];
  [tv setVerticallyResizable: YES];
  [tv setHorizontallyResizable: NO];
  [tv setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable];
  [tv setSelectable: YES];
  [tv setEditable: YES];
  [tv setRichText: YES];
  [tv setImportsGraphics: YES];

  // [[tv textContainer] setContainerSize:NSMakeSize(rect.size.width,1e7)];
  // [[tv textContainer] setWidthTracksTextView:YES];
  
  [v setDocumentView:tv];
  [contents addSubview: v];
  RELEASE(v);
  RELEASE(tv);

/********************/
/* Second Column... */
/********************/


  // NSImageView
  v = [[NSImageView alloc] initWithFrame: NSMakeRect(153, 98, 96, 72)];
  [v setImageFrameStyle: NSImageFramePhoto]; //FramePhoto not implemented
  [v setImageScaling: NSScaleProportionally];
  [v setImageAlignment: NSImageAlignCenter];
  [v setImage: [NSImage imageNamed: @"Sunday_seurat.tiff"]];
  [contents addSubview: v];
  RELEASE(v);

  /* Number and Date formatters. Note that they have a specific drag type.
     * All other palette objects are views and use the default  IBViewPboardType
     * drag type
     */
  v = [[NSImageView alloc] initWithFrame: NSMakeRect(153, 48, 43, 43)];
  [v setImageFrameStyle: NSImageFramePhoto];
  [v setImageScaling: NSScaleProportionally];
  [v setImageAlignment: NSImageAlignCenter];
  [v setImage: [NSImage imageNamed: @"number_formatter.tiff"]];
  [contents addSubview: v];

  nf = [[NSNumberFormatter alloc] init];
  [nf setFormat: [NSNumberFormatter defaultFormat]];

  [self associateObject: nf type: IBFormatterPboardType with: v];
  RELEASE(v);

  v = [[NSImageView alloc] initWithFrame: NSMakeRect(206, 48, 43, 43)];
  [v setImageFrameStyle: NSImageFramePhoto];
  [v setImageScaling: NSScaleProportionally];
  [v setImageAlignment: NSImageAlignCenter];
  [v setImage: [NSImage imageNamed: @"date_formatter.tiff"]];
  [contents addSubview: v];

  df = [[NSDateFormatter alloc]
           initWithDateFormat: [NSDateFormatter defaultFormat]
         allowNaturalLanguage: NO];

  [self associateObject: df type: IBFormatterPboardType with: v];
  RELEASE(v);
  
  // NSComboBox
  v = [[NSComboBox alloc] initWithFrame: NSMakeRect(153, 22, 96, 21)];
  [contents addSubview: v];
  RELEASE(v);
}

- (void) willInspectObject: (NSNotification *)notification
{
  id o = [notification object];
  if([o respondsToSelector: @selector(cell)])
    {
      id cell = [o cell];
      if([cell respondsToSelector: @selector(formatter)])
	{
	  id formatter = [o formatter];
	  if([formatter isKindOfClass: [NSFormatter class]])
	    {
	      NSString *ident = NSStringFromClass([formatter class]);
	      [[IBInspectorManager sharedInspectorManager]
		addInspectorModeWithIdentifier: ident 
		forObject: o
		localizedLabel: _(@"Formatter")
		inspectorClassName: [formatter inspectorClassName]
		ordering: -1.0];      
	    }
	}
    }
}

// view resource dragging delegate...

/**
 * Ask if the view accepts the object.
 */
- (BOOL) acceptsViewResourceFromPasteboard: (NSPasteboard *)pb
                                 forObject: (id)obj
                                   atPoint: (NSPoint)p
{
  return ([obj respondsToSelector: @selector(setFormatter:)] && 
	  [[pb types] containsObject: IBFormatterPboardType]);
}

/**
 * Perform the action of depositing the object.
 */
- (void) depositViewResourceFromPasteboard: (NSPasteboard *)pb
                                  onObject: (id)obj
                                   atPoint: (NSPoint)p
{
  NSData *data = [pb dataForType: IBFormatterPboardType];
  id array = [NSUnarchiver unarchiveObjectWithData: data];
  
  if(array != nil)
    {
      if([array count] > 0)
	{
	  id formatter = [array objectAtIndex: 0];

	  // Add the formatter if the object accepts one...
	  if([obj respondsToSelector: @selector(setFormatter:)])
	    {
	      // Touch the document...
	      [[(id<IB>)[NSApp delegate] activeDocument] touch];

	      [obj setFormatter: formatter];
	      RETAIN(formatter);
	      if ([formatter isMemberOfClass: [NSNumberFormatter class]])
		{
		  id fieldValue = [NSNumber numberWithFloat: 1.123456789];
		  [obj setStringValue: [fieldValue stringValue]];
		  [obj setObjectValue: fieldValue];
		}
	      else if ([formatter isMemberOfClass: [NSDateFormatter class]])
		{
		  id fieldValue = [NSDate date];
		  [obj setStringValue: [fieldValue description]];
		  [obj setObjectValue: fieldValue];
		}	      
	    }
	}
    }
}

/**
 * Should we draw the connection frame when the resource is
 * dragged in?
 */
- (BOOL) shouldDrawConnectionFrame
{
  return NO;
}

/**
 * Types of resources accepted by this view.
 */
- (NSArray *)viewResourcePasteboardTypes
{
  return [NSArray arrayWithObject: IBFormatterPboardType];
}

@end
