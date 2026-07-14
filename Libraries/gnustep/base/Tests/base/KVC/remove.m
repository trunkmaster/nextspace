#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

@interface TestObject : NSObject
{
  NSArray	*items;
}

@property (nonatomic, copy) NSArray *items;
- (void) addItem: (id)item;
- (NSArray*) items;
- (void) removeItem: (id)item;
- (void) setItems: (NSArray*)a;
@end

@implementation TestObject

- (void) dealloc
{
  DESTROY(items);
  DEALLOC
}

- (instancetype) init
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(items, [NSMutableArray array]);
    }
  return self;
}

- (void) addItem: (id)item
{
  [[self mutableArrayValueForKeyPath: @"items"] addObject: item];
}

- (NSArray*) items
{
  return items;
}

- (void) removeItem: (id)item
{
  [[self mutableArrayValueForKeyPath: @"items"] removeObject: item];
}

- (void) setItems: (NSArray*)a
{
  ASSIGNCOPY(items, a);
}
@end

int main(int argc,char **argv)
{
  ENTER_POOL
  NSString *s1 = [NSString stringWithFormat: @"Moose1"];
  NSString *s2 = [NSString stringWithFormat: @"Moose2"];
  
  // Removing s1 then s2 works
  TestObject *t1 = AUTORELEASE([[TestObject alloc] init]);
  [t1 addItem: s1];
  [t1 addItem: s2];
  
  PASS_RUNS(({ [t1 removeItem: s1]; [t1 removeItem: s2]; }),
    "array remove first t last")
  
  // Removing s2 then s1 throws exception
  TestObject *t2 = AUTORELEASE([[TestObject alloc] init]);
  [t2 addItem: s1];
  [t2 addItem: s2];
  
  PASS_RUNS(({ [t2 removeItem: s2]; [t2 removeItem: s1]; }),
    "array remove last to first")

  LEAVE_POOL
  return 0;
}

