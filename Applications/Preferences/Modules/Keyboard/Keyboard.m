/*
  Controller class for Keyboard preferences bundle

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
#import <AppKit/NSView.h>
#import <AppKit/NSBox.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSBrowser.h>
#import <AppKit/NSMatrix.h>

#import <NXFoundation/NXDefaults.h>

#import "Keyboard.h"

@implementation Keyboard

static NSBundle                 *bundle = nil;
static NSUserDefaults           *defaults = nil;
static NSMutableDictionary      *domain = nil;

- (id)init
{
  self = [super init];
  
  defaults = [NSUserDefaults standardUserDefaults];
  domain = [[defaults persistentDomainForName:NSGlobalDomain] mutableCopy];

  bundle = [NSBundle bundleForClass:[self class]];
  NSString *imagePath = [bundle pathForResource:@"Keyboard" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];
      
  return self;
}

- (void)dealloc
{
  NSLog(@"KeyboardPrefs -dealloc");
  [image release];
  [super dealloc];
}

- (void)awakeFromNib
{
  [view retain];
  [window release];

  [repeatBox retain];
  [repeatBox removeFromSuperview];
  [layoutsBox retain];
  [layoutsBox removeFromSuperview];
  [shortcutsBox retain];
  [shortcutsBox removeFromSuperview];

  [[sectionsMtrx cellWithTag:0] setRefusesFirstResponder:YES];
  [[sectionsMtrx cellWithTag:1] setRefusesFirstResponder:YES];
  [[sectionsMtrx cellWithTag:2] setRefusesFirstResponder:YES];
  [[sectionsMtrx cellWithTag:3] setRefusesFirstResponder:YES];

  [shortcutsBrowser loadColumnZero];
  [shortcutsBrowser setTitle:@"Action" ofColumn:0];
  [shortcutsBrowser setTitle:@"Shortcut" ofColumn:1];

  [self sectionButtonClicked:sectionsMtrx];
}

- (NSView *)view
{
  if (view == nil)
    {
      if (![NSBundle loadNibNamed:@"Keyboard" owner:self])
        {
          NSLog (@"Could not load Keyboard.gorm file.");
          return nil;
        }
    }
  
  return view;
}

- (NSString *)buttonCaption
{
  return @"Keyboard Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

//
// Action methods
//
- (void)sectionButtonClicked:(id)sender
{
  switch ([[sender selectedCell] tag])
    {
    case 0: // Key Repeat
      [sectionBox setContentView:repeatBox];
      break;
    case 1: // Layouts
      [sectionBox setContentView:layoutsBox];
      [self parseXkbBaseList];
      break;
    case 2: // Shortcuts
      [sectionBox setContentView:shortcutsBox];
      break;
    default:
      NSLog(@"Keyboard.preferences: Unknow section button was clicked!");
    }
}

@end

@implementation Keyboard (KeyRepeat)

- (void)repeatAction:(id)sender
{
  NXDefaults 		*defs = [[NXDefaults alloc] initWithUserDefaults];
  NSMutableDictionary	*keybDefs;
  
  keybDefs = [[defs objectForKey:@"NXKeyboard"] mutableCopy];
  if (sender == initialRepeatMtrx)
    { // NXKeyboard-InitialKeyRepeat - delay in milliseconds before repeat
      [keybDefs setObject:[NSNumber numberWithInt:[[sender selectedCell] tag]]
                   forKey:@"InitialKeyRepeat"];
    }
  else if (sender == repeatRateMtrx)
    { // NXKeyboard - RepeatRate - num of repeates per second
      [keybDefs setObject:[NSNumber numberWithInt:[[sender selectedCell] tag]]
                   forKey:@"RepeatRate"];
    }

  [defs setObject:keybDefs forKey:@"NXKeyboard"];
  [defs synchronize];
}

@end

@implementation Keyboard (XKB)

#define XKB_BASE_LST @"/usr/share/X11/xkb/rules/base.lst"

- (void)parseXkbBaseList
{
  NSMutableDictionary	*dict = [[NSMutableDictionary alloc] init];
  NSMutableDictionary	*modeDict = [[NSMutableDictionary alloc] init];
  NSString		*baseLst;
  NSScanner		*scanner;
  NSString		*lineString = @" ";
  NSString		*sectionName, *fileName;

  baseLst = [NSString stringWithContentsOfFile:XKB_BASE_LST];
  scanner = [NSScanner scannerWithString:baseLst];

  while ([scanner scanUpToString:@"\n" intoString:&lineString] == YES)
    {
      // New section start encountered
      if ([lineString characterAtIndex:0] == '!')
        {
          if ([[modeDict allKeys] count] > 0)
            {
              [dict setObject:[modeDict copy] forKey:sectionName];
              
              fileName = [NSString
                           stringWithFormat:@"/Users/me/Library/XKB_%@.list",
                          sectionName];
              [modeDict writeToFile:fileName atomically:YES];
              // NSLog(@"%@: %@", sectionName, modeDict);
              [modeDict removeAllObjects];
              [modeDict release];
              modeDict = [[NSMutableDictionary alloc] init];
            }
          
          sectionName = [lineString substringFromIndex:2];
          
          NSLog(@"Keyboard: found section: %@", sectionName);
        }
      else
        { // Parse line and add into 'modeDict' dictionary
          NSMutableArray	*lineComponents;
          NSString		*key;
          NSMutableString	*value = [[NSMutableString alloc] init];
          BOOL			add = NO;
          
          lineComponents = [[lineString componentsSeparatedByString:@" "]
                             mutableCopy];
          key = [lineComponents objectAtIndex:0];

          for (int i = 1; i < [lineComponents count]; i++)
            {
              if (add == NO &&
                  ![[lineComponents objectAtIndex:i] isEqualToString:@""])
                {
                  add = YES;
                  [value appendFormat:@"%@", [lineComponents objectAtIndex:i]];
                }
              else if (add == YES)
                [value appendFormat:@" %@", [lineComponents objectAtIndex:i]];
            }
          
          [modeDict setObject:value forKey:key];
          
          [value release];
          [lineComponents release];
        }
    }
  
  [dict setObject:[modeDict copy] forKey:sectionName];
  fileName = [NSString stringWithFormat:@"/Users/me/Library/XKB_%@.list",
                       sectionName];
  [modeDict writeToFile:fileName atomically:YES];
  [modeDict removeAllObjects];
  [modeDict release];

  [dict writeToFile:@"/Users/me/Library/Keyboards.list" atomically:YES];
  [dict release];
}

@end
