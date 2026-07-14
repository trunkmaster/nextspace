#import "ObjectTesting.h"

#import <Foundation/NSData.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSEvent.h>
#import <Additions/GNUstepGUI/GSXibKeyedUnarchiver.h>

#define PASS_MODIFIER(index, expected) PASS([[menu itemAtIndex:index] keyEquivalentModifierMask] == expected, "Modifier mask 0x%x equals expected 0x%x", [[menu itemAtIndex:index] keyEquivalentModifierMask], expected);

int main()
{
  START_SET("GSXib5KeyedUnarchiver NSMenu tests")

  NS_DURING
    {
      [NSApplication sharedApplication];
    }
  NS_HANDLER
    {
      if ([[localException name]
	isEqualToString: NSInternalInconsistencyException ])
	{
	  SKIP("It looks like GNUstep backend is not yet installed")
	}
    }
  NS_ENDHANDLER;
    
  NSData		*data;
  GSXibKeyedUnarchiver	*unarchiver;
  NSArray 		*rootObjects;
  NSEnumerator		*enumerator;
  id			element;
  NSMenu		*menu;

  data = [NSData dataWithContentsOfFile:@"Menu.xib"];
  unarchiver = [GSXibKeyedUnarchiver unarchiverForReadingWithData:data];
  rootObjects = [unarchiver decodeObjectForKey: @"IBDocument.RootObjects"];
  enumerator = [rootObjects objectEnumerator];

  while ((element = [enumerator nextObject]) != nil)
     {
      if ([element isKindOfClass: [NSMenu class]])
	{
          menu = (NSMenu*)element;
          break;
	}
    }

  PASS(menu != nil, "Top-level NSMenu was found")


  // Empty <modifierMask key="keyEquivalentModifierMask"/> node
  PASS_MODIFIER(0, 0)
  // <modifierMask key="keyEquivalentModifierMask" shift="YES"/>
  PASS_MODIFIER(1, NSShiftKeyMask)
  // <modifierMask key="keyEquivalentModifierMask" command="YES"/>
  PASS_MODIFIER(2, NSCommandKeyMask)
  // <modifierMask key="keyEquivalentModifierMask" option="YES"/>
  PASS_MODIFIER(3, NSAlternateKeyMask)
  // No modifierMask element
  PASS_MODIFIER(4, NSCommandKeyMask)
  // No modifierMask element and no keyEquivalent attribute
  PASS_MODIFIER(5, NSCommandKeyMask)

  // no modfierMask
  PASS_MODIFIER(6, NSCommandKeyMask)
  // empty modifierMask
  PASS_MODIFIER(7, 0)
  // explicit modifier mask
  PASS_MODIFIER(8, NSCommandKeyMask)
  
  END_SET("GSXib5KeyedUnarchiver NSMenu tests")

  return 0;
}
