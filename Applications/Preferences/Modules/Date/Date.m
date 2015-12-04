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

#import <AppKit/NSApplication.h>

#import "Date.h"

@implementation Date

static Date			*sharedInstance = nil;
static id <XSPrefsController>	owner = nil;

static NSBundle                 *bundle = nil;
static NSUserDefaults           *defaults = nil;
static NSMutableDictionary      *domain = nil;

- (id) initWithOwner:(id <XSPrefsController>)anOwner
{
  if (sharedInstance)
    {
      [self dealloc];
    }
  else
    {
      self = [super init];
      owner = anOwner;
      defaults = [NSUserDefaults standardUserDefaults];
      domain = [[defaults persistentDomainForName: NSGlobalDomain] mutableCopy];
      bundle = [NSBundle bundleForClass: [self class]];
      
      [owner registerPrefsModule: self];
      
      sharedInstance = self;
    }
  return sharedInstance;
}

- (void)release
{
  [super release];
}

- (void)dealloc
{
  [super dealloc];
}

- (void)awakeFromNib
{
}

- (void) showView:(id)sender;
{
  if (!view)
    {
      [NSBundle loadNibNamed:@"Date" owner:self];
    }

  [owner setCurrentModule:self];
  [view setNeedsDisplay:YES];
}

- (NSView *) view
{
  return view;
}

- (NSString *) buttonCaption
{
  return NSLocalizedStringFromTableInBundle(@"Time and Date Preferences", 
					    @"Localizable", bundle, @"");
}

- (NSImage *) buttonImage
{
  return [NSImage imageNamed: @"Time"];
}

- (SEL) buttonAction
{
  return @selector(showView:);
}

//
// Action methods
//
/*- (IBAction) passwordChanged: (id)sender
{
}*/

@end
