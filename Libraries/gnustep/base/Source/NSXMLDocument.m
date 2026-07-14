/* Implementation for NSXMLDocument for GNUStep
   Copyright (C) 2008 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Written by:  Gregory John Casamento <greg.casamento@gmail.com>
   Created/Modified: September 2008,2012
      
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#import "common.h"

#if defined(HAVE_LIBXML)

#define GSInternal	NSXMLDocumentInternal

#import "NSXMLPrivate.h"
#import "GSInternal.h"

GS_PRIVATE_INTERNAL(NSXMLDocument)

//#import <Foundation/NSXMLParser.h>
#import "Foundation/NSError.h"

@implementation	NSXMLDocument

+ (Class) replacementClassForClass: (Class)cls
{
  return cls;
}

- (void) dealloc
{
  if (GS_EXISTS_INTERNAL)
    {
      [internal->MIMEType release];
    }
  [super dealloc];
}

- (NSString*) characterEncoding
{
  if (internal->node.doc->encoding)
    return StringFromXMLStringPtr(internal->node.doc->encoding);
  else
    return nil;
}

- (NSXMLDocumentContentKind) documentContentKind
{
  return internal->contentKind;
}

- (NSXMLDTD*) DTD
{
  xmlDtdPtr dtd = xmlGetIntSubset(internal->node.doc);
  return (NSXMLDTD *)[NSXMLNode _objectForNode: (xmlNodePtr)dtd];
}

- (void) _createInternal
{
  GS_CREATE_INTERNAL(NSXMLDocument);
}

- (id) init
{
  return [self initWithKind: NSXMLDocumentKind options: 0];
}

- (id) initWithContentsOfURL: (NSURL*)url
                     options: (NSUInteger)mask
                       error: (NSError**)error
{
  NSData	*data;
  NSXMLDocument	*doc;

  data = [NSData dataWithContentsOfURL: url];
  doc = [self initWithData: data options: mask error: error];
  [doc setURI: [url absoluteString]];
  return doc;
}

- (id) initWithData: (NSData*)data
            options: (NSUInteger)mask
              error: (NSError**)error
{
  // Check for nil data and throw an exception 
  if (nil == data)
    {
      DESTROY(self);
      [NSException raise: NSInvalidArgumentException
		  format: @"[NSXMLDocument-%@] nil argument",
		   NSStringFromSelector(_cmd)];
    }
  if (![data isKindOfClass: [NSData class]])
    {
      DESTROY(self);
      [NSException raise: NSInvalidArgumentException
		  format: @"[NSXMLDocument-%@] non data argument",
		   NSStringFromSelector(_cmd)];
    }

  if ((self = [self initWithKind: NSXMLDocumentKind options: 0]) != nil)
    {
      char *url = NULL;
      char *encoding = NULL; // "UTF8";
      int xmlOptions = XML_PARSE_NOERROR;
      xmlDocPtr doc = NULL;

      if (!(mask & NSXMLNodePreserveWhitespace))
        {
          xmlOptions |= XML_PARSE_NOBLANKS;
          //xmlKeepBlanksDefault(0);
        }
      if (mask & NSXMLNodeLoadExternalEntitiesNever)
        {
          xmlOptions |= XML_PARSE_NOENT;
        }
      if (!(mask & NSXMLNodeLoadExternalEntitiesAlways))
        {
          xmlOptions |= XML_PARSE_NONET;
        }

      doc = xmlReadMemory([data bytes], [data length], 
                          url, encoding, xmlOptions);
      if (doc == NULL)
	{
          DESTROY(self);
	  if (error != NULL)
            {
              *error = [NSError errorWithDomain: @"NSXMLErrorDomain"
                                           code: 0
                                       userInfo: nil]; 
            }
          return nil;
	}

      // Free old node
      xmlFreeDoc((xmlDocPtr)internal->node.doc);
      [self _setNode: doc];

      if (mask & NSXMLDocumentValidate)
        {
          [self validateAndReturnError: error];
        }
    }

  return self;
}

- (id) initWithKind: (NSXMLNodeKind)theKind options: (NSUInteger)theOptions
{
  if (NSXMLDocumentKind == theKind)
    {
      return [super initWithKind: theKind options: theOptions];
    }
  else
    {
      [self release];
      // This cast is here to keep clang quite that expects an init* method to 
      // return an object of the same class, which is not true here.
      return (NSXMLDocument*)[[NSXMLNode alloc] initWithKind: theKind
                                                     options: theOptions];
    }
}

- (id) initWithRootElement: (NSXMLElement*)element
{
  self = [self initWithKind: NSXMLDocumentKind options: 0];
  if (self != nil)
    {
      NS_DURING
        [self setRootElement: (NSXMLNode*)element];
      NS_HANDLER
	RELEASE(self);
	[localException raise];
      NS_ENDHANDLER
    }
  return self;
}

- (id) initWithXMLString: (NSString*)string
                 options: (NSUInteger)mask
                   error: (NSError**)error
{
  if (nil == string)
    {
      DESTROY(self);
      [NSException raise: NSInvalidArgumentException
                  format: @"[NSXMLDocument-%@] nil argument",
                   NSStringFromSelector(_cmd)];
    }
  if (NO == [string isKindOfClass: [NSString class]])
    {
      DESTROY(self);
      [NSException raise: NSInvalidArgumentException
		  format: @"[NSXMLDocument-%@] invalid argument",
                   NSStringFromSelector(_cmd)];
    }
  return [self initWithData: [string dataUsingEncoding: NSUTF8StringEncoding]
                    options: mask
                      error: error];
}

- (BOOL) isStandalone
{
  return (internal->node.doc->standalone == 1);
}

- (NSString*) MIMEType
{
  return internal->MIMEType;
}

- (NSXMLElement*) rootElement
{
  xmlNodePtr rootElem = xmlDocGetRootElement(internal->node.doc);
  return (NSXMLElement *)[NSXMLNode _objectForNode: rootElem];
}

- (void) setCharacterEncoding: (NSString*)encoding
{
  if (internal->node.doc->encoding != NULL)
    {
      xmlFree((xmlChar *)internal->node.doc->encoding);
    }
  internal->node.doc->encoding = XMLStringCopy(encoding);
}

- (void) setDocumentContentKind: (NSXMLDocumentContentKind)theContentKind
{
  internal->contentKind = theContentKind;
}

- (void) setDTD: (NSXMLDTD*)documentTypeDeclaration
{
  NSXMLDTD *old;

  NSAssert(documentTypeDeclaration != nil, NSInvalidArgumentException);

  // detach the old DTD, this also removes the corresponding child
  old = [self DTD];
  [old detach];

  internal->node.doc->intSubset = (xmlDtdPtr)[documentTypeDeclaration _node];
  [self addChild: documentTypeDeclaration];
}

- (void) setMIMEType: (NSString*)theMIMEType
{
  ASSIGNCOPY(internal->MIMEType, theMIMEType);
}

- (void) setRootElement: (NSXMLNode*)root
{
  if (root == nil)
    {
      return;
    }
  if ([root parent] != nil)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"%@ cannot be used as root of %@", 
		   root, 
		   self];
    }

  // remove all sub nodes
  [self setChildren: nil];

  // FIXME: Should we use addChild: here? 
  xmlDocSetRootElement(internal->node.doc, [root _node]);
  if (GSIVar(root, detached))
    {
      xmlFreeDoc(GSIVar(root, detached));
      GSIVar(root, detached) = 0;
    }

  // Do our subNode housekeeping...
  [self _addSubNode: root];
}

- (void) setStandalone: (BOOL)standalone
{
  internal->node.doc->standalone = standalone;
}

- (void) setURI: (NSString*)URI
{
  xmlDocPtr theNode = internal->node.doc;

  if (theNode->URL != NULL)
    {
      xmlFree((xmlChar *)theNode->URL);
    }
  theNode->URL = XMLStringCopy(URI);
}

- (NSString*) URI
{
  xmlDocPtr theNode = internal->node.doc;

  if (theNode->URL)
    {
      return StringFromXMLStringPtr(theNode->URL);
    }
  else
    {
      return nil;
    }
}

- (void) setVersion: (NSString*)version
{
  if ([version isEqualToString: @"1.0"] || [version isEqualToString: @"1.1"])
    {
      xmlDocPtr theNode = internal->node.doc;
  
      if (theNode->version != NULL)
        {
          xmlFree((xmlChar *)theNode->version);
        }
      theNode->version = XMLStringCopy(version);
    }
  else
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Bad XML version (%@)", version];
    }
}

- (NSString*) version
{
  xmlDocPtr theNode = internal->node.doc;

  if (theNode->version)
    return StringFromXMLStringPtr(theNode->version);
  else
    return @"1.0";
}

- (void) insertChild: (NSXMLNode*)child atIndex: (NSUInteger)index
{
  NSXMLNodeKind	theKind = [child kind];
  NSUInteger childCount = [self childCount];

  // Check to make sure this is a valid addition...
  NSAssert(nil != child, NSInvalidArgumentException);
  NSAssert(index <= childCount, NSInvalidArgumentException);
  NSAssert(nil == [child parent], NSInvalidArgumentException);
  NSAssert(NSXMLAttributeKind != theKind, NSInvalidArgumentException);
  NSAssert(NSXMLDTDKind != theKind, NSInvalidArgumentException);
  NSAssert(NSXMLDocumentKind != theKind, NSInvalidArgumentException);
  NSAssert(NSXMLElementDeclarationKind != theKind, NSInvalidArgumentException);
  NSAssert(NSXMLEntityDeclarationKind != theKind, NSInvalidArgumentException);
  NSAssert(NSXMLInvalidKind != theKind, NSInvalidArgumentException);
  NSAssert(NSXMLNamespaceKind != theKind, NSInvalidArgumentException);
  NSAssert(NSXMLNotationDeclarationKind != theKind, NSInvalidArgumentException);

  [self _insertChild: child atIndex: index];
}

- (void) insertChildren: (NSArray*)children atIndex: (NSUInteger)index
{
  NSEnumerator	*enumerator = [children objectEnumerator];
  NSXMLNode	*child;
  
  while ((child = [enumerator nextObject]) != nil)
    {
      [self insertChild: child atIndex: index++];
    }
}

- (void) removeChildAtIndex: (NSUInteger)index
{
  NSXMLNode *child;

  if (index >= [self childCount])
    {
      [NSException raise: NSRangeException
                 format: @"index too large"];
    }

  child = [self childAtIndex: index];
  [child detach];
}

- (void) setChildren: (NSArray*)children
{
  NSUInteger count = [self childCount];

  while (count-- > 0)
    {
      [self removeChildAtIndex: count];
    }

  [self insertChildren: children atIndex: 0];
}
 
- (void) addChild: (NSXMLNode*)child
{
  [self insertChild: child atIndex: [self childCount]];
}
 
- (void) replaceChildAtIndex: (NSUInteger)index withNode: (NSXMLNode*)theNode
{
  [self insertChild: theNode atIndex: index];
  [self removeChildAtIndex: index + 1];
}

- (NSData*) XMLData
{ 
  return [self XMLDataWithOptions: NSXMLNodeOptionsNone]; 
}

- (NSData *) XMLDataWithOptions: (NSUInteger)theOptions
{
  NSString *xmlString = [self XMLStringWithOptions: theOptions];

  return [xmlString dataUsingEncoding: NSUTF8StringEncoding
                 allowLossyConversion: NO];
}

- (id) objectByApplyingXSLT: (NSData*)xslt
                  arguments: (NSDictionary*)arguments
                      error: (NSError**)error
{
#ifdef HAVE_LIBXSLT
  xmlChar **params = NULL;
  xmlDocPtr stylesheetDoc = xmlReadMemory([xslt bytes], [xslt length],
                                          NULL, NULL, XML_PARSE_NOERROR | XML_PARSE_NONET);
  xsltStylesheetPtr stylesheet = xsltParseStylesheetDoc(stylesheetDoc);
  xmlDocPtr resultDoc = NULL;
 
  // Iterate over the keys and put them into params...
  if (arguments != nil)
    {
      NSEnumerator *en = [arguments keyEnumerator];
      NSString *key = nil;
      NSUInteger index = 0;
      int count = [[arguments allKeys] count];

      params = NSZoneCalloc([self zone], ((count + 1) * 2), sizeof(xmlChar *));
      while ((key = [en nextObject]) != nil)
	{
	  params[index] = (xmlChar *)XMLSTRING(key);
	  params[index + 1]
            = (xmlChar *)XMLSTRING([arguments objectForKey: key]);
	  index += 2;
	}
      params[index] = NULL;
      params[index + 1] = NULL;
    }

  // Apply the stylesheet and get the result...
  resultDoc = xsltApplyStylesheet(stylesheet, internal->node.doc,
                                  (const char **)params);
  
  // Cleanup...
  xsltFreeStylesheet(stylesheet);
  xmlFreeDoc(stylesheetDoc);
  xsltCleanupGlobals();
  xmlCleanupParser();
  NSZoneFree([self zone], params);

  return [NSXMLNode _objectForNode: (xmlNodePtr)resultDoc];
#else /* HAVE_LIBXSLT */ 
  return nil;
