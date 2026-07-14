#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSExpression.h>
#import <Foundation/NSKeyValueCoding.h>
#import <Foundation/NSPredicate.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import "Foundation/NSException.h"
#import "Foundation/NSDateFormatter.h"

void
testKVC(NSDictionary *dict)
{
  PASS([@"A Title" isEqual: [dict valueForKey: @"title"]], "valueForKeyPath: with string");
  PASS([@"A Title" isEqual: [dict valueForKeyPath: @"title"]], "valueForKeyPath: with string");
PASS([@"John" isEqual: [dict valueForKeyPath: @"Record1.Name"]], "valueForKeyPath: with string");
  PASS(30 == [[dict valueForKeyPath: @"Record2.Age"] intValue], "valueForKeyPath: with int");
}

void
testContains(NSDictionary *dict)
{
  NSPredicate *p;

  p = [NSPredicate predicateWithFormat: @"%@ CONTAINS %@", @"AABBBAA", @"BBB"];
  PASS([p evaluateWithObject: dict], "%%@ CONTAINS %%@");
  p = [NSPredicate predicateWithFormat: @"%@ IN %@", @"BBB", @"AABBBAA"];
  PASS([p evaluateWithObject: dict], "%%@ IN %%@");
}

void
testString(NSDictionary *dict)
{
  NSPredicate *p;

  p = [NSPredicate predicateWithFormat: @"%K == %@", @"Record1.Name", @"John"];
  PASS([p evaluateWithObject: dict], "%%K == %%@");
  p = [NSPredicate predicateWithFormat: @"%K MATCHES[c] %@", @"Record1.Name", @"john"];
  PASS([p evaluateWithObject: dict], "%%K MATCHES[c] %%@");
  p = [NSPredicate predicateWithFormat: @"%K BEGINSWITH %@", @"Record1.Name", @"Jo"];
  PASS([p evaluateWithObject: dict], "%%K BEGINSWITH %%@");
  p = [NSPredicate predicateWithFormat: @"(%K == %@) AND (%K == %@)", @"Record1.Name", @"John", @"Record2.Name", @"Mary"];
  PASS([p evaluateWithObject: dict], "(%%K == %%@) AND (%%K == %%@)");

  NSMutableArray *strings = [NSMutableArray arrayWithObjects: @"a", @"aa",
    @"aaa", @"aaaa", nil];
  NSArray *expect = [NSMutableArray arrayWithObjects: @"aaa", @"aaaa", nil];
  p = [NSPredicate predicateWithFormat: @"self beginswith 'aaa'"];
  [strings filterUsingPredicate: p];
  PASS_EQUAL(strings, expect, "filter using BEGINSWITH") 
}

void
testInteger(NSDictionary *dict)
{
  NSPredicate *p;

  p = [NSPredicate predicateWithFormat: @"%K == %d", @"Record1.Age", 34];
  PASS([p evaluateWithObject: dict], "%%K == %%d");
  p = [NSPredicate predicateWithFormat: @"%K = %@", @"Record1.Age", [NSNumber numberWithInt: 34]];
  PASS([p evaluateWithObject: dict], "%%K = %%@");
  p = [NSPredicate predicateWithFormat: @"%K == %@", @"Record1.Age", [NSNumber numberWithInt: 34]];
  PASS([p evaluateWithObject: dict], "%%K == %%@");
  p = [NSPredicate predicateWithFormat: @"%K < %d", @"Record1.Age", 40];
  PASS([p evaluateWithObject: dict], "%%K < %%d");
  p = [NSPredicate predicateWithFormat: @"%K < %@", @"Record1.Age", [NSNumber numberWithInt: 40]];
  PASS([p evaluateWithObject: dict], "%%K < %%@");
  p = [NSPredicate predicateWithFormat: @"%K <= %@", @"Record1.Age", [NSNumber numberWithInt: 40]];
  PASS([p evaluateWithObject: dict], "%%K <= %%@");
  p = [NSPredicate predicateWithFormat: @"%K <= %@", @"Record1.Age", [NSNumber numberWithInt: 34]];
  PASS([p evaluateWithObject: dict], "%%K <= %%@");
  p = [NSPredicate predicateWithFormat: @"%K > %@", @"Record1.Age", [NSNumber numberWithInt: 20]];
  PASS([p evaluateWithObject: dict], "%%K > %%@");
  p = [NSPredicate predicateWithFormat: @"%K >= %@", @"Record1.Age", [NSNumber numberWithInt: 34]];
  PASS([p evaluateWithObject: dict], "%%K >= %%@");
  p = [NSPredicate predicateWithFormat: @"%K >= %@", @"Record1.Age", [NSNumber numberWithInt: 20]];
  PASS([p evaluateWithObject: dict], "%%K >= %%@");
  p = [NSPredicate predicateWithFormat: @"%K != %@", @"Record1.Age", [NSNumber numberWithInt: 20]];
  PASS([p evaluateWithObject: dict], "%%K != %%@");
  p = [NSPredicate predicateWithFormat: @"%K <> %@", @"Record1.Age", [NSNumber numberWithInt: 20]];
  PASS([p evaluateWithObject: dict], "%%K <> %%@");
  p = [NSPredicate predicateWithFormat: @"%K BETWEEN %@", @"Record1.Age", [NSArray arrayWithObjects: [NSNumber numberWithInt: 20], [NSNumber numberWithInt: 40], nil]];
  PASS([p evaluateWithObject: dict], "%%K BETWEEN %%@");
  p = [NSPredicate predicateWithFormat: @"(%K == %d) OR (%K == %d)", @"Record1.Age", 34, @"Record2.Age", 34];
  PASS([p evaluateWithObject: dict], "(%%K == %%d) OR (%%K == %%d)");


}

