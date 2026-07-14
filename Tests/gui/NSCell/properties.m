#include "Testing.h"

#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSValue.h>

#include <AppKit/NSApplication.h>
#include <AppKit/NSCell.h>
#include <AppKit/NSImageCell.h>
#include <AppKit/NSActionCell.h>
#include <AppKit/NSTextFieldCell.h>
#include <AppKit/NSButtonCell.h>

int main()
{
  CREATE_AUTORELEASE_POOL(arp);
  NSImageCell *imgCell;
  NSActionCell *actCell;
  NSButtonCell *buttCell;
  NSTextFieldCell *tfCell;
  NSCell *cell; 

  START_SET("NSCell RefusesResponder")
  
  NS_DURING
  {
    [NSApplication sharedApplication];
  }
  NS_HANDLER
  {
    if ([[localException name] isEqualToString: NSInternalInconsistencyException ])
       SKIP("It looks like GNUstep backend is not yet installed")
  }
  NS_ENDHANDLER

  imgCell = [[NSImageCell alloc] initImageCell:nil];
  pass([imgCell refusesFirstResponder] == YES, "NSImageCell initImageCell refusesFirstResponder");

  cell = [[NSCell alloc] initImageCell:nil];
  pass([cell refusesFirstResponder] == NO, "NSCell initImageCell refusesFirstResponder");

  buttCell = [[NSButtonCell alloc] init];
  pass([buttCell refusesFirstResponder] == NO, "NSButtonCell init refusesFirstResponder");

  tfCell = [[NSTextFieldCell alloc] initTextCell:@""];
  pass([tfCell refusesFirstResponder] == NO, "NSTextFieldCell initTextCell refusesFirstResponder");

  actCell = [[NSActionCell alloc] init];
  pass([actCell refusesFirstResponder] == NO, "NSActionCell init refusesFirstResponder");

  cell = [[NSCell alloc] init];
  pass([cell refusesFirstResponder] == NO, "NSCell init refusesFirstResponder");

  END_SET("NSCell RefusesResponder")

  DESTROY(arp);
  return 0;
}
