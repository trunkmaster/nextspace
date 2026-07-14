#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

int main()
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSURLRequest          *request;
  NSMutableURLRequest   *mutable;
  NSURL                 *httpURL, *foobarURL;
  NSDictionary          *expected;

  httpURL = [NSURL URLWithString: @"http://www.gnustep.org"];
  foobarURL = [NSURL URLWithString: @"foobar://localhost/madeupscheme"];

  TEST_FOR_CLASS(@"NSURLRequest", AUTORELEASE([NSURLRequest alloc]),
    "NSURLRequest +alloc returns an NSURLRequest");

  request = [NSURLRequest requestWithURL: httpURL];
  PASS(request != nil,
    "NSURLRequest +requestWithURL returns a request from a valid URL");
  PASS_EQUAL([[request URL] absoluteString], [httpURL absoluteString],
    "Request URL is equal to the URL used for creation");
  PASS_EQUAL([request HTTPMethod], @"GET",
    "Request is initialized with a GET method");

  request = [NSURLRequest requestWithURL: foobarURL];
  PASS(request != nil,
    "NSURLRequest +requestWithURL returns a request from an invalid URL (unknown scheme)");
  
  mutable = AUTORELEASE([request mutableCopy]);
  PASS(mutable != nil && [mutable isKindOfClass:[NSMutableURLRequest class]],
    "NSURLRequest -mutableCopy returns a mutable request");
  [mutable setHTTPMethod: @"POST"];
  PASS_EQUAL([mutable HTTPMethod], @"POST",
    "Can setHTTPMethod of a mutable request (POST)");
  [mutable setHTTPMethod: @"NONHTTPMETHOD"];
  PASS_EQUAL([mutable HTTPMethod], @"NONHTTPMETHOD",
    "Can setHTTPMethod of a mutable request (non existant NONHTTPMETHOD)");

  [mutable addValue: @"value1" forHTTPHeaderField: @"gnustep"];
  PASS_EQUAL([mutable valueForHTTPHeaderField: @"gnustep"], @"value1",
    "Can set and get a value for an HTTP header field");
  [mutable addValue: @"value2" forHTTPHeaderField: @"gnustep"];
  PASS_EQUAL([mutable valueForHTTPHeaderField: @"gnustep"], (@"value1,value2"),
    "Handle multiple values for an HTTP header field");
  [mutable setAllHTTPHeaderFields: [NSDictionary dictionaryWithObject: @"object" forKey: @"key"]];
  expected = [NSDictionary dictionaryWithObjectsAndKeys:@"object", @"key", @"value1,value2", @"gnustep", nil];
  PASS_EQUAL([mutable allHTTPHeaderFields], expected, "setAllHTTPHeaderFields adds header");
  [mutable setValue: @"value3" forHTTPHeaderField: @"gnustep"];
  expected = [NSDictionary dictionaryWithObjectsAndKeys:@"object", @"key", @"value3", @"gnustep", nil];
  PASS_EQUAL([mutable allHTTPHeaderFields], expected, "Update header field");
  [mutable setValue: nil forHTTPHeaderField: @"gnustep"];
  expected = [NSDictionary dictionaryWithObjectsAndKeys:@"object", @"key", nil];
  PASS_EQUAL([mutable allHTTPHeaderFields], expected, "Remove header field");

  mutable = AUTORELEASE([NSMutableURLRequest new]);
  PASS(mutable != nil && [mutable isKindOfClass:[NSMutableURLRequest class]],
    "NSURLRequest +new returns a mutable request");

  PASS_EQUAL([mutable URL], nil, "nil URL from empty request");
  PASS_EQUAL([mutable HTTPMethod], @"GET", "GET method from empty request");

  [arp release]; arp = nil;
  return 0;
}
