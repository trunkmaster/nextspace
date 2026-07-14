/* All rights reserved */

#include <AppKit/AppKit.h>

#include "GormNSSplitViewInspector.h"

@implementation NSSplitView (IBObjectAdditions)
- (NSString *) inspectorClassName
{
  return @"GormNSSplitViewInspector";
}

- (NSString*) editorClassName
{
  return @"GormSplitViewEditor";
}
@end

@implementation GormNSSplitViewInspector

- init
{
  self = [super init];
  if (self != nil)
    {
      NSBundle *bundle = [NSBundle bundleForClass: [self class]];
      
      if ([bundle loadNibNamed: @"GormNSSplitViewInspector" 
			 owner: self
	       topLevelObjects: NULL] == NO)
	{
	  NSLog(@"Could not open gorm GormNSSplitViewInspector");
	  NSLog(@"self %@", self);
	  return nil;
	}
    }

  return self;
}

- (void)awakeFromNib
{
}

- (void) _getValuesFromObject
{
  BOOL state = [(NSSplitView *)object isVertical];
  NSUInteger dividerStyle = [(NSSplitView *)object dividerStyle];
  
  // get the values from the object
  if(state == NO)
    {
      [orientation selectCellAtRow: 0 column: 0];
    }
  else
    {
      [orientation selectCellAtRow: 1 column: 0];      
    }

  [divider selectItemWithTag: dividerStyle];
}

- (void) setObject: (id)anObject
{
  [super setObject: anObject];
  [self _getValuesFromObject];
}

- (void) ok: (id)sender
{
  id cell = nil;
  BOOL state = NO;
  NSUInteger styleTag = 0;
  
  // horizontal switch..  if it's active/inactive we 
  // know what the selection is.
  [super ok: sender];
  cell = [orientation cellAtRow: 0 column: 0];
  state = ([cell state] == NSOnState)?NO:YES;
  styleTag = [divider selectedTag];
  
  [object setVertical: state];
  [object adjustSubviews];
  [object setDividerStyle: styleTag];
}
@end
