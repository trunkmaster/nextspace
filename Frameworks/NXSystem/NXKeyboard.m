/*
  Class:               NXKeyboard
  Inherits from:       NSObject
  Class descritopn:    Keyboard configuration manipulation (type, rate, layouts)

  Copyright (C) 2017 Sergii Stoian <stoyan255@ukr.net>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import "NXKeyboard.h"
#include <X11/XKBlib.h>

NSString *InitialRepeat = @"NXKeyboardInitialKeyRepeat";
NSString *RepeatRate = @"NXKeyboardRepeatRate";
NSString *Layouts = @"NXKeyboardLayouts";
NSString *SwitchLayoutKey = @"NXKeyboardSwitchLayoutKey";

@implementation NXKeyboard : NSObject

+ (void)configureWithDefaults:(NXDefaults *)defs
{
  NSInteger initialRepeat, repeatRate;
  NXKeyboard *keyb = [NXKeyboard new];
  
  if ((initialRepeat = [defs integerForKey:InitialRepeat]) < 0)
    initialRepeat = 0;
  if ((repeatRate = [defs integerForKey:RepeatRate]) < 0)
    repeatRate = 0;
  [keyb setInitialRepeat:initialRepeat rate:repeatRate];  
}

- (NSDictionary *)_parseVariantString:(NSString *)value
{
  NSArray *comps = [value componentsSeparatedByString:@": "];
  NSArray *keys = [NSArray arrayWithObjects:@"Layout", @"Desc", nil];

  return [NSDictionary dictionaryWithObjects:comps forKeys:keys];
}

- (NSDictionary *)_xkbBaseListDictionary
{
  NSMutableDictionary	*dict = [[NSMutableDictionary alloc] init];
  NSMutableDictionary	*modeDict = [[NSMutableDictionary alloc] init];
  NSString		*baseLst;
  NSScanner		*scanner;
  NSString		*lineString = @" ";
  NSString		*sectionName;
  // NSString		*fileName;

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
              // fileName = [NSString
              //              stringWithFormat:@"/Users/me/Library/XKB_%@.list",
              //             sectionName];
              // [modeDict writeToFile:fileName atomically:YES];
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

          for (NSUInteger i = 1; i < [lineComponents count]; i++)
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

          // homophonic = {
          //   Layout = ua;
          //   Description = "Ukrainian (homophonic)";
          // }
          if ([sectionName isEqualToString:@"variant"])
            {
              [modeDict setObject:[self _parseVariantString:value] forKey:key];
            }
          else
            {
              [modeDict setObject:value forKey:key];
              [value release];
            }
          
          [lineComponents release];
        }
    }
  
  [dict setObject:[modeDict copy] forKey:sectionName];
  // fileName = [NSString stringWithFormat:@"/Users/me/Library/XKB_%@.list",
  //                      sectionName];
  // [modeDict writeToFile:fileName atomically:YES];
  [modeDict removeAllObjects];
  [modeDict release];

  [dict writeToFile:@"/Users/me/Library/Keyboards.list" atomically:YES];
  
  return [dict autorelease];
}

- (void)dealloc
{
  if (layoutDict)  [layoutDict release];
  if (modelDict)   [modelDict release];
  if (variantDict) [variantDict release];
  if (optionDict)  [optionDict release];

  [super dealloc];
}

- (NSDictionary *)modelList
{
  if (!modelDict)
    {
      modelDict = [[NSDictionary alloc]
                    initWithDictionary:[[self _xkbBaseListDictionary]
                                         objectForKey:@"model"]];
    }

  return modelDict;
}

// TODO
- (NSString *)model
{
  return nil;
}

// TODO
- (void)setModel:(NSString *)name
{
}

- (NSDictionary *)layoutList
{
  if (!layoutDict)
    {
      layoutDict = [[NSDictionary alloc]
                     initWithDictionary:[[self _xkbBaseListDictionary]
                                          objectForKey:@"layout"]];
    }

  return layoutDict;
}

// TODO
- (NSString *)layout
{
  return nil;
}
// TODO
- (void)addLayout:(NSString *)name
{
}
// TODO
- (void)removeLayout:(NSString *)name
{
}
// TODO
- (void)setLayoutList:(NSArray *)layouts variants:(NSArray *)variants
{
}

- (NSDictionary *)variantsForLayout:(NSString *)layout
{
  NSMutableDictionary	*layoutVariants;
  NSDictionary		*variant;
    
  if (!variantDict)
    {
      variantDict = [[NSDictionary alloc]
                      initWithDictionary:[[self _xkbBaseListDictionary]
                                           objectForKey:@"variant"]];
    }

  layoutVariants = [[NSMutableDictionary alloc] init];
  for (NSString *key in [variantDict allKeys])
    {
      variant = [variantDict objectForKey:key];
      if ([[variant objectForKey:@"Layout"] isEqualToString:layout])
        {
          [layoutVariants setObject:variant forKey:key];
        }
    }

  return [layoutVariants autorelease];
}

//
// Initial Repeat and Repeat Rate
// 

- (void)_setXKBRepeat:(NSInteger)repeat rate:(NSInteger)rate
{
  XkbDescPtr xkb = XkbAllocKeyboard();
  Display    *dpy = XOpenDisplay(NULL);

  if (!dpy)
    {
      NSLog(@"Can't open Display! This program must be run in X Window System.");
      return;
    }
  if (!xkb)
    {
      NSLog(@"No X11 XKB extension found!");
      return;
    }
  
  XkbGetControls(dpy, XkbRepeatKeysMask, xkb);
  if (repeat)
    xkb->ctrls->repeat_delay = (int)repeat;
  if (rate)
    xkb->ctrls->repeat_interval = (int)rate;
  XkbSetControls(dpy, XkbRepeatKeysMask, xkb);
  
  XCloseDisplay(dpy);
}
- (XkbDescPtr)_xkbControls
{
  XkbDescPtr xkb = XkbAllocKeyboard();
  Display    *dpy = XOpenDisplay(NULL);

  if (!dpy)
    {
      NSLog(@"Can't open Display! This program must be run in X Window System.");
      return NULL;
    }
  if (!xkb)
    {
      NSLog(@"No X11 XKB extension found!");
      return NULL;
    }
  
  XkbGetControls(dpy, XkbRepeatKeysMask, xkb);
  XCloseDisplay(dpy);

  return xkb;
}

- (NSInteger)initialRepeat
{
  return [self _xkbControls]->ctrls->repeat_delay;
}
- (void)setInitialRepeat:(NSInteger)delay
{
  [self _setXKBRepeat:delay rate:0];
}
- (NSInteger)repeatRate
{
  return [self _xkbControls]->ctrls->repeat_interval;
}
- (void)setRepeatRate:(NSInteger)rate
{
  [self _setXKBRepeat:0 rate:rate];
}
- (void)setInitialRepeat:(NSInteger)delay rate:(NSInteger)rate
{
  [self _setXKBRepeat:delay rate:rate];
}

@end
