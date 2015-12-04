/*
	Font.m

	Controller class for this bundle

	Author: Sir Raorn <raorn@binec.ru>
	Date:	10 Aug 2002

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
#import <math.h>

#import <AppKit/NSPopUpButton.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSTextView.h>
#import <AppKit/NSFont.h>
#import <AppKit/NSFontPanel.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSOpenPanel.h>
#import <AppKit/NSImage.h>

#import <AppKit/NSApplication.h>

#import "Login.h"

@implementation Login

static NSUserDefaults       *defaults = nil;
static NSMutableDictionary  *domain = nil;

- (id)init
{
  NSBundle *bundle;
  NSString *imagePath;
      
  self = [super init];
      
  defaults = [NSUserDefaults standardUserDefaults];
  domain = [[defaults persistentDomainForName:NSGlobalDomain] mutableCopy];

  bundle = [NSBundle bundleForClass:[self class]];
  imagePath = [bundle pathForResource:@"Loginwindow" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];
  view = nil;
      
  return self;
}

- (oneway void)release
{
  NSLog(@"[release] view RC: %lu", [view retainCount]);
  [super release];
}

- (void)dealloc
{
  NSLog(@"view RC: %lu", [view retainCount]);
  [image release];
  [super dealloc];
}

- (void)awakeFromNib
{
  [view retain];
}

- (NSView *)view
{
  if (view == nil)
    {
      if (![NSBundle loadNibNamed:@"Login" owner:self])
        {
          return nil;
        }      
    }
  return view;
}

- (NSString *)buttonCaption
{
  return @"Login Window Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

//
// Action methods
//
- (IBAction)passwordChanged:(id)sender
{
}

@end
