#import "ObjectTesting.h"

#import <Foundation/NSData.h>
#import <Foundation/NSValue.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSMenuItem.h>

int main()
{
  START_SET("NSMenuItem key equivalent mask")

  NSString		*mask = @"NSKeyEquivModMask";
  NSMenuItem		*item = AUTORELEASE([[NSMenuItem alloc] init]);
  NSMutableData		*data = [NSMutableData data];
  NSNumber		*encodedKeyMask;
  NSError		*error = nil;
  NSDictionary		*dict = nil;
  NSArray		*topLevelObjects;
  NSKeyedArchiver 	*archiver;
  NSDictionary		*archive;
  NSEnumerator		*enumerator;
  id			element;

  item.keyEquivalentModifierMask = NSShiftKeyMask;

  archiver = AUTORELEASE(
    [[NSKeyedArchiver alloc] initForWritingWithMutableData: data]);

  [archiver encodeRootObject: item];
  [archiver finishEncoding];

  archive = [NSPropertyListSerialization propertyListWithData: data
    options: NSPropertyListImmutable
    format: nil
    error: &error];

  topLevelObjects = [archive objectForKey: @"$objects"];
  enumerator = [topLevelObjects objectEnumerator];

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

  PASS(dict != nil, "Found a dict with a NSKeyEquivModMask entry");

  encodedKeyMask = [dict valueForKey: mask];
  PASS(encodedKeyMask != nil, "Retrieved the NSKeyEquivModMask value")
  PASS([encodedKeyMask intValue] == NSShiftKeyMask,
    "Encoded key mask 0x%x matches expected key mask 0x%x",
    [encodedKeyMask intValue], NSShiftKeyMask)

  END_SET("NSMenuItem key equivalent mask")

  return 0;
}
