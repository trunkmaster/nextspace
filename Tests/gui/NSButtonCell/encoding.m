#import "ObjectTesting.h"

#import <Foundation/NSData.h>
#import <Foundation/NSValue.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSButtonCell.h>

int main()
{
  START_SET("NSButtonCell encoding tests")

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

  NSString	*mask = @"NSButtonFlags2";
  NSButtonCell	*item = [[NSButtonCell alloc] init];

  item.keyEquivalent = @"A";
  item.keyEquivalentModifierMask = NSShiftKeyMask;

  NSMutableData		*data = [NSMutableData data];
  NSKeyedArchiver	*archiver;

  archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData: data];

  [archiver encodeRootObject: item];
  [archiver finishEncoding];

  NSError	*error;
  NSDictionary	*archive;

  archive = [NSPropertyListSerialization
    propertyListWithData: data
    options: NSPropertyListImmutable
    format: nil
    error: &error];

  NSArray	*topLevelObjects = [archive objectForKey: @"$objects"];
  NSEnumerator	*enumerator = [topLevelObjects objectEnumerator];
  NSDictionary	*dict;
  id		element;

  while ((element = [enumerator nextObject]) != nil)
    {
      if ([element isKindOfClass: [NSDictionary class]])
        {
          dict = (NSDictionary*)element;
          
          if ([[dict allKeys] containsObject: mask])
            {
              break;
            }
          else
            {
              dict = nil;
            }
	}
    }

  PASS(dict != nil, "Found a dict with a NSButtonFlags2 entry");

  NSNumber	*encodedKeyMask = [dict valueForKey: mask];
  int		expect = (NSShiftKeyMask << 8);
  int		modMask = (NSEventModifierFlagDeviceIndependentFlagsMask << 8);
  int		found = [encodedKeyMask intValue] & modMask;

  PASS(encodedKeyMask != nil, "Retrieved the NSButtonFlags2 value");
  PASS(found == expect,
    "Encoded key mask 0x%x matches expected key mask 0x%x",
    found, expect);
  
  END_SET("NSButtonCell encoding tests")

  return 0;
}