#endif /* HAVE_LIBXSLT */
}

- (id) objectByApplyingXSLTString: (NSString*)xslt
                        arguments: (NSDictionary*)arguments
                            error: (NSError**)error
{
  NSData *data =  [xslt dataUsingEncoding: NSUTF8StringEncoding];
  NSXMLDocument *result = [self objectByApplyingXSLT: data
                                           arguments: arguments
                                               error: error];
  return result;
}

- (id) objectByApplyingXSLTAtURL: (NSURL*)xsltURL
                       arguments: (NSDictionary*)arguments
                           error: (NSError**)error
{
  NSData *data = [NSData dataWithContentsOfURL: xsltURL];
  NSXMLDocument *result = [self objectByApplyingXSLT: data
                                           arguments: arguments
                                               error: error];
  return result;
}

- (BOOL) validateAndReturnError: (NSError**)error
{
  xmlValidCtxtPtr ctxt = xmlNewValidCtxt();
  // FIXME: Should use xmlValidityErrorFunc and userData
  // to get the error
  BOOL result = (BOOL)(xmlValidateDocument(ctxt, internal->node.doc));
  xmlFreeValidCtxt(ctxt);
  return result;
}

- (id) copyWithZone: (NSZone *)zone
{
  NSXMLDocument *c = (NSXMLDocument*)[super copyWithZone: zone];

  [c setMIMEType: [self MIMEType]];
  // the intSubset is copied by libxml2
  //[c setDTD: [self DTD]];
  [c setDocumentContentKind: [self documentContentKind]];
  return c;
}