void
testFloat(NSDictionary *dict)
{
  NSPredicate *p;

  p = [NSPredicate predicateWithFormat: @"%K < %f", @"Record1.Age", 40.5];
  PASS([p evaluateWithObject: dict], "%%K < %%f");
p = [NSPredicate predicateWithFormat: @"%f > %K", 40.5, @"Record1.Age"];
  PASS([p evaluateWithObject: dict], "%%f > %%K");
}

void
testAttregate(NSDictionary *dict)
{
  NSPredicate *p;

  p = [NSPredicate predicateWithFormat: @"%@ IN %K", @"Kid1", @"Record1.Children"];
  PASS([p evaluateWithObject: dict], "%%@ IN %%K");
  p = [NSPredicate predicateWithFormat: @"Any %K == %@", @"Record2.Children", @"Girl1"];
  PASS([p evaluateWithObject: dict], "Any %%K == %%@");
}


void
testBlock(NSDictionary* dict)
{
  START_SET("Block predicates");
# if __has_feature(blocks)
  NSPredicate *p = nil;
  NSPredicate *p2 = nil;
  NSDictionary *v = 
    [NSDictionary dictionaryWithObjectsAndKeys: @"Record2", @"Key", nil];
  p = [NSPredicate predicateWithBlock: ^BOOL(id obj, NSDictionary *bindings)
    {
      NSString *key = [bindings objectForKey: @"Key"];

      if (nil == key)
        {
          key = @"Record1";
        }
      NSString *value = [[obj objectForKey: key] objectForKey: @"Name"];
      return [value isEqualToString: @"John"];
    }];
  PASS([p evaluateWithObject: dict], "BLOCKPREDICATE() without bindings");
  PASS(![p evaluateWithObject: dict 
        substitutionVariables: v], "BLOCKPREDICATE() with bound variables");
  p2 = [p predicateWithSubstitutionVariables: 
    [NSDictionary dictionaryWithObjectsAndKeys: @"Record2", @"Key", nil]];
  PASS(p2 != nil, "BLOCKPREDICATE() instantiated from template");
# ifdef APPLE
  /* The next test is known to be fail on OS X, so mark it as hopeful there. 
   * cf. rdar://25059737
   */
  testHopeful = YES;
# endif 
  PASS(![p2 evaluateWithObject: dict], 
    "BLOCKPREDICATE() with bound variables in separate object");
# ifdef APPLE
  testHopeful = NO;
# endif
#  else
  SKIP("No blocks support in the compiler.");
#  endif
  END_SET("Block predicates");
}

void testArray(void)
{
  NSArray	*array;
  NSPredicate 	*predicate;

  array = [NSArray arrayWithObjects:
    [NSNumber numberWithInteger: 1],
    [NSNumber numberWithInteger: 2],
    [NSNumber numberWithInteger: 0],
    nil];

  predicate = [NSPredicate predicateWithFormat: @"SELF[FIRST] = 1"];
  PASS([predicate evaluateWithObject: array], "first is one")

  predicate = [NSPredicate predicateWithFormat: @"SELF[LAST] = 0"];
  PASS([predicate evaluateWithObject: array], "last is zero")

  predicate = [NSPredicate predicateWithFormat: @"SELF[SIZE] = 3"];
  PASS([predicate evaluateWithObject: array], "size is three")
}

