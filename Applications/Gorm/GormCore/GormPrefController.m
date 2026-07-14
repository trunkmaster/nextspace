#include <AppKit/AppKit.h>

#include "GormPrefController.h"
#include "GormGeneralPref.h"
#include "GormHeadersPref.h"
#include "GormShelfPref.h"
#include "GormPalettesPref.h"
#include "GormPluginsPref.h"
#include "GormGuidelinePref.h"

@implementation GormPrefController

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      if(![NSBundle loadNibNamed: @"GormPreferences" owner: self])
	{
	  return nil;
	}
    }
  return self;
}

- (void) awakeFromNib
{
  _generalView  = [[GormGeneralPref alloc] init];
  _headersView  = [[GormHeadersPref alloc] init];
  _shelfView    = [[GormShelfPref alloc] init];
  _palettesView = [[GormPalettesPref alloc] init];
  _pluginsView = [[GormPluginsPref alloc] init];
  _guidelineView = [[GormGuidelinePref alloc] init];

  [prefBox setContentView:[_generalView view]];

  [[self panel] setFrameUsingName: @"Preferences"];
  [[self panel] setFrameAutosaveName: @"Preferences"];
  [[self panel] center];
}

- (void) popupAction: (id)sender
{
  int tag = -1;

  if ( sender != popup )
    return;

  tag = [[sender selectedItem] tag];
  switch(tag)
    {
    case 0: 
      [prefBox setContentView: [_generalView view]];
      break;	
    case 1:
      [prefBox setContentView: [_headersView view]];
      break;
    case 2:
      [prefBox setContentView: [_shelfView view]];
      break;
    case 4:
      [prefBox setContentView: [_palettesView view]];
      break;
    case 5:
      [prefBox setContentView: [_guidelineView view]];
      break;
    case 6:
      [prefBox setContentView: [_pluginsView view]];
      break;
    default:
      NSLog(@"Error Default (GormPrefController.m) : - (void) popupAction: (id)sender, no match for tag %d",tag);
      break;
    }
}

- (void) dealloc
{
  RELEASE(_generalView);
  RELEASE(_headersView);
  RELEASE(_shelfView);
  RELEASE(_colorsView);
  RELEASE(_palettesView);
  RELEASE(_pluginsView);
  RELEASE(panel);
  [super dealloc];
}

- (id) panel
{
  return panel;
}
@end
