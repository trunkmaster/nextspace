#import "ObjectTesting.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSPredicate.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSNull.h"

int main(void) {
    NSAutoreleasePool *arp = [NSAutoreleasePool new];
    NSDictionary *dict1, *dict2;
	NSArray *array, *filtered;
    NSString *value;
	NSPredicate *predicate;

    dict1 = [NSDictionary dictionaryWithObject:@"value1" forKey:@"key"];
    dict2 = [NSDictionary dictionaryWithObject:@"value2" forKey:@"key"];
    array = [NSArray arrayWithObjects:dict1, dict2, [NSNull null], nil];

    // Basic filtering with NSPredicate
	predicate = [NSPredicate predicateWithFormat:@"key == %@", @"value2"];
    filtered = [array filteredArrayUsingPredicate: predicate];

    value = [[filtered objectAtIndex:0] objectForKey:@"key"];

    PASS([filtered count] == 1 && [value isEqualToString:@"value2"], 
         "NSPredicate should correctly filter array including NSNull");

    // Filtering with NSPredicate where no match is found
	predicate = [NSPredicate predicateWithFormat:@"key == %@", @"nonexistent"];
    filtered = [array filteredArrayUsingPredicate: predicate];
    PASS([filtered count] == 0, 
         "NSPredicate should return an empty array when no match is found");

    // Filtering with NSPredicate with a different key
	predicate = [NSPredicate predicateWithFormat:@"anotherKey == %@", @"value1"];
    filtered = [array filteredArrayUsingPredicate: predicate];
    PASS([filtered count] == 0, 
         "NSPredicate should return an empty array when filtering with a non-existent key");

    [arp release];
    return 0;
}
