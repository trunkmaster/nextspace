/* All rights reserved */

#include <AppKit/AppKit.h>

#include <GNUstepGUI/GSNibLoading.h>

#include "GormHelpInspector.h"

@implementation GormHelpInspector
- (id) init
{
  NSBundle *bundle = [NSBundle bundleForClass: [self class]];

  if ([super init] == nil)
    {
      return nil;
    }

  if ([bundle loadNibNamed: @"GormHelpInspector" owner: self topLevelObjects: NULL] == NO)
    {
      NSLog(@"Could not gorm GormHelpInspector");
      return nil;
    }

  return self;
}

- (void) ok: (id)sender
{
  id<IBDocuments> document = [(id<IB>)[NSApp delegate] activeDocument];
  NSArray *cons = [document connectorsForDestination: object
			    ofClass: [NSIBHelpConnector class]];
  NSIBHelpConnector *con = nil;

  if([cons count] > 0)
    {
      NSEnumerator *en = [cons objectEnumerator];
      NSString *val = [sender stringValue];

      if([val isEqualToString: @""] == NO)
	{
	  while((con = [en nextObject]) != nil)
	    {
	      [con setMarker: [sender stringValue]];
	    }
	}
      else
	{
	  while((con = [en nextObject]) != nil)
	    {
	      [document removeConnector: con];
	    }
	}
    }
  else
    {     
      con = [[NSIBHelpConnector alloc] init];

      [con setFile: @"NSToolTipHelpKey"];
      [con setMarker: [sender stringValue]];
      [con setDestination: object];
      
      [document addConnector: con];
    }
  [super ok: sender];
}

- (void) revert: (id)sender
{
  id<IBDocuments> document = [(id<IB>)[NSApp delegate] activeDocument];
  NSArray *cons = [document connectorsForDestination: object
			    ofClass: [NSIBHelpConnector class]];

  if([cons count] > 0)
    { 
      NSIBHelpConnector *con = [cons objectAtIndex: 0];
      NSString *val = [con marker];
      [toolTip setStringValue: val];
    }
  else
    {
      [toolTip setStringValue: @""];
    }

  [super revert: sender];
}

-(void) controlTextDidChange:(NSNotification *)aNotification
{
  [self ok: [aNotification object]];
}
@end