- (BOOL) isEqual: (id)other
{
  if (self == other)
    {
      return YES;
    }
  // FIXME
  return [[self rootElement] isEqual: [other rootElement]];
}
@end

#else /* HAVE_LIBXML */

#import "Foundation/NSXMLDocument.h"

@implementation	NSXMLDocument

+ (Class) replacementClassForClass: (Class)cls
{
  return cls;
}

- (NSString*) characterEncoding
{
  return [self notImplemented: _cmd];
}

- (NSXMLDocumentContentKind) documentContentKind
{
  return 0;
}

- (NSXMLDTD*) DTD
{
  return [self notImplemented: _cmd];
}

- (id) init
{
  return [super init];
}

- (id) initWithContentsOfURL: (NSURL*)url
                     options: (NSUInteger)mask
                       error: (NSError**)error
{
  return [self init];
}

- (id) initWithData: (NSData*)data
            options: (NSUInteger)mask
              error: (NSError**)error
{
  return [self init];
}

- (id) initWithKind: (NSXMLNodeKind)theKind options: (NSUInteger)theOptions
{
  return [self init];
}

- (id) initWithRootElement: (NSXMLElement*)element
{
  return [self init];
}

- (id) initWithXMLString: (NSString*)string
                 options: (NSUInteger)mask
                   error: (NSError**)error
{
  return [self init];
}

