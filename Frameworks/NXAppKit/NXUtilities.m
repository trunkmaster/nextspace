/** @brief The various utility functions wich can't be assigned to some class.
    
    @author Sergii Stoian
*/

#import "NXUtilities.h"

NSString *NXShortenString(NSString *fullString,
                          CGFloat viewWidth,
                          NSFont *font,
                          NXElementType elementType,
                          NXDotsPosition dotsPosition)
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
    switch (dotsPosition) {
    case NXDotsAtLeft:
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
    case NXDotsAtRight:
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
    case NXDotsAtCenter:
      position = round([shortString length]/2);
      if (elementType == NXSymbolElement) {
        [shortString deleteCharactersInRange:NSMakeRange(position, 1)];
      }
      else if (elementType == NXPathElement) {
        pathComponents = [[shortString pathComponents] mutableCopy];
        if ([pathComponents count] > 3) {
          range = NSMakeRange(position, 1);
          for (NSString *component in pathComponents) {
            del_range = [shortString rangeOfString:component];
            if (NSIntersectionRange(del_range, range).length > 0) {
              position = del_range.location - 1;
              [pathComponents removeObject:component];
              [shortString
                setString:[pathComponents componentsJoinedByString:@"/"]];
              if ([[pathComponents objectAtIndex:0] isEqualToString:@"/"]) {
                [shortString deleteCharactersInRange:NSMakeRange(0, 1)];
              }
              break;
            }
          }
        }
        else {
          [shortString deleteCharactersInRange:NSMakeRange(position, 1)];
        }
        
        [pathComponents release];
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
  if (dotsPosition == NXDotsAtLeft) {
    if (elementType == NXSymbolElement ||
        elementType == NXWordElement) {
      return [NSString stringWithFormat:@"...%@", shortString];
    }
    else if (elementType == NXPathElement) {
      return [NSString stringWithFormat:@".../%@", shortString];
    }
  }
  else if (dotsPosition == NXDotsAtRight) {
    if (elementType == NXSymbolElement ||
        elementType == NXWordElement) {
      return [NSString stringWithFormat:@"%@...", shortString];
    }
    else if (elementType == NXPathElement) {
      return [NSString stringWithFormat:@"%@/...", shortString];
    }
  }
  else if (dotsPosition == NXDotsAtCenter) {
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
