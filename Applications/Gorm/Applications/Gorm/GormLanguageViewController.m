/* GormLanguageViewController.m
 *
 * Copyright (C) 2023 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2023
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

#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSLocale.h>

#import <AppKit/NSPopUpButton.h>

#import "GormLanguageViewController.h"

@implementation GormLanguageViewController

- (void) selectPreferredLanguage
{
  NSString *language = [[NSLocale preferredLanguages] objectAtIndex: 0];
  NSInteger i = [[ldict allKeys] indexOfObject: language];

  NSDebugLog(@"language = %@", language);

  // Set the default translation to the current language
  [sourceLanguage selectItemAtIndex: i];
  [targetLanguage selectItemAtIndex: i];

  // Set them since the above doesn't invoke the method that sets them.
  [self updateTargetLanguage: self];
  [self updateSourceLanguage: self];
}


- (void) viewDidLoad
{
  NSBundle *bundle = [NSBundle bundleForClass: [self class]];
  NSString *path = [bundle pathForResource: @"language-codes" ofType: @"plist"];

  [super viewDidLoad];
  if (path != nil)
    {
      [targetLanguage removeAllItems];
      [sourceLanguage removeAllItems];
      
      NSDebugLog(@"path = %@", path);
      
      ldict = [[NSDictionary alloc] initWithContentsOfFile: path];
      if (ldict != nil)
	{
	  NSEnumerator *en = [ldict keyEnumerator];
	  id k = nil;
	  
	  while ((k = [en nextObject]) != nil)
	    {
	      NSString *v = [ldict objectForKey: k];
	      NSString *itemTitle = [NSString stringWithFormat: @"%@ (%@)", k, v];
	      
	      [targetLanguage addItemWithTitle: itemTitle];
	      [sourceLanguage addItemWithTitle: itemTitle];
	    }

	  // Select preferred language in pop up...
	  [self selectPreferredLanguage];
	}
    }
  else
    {
      NSLog(@"Unable to load language codes");
    }
}

- (void) dealloc
{
  RELEASE(ldict);
  [super dealloc];
}

- (IBAction) updateTargetLanguage: (id)sender
{
  NSInteger i = [targetLanguage indexOfSelectedItem];
  targetLanguageIdentifier = [[ldict allKeys] objectAtIndex: i];
}

- (IBAction) updateSourceLanguage: (id)sender
{
  NSInteger i = [sourceLanguage indexOfSelectedItem];
  sourceLanguageIdentifier = [[ldict allKeys] objectAtIndex: i];
}

- (NSString *) sourceLanguageIdentifier
{
  return sourceLanguageIdentifier;
}

- (NSString *) targetLanguageIdentifier
{
  return targetLanguageIdentifier;
}

@end
