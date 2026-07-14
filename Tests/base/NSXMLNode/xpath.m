#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSXMLElement.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSXMLNode.h>
#import <Foundation/NSError.h>

int main()
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  
  NSString *sourceXML = @"<parent>"
    "<chyld>buzz</chyld>"
    "<otherchyld>woody</otherchyld>"
	"<zorgtree>gollyfoo</zorgtree>"
    "<ln:loner xmlns:ln=\"http://loner.ns\">POW</ln:loner>"
	"</parent>";
  NSXMLDocument *doc = [[[NSXMLDocument alloc] initWithXMLString:sourceXML options:0 error:NULL] autorelease];
  PASS(doc != nil, "created a document from an XML string");
  
  NSError *anError = nil;
  NSXMLNode *node = [[doc nodesForXPath:@"//chyld" error:&anError] lastObject];
  PASS(node != nil, "access chyld node");
  PASS(anError == nil, "no error accessing chyld node");
  PASS_EQUAL([node stringValue], @"buzz", "retrieve chyld node");

  node = [[doc nodesForXPath:@"//ln:loner" error:&anError] lastObject];
  PASS(node == nil, "can't access ln:loner node if namespace not defined at top");
  PASS(anError != nil, "should get error when fail to access node");

  [arp release];
  arp = nil;

  return 0;
}