void testExpressions(void)
{
  NSExpression *expression = [NSExpression expressionWithFormat: @"%d*%f",3,3.5];
  PASS(expression != nil, "expressionWithFormat: returns an initialized expression");

  id value = [expression expressionValueWithObject: nil context: nil];
  PASS(value != nil, "Expression evaluation returns a value");

  NSExpression *expression2 = [NSExpression expressionWithFormat: @"%f*%f"
    argumentArray: [NSArray arrayWithObjects:
      [NSNumber numberWithFloat: 3.4], [NSNumber numberWithFloat: 3.1], nil]];
  PASS(expression2 != nil, "expressionWithFormat:argumentArray: returns an initialized expression");

  id value2 = [expression2 expressionValueWithObject: nil context: nil];
  PASS(value2 != nil, "Expression evaluation returns a value");

  NSExpression *expression3 = [NSExpression expressionForAggregate:[NSArray arrayWithObjects: expression, expression2, nil]];
  PASS(expression3 != nil, "expressionForAggregate: returns an initialized expression");

  id value3 = [expression3 expressionValueWithObject: nil context: nil];
  PASS(value3 != nil, "Expression evaluation returns a value");
  PASS([value3 isKindOfClass: [NSArray class]], "value is an NSArray");
        
  NSExpression *set1 = [NSExpression expressionForAggregate: [NSArray arrayWithObjects:
									[NSExpression expressionForConstantValue: @"A"],
								      [NSExpression expressionForConstantValue: @"B"],
								      [NSExpression expressionForConstantValue: @"C"], nil]];
  NSExpression *set2 = [NSExpression expressionForAggregate: [NSArray arrayWithObjects:
									[NSExpression expressionForConstantValue: @"C"],
								      [NSExpression expressionForConstantValue: @"D"],
								      [NSExpression expressionForConstantValue: @"E"], nil]];

  NSExpression *expression4 = [NSExpression expressionForIntersectSet:set1 with:set2];
  id value4 = [expression4 expressionValueWithObject:nil context:nil];
  BOOL flag4 = [value4 isEqualToSet: [NSSet setWithObjects: @"C", nil]]; 
  PASS(value4 != nil, "Expression evaluation returns a value");
  PASS([value4 isKindOfClass: [NSSet class]], "value is an NSSet");
  PASS(flag4 == YES, "returns correct value");
  
  NSExpression *expression5 = [NSExpression expressionForUnionSet:set1 with:set2];
  id value5 = [expression5 expressionValueWithObject:nil context:nil];
  // BOOL flag5 = [value5 isEqualToSet: [NSSet setWithObjects: @"A", @"B", @"C" @"E", @"E", nil]]; 
  PASS(value5 != nil, "Expression evaluation returns a value");
  PASS([value5 isKindOfClass: [NSSet class]], "value is an NSSet");
  // PASS(flag5 == YES, "returns correct value");
  
  NSExpression *expression6 = [NSExpression expressionForMinusSet:set1 with:set2];
  id value6 = [expression6 expressionValueWithObject:nil context:nil];
  BOOL flag6 = [value6 isEqualToSet: [NSSet setWithObjects: @"A", @"B", nil]];   
  PASS(value6 != nil, "Expression evaluation returns a value");
  PASS([value6 isKindOfClass: [NSSet class]], "value is an NSSet");
  PASS(flag6 == YES, "returns correct value");

  // This should error out...
  BOOL raised = NO;
  NS_DURING
    {
      NSExpression *expression7 = [NSExpression expressionForMinusSet:set1 with:expression2];
      NSLog(@"%@",[expression7 expressionValueWithObject:nil context:nil]);
    }
  NS_HANDLER
    {
      raised = YES;
      NSLog(@"exception = %@", localException);
    }
  NS_ENDHANDLER;

  PASS(raised, "Raise an exception when a set based NSExpression tries to process a non-set");
}

