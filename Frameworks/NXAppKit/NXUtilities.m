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

  viewWidth -= [font widthOfString:@"..."];

  if (([font widthOfString:shortString]) <= viewWidth) {
    return fullString;
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
        shortString = [[NSString pathWithComponents:pathComponents] 
                        mutableCopy];
        [pathComponents release];
      }
      else { // NXWordElement
        // TODO
      }
      break;
    case NXDotsAtRight:
      if (elementType == NXSymbolElement) {
        position = [shortString length]-1;
        [shortString deleteCharactersInRange:NSMakeRange(position, 1)];
        position--;
      }
      else if (elementType == NXPathElement) {
        shortString = [NSMutableString 
                              stringWithString:
                          [shortString stringByDeletingLastPathComponent]];
      }
      else { // NXWordElement
        // TODO
      }
      break;
    case NXDotsAtCenter:
      if (elementType == NXSymbolElement) {
        position = round([shortString length]/2);
        [shortString deleteCharactersInRange:NSMakeRange(position, 1)];
      }
      else if (elementType == NXPathElement) {
        shortString = [NSMutableString 
                              stringWithString:
                          [shortString stringByDeletingLastPathComponent]];
      }
      else { // NXWordElement
        // TODO
      }
      break;
    default:
      // TODO
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
  else { // TODO: NXDotsAtCenter
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
