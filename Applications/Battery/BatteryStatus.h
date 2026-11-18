#import <Foundation/Foundation.h>

/* apm -abl returns AC status, battery state, then percentage, in that order. */
BOOL BatteryParseStatus(NSString *output, NSInteger *percent, NSInteger *ac,
                        NSInteger *state);