- (BOOL) isStandalone
{
  return NO;
}

- (NSString*) MIMEType
{
  return [self notImplemented: _cmd];
}

- (NSXMLElement*) rootElement
{
  return [self notImplemented: _cmd];
}

- (void) setCharacterEncoding: (NSString*)encoding
{
  [self notImplemented: _cmd];
}

- (void) setDocumentContentKind: (NSXMLDocumentContentKind)theContentKind
{
  [self notImplemented: _cmd];
}

- (void) setDTD: (NSXMLDTD*)documentTypeDeclaration
{
  [self notImplemented: _cmd];
}

- (void) setMIMEType: (NSString*)theMIMEType
{
  [self notImplemented: _cmd];
}

- (void) setRootElement: (NSXMLNode*)root
{
  [self notImplemented: _cmd];
}

- (void) setStandalone: (BOOL)standalone
{
  [self notImplemented: _cmd];
}

- (void) setURI: (NSString*)URI
{
  [self notImplemented: _cmd];
}

- (NSString*) URI
{
  return [self notImplemented: _cmd];
}

- (void) setVersion: (NSString*)version
{
  [self notImplemented: _cmd];
}

- (NSString*) version
{
  return [self notImplemented: _cmd];
}

- (void) insertChild: (NSXMLNode*)child atIndex: (NSUInteger)index
{
  [self notImplemented: _cmd];
}

