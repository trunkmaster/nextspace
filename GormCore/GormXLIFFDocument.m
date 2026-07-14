/* GormXLIFFDocument.m
 *
 * Copyright (C) 2023 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2023
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSXMLNode.h>
#import <Foundation/NSXMLElement.h>
#import <Foundation/NSXMLParser.h>

#import <AppKit/NSMenu.h>
#import <AppKit/NSPopUpButton.h>
#import <AppKit/NSView.h>

#import "GormDocument.h"
#import "GormDocumentController.h"
#import "GormFilePrefsManager.h"
#import "GormProtocol.h"
#import "GormPrivate.h"
#import "GormXLIFFDocument.h"

@implementation GormXLIFFDocument

/**
 * Returns an autoreleast GormXLIFFDocument object;
 */
+ (instancetype) xliffWithGormDocument: (GormDocument *)doc
{
  return AUTORELEASE([[self alloc] initWithGormDocument: doc]);
}

/**
 * Initialize with GormDocument object to parse the XML from or into.
 */
- (instancetype) initWithGormDocument: (GormDocument *)doc
{
  self = [super init];
  if (self != nil)
    {
      ASSIGN(_gormDocument, doc);

      _objectId = nil;
      _source = NO;
      _target = NO;
      _sourceString = nil;
      _targetString = nil;
      _translationDictionary = [[NSMutableDictionary alloc] init];
    }
  return self;
}

- (void) dealloc
{
  DESTROY(_gormDocument);
  _objectId = nil;
  _sourceString = nil;
  _targetString = nil;
  DESTROY(_translationDictionary);
  
  [super dealloc];
}

- (void) _collectObjectsFromObject: (id)obj
			  withNode: (NSXMLElement  *)node
{
  NSString *name = [_gormDocument nameForObject: obj];

  if (name != nil)
    {
      NSString *className = NSStringFromClass([obj class]);
      NSXMLElement *group = [NSXMLNode elementWithName: @"group"];
      NSXMLNode *attr = [NSXMLNode attributeWithName: @"ib:object-id" stringValue: name];

      [group addAttribute: attr];
      if ([obj isKindOfClass: [GormObjectProxy class]] ||
	  [obj respondsToSelector: @selector(className)])
	{
	  className = [obj className];
	}
	    
      attr = [NSXMLNode attributeWithName: @"ib:class" stringValue: className];
      [group addAttribute: attr];      
      [node addChild: group];

      // If the object responds to "title" get that and add it to the XML
      if ([obj respondsToSelector: @selector(title)])
	{
	  NSString *title = [obj title];
	  if (title != nil)
	    {
	      NSXMLElement *transunit = [NSXMLNode elementWithName: @"trans-unit"];
	      NSString *objId = [NSString stringWithFormat: @"%@.title", name];
	      
	      attr = [NSXMLNode attributeWithName: @"ib:key-path-category"
				      stringValue: @"string"];
	      [transunit addAttribute: attr];
	      attr = [NSXMLNode attributeWithName: @"ib:key-path" stringValue: @"title"];
	      [transunit addAttribute: attr];
	      attr = [NSXMLNode attributeWithName: @"id" stringValue: objId];
	      [transunit addAttribute: attr];
	      [group addChild: transunit];
	      
	      NSXMLElement *source = [NSXMLNode elementWithName: @"source"];
	      [source setStringValue: title];
	      [transunit addChild: source];	  
	    }
	}

      // For each different class, recurse through the structure as needed.
      if ([obj isKindOfClass: [NSMenu class]] ||
	  [obj isKindOfClass: [NSPopUpButton class]]) 
	{
	  NSArray *items = [obj itemArray];
	  NSEnumerator *en = [items objectEnumerator];
	  id item = nil;
	  while ((item = [en nextObject]) != nil)
	    {
	      [self _collectObjectsFromObject: item
				     withNode: group];
	    }
	}
      else if ([obj isKindOfClass: [NSMenuItem class]])
	{
	  NSMenu *sm = [obj submenu];
	  if (sm != nil)
	    {
	      [self _collectObjectsFromObject: sm
				     withNode: group];
	    }
	}
      else if ([obj isKindOfClass: [NSWindow class]])
	{
	  [self _collectObjectsFromObject: [obj contentView]
				 withNode: group];
	}
      else if ([obj isKindOfClass: [NSView class]])
	{
	  NSArray *subviews = [obj subviews];
	  NSEnumerator *en = [subviews objectEnumerator];
	  id v = nil;

	  while ((v = [en nextObject]) != nil)
	    {
	      [self _collectObjectsFromObject: v
				     withNode: group];
	    }
	}
    }
}

