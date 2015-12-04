
#import "NSStringAdditions.h"

#import <errno.h>
#import <string.h>

@implementation NSString (Additions)

+ (NSString *)errnoDescription
{
  return [NSString stringWithCString:strerror(errno)];
}

@end
