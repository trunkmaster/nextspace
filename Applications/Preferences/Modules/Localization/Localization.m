/*
  Localization.m

  Controller class for Localization preferences bundle

  Author:	Sergii Stoian <stoyan255@ukr.net>
  Date:		28 Nov 2015

  This program is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public License as
  published by the Free Software Foundation; either version 2 of
  the License, or (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public
  License along with this program; if not, write to:

  	Free Software Foundation, Inc.
  	59 Temple Place - Suite 330
  	Boston, MA  02111-1307, USA
*/
#import <Foundation/Foundation.h>

#import <AppKit/NSApplication.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSScrollView.h>
#import <AppKit/NSScroller.h>
#import <AppKit/NSTableView.h>
#import <AppKit/NSTableColumn.h>
#import <AppKit/NSPasteboard.h>

#import "Localization.h"

@implementation Localization

static NSBundle                 *bundle = nil;
static NSUserDefaults           *defaults = nil;
static NSMutableDictionary      *domain = nil;

- (id)init
{
  self = [super init];
  
  defaults = [NSUserDefaults standardUserDefaults];
  domain = [[defaults persistentDomainForName:NSGlobalDomain] mutableCopy];

  bundle = [NSBundle bundleForClass:[self class]];
  NSString *imagePath = [bundle pathForResource:@"Localization" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];

  [self readUserDefaults];

  return self;
}

- (void)dealloc
{
  NSLog(@"Localization - dealloc");
  [domain dealloc];
  [image release];
  [view release];
  
  [super dealloc];
}

// Languages = NSLanguages = (English, Esperanto, ...)
// Text Encoding = GNUSTEP_STRING_ENCODING = NSUTF8StringEncoding
// Measurement Unit = NSMeasurementUnit (Centimeters, Inches, Points, Picas)
- (void)readUserDefaults
{
  id value = nil;
  BOOL isSyncDomain = NO;

  languages = [domain objectForKey:@"NSLanguages"];
  if (!languages
      || ![languages isKindOfClass:[NSArray class]]
      || [languages count] < 1)
    {
      NSString *lPath = [bundle pathForResource:@"languages" ofType:@"list"];
      
      languages = [[NSArray alloc] initWithContentsOfFile:lPath];
      [domain setObject:languages forKey:@"NSLanguages"];
      isSyncDomain = YES;
    }

  value = [domain objectForKey:@"NSMeasurementUnit"];
  if (!value || ![value isKindOfClass:[NSString class]])
    {
      [domain setObject:@"Centimeters" forKey:@"NSMeasurementUnit"];
      isSyncDomain = YES;
    }

  if (isSyncDomain == YES)
    {
      [defaults setPersistentDomain:domain forName:@"NSGlobalDomain"];
      [defaults synchronize];
    }
}

- (void)awakeFromNib
{
  [view retain];
  [window release];

  /* Language */
  {
    [languageScrollView setHasVerticalScroller:YES];
    [languageScrollView setBorderType:NSBezelBorder];
  
    NSRect lsvFrame = [languageScrollView frame];
    languageList = [[LanguageList alloc] initWithFrame:NSMakeRect(0,0,100,100)];
    [languageList loadRowsFromArray:languages];
    [languageList setCellSize:NSMakeSize(lsvFrame.size.width-24, 17)];
    [languageList setScrollView:languageScrollView];
    [languageList setTarget:self];
    [languageList setAction:@selector(languageListChanged)];
  
    [languageScrollView setDocumentView:languageList];
    [languageScrollView setLineScroll:17.0];
    [languageList release];
  }

  /* Date & Time examples*/
  NSCalendarDate  *cDate = [NSCalendarDate date];
  NSString        *format;

  format = [defaults objectForKey:NSDateFormatString];
  [dateExample setStringValue:[cDate descriptionWithCalendarFormat:format]];
  
  format = [defaults objectForKey:NSShortDateFormatString];
  [shortDateExample setStringValue:[cDate descriptionWithCalendarFormat:format]];

  format = [defaults objectForKey:NSTimeFormatString];
  [timeExample setStringValue:[cDate descriptionWithCalendarFormat:format]];

  format = [defaults objectForKey:NSTimeDateFormatString];
  [timeDateExample setStringValue:[cDate descriptionWithCalendarFormat:format]];
  
  format = [defaults objectForKey:NSShortTimeDateFormatString];
  [shortTimeDateExample
    setStringValue:[cDate descriptionWithCalendarFormat:format]];

  /* Numbers & Currency example*/
  format = [defaults objectForKey:@"NSPositiveCurrencyFormatString"];
  [numbersExample setStringValue:format];

  /* Measurement Units */
  [unitsBtn selectItemWithTitle:[domain objectForKey:@"NSMeasurementUnit"]];
}

- (NSView *)view
{
  if (view == nil)
    {
      if (![NSBundle loadNibNamed:@"Localization" owner:self])
        {
          NSLog (@"Localization.preferences: Could not load nib, aborting.");
          return nil;
        }
    }
  
  return view;
}

- (NSString *)buttonCaption
{
  return @"Localization Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

// Actions
- (void)updateFormatExamples
{
  /* Date & Time examples*/
  NSCalendarDate  *cDate = [NSCalendarDate date];
  NSString        *format;

  [NSUserDefaults resetStandardUserDefaults];
  defaults = [NSUserDefaults standardUserDefaults];

  format = [defaults objectForKey:NSDateFormatString];
  [dateExample setStringValue:[cDate descriptionWithCalendarFormat:format]];
  
  format = [defaults objectForKey:NSShortDateFormatString];
  [shortDateExample setStringValue:[cDate descriptionWithCalendarFormat:format]];

  format = [defaults objectForKey:NSTimeFormatString];
  [timeExample setStringValue:[cDate descriptionWithCalendarFormat:format]];

  format = [defaults objectForKey:NSTimeDateFormatString];
  [timeDateExample setStringValue:[cDate descriptionWithCalendarFormat:format]];
  
  format = [defaults objectForKey:NSShortTimeDateFormatString];
  [shortTimeDateExample
    setStringValue:[cDate descriptionWithCalendarFormat:format]];

  /* Numbers & Currency example*/
  format = [defaults objectForKey:@"NSPositiveCurrencyFormatString"];
  [numbersExample setStringValue:format];
}

- (void)languageListChanged
{
  // NSLog(@"Localization-languageListChanged: %@", [languageList arrayFromRows]);
  languages = [languageList arrayFromRows];
  [domain setObject:languages forKey:@"NSLanguages"];
  [defaults setPersistentDomain:domain forName:@"NSGlobalDomain"];
  [defaults synchronize];
  [self updateFormatExamples];
}

- (void)measurementUnitChanged:(id)sender
{
  [domain setObject:[unitsBtn stringValue] forKey:@"NSMeasurementUnit"];
  [defaults setPersistentDomain:domain forName:@"NSGlobalDomain"];
  [defaults synchronize];
}

@end
