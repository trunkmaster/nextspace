/*
  Copyright (c) 2002, 2003 Alexander Malmberg <alexander@malmberg.org>
  Copyright (c) 2015-2017 Sergii Stoian <stoyan255@gmail.com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; version 2 of the License.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#import <Foundation/NSDebug.h>

#import <AppKit/NSApplication.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSEvent.h>

#import "TerminalApplication.h"
#import "Defaults.h"


@implementation TerminalApplication

- (void)sendEvent:(NSEvent *)e
{
  if ([e type] == NSKeyDown)
  {
    if ([e modifierFlags] & NSCommandKeyMask)
    {
      NSDebugLLog(@"key", @"intercepting key equivalent");
      if ([[Defaults shared] alternateAsMeta])
      {
        if ([[[NSUserDefaults standardUserDefaults]
            objectForKey:@"PreserveReadlineWordMovement"] boolValue])
        {
        if ([[e characters] length] == 1)
        {
          unichar c = [[e characters] characterAtIndex:0];
          NSDebugLLog(@"key", @"Saw %hu", c);

          // Preserve readline-esque word operations:
          //   Alt+f/b: word forward/backward movement
          //   Alt+d: delete word forward
          if ((c == 'f' || c == 'b' || c == 'd') && !([e modifierFlags] & NSShiftKeyMask))
          {
            NSString *metaSeq = [NSString stringWithFormat:@"\033%c", c];

            NSEvent *escEvent =
              [NSEvent keyEventWithType:NSKeyDown
                               location:[e locationInWindow]
                          modifierFlags:0
                              timestamp:[e timestamp]
                           windowNumber:[e windowNumber]
                                context:[e context]
                             characters:metaSeq
            charactersIgnoringModifiers:metaSeq
                              isARepeat:[e isARepeat]
                                keyCode:[e keyCode]];

            [super sendEvent:escEvent];
            return;
            }

          // Alt+Backspace: delete word backward
          // Backspace sends DEL (127) or BS (8) depending on terminal settings
          if (c == 127 || c == 8)
          {
            NSString *metaSeq = @"\033\177";

            NSEvent *escEvent =
              [NSEvent keyEventWithType:NSKeyDown
                               location:[e locationInWindow]
                          modifierFlags:0
                              timestamp:[e timestamp]
                           windowNumber:[e windowNumber]
                                context:[e context]
                             characters:metaSeq
            charactersIgnoringModifiers:metaSeq
                              isARepeat:[e isARepeat]
                                keyCode:[e keyCode]];

            [super sendEvent:escEvent];
            return;
            }
          }
          else // char length > 1
          {
            [[e window] sendEvent:e];
          }
        } // no PreserveReadlineWordMovement default
      } // no alternateAsMeta
    } // no NSCommandKeyMask

    if (
        ([e keyCode] == (unsigned long)[[Defaults shared] superKeyKeycode]) &&
        [[Defaults shared] swallowSuperKey] &&
        [[Defaults shared] alternateAsMeta] &&
        [[e characters] length] == 1)
    {
      /* Swallow the super key (used to Super + Tab to change applications)
       *
       * This works because we don't pass the event down into the [e window], but
       * rather let the event bubble /up/ to the desktop layer
       *
       */
      NSDebugLLog(@"key", @"SuperKey Path: Got key flags=%08lx  repeat=%i '%@' '%@' %4i %04x %lu %04x %lu\n",
                [e modifierFlags], [e isARepeat], [e characters], [e charactersIgnoringModifiers],
                [e keyCode], [[e characters] characterAtIndex:0], [[e characters] length],
                [[e charactersIgnoringModifiers] characterAtIndex:0],
                [[e charactersIgnoringModifiers] length]);
      NSDebugLLog(@"key", @"Done");
      return;
    }
  } // was a keyDown menu equivalent

    // Frustratingly, GNUstep is issuing Paste on Control+V, but I only want it
    // on Control + Shift + V (which it does). Swallow Control + V
    if ([e modifierFlags] & NSControlKeyMask)
    {
      unichar c = [[e characters] characterAtIndex:0];
      NSDebugLLog(@"key", @"Testing unichar %hu", c);
      if ([[e characters] length] == 1)
      {
        if (c == 'v')
        {
          NSDebugLLog(@"key", @"Discarding bogus ^v as paste versus acceptable ^V");
          return;
        }
      }
    }

  [super sendEvent:e];
}

@end

