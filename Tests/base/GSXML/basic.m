#import <Foundation/Foundation.h>
#import "Testing.h"
#if     defined(GNUSTEP_BASE_LIBRARY) && (GS_USE_LIBXML == 1)
#import <Foundation/NSFileManager.h>
#import <GNUstepBase/GSXML.h>
#import "ObjectTesting.h"
int main()
{
  NSAutoreleasePool   	*arp = [NSAutoreleasePool new];
  NSFileManager 	*mgr;
  GSXMLParser   	*parser;
  GSXMLDocument 	*doc;
  GSXMLNamespace 	*namespace;
  NSMutableArray 	*iparams;
  NSMutableArray 	*oparams;
  GSXMLNode		*node;
  GSXMLRPC		*rpc;
  NSString		*xml;
  NSString		*str;
  NSString  		*testPath;
  NSString  		*absolutePath;
  NSData        	*dat;

  TEST_FOR_CLASS(@"GSXMLDocument", AUTORELEASE([GSXMLDocument alloc]),
    "GSXMLDocument +alloc returns a GSXMLDocument");
  
  TEST_FOR_CLASS(@"GSXMLDocument", [GSXMLDocument documentWithVersion: @"1.0"],
    "GSXMLDocument +documentWithVersion: returns a GSXMLDocument");
  
  TEST_FOR_CLASS(@"GSXMLNode", AUTORELEASE([GSXMLNode alloc]),
    "GSXMLNode +alloc returns a GSXMLNode");
  
  TEST_FOR_CLASS(@"GSXMLRPC", AUTORELEASE([GSXMLRPC alloc]),
    "GSXMLRPC +alloc returns a GSXMLRPC instance");

  NS_DURING
    node = [GSXMLNode new]; 
    PASS(node == nil, "GSXMLNode +new returns nil");
  NS_HANDLER
    PASS(node == nil, "GSXMLNode +new returns nil");
  NS_ENDHANDLER
  
  TEST_FOR_CLASS(@"GSXMLNamespace", AUTORELEASE([GSXMLNamespace alloc]),
    "GSXMLNamespace +alloc returns a GSXMLNamespace");
  

  NS_DURING
    namespace = [GSXMLNamespace new]; 
    PASS(namespace == nil, "GSXMLNamespace +new returns nil");
  NS_HANDLER
    PASS(namespace == nil, "GSXMLNamespace +new returns nil");
  NS_ENDHANDLER
  
  doc = [GSXMLDocument documentWithVersion: @"1.0"];
  node = [doc makeNodeWithNamespace: nil name: @"nicola" content: nil]; 
  PASS (node != nil,"Can create a document node");
  
  [doc setRoot: node];
  PASS([[doc root] isEqual: node],"Can set document node as root node");
  
  node = [doc makeNodeWithNamespace: nil name: @"nicola" content: nil];
  [node makeChildWithNamespace: nil
			  name: @"paragraph"
		       content: @"Hi this is some text"];
  [node makeChildWithNamespace: nil
			  name: @"paragraph"
		       content: @"Hi this is even some more text"];
  [doc setRoot: node];
  PASS([[doc root] isEqual: node],
    "Can set a document node (with children) as root node");
  
  namespace = [node makeNamespaceHref: @"http: //www.gnustep.org"
			       prefix: @"gnustep"];
  PASS(namespace != nil,"Can create a node namespace");
  
  node = [doc makeNodeWithNamespace: namespace name: @"nicola" content: nil];
  PASS([[node namespace] isEqual: namespace],
    "Can create a node with a namespace");

  node = [doc makeNodeWithNamespace: namespace name: @"another" content: nil];
  PASS([[node namespace] isEqual: namespace],
    "Can create a node with same namespace as another node");
  
  PASS([[namespace prefix] isEqual: @"gnustep"],
    "A namespace remembers its prefix");
  

  rpc = AUTORELEASE([(GSXMLRPC*)[GSXMLRPC alloc]
    initWithURL: @"http://localhost/"]);
  PASS(rpc != nil, "Can initialise an RPC instance");

  iparams = [NSMutableArray array];
  oparams = [NSMutableArray array];

  dat = [rpc buildMethod: @"method" params: nil];
  PASS(dat != nil, "Can build an empty method call (nil params)");
  str = [rpc parseMethod: dat params: oparams];
  PASS([str isEqual: @"method"] && [iparams isEqual: oparams],
    "Can parse an empty method call (nil params)");

  dat = [rpc buildMethod: @"method" params: iparams];
  PASS(dat != nil, "Can build an empty method call");
  str = [rpc parseMethod: dat params: oparams];
  PASS([str isEqual: @"method"] && [iparams isEqual: oparams],
    "Can parse an empty method call");

  [iparams addObject: @"a string"];
  dat = [rpc buildMethod: @"method" params: iparams];
  PASS(dat != nil, "Can build a method call with a string");
  str = [rpc parseMethod: dat params: oparams];
  PASS([str isEqual: @"method"] && [iparams isEqual: oparams],
    "Can parse a method call with a string");

  [rpc setCompact: YES];
  str = [rpc buildMethodCall: @"method" params: iparams];
  [rpc setCompact: NO];
  str = [str stringByReplacingString: @"<string>" withString: @""];
  str = [str stringByReplacingString: @"</string>" withString: @""];
  str = [rpc parseMethod: [str dataUsingEncoding: NSUTF8StringEncoding]
  		  params: oparams];
  PASS([str isEqual: @"method"] && [iparams isEqual: oparams],
    "Can parse a method call with a string without the <string> element");

  [iparams addObject: [NSNumber numberWithInt: 4]];
  dat = [rpc buildMethod: @"method" params: iparams];
  PASS(dat != nil, "Can build a method call with an integer");
  str = [rpc parseMethod: dat params: oparams];
  PASS([str isEqual: @"method"] && [iparams isEqual: oparams],
    "Can parse a method call with an integer");

  [iparams addObject: [NSNumber numberWithFloat: 4.5]];
  dat = [rpc buildMethod: @"method" params: iparams];
  PASS(dat != nil, "Can build a method call with a float");
  str = [rpc parseMethod: dat params: oparams];
  PASS([str isEqual: @"method"] && [iparams isEqual: oparams],
    "Can parse a method call with a float");

  [iparams addObject: [NSData dataWithBytes: "1234" length: 4]];
  dat = [rpc buildMethod: @"method" params: iparams];
  PASS(dat != nil, "Can build a method call with binary data");
  str = [rpc parseMethod: dat params: oparams];
  PASS([str isEqual: @"method"] && [iparams isEqual: oparams],
    "Can parse a method call with binary data");

  [rpc setTimeZone: [NSTimeZone systemTimeZone]];
  [iparams addObject: [NSDate date]];
  dat = [rpc buildMethod: @"method" params: iparams];
  PASS(dat != nil, "Can build a method call with a date");
  str = [rpc parseMethod: dat params: oparams];
  PASS([str isEqual: @"method"]
    && [[iparams description] isEqual: [oparams description]],
    "Can parse a method call with a date");

  mgr = [NSFileManager defaultManager];
  testPath = [[mgr currentDirectoryPath]
              stringByAppendingPathComponent: @"GNUmakefile"];
  absolutePath = [[NSURL fileURLWithPath: testPath] absoluteString];

  xml = [NSString stringWithFormat:
@"<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n"
@"<!DOCTYPE foo [\n"
@"<!ENTITY foo SYSTEM \"%@\">\n"
@"]>\n"
@"<file>&amp;&foo;&#65;</file>", absolutePath];
  dat = [xml dataUsingEncoding: NSUTF8StringEncoding];

  parser = [GSXMLParser parserWithData: dat];
  [parser substituteEntities: YES];
  [parser parse];
  str = [[[parser document] root] content];
  PASS_EQUAL(str, @"&A", "external entity is ignored")

  parser = [GSXMLParser parserWithData: dat];
  [parser substituteEntities: YES];
  [parser resolveEntities: YES];
  [parser parse];
  str = [[[parser document] root] content];
  PASS(str != nil && [str rangeOfString: @"MAKEFILES"].length > 0,
    "external entity is resolved")

  xml = @"<!DOCTYPE plist PUBLIC \"-//GNUstep//DTD plist 0.9//EN\""
    @" \"http://www.gnustep.org/plist-0_9.xml\">\n"
    @"<plist></plist>";
  dat = [xml dataUsingEncoding: NSUTF8StringEncoding];
  parser = [GSXMLParser parserWithData: dat];
  [parser substituteEntities: YES];
  [parser resolveEntities: YES];
  [parser doValidityChecking: YES];
  PASS([parser parse] == NO, "empty plist is not valid")

  xml = @"<!DOCTYPE plist PUBLIC \"-//GNUstep//DTD plist 0.9//EN\""
    @" \"http://www.gnustep.org/plist-0_9.xml\">\n"
    @"<plist><string>xxx</string></plist>";
  dat = [xml dataUsingEncoding: NSUTF8StringEncoding];
  parser = [GSXMLParser parserWithData: dat];
  [parser substituteEntities: YES];
  [parser resolveEntities: YES];
  [parser doValidityChecking: YES];
  PASS([parser parse] == YES, "plist containing string is valid")

  PASS_EQUAL([[[[[parser document] root] firstChild] firstChild] content],
    @"xxx", "root/plist/string is parsed")

  [arp release]; arp = nil;
  return 0;
}
#else
int main(int argc,char **argv)
{
  START_SET("GSXML")
    SKIP("GSXML support unavailable");
  END_SET("GSXML")
  return 0;
}
#endif