- (void) _buildXLIFFDocumentWithParentNode: (NSXMLElement *)parentNode
{
  NSEnumerator *en = [[_gormDocument topLevelObjects] objectEnumerator];
  id o = nil;

  [_gormDocument deactivateEditors];
  while ((o = [en nextObject]) != nil)
    {
      [self _collectObjectsFromObject: o
			     withNode: parentNode];
    }
  [_gormDocument reactivateEditors];
}

/**
 * Exports XLIFF file for CAT.  This method starts the process and calls
 * another method that recurses through the objects in the model and pulls
 * any translatable elements.
 */
- (BOOL) exportXLIFFDocumentWithName: (NSString *)name
                  withSourceLanguage: (NSString *)slang
                   andTargetLanguage: (NSString *)tlang
{
  BOOL result = NO;
  id delegate = [NSApp delegate];
  
  if (slang != nil)
    {
      NSString *toolId = @"gnu.gnustep.Gorm";
      NSString *toolName = @"Gorm";
      NSString *toolVersion = [NSString stringWithFormat: @"%d", [GormFilePrefsManager currentVersion]];
      
      if ([delegate isInTool])
	{
	  toolName = @"gormtool";
	  toolId = @"gnu.gnustep.gormtool";
	}
      
      // Build root element...
      NSXMLElement *rootElement = [NSXMLNode elementWithName: @"xliff"];
      NSXMLNode *attr = [NSXMLNode attributeWithName: @"xmlns"
					 stringValue: @"urn:oasis:names:tc:xliff:document:1.2"];
      [rootElement addAttribute: attr];
      NSXMLNode *xsi_ns = [NSXMLNode namespaceWithName: @"xsi"
					   stringValue: @"http://www.w3.org/2001/XMLSchema-instance"];
      [rootElement addNamespace: xsi_ns];
      NSXMLNode *ib_ns = [NSXMLNode namespaceWithName: @"ib"
					  stringValue: @"com.apple.InterfaceBuilder3"];
      [rootElement addNamespace: ib_ns];

      attr = [NSXMLNode attributeWithName: @"version" stringValue: @"1.2"];
      [rootElement addAttribute: attr];
      attr = [NSXMLNode attributeWithName: @"xsi:schemaLocation"
			      stringValue: @"urn:oasis:names:tc:xliff:document:1.2 xliff-core-1.2-transitional.xsd"];
      [rootElement addAttribute: attr];
      
      // Build header...
      NSXMLElement *header = [NSXMLNode elementWithName: @"header"];
      NSXMLElement *tool = [NSXMLNode elementWithName: @"tool"];
      attr = [NSXMLNode attributeWithName: @"tool-id" stringValue: toolId];
      [tool addAttribute: attr];
      attr = [NSXMLNode attributeWithName: @"tool-name" stringValue: toolName];
      [tool addAttribute: attr];
      attr = [NSXMLNode attributeWithName: @"tool-version" stringValue: toolVersion];
      [tool addAttribute: attr];
      [header addChild: tool];

      // Build "file" element...
      NSString *filename = [[_gormDocument fileName] lastPathComponent];
      NSXMLElement *file = [NSXMLNode elementWithName: @"file"];
      GormDocumentController *dc = [GormDocumentController sharedDocumentController];
      NSString *type = [dc typeFromFileExtension: [filename pathExtension]];

      attr = [NSXMLNode attributeWithName: @"original" stringValue: filename];
      [file addAttribute: attr];      
      attr = [NSXMLNode attributeWithName: @"datatype" stringValue: type]; // we will have the plugin return a datatype...
      [file addAttribute: attr];
      attr = [NSXMLNode attributeWithName: @"tool-id" stringValue: toolId];
      [file addAttribute: attr];
      attr = [NSXMLNode attributeWithName: @"source-language" stringValue: slang];
      [file addAttribute: attr];
      if (tlang != nil)
	{
	  attr = [NSXMLNode attributeWithName: @"target-language" stringValue: tlang];
	  [file addAttribute: attr];
	}
      [rootElement addChild: file];
      
      // Set up document...
      NSXMLDocument *xliffDocument = [NSXMLNode documentWithRootElement: rootElement];
      [file addChild: header];
      
      NSXMLElement *body = [NSXMLNode elementWithName: @"body"];
      NSXMLElement *group = [NSXMLNode elementWithName: @"group"];
      attr = [NSXMLNode attributeWithName: @"ib_member-type" stringValue: @"objects"]; // not sure why generates ib_1 when using a colon
      [group addAttribute: attr];
      [body addChild: group];

      // add body to document...
      [file addChild: body];
      
      // Recursively build the XLIFF document from the GormDocument...
      [self _buildXLIFFDocumentWithParentNode: group];
      
      NSData *data = [xliffDocument XMLDataWithOptions: NSXMLNodePrettyPrint | NSXMLNodeCompactEmptyElement ];
      NSString *xmlString = [[NSString alloc] initWithBytes: [data bytes] length: [data length] encoding: NSUTF8StringEncoding];
      NSString *fixedString = [xmlString stringByReplacingOccurrencesOfString: @"ib_member-type"
								   withString: @"ib:member-type"];

      // "fixedString" corrects a rather confusing problem where adding the
      // ib:member-type attribute, for some reason causes the NSXMLNode to
      // create a repeated declaration of the "ib" namespace.  I don't understand
      // why this is happening, but this fixes it in the output for now.
      
      AUTORELEASE(xmlString);
      result = [fixedString writeToFile: name atomically: YES];
    }
  else
    {
      NSLog(@"Source language not specified");
    }
  
  return result;
}

