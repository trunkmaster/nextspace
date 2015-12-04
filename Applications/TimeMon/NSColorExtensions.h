#import <AppKit/NSColor.h>

#if !defined (GNUSTEP) &&  (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_4)
#if !defined(NSUInteger)
#define NSUInteger unsigned
#endif
#if !defined(NSInteger)
#define NSInteger int
#endif
#if !defined(CGFloat)
#define CGFloat float
#endif
#endif

@class NSString;

@interface NSColor (GetColorsFromString)
+ (NSColor *)colorFromStringRepresentation:(NSString *)colorString;
- (NSString *)stringRepresentation;
@end
