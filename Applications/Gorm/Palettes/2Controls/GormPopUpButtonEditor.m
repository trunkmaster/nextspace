#include <AppKit/AppKit.h>

#include <GormCore/GormCore.h>

#include "GormNSPopUpButton.h"

#define _EO ((NSPopUpButton *)_editedObject)

@interface GormPopUpButtonEditor : GormControlEditor
{
}
@end

@implementation GormPopUpButtonEditor
- (void) mouseDown: (NSEvent *)theEvent
{
  // double-clicked -> let's edit
  if (([theEvent clickCount] == 2) && [parent isOpened])
    {
      [[_EO cell]
	attachPopUpWithFrame: [_EO bounds]
	inView: _editedObject];
      NSDebugLog(@"attach down");
      [[document openEditorForObject: [[_EO cell] menu]] activate];
    }
  else
    {
      [super mouseDown: theEvent];
    }  
}
@end