- (void) parserDidStartDocument: (NSXMLParser *)parser
{
  NSDebugLog(@"start of document");
}

- (void) parser: (NSXMLParser *)parser
didStartElement: (NSString *)elementName
   namespaceURI: (NSString *)namespaceURI
  qualifiedName: (NSString *)qName
     attributes: (NSDictionary *)attrs
{
  NSDebugLog(@"start element %@", elementName);
  if ([elementName isEqualToString: @"trans-unit"])
    {
      NSString *objId = [attrs objectForKey: @"id"];
      _objectId = objId;
    }
  else if ([elementName isEqualToString: @"source"])
    {
      _source = YES;
    }
  else if ([elementName isEqualToString: @"target"])
    {
      _target = YES;
    }
}

- (void) parser: (NSXMLParser *)parser
foundCharacters: (NSString *)string
{
  if (_objectId != nil)
    {
      if (_source)
	{
	  NSDebugLog(@"Found source string %@, current id = %@", string, _objectId);
	}

      if (_target)
	{
	  [_translationDictionary setObject: string forKey: _objectId];
	  
	  NSDebugLog(@"Found target string %@, current id = %@", string, _objectId);
	}
    }
}

- (void) parser: (NSXMLParser *)parser
  didEndElement: (NSString *)elementName
   namespaceURI: (NSString *)namespaceURI
  qualifiedName: (NSString *)qName
{
  NSDebugLog(@"end element %@", elementName);
  if ([elementName isEqualToString: @"trans-unit"])
    {
      _objectId = nil;
    }
  else if ([elementName isEqualToString: @"source"])
    {
      _source = NO;
    }
  else if ([elementName isEqualToString: @"target"])
    {
      _target = NO;
    }
}

- (void) parserDidEndDocument: (NSXMLParser *)parser
{
  NSDebugLog(@"end of document");
}

/**
 * Import XLIFF Document withthe name filename
 */
- (BOOL) importXLIFFDocumentWithName: (NSString *)filename
{
  NSData *xmlData = [NSData dataWithContentsOfFile: filename];
  NSXMLParser *xmlParser =
    [[NSXMLParser alloc] initWithData: xmlData];
  BOOL result = NO;
  
  [xmlParser setDelegate: self];
  [xmlParser parse];

  if ([_translationDictionary count] > 0)
    {
      NSEnumerator *en = [_translationDictionary keyEnumerator];
      NSString *oid = nil;

      while ((oid = [en nextObject]) != nil)
	{
	  NSString *target = [_translationDictionary objectForKey: oid];
	  NSArray *c = [oid componentsSeparatedByString: @"."];

	  if ([c count] == 2)
	    {
	      NSString *nm = [c objectAtIndex: 0];
	      NSString *kp = [c objectAtIndex: 1];
	      id o = nil;
	      NSString *capName = [kp capitalizedString];
	      NSString *selName = [NSString stringWithFormat: @"set%@:", capName];
	      SEL _sel = NSSelectorFromString(selName);

	      NSDebugLog(@"computed selector name = %@", selName);
	      
	      // Pull the object that we want to translate and apply the target translation...
	      o = [_gormDocument objectForName: nm];
	      if ([o respondsToSelector: _sel])
		{
		  NSDebugLog(@"performing %@, with object: %@", selName, target);
		  [o performSelector: _sel withObject: target];
		}
	    }	  
	  NSDebugLog(@"target = %@, oid = %@", target, oid);
	}

      result = YES;
    }
  else
    {
      NSLog(@"Document contains no target translation elements");
    }

  
  RELEASE(xmlParser);

  return result;
}

@end
