/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import "Utilities.h"

NSString *NXTShortenString(NSString *fullString,
                          CGFloat viewWidth,
                          NSFont *font,
                          NXTElementType elementType,
                          NXTDotsPosition dotsPosition)
{
  NSMutableString *shortString = [NSMutableString stringWithString:fullString];
  NSMutableArray  *pathComponents;
  NSUInteger      position;
  NSCharacterSet  *charset;
  NSRange         range, del_range;

  viewWidth -= [font widthOfString:@"..."];

  if (([font widthOfString:shortString]) <= viewWidth) {
    return fullString;
  }

  if (elementType == NXWordElement) {
    charset = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  }

  while ([font widthOfString:shortString] > viewWidth) {
    switch (dotsPosition)
      {
      case NXTDotsAtLeft:
        if (elementType == NXSymbolElement) {
          position = 0;
          [shortString deleteCharactersInRange:NSMakeRange(position, 1)];
        }
        else if (elementType == NXPathElement) {
          pathComponents = [[shortString pathComponents] mutableCopy];
          [pathComponents removeObjectAtIndex:0];
          [shortString setString:[NSString pathWithComponents:pathComponents]];
          [pathComponents release];
        }
        else if (elementType == NXWordElement) {
          range = [shortString rangeOfCharacterFromSet:charset];
          if (range.location != NSNotFound) {
            [shortString
              deleteCharactersInRange:NSMakeRange(0, range.location+range.length)];
          }
        }
        break;
      case NXTDotsAtRight:
        if (elementType == NXSymbolElement) {
          position = [shortString length]-1;
          [shortString deleteCharactersInRange:NSMakeRange(position, 1)];
          position--;
        }
        else if (elementType == NXPathElement) {
          [shortString setString:[shortString stringByDeletingLastPathComponent]];
        }
        else if (elementType == NXWordElement) {
          range = [shortString rangeOfCharacterFromSet:charset
                                               options:NSBackwardsSearch];
          del_range.location = range.location;
          del_range.length = [shortString length] - range.location;
          if (range.location != NSNotFound) {
            [shortString deleteCharactersInRange:del_range];
          }
        }
        break;
      case NXTDotsAtCenter:
        position = round([shortString length]/2);
        if (elementType == NXSymbolElement) {
          [shortString deleteCharactersInRange:NSMakeRange(position, 1)];
        }
        else if (elementType == NXPathElement) {
          if ([shortString characterAtIndex:position] == '/') {
            position += 1;
          }
          // NSLog(@"NXTDotsAtCenter: %c", [shortString characterAtIndex:position]);
          range = NSMakeRange(position, 1);
          if ([[shortString pathComponents] count] > 2) {
            NSRange    f_slash, b_slash;
            NSUInteger s_length =  [shortString length];
            // Search forward for '/'
            f_slash = [shortString
                        rangeOfString:@"/"
                              options:0
                                range:NSMakeRange(position, s_length - position)];
            if (f_slash.location == NSNotFound) {
              f_slash.location = s_length;
            }
            // Search backwards for '/'
            b_slash = [shortString rangeOfString:@"/"
                                         options:NSBackwardsSearch
                                           range:NSMakeRange(0, position)];
            if (b_slash.location == NSNotFound) {
              b_slash.location = 0;
            }
          
            range.location = b_slash.location;
            range.length = f_slash.location - range.location;
            position = range.location;
          }
          // NSLog(@"Delete characters in range: %@", NSStringFromRange(range));
          [shortString deleteCharactersInRange:range];
          // NSLog(@"Result: %@", shortString);
        }
        else if (elementType == NXWordElement) {
          // TODO
        }
        break;
      default:
        break;
      }
  }

  // String was shortened - insert dots
  if (dotsPosition == NXTDotsAtLeft) {
    if (elementType == NXSymbolElement ||
        elementType == NXWordElement) {
      return [NSString stringWithFormat:@"...%@", shortString];
    }
    else if (elementType == NXPathElement) {
      return [NSString stringWithFormat:@".../%@", shortString];
    }
  }
  else if (dotsPosition == NXTDotsAtRight) {
    if (elementType == NXSymbolElement ||
        elementType == NXWordElement) {
      return [NSString stringWithFormat:@"%@...", shortString];
    }
    else if (elementType == NXPathElement) {
      return [NSString stringWithFormat:@"%@/...", shortString];
    }
  }
  else if (dotsPosition == NXTDotsAtCenter) {
    NSString *shrinked;
    NSRange  rightPartRange;

    rightPartRange = NSMakeRange(position, [shortString length]-position);
    shrinked = [NSString stringWithFormat:@"%@...%@",
                         [shortString substringToIndex:position],
                         [shortString substringWithRange:rightPartRange]];
    return shrinked;
  }

  return fullString;
}
