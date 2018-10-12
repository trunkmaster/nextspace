/*
   A subclass of NSBrowser to send a subaction on "return".

   Copyright (C) 2005 Saso Kiselkov

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import "BrowserViewerBrowser.h"

#import <Foundation/NSTimer.h>
#import <Foundation/NSDate.h>

#import <AppKit/NSEvent.h>
#import <AppKit/NSMatrix.h>
#import <AppKit/NSWindow.h>

static NSTimer *clickTimer = nil;

@implementation BrowserViewerBrowser

- (void)_emptyColumn:(NSInteger)number
{
  NSMatrix  *matrix = [self matrixInColumn:number];
  NSInteger rowsNum = [matrix numberOfRows];
  int       i;

  NSLog(@"[BrowserViewerBrowser] emptyColumn:%li", number);

  while([matrix numberOfRows])
    {
      [matrix removeRow:0];
    }
  [self displayColumn:number];
}

- (void)_performClick:(NSTimer *)timer
{
  [[timer userInfo] performClick:self];
  [clickTimer invalidate];
  clickTimer = nil;
}

- (void)keyDown:(NSEvent *)ev
{
  NSString   *characters = [ev characters];
  NSUInteger charsLength = [characters length];
  unichar    ch = 0;

  if (charsLength > 0) {
    ch = [characters characterAtIndex:0];
  }
  
  NSLog(@"%c", ch);

  if (ch == NSCarriageReturnCharacter ||
      ch == NSNewlineCharacter ||
      ch == NSEnterCharacter) {
    [self doDoubleClick:nil];
    return;
  }
  else if (ch == NSRightArrowFunctionKey && 
	   [[self matrixInColumn:[self lastColumn]] numberOfRows] == 0) {
    return;
  }
  else if (ch == NSUpArrowFunctionKey) {
    NSLog(@"keyDown: UpArrow");
    return;
  }
  else if (ch == NSDownArrowFunctionKey) {
    NSLog(@"keyDown: DownArrow");
    return;
  }
//     else if (character == NSLeftArrowFunctionKey)
//     {
//       NSInteger lastC = [self lastColumn];
//       NSInteger lastVC = [self lastVisibleColumn];
//       NSInteger i;
//       NSInteger selectedC = [self selectedColumn];
//       NSInteger firstVC = [self firstVisibleColumn];

//       NSLog(@"1. [BrowserViewerBrowser] lastC: %i selectedC: %i lastVC: %i firstVC: %i",
// 	    lastC, selectedC, lastVC, firstVC);

//       [super keyDown:ev];
// //      [[self matrixInColumn:selectedC] deselectAllCells];
// //      [_browserDelegate doClick:nil];
//       if (selectedC == firstVC)
// 	{
// //	  [self setPath:[self pathToColumn:selectedC]];
// //	  [self scrollColumnsRightBy:2];
// 	  [self scrollColumnToVisible:lastVC];
// //	  for (i=lastVC; i > selectedC; i--)
// //	    {
// //	      [self _emptyColumn:i];
// //	    }
// 	}
//       return;
//     }

  if (_acceptsAlphaNumericalKeys && (ch < 0xF700) && (charsLength > 0))
    {
      NSMatrix *matrix;
      NSString *sv;
      NSInteger i, n, s;
      NSInteger match;
      NSInteger selectedColumn;
      SEL lcarcSel = @selector(loadedCellAtRow:column:);
      IMP lcarc = [self methodForSelector:lcarcSel];

      // selectedColumn = [self selectedColumn];
      // selectedColumn = [self lastColumn];
      {
        selectedColumn = -1;
        for (i=_lastColumnLoaded; i>=0; i--)
          {
            if ([[self matrixInColumn:i] numberOfRows] > 0)
              {
                selectedColumn = i;
                break;
              }
          }
      }
      
      // NSLog(@"selectedColumn: %i", selectedColumn);
      
      if (selectedColumn != -1)
        {
          matrix = [self matrixInColumn:selectedColumn];
          n = [matrix numberOfRows];
          s = [matrix selectedRow];
          
          if (clickTimer && [clickTimer isValid])
            {
              [clickTimer invalidate];
            }
          clickTimer =
            [NSTimer
              scheduledTimerWithTimeInterval:0.8
                                      target:self
                                    selector:@selector(_performClick:)
                                    userInfo:matrix
                                     repeats:NO];
          if (!_charBuffer)
            {
              _charBuffer = [characters substringToIndex:1];
              RETAIN(_charBuffer);
            }
          else
            {
              if (([ev timestamp] - _lastKeyPressed < 2.0)
                  && (_alphaNumericalLastColumn == selectedColumn)
                  && s >= 0)
                {
                  NSString *transition;
                  transition = [_charBuffer 
                                 stringByAppendingString:
                                   [characters substringToIndex:1]];
                  RELEASE(_charBuffer);
                  _charBuffer = transition;
                  RETAIN(_charBuffer);
                }
              else
                {
                  RELEASE(_charBuffer);
                  _charBuffer = [characters substringToIndex:1];
                  RETAIN(_charBuffer);
                }
            }

          // NSLog(@"_charBuffer: %@ _lastKeyPressed:%f(%f) selected:%i",
          //       _charBuffer, _lastKeyPressed, [ev timestamp], s);

          _alphaNumericalLastColumn = selectedColumn;
          _lastKeyPressed = [ev timestamp];

          //[[self loadedCellAtRow:column:] stringValue]
          sv = [((*lcarc)(self, lcarcSel, s, selectedColumn)) stringValue];

          // selected cell aleady contains typed string - _charBuffer
          if (([sv length] > 0) && ([sv hasPrefix:_charBuffer]))
            {
              return;
            }

          // search row from selected to the bottom
          match = -1;
          for (i = s + 1; i < n; i++)
            {
              sv = [((*lcarc)(self, lcarcSel, i, selectedColumn)) stringValue];
              if (([sv length] > 0) && ([sv hasPrefix: _charBuffer]))
                {
                  match = i;
                  break;
                }
            }
          // previous search found nothing, start from top
          if (i == n)
            {
              for (i = 0; i < s; i++)
                {
                  sv = [((*lcarc)(self, lcarcSel, i, selectedColumn))
                         stringValue];
                  if (([sv length] > 0)
                      && ([sv hasPrefix: _charBuffer]))
                    {
                      match = i;
                      break;
                    }
                }
            }
          if (match != -1)
            {
              [matrix deselectAllCells];
              [matrix selectCellAtRow:match column:0];
              [matrix scrollCellToVisibleAtRow:match column:0];
              // click performed with timer
              // [matrix performClick:self];
              return;
            }
        }
      _lastKeyPressed = 0.;
      return;
    }
  
  [super keyDown:ev];
}

- (BOOL)becomeFirstResponder
{
  int lastVisibleC;
  int lastSelectedC;
  
  // NSLog(@"<BrowserViewerBrowser> becomeFirstResponder");

  lastVisibleC = [self lastVisibleColumn];
  lastSelectedC = [self selectedColumn];

  if (lastVisibleC < [self lastColumn])
    {
      [_window makeFirstResponder:[self matrixInColumn:lastVisibleC]];
    }
  else
    {
      [_window makeFirstResponder:[self matrixInColumn:lastSelectedC]];
    }

  return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
  if ([event type] == NSLeftMouseDown) {
    return YES;
  }
  return NO;
}

@end