- (void) insertChildren: (NSArray*)children atIndex: (NSUInteger)index
{
  [self notImplemented: _cmd];
}

- (void) removeChildAtIndex: (NSUInteger)index
{
  [self notImplemented: _cmd];
}

- (void) setChildren: (NSArray*)children
{
  [self notImplemented: _cmd];
}
 
- (void) addChild: (NSXMLNode*)child
{
  [self notImplemented: _cmd];
}
 
- (void) replaceChildAtIndex: (NSUInteger)index withNode: (NSXMLNode*)theNode
{
  [self notImplemented: _cmd];
}

- (NSData*) XMLData
{ 
  return [self notImplemented: _cmd];
}

- (NSData *) XMLDataWithOptions: (NSUInteger)theOptions
{
  return [self notImplemented: _cmd];
}

- (id) objectByApplyingXSLT: (NSData*)xslt
                  arguments: (NSDictionary*)arguments
                      error: (NSError**)error
{
  return [self notImplemented: _cmd];
}

- (id) objectByApplyingXSLTString: (NSString*)xslt
                        arguments: (NSDictionary*)arguments
                            error: (NSError**)error
{
  return [self notImplemented: _cmd];
}

- (id) objectByApplyingXSLTAtURL: (NSURL*)xsltURL
                       arguments: (NSDictionary*)arguments
                           error: (NSError**)error
{
  return [self notImplemented: _cmd];
}

- (BOOL) validateAndReturnError: (NSError**)error
{
  return NO;
}

- (id) copyWithZone: (NSZone *)zone
{
  return [self notImplemented: _cmd];
}

- (BOOL) isEqual: (id)other
{
  return NO;
}
@end

#endif /* HAVE_LIBXML */
