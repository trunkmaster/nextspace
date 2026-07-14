#import "ObjectTesting.h"
#import <Foundation/NSNull.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSKeyValueCoding.h>

int main(void) {
    NSAutoreleasePool *arp = [NSAutoreleasePool new];

    NSNull *nullObject = [NSNull null];

    // Accessing an undefined key
    id result = [nullObject valueForKey:@"undefinedKey"];
    PASS(result == nullObject, "NSNull returns itself for undefined keys.");

    // Attempting to set a value for an undefined key
    PASS_EXCEPTION([nullObject setValue:@"value" forKey:@"undefinedKey"],
	          NSUndefinedKeyException,
              "Setting an undefined key on NSNull should not crash.");

    // Accessing an undefined key path
    result = [nullObject valueForKeyPath:@"some.path"];
    PASS(result == nullObject, "NSNull returns itself for undefined key paths.");

    //  Attempting to set a value for an undefined key path
    PASS_EXCEPTION([nullObject setValue:@"value" forKeyPath:@"some.path"],
	          NSUndefinedKeyException,
              "Setting an undefined key path on NSNull should not crash.");

    [arp release];
    return 0;
}