int main()
{
  NSArray *filtered;
  NSArray *pitches;
  NSArray *expect;
  NSArray *a;
  NSMutableDictionary *dict;
  NSPredicate *p;
  NSDictionary *d;

  START_SET("basic")

  dict = [[NSMutableDictionary alloc] init];
  [dict setObject: @"A Title" forKey: @"title"];

  d = [NSDictionary dictionaryWithObjectsAndKeys:
    @"John", @"Name",
    [NSNumber numberWithInt: 34], @"Age",
    [NSArray arrayWithObjects: @"Kid1", @"Kid2", nil], @"Children",
    nil];
  [dict setObject: d forKey: @"Record1"];

  d = [NSDictionary dictionaryWithObjectsAndKeys:
    @"Mary", @"Name",
    [NSNumber numberWithInt: 30], @"Age",
    [NSArray arrayWithObjects: @"Kid1", @"Girl1", nil], @"Children",
    nil];
  [dict setObject: d forKey: @"Record2"];

  testKVC(dict);
  testContains(dict);
  testString(dict);
  testInteger(dict);
  testFloat(dict);
  testAttregate(dict);
  testBlock(dict);
  [dict release];

  pitches = [NSArray arrayWithObjects:
    @"Do", @"Re", @"Mi", @"Fa", @"So", @"La", nil];
  expect = [NSArray arrayWithObjects: @"Do", nil];

  filtered = [pitches filteredArrayUsingPredicate:
    [NSPredicate predicateWithFormat: @"SELF == 'Do'"]];  
  PASS([filtered isEqual: expect], "filter with SELF");

  filtered = [pitches filteredArrayUsingPredicate:
    [NSPredicate predicateWithFormat: @"description == 'Do'"]];
  PASS([filtered isEqual: expect], "filter with description");

  filtered = [pitches filteredArrayUsingPredicate:
    [NSPredicate predicateWithFormat: @"SELF == '%@'", @"Do"]];
  PASS([filtered isEqual: [NSArray array]], "filter with format");

  PASS([NSExpression expressionForEvaluatedObject]
    == [NSExpression expressionForEvaluatedObject],
    "expressionForEvaluatedObject is unique");

  p = [NSPredicate predicateWithFormat: @"SELF == 'aaa'"];
  PASS([p evaluateWithObject: @"aaa"], "SELF equality works");

  d = [NSDictionary dictionaryWithObjectsAndKeys: 
    @"2", @"foo", nil]; 
  p = [NSPredicate predicateWithFormat: @"SELF.foo <= 2"];
  PASS_EXCEPTION([p evaluateWithObject: d], NSInvalidArgumentException, "SELF.foo <= 2 throws an exception");

  a = [NSArray arrayWithObjects: @"a", @"b", @"c", @"d", nil];
  expect = [NSArray arrayWithObjects: @"b", @"c", nil];
  p = [NSPredicate predicateWithFormat:@"SELF BETWEEN {%@, %@}", @"b", @"c"];
  PASS_EQUAL([a filteredArrayUsingPredicate: p], expect, "BETWEEN on string array works");

  NSNumber *num1 = [NSNumber numberWithInt: 1];
  NSNumber *num2 = [NSNumber numberWithInt: 2];
  NSNumber *num3 = [NSNumber numberWithInt: 3];

  a = [NSArray arrayWithObjects: num1, num2, num3, nil];
  expect = [NSArray arrayWithObjects: num2, num3, nil];
  p = [NSPredicate predicateWithFormat:@"SELF BETWEEN {%d, %d}", 2, 3];
  PASS_EQUAL([a filteredArrayUsingPredicate: p], expect, "BETWEEN on number array works");

  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setDateFormat:@"yyyy-MM-dd"];

  NSDate *first = [dateFormatter dateFromString:@"2024-01-01"];
  NSDate *second = [dateFormatter dateFromString:@"2024-02-01"];
  NSDate *third = [dateFormatter dateFromString:@"2024-03-01"];
  NSDate *fourth = [dateFormatter dateFromString:@"2024-04-01"];

  a = [NSArray arrayWithObjects: first, second, third, fourth, nil];
  expect = [NSArray arrayWithObjects: second, third, nil];
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF BETWEEN {%@, %@}", second, third];
  PASS_EQUAL([a filteredArrayUsingPredicate:predicate], expect, "BETWEEN on date array works");
  [dateFormatter release];

#if 0
  if ([p respondsToSelector: @selector(subpredicates)])
    NSLog(@"subpredicates=%@", [(NSCompoundPredicate *)p subpredicates]);
  if ([p respondsToSelector: @selector(leftExpression)])
    NSLog(@"left=%@", [(NSComparisonPredicate *)p leftExpression]);
  if ([p respondsToSelector: @selector(rightExpression)])
    NSLog(@"right=%@", [(NSComparisonPredicate *)p rightExpression]);
#endif
  
  p = [NSPredicate predicateWithFormat:
    @"%K like %@+$b+$c", @"$single", @"b\""];
  PASS_EQUAL([p predicateFormat], @"$single LIKE (\"b\\\"\" + $b) + $c",
    "predicate created with format has the format is preserved");

  p = [p predicateWithSubstitutionVariables:
    [NSDictionary dictionaryWithObjectsAndKeys:
      @"val_for_single_string", @"single", // why %K does not make a variable
      @"val_for_$b", @"b",
      @"val_for_$c", @"c",
      nil]];
  PASS_EQUAL([p predicateFormat],
    @"$single LIKE (\"b\\\"\" + \"val_for_$b\") + \"val_for_$c\"",
    "Predicate created by substitution has the expected format");

  a = [NSArray arrayWithObjects:
    [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithInt: 1], @"a", nil],
    [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithInt: 2], @"a", nil],
    nil];
  p = [NSPredicate predicateWithFormat: @"sum(a) == 3"]; 
  PASS([p evaluateWithObject: a], "aggregate sum works");

  p = [NSPredicate predicateWithFormat: @"self IN %@",
    [NSArray arrayWithObject:@"yes"]];
  a = [[NSArray arrayWithObjects:@"yes", @"no", nil]
    filteredArrayUsingPredicate: p];
  PASS_EQUAL([a description], @"(yes)",
    "predicate created with format can filter an array")

  testArray();
  testExpressions();
  
  END_SET("basic")

  return 0;
}
