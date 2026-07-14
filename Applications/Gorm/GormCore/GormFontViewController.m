/* All rights reserved */

#include <AppKit/AppKit.h>

#include "GormFontViewController.h"

static GormFontViewController *gorm_font_cont = nil;

@implementation GormFontViewController

+ (GormFontViewController *) sharedGormFontViewController
{
  if (gorm_font_cont == nil)
    {
      gorm_font_cont = [[self alloc] init];
    }
  return gorm_font_cont;
}

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      NSBundle *bundle = [NSBundle bundleForClass: [self class]];
      
      // load the gui...
      if (![bundle loadNibNamed: @"GormFontView"
			  owner: self
		topLevelObjects: NULL])
	{
	  NSLog(@"Could not open gorm GormFontView");
	  return nil;
	}
      [[NSFontManager sharedFontManager] setDelegate: self];
    }
  return self;
}

- (NSFont *) convertFont: (NSFont *)aFont
{
  float size;
  NSFont *font;
  
  // If aFont isn't nil and the button is off then set the size
  // to the size of the passed in font.
  
  size = (aFont && [encodeButton state] == NSOffState) 
   ? [aFont pointSize] : 0.0;

  switch([fontSelector indexOfSelectedItem])
    {
    default:
    case 0: // selected font
      font = (aFont) ? aFont :
       [[NSFontManager sharedFontManager] selectedFont];
      if (!font) font = [NSFont userFontOfSize: size];
      break;
    case 1: // bold system font
      font = [NSFont boldSystemFontOfSize: size];
      break;
    case 2: // system font
      font = [NSFont systemFontOfSize: size];
      break;
    case 3: // user fixed font
      font = [NSFont userFixedPitchFontOfSize: size];
      break;
    case 4: // user font
      font = [NSFont userFontOfSize: size];
      break;
    case 5: // title bar font
      font = [NSFont titleBarFontOfSize: size];
      break;
    case 6: // menu font
      font = [NSFont menuFontOfSize: size];
      break;
    case 7: // message font
      font = [NSFont messageFontOfSize: size];
      break;
    case 8: // palette font
      font = [NSFont paletteFontOfSize: size];
      break;
    case 9: // tooltops font
      font = [NSFont toolTipsFontOfSize: size];
      break;
    case 10: // control content font
      font = [NSFont controlContentFontOfSize: size];
      break;
    case 11:
      font = [NSFont labelFontOfSize: size];
      break;
    }
  
  return font;
} 

- (void) selectFont: (id)sender
{
  NSFontManager *fontManager = [NSFontManager sharedFontManager];
  NSFont *font;

  font = [self convertFont: nil];

  [fontManager setSelectedFont: font isMultiple: NO];

  if ([fontSelector indexOfSelectedItem] == 0)
    {
      [encodeButton setEnabled: NO];
      [encodeButton setState: NSOffState];
    }
  else
    {
      [encodeButton setEnabled: YES];
      [encodeButton setState: NSOffState];
    }
}

- (id) view
{
  return view;
}

- (void) mouseDragged: (NSEvent *)event
{
  // here to make certain we don't crash..
}

- (void) flagsChanged: (NSEvent *)event
{
  // here to make certain we don't crash..
}

@end
