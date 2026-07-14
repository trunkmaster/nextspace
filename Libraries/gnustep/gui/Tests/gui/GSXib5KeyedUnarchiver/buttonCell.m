#import "ObjectTesting.h"

#import <Foundation/NSData.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSMatrix.h>
#import <Additions/GNUstepGUI/GSXibKeyedUnarchiver.h>

#define PASS_MODIFIER(index, expected) PASS([[cells objectAtIndex:index] keyEquivalentModifierMask] == expected, "Modifier mask 0x%x equals expected 0x%x", [[cells objectAtIndex:index] keyEquivalentModifierMask], expected);

int main()
{
  START_SET("GSXib5KeyedUnarchiver NSButtonCell tests")

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
  NS_ENDHANDLER

  NSData		*data;
  GSXibKeyedUnarchiver	*unarchiver;
  NSArray		*rootObjects;
  NSEnumerator		*enumerator;
  NSMatrix		*matrix;
  id			element;

  data = [NSData dataWithContentsOfFile: @"ButtonCell.xib"];
  unarchiver = [GSXibKeyedUnarchiver unarchiverForReadingWithData:data];
  rootObjects = [unarchiver decodeObjectForKey: @"IBDocument.RootObjects"];

  enumerator = [rootObjects objectEnumerator];
  while ((element = [enumerator nextObject]) != nil)
    {
      if ([element isKindOfClass: [NSMatrix class]])
	{
          matrix = (NSMatrix*)element;
          break;
	}
    }

  PASS(matrix != nil, "Top-level NSMatrix was found")

  NSArray	*cells = [matrix cells];

  // <modifierMask key="keyEquivalentModifierMask" shift="YES"/> node
  PASS_MODIFIER(0, NSShiftKeyMask)

  // <modifierMask key="keyEquivalentModifierMask" command="YES"/> node
  PASS_MODIFIER(1, NSCommandKeyMask)

  // <modifierMask key="keyEquivalentModifierMask" />
  PASS_MODIFIER(2, 0)

  // Unlike NSMenuItem, the default for NSButtonCell is 0
  PASS_MODIFIER(3, 0)
  
  END_SET("GSXib5KeyedUnarchiver NSButtonCell tests")

  return 0;
}
