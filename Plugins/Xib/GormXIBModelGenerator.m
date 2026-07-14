/** <title>GormXIBKeyedArchiver</title>

    <abstract>Interface of GormXIBKeyedArchiver</abstract>

    Copyright (C) 2023 Free Software Foundation, Inc.

    Author:  Gregory John Casamento <greg.casamento@gmail.com>
    Date: 2023

    This file is part of the GNUstep GUI Library.

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; see the file COPYING.LIB.
    If not, see <http://www.gnu.org/licenses/> or write to the
    Free Software Foundation, 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1301, USA.
*/

#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#import <Foundation/NSXMLDocument.h>
#import <Foundation/NSXMLNode.h>
#import <Foundation/NSXMLElement.h>
#import <Foundation/NSXMLParser.h>
#import <Foundation/NSMapTable.h>

#import <AppKit/NSMenu.h>
#import <AppKit/NSPopUpButton.h>
#import <AppKit/NSView.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSTextField.h>
#import <AppKit/NSBox.h>
#import <AppKit/NSTableView.h>
#import <AppKit/NSOutlineView.h>
#import <AppKit/NSBrowser.h>

#import <GNUstepBase/GSObjCRuntime.h>

#import <GormCore/GormDocument.h>
#import <GormCore/GormDocumentController.h>
#import <GormCore/GormFilePrefsManager.h>
#import <GormCore/GormProtocol.h>
#import <GormCore/GormPrivate.h>

#import "GormXIBModelGenerator.h"

static NSArray *_allowedSizeKeys = nil;
static NSArray *_externallyReferencedClasses = nil;
static NSDictionary *_signatures = nil;
static NSArray *_skipClass = nil;
static NSArray *_skipCollectionForKey = nil;
static NSArray *_singletonObjects = nil;
static NSDictionary *_methodToKeyName = nil;
static NSDictionary *_nonProperties = nil;
static NSArray *_excludedKeys = nil;
static NSDictionary *_mappedClassNames = nil;
static NSDictionary *_valueMapping = nil;

static NSUInteger _count = INT_MAX;

/*
NSString* XIBStringFromClass(Class cls)
{
  NSString *className = NSStringFromClass(cls);

  if (className != nil)
    {
      NSString *newClassName = [_mappedClassNames objectForKey: className];

      if (newClassName != nil)
	{
	  className = newClassName;
	}
    }

  return className;
}
*/

@interface NSButtonCell (_Private_)

- (NSButtonType) buttonType;

@end

@implementation NSButtonCell (_Private_)

- (NSButtonType) buttonType
{
  NSButtonType type = 0;
  NSInteger highlightsBy = [self highlightsBy];
  NSInteger showsStateBy = [self showsStateBy];
  BOOL imageDimsWhenDisabled = [self imageDimsWhenDisabled];
  NSString *imageName = [[self image] name];

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wtautological-bitwise-compare"
  if ([imageName isEqualToString: @"GSSwitch"])
    {
      type = NSSwitchButton;
    }
  else if ([imageName isEqualToString: @"GSRadio"])
    {
      type = NSRadioButton;
    }
  else if ((highlightsBy | NSChangeBackgroundCellMask)
	   && (showsStateBy | NSNoCellMask)
	   && (imageDimsWhenDisabled == YES))
    {
      type = NSMomentaryLightButton;
    }
  else if ((highlightsBy | (NSPushInCellMask | NSChangeGrayCellMask))
	   && (showsStateBy | NSNoCellMask)
	   && (imageDimsWhenDisabled == YES))
    {
      type = NSMomentaryPushInButton;
    }
  else if ((highlightsBy | NSContentsCellMask)
	   && (showsStateBy | NSNoCellMask)
	   && (imageDimsWhenDisabled == YES))
    {
      type = NSMomentaryChangeButton;
    }
  else if ((highlightsBy | (NSPushInCellMask | NSChangeGrayCellMask))
	   && (showsStateBy | NSChangeBackgroundCellMask)
	   && (imageDimsWhenDisabled == YES))
    {
      type = NSPushOnPushOffButton;
    }
  else if ((highlightsBy | (NSPushInCellMask | NSContentsCellMask))
	   && (showsStateBy | NSContentsCellMask)
	   && (imageDimsWhenDisabled == YES))
    {
      type = NSOnOffButton;
    }
#pragma GCC diagnostic pop

  return type;
}

- (NSString *) buttonTypeString
{
  NSButtonType type = [self buttonType];
  NSString *result = @"";

  switch (type)
    {
    case NSMomentaryLightButton:
      result = @"push";
      break;
    case NSMomentaryPushInButton:
      result = @"push"; // @"momentaryPushIn";
      break;
    case NSMomentaryChangeButton:
      result = @"momentarychange";
      break;
    case NSPushOnPushOffButton:
      result = @"push"; // @"pushonpushoff";
      break;
    case NSOnOffButton:
      result = @"onoff";
      break;
    case NSToggleButton:
      result = @"toggle";
      break;
    case NSSwitchButton:
      result = @"check";
      break;
    case NSRadioButton:
      result = @"radio";
      break;
    default:
      NSLog(@"Using unsupported button type %d", type);
      break;
    }

  return result;
}
@end

@interface NSString (_hex_)

- (NSString *) lowercaseFirstCharacter;
- (NSString *) splitString;
- (NSString *) hexString;
+ (NSString *) randomHex;

@end

@implementation NSString (_hex_)

- (NSString *) lowercaseFirstCharacter
{
  // Lowercase the first letter of the class to make the element name
  NSString *first = [[self substringToIndex: 1] lowercaseString];
  NSString *rest = [self substringFromIndex: 1];
  NSString *result = [NSString stringWithFormat: @"%@%@", first, rest];
  return result;
}

- (NSString *) splitString
{
  NSString *result = [self substringFromIndex: [self length] - 8];

  result = [NSString stringWithFormat: @"%@-%@-%@",
		     [result substringWithRange: NSMakeRange(0,3)],
		     [result substringWithRange: NSMakeRange(3,2)],
		     [result substringWithRange: NSMakeRange(5,3)]];

  return result;
}

- (NSString *) hexString
{
  NSUInteger l = [self length];
  unichar *c = malloc(l * sizeof(unichar));
  NSUInteger i = 0;

  [self getCharacters: c];

  NSString *result = @"";

  for (i = 0; i < l; i++)
    {
      result = [result stringByAppendingString: [NSString stringWithFormat: @"%x", c[i]]];
    }

  free(c);

  return result;
}

+ (NSString *) randomHex
{
  srand((unsigned int)_count--);
  uint32_t r = (uint32_t)rand();
  return [NSString stringWithFormat: @"%08X", r]; // uppercase so we know it was generated...
}

@end

@interface GormXIBModelGenerator (Private)

- (void) _collectObjectsFromObject: (id)obj
			withParent: (NSXMLElement  *)node;

- (void) _collectObjectsFromObject: (id)obj
			    ForKey: (NSString *)keyName
			withParent: (NSXMLElement  *)node;

@end


@implementation GormXIBModelGenerator

+ (void) initialize
{
  if (self == [GormXIBModelGenerator class])
    {
      _allowedSizeKeys =
	[[NSArray alloc] initWithObjects:
			   @"cellSize",
			 @"intercellSpacing",
			 nil];

      _externallyReferencedClasses =
	[[NSArray alloc] initWithObjects:
			   @"NSTableHeaderView",
			 nil];

      _valueMapping =
	[[NSDictionary alloc] initWithObjectsAndKeys:
				@"catalog", @"NSNamedColorSpace",
			      @"white", @"NSWhiteColorSpace",
			      @"deviceWhite", @"NSDeviceWhiteColorSpace",
			      @"calibratedWhite", @"NSCalibratedWhiteColorSpace",
			      @"deviceCMYK", @"NSDeviceCMYKColorSpace",
			      @"RGB", @"NSRGBColorSpace",
			      @"deviceRGB", @"NSDeviceRGBColorSpace",
			      @"calibratedRGB", @"NSCalibratedRGBColorSpace",
			      @"pattern", @"NSPatternColorSpace",
			      nil];

      _signatures =
	[[NSDictionary alloc] initWithObjectsAndKeys:
				@"char",        @"c",
			      @"NSUInteger",    @"i", // this might be wrong.. maybe it should be NSInteger or just int
			      @"short",         @"s",
			      @"long",          @"l",
			      @"long long",     @"q",
			      @"BOOL",          @"C", // unsigned char
			      @"NSUInteger",    @"I",
			      @"unsigned short",@"S",
			      @"unsigned long", @"L",
			      @"long long",     @"Q",
			      @"float",         @"f",
			      @"CGFloat",       @"d",
			      @"bool",          @"B",
			      @"void",          @"v",
			      @"char*",         @"*",
			      @"id",            @"@",
			      @"Class",         @"#",
			      @"SEL",           @":",
			      @"NSRect",        @"{_NSRect={_NSPoint=dd}{_NSSize=dd}}",
			      @"NSSize",        @"{_NSSize=dd}",
			      @"NSPoint",       @"{_NSPoint=dd}",
			      nil];
      _skipClass =
	[[NSArray alloc] initWithObjects:
			   @"NSBrowserCell",
			 @"NSDateFormatter",
			 @"NSNumberFormatter",
			 nil];

      _skipCollectionForKey =
	[[NSArray alloc] initWithObjects:
			   @"headerView",
			 @"controlView",
			 @"outlineTableColumn",
			 @"documentView",
			 @"menu",
			 @"owner",
			 @"subviews",
			 @"contentView",
			 @"titleCell",
			 nil];

      _singletonObjects =
	[[NSArray alloc] initWithObjects:
			   @"GSNamedColor",
			 @"NSFont",
			 @"NSColor",
			 @"NSImage",
			 @"GSCalibratedWhiteColor",
			 nil];

      _methodToKeyName =
	[[NSDictionary alloc] initWithObjectsAndKeys:
				@"name", @"colorNameComponent",
			      @"catalog", @"catalogNameComponent",
			      @"colorSpace", @"colorSpaceName",
			      @"white", @"whiteComponent",
			      @"red", @"redComponent",
			      @"green", @"greenComponent",
			      @"blue", @"blueComponent",
			      @"alpha", @"alphaComponent",
			      @"cyan", @"cyanComponent",
			      @"magenta", @"magentaComponent",
			      @"yellow", @"yellowComponent",
			      @"black", @"blackComponent",
			      nil];

      _nonProperties =
	[[NSDictionary alloc] initWithObjectsAndKeys:
			    [NSArray arrayWithObject: @"cells"],
			      @"NSMatrix",
			   [NSArray arrayWithObjects:
				      @"colorNameComponent",
				    @"catalogNameComponent",
				    @"colorSpaceName", nil],
			      @"GSNamedColor",
			   [NSArray arrayWithObjects:
				      @"wjoteComponent",
				    @"colorSpaceName", nil],
			      @"GSWhiteColor",
			   [NSArray arrayWithObjects:
				      @"whiteComponent",
				    @"colorSpaceName", nil],
			      @"GSDeviceWhiteColor",
			   [NSArray arrayWithObjects:
				      @"whiteComponent",
				    @"colorSpaceName", nil],
			      @"GSCalibratedWhiteColor",
			   [NSArray arrayWithObjects:
				      @"cyanComponent",
				    @"magentaComponent",
				    @"yellowComponent",
				    @"blackComponent",
				    @"alphaComponent",
				    @"colorSpaceName", nil],
			      @"GSDeviceCMYKColor",
			   [NSArray arrayWithObjects:
				      @"redComponent",
				    @"blueComponent",
				    @"greenComponent",
				    @"alphaComponent",
				    @"colorSpaceName", nil],
			      @"GSRGBColor",
			   [NSArray arrayWithObjects:
				      @"redComponent",
				    @"blueComponent",
				    @"greenComponent",
				    @"alphaComponent",
				    @"colorSpaceName", nil],
			      @"GSDeviceRGBColor",
			   [NSArray arrayWithObjects:
				      @"redComponent",
				    @"blueComponent",
				    @"greenComponent",
				    @"alphaComponent",
				    @"colorSpaceName", nil],
			      @"GSCalibratedRBGColor",
			   [NSArray arrayWithObjects:
				      @"patternImage",
				    @"colorSpaceName", nil],
			      @"GSPatternColor",
			      nil];

      _mappedClassNames =
	[[NSDictionary alloc] initWithObjectsAndKeys:
				@"NSColor", @"GSNamedColor",
			      @"NSColor", @"GSWhiteColor",
			      @"NSColor", @"GSDeviceWhiteColor",
			      @"NSColor", @"GSCalibratedWhiteColor",
			      @"NSColor", @"GSDeviceCMYKColor",
			      @"NSColor", @"GSRGBColor",
			      @"NSColor", @"GSDeviceRGBColor",
			      @"NSColor", @"GSCalibratedRGBColor",
			      @"NSColor", @"GSPatternColor",
			      @"NSView", @"GSTableCornerView",
			      @"NSWindow", @"NSPanel",
			      @"NSWindow", @"GormNSPanel",
			      nil];
      _excludedKeys =
	[[NSArray alloc] initWithObjects:
			   @"font",
			 @"alphaValue",
			 @"servicesProvider",
			 @"servicesMenu",
			 @"nextResponder",
			 @"supermenu",
			 @"attributedStringValue",
			 @"stringValue",
			 @"objectValue",
			 @"menuView", @"menu",
			 @"attributedAlternateTitle",
			 @"attributedTitle",
			 @"miniwindowImage",
			 @"menuItem",
			 @"showsResizeIndicator",
			 @"titleFont",
			 @"target",
			 @"action",
			 @"textContainer",
			 @"subviews",
			 @"selectedRanges",
			 @"linkTextAttributes",
			 @"typingAttributes",
			 @"defaultParagraphStyle",
			 @"tableView",
			 @"sortDescriptors",
			 @"previousText",
			 @"nextText",
			 @"needsDisplay",
			 @"postsFrameChangedNotifications",
			 @"postsBoundsChangedNotifications",
			 @"menuRepresentation",
			 @"submenu",
			 @"initialFirstResponder",
			 @"cornerView",
			 @"doubleValue",
			 @"intValue",
			 @"previousKeyView",
			 @"nextKeyView",
			 @"prototype",
			 @"keyCell",
			 @"isLenient",
			 nil];
    }
}

/**
 * Returns an autoreleast GormXIBDocument object;
 */
+ (instancetype) xibWithGormDocument: (GormDocument *)doc
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
      _mappingDictionary = [[NSMutableDictionary alloc] init];
      _allIdentifiers = [[NSMutableArray alloc] init];
      _objectToIdentifier = RETAIN([NSMapTable weakToWeakObjectsMapTable]);
    }
  return self;
}

- (void) dealloc
{
  DESTROY(_gormDocument);
  DESTROY(_mappingDictionary);
  DESTROY(_allIdentifiers);
  DESTROY(_objectToIdentifier);

  [super dealloc];
}

- (NSString *) _convertName: (NSString *)name
{
  NSString *className = name;

  // NSLog(@"Name = %@", name);

  if ([_mappedClassNames objectForKey: name])
    {
      className = [_mappedClassNames objectForKey: name];
      // NSLog(@"%@ => %@", name, className);
    }

  NSString *result = [className stringByReplacingOccurrencesOfString: @"NS"
							  withString: @""];

  // Try removing other prefixes...
  result = [result stringByReplacingOccurrencesOfString: @"GS"
					     withString: @""];
  result = [result stringByReplacingOccurrencesOfString: @"Gorm"
					     withString: @""];

  // Lowercase the first letter of the class to make the element name
  result = [result lowercaseFirstCharacter];

  // Map certain names to XIB equivalents...
  if ([result isEqualToString: @"objectProxy"])
    {
      result = @"customObject";
    }

  // NSLog(@"Result = %@", result);

  return result;
}

- (BOOL) _isSameClass: (NSString *)className1
		  and: (NSString *)className2
{
  NSString *cc1 = [self _convertName: className1];
  NSString *cc2 = [self _convertName: className2];

  return [cc1 isEqualToString: cc2];
}

- (NSString *) _createIdentifierForObject: (id)obj
{
  NSString *result = nil;

  if (obj != nil)
    {
      result = [_objectToIdentifier objectForKey: obj];
      if (result == nil)
	{
	  if ([obj isKindOfClass: [GormObjectProxy class]])
	    {
	      NSString *className = [obj className];

	      if ([className isEqualToString: @"NSApplication"])
		{
		  result = @"-3";
		  return result;
		}
	      else if ([className isEqualToString: @"NSOwner"])
		{
		  result = @"-2";
		  return result;
		}
	      else if ([className isEqualToString: @"NSFirst"])
		{
		  result = @"-1";
		  return result;
		}
	    }
	  else if([obj isKindOfClass: [GormFilesOwner class]])
	    {
	      result = @"-2";
	      return result;
	}
	  else if([obj isKindOfClass: [GormFirstResponder class]])
	    {
	      result = @"-1";
	      return result;
	    }
	  else
	    {
	      result = [_gormDocument nameForObject: obj];
	    }

	  // Encoding
	  NSString *originalName = [result copy];
	  NSString *stackedResult = [NSString stringWithFormat: @"%@%@%@%@", result,
					      result, result, result];  // kludge...
	  //
	  result = [stackedResult hexString];
	  result = [result splitString];

	  // Collision...
	  id o = [_mappingDictionary objectForKey: result];
	  if (o != nil)
	    {
	      result = [[NSString randomHex] splitString];
	    }

	  // If the id already exists, but isn't mapped...
	  if ([_allIdentifiers containsObject: result])
	    {
	      result = [[NSString randomHex] splitString];
	    }

	  if (originalName != nil)
	    {
	      // Map the name...
	      [_mappingDictionary setObject: originalName
				     forKey: result];
	    }

	  // Record the id...
	  [_allIdentifiers addObject: result];

	  // Record the mapping of obj -> identifier...
	  [_objectToIdentifier setObject: result
				  forKey: obj];
	}
    }

  return result;
}

- (NSString *) _userLabelForObject: (id)obj
{
  NSString *result = nil;

  if ([obj isKindOfClass: [GormObjectProxy class]])
    {
      NSString *className = [obj className];

      if ([className isEqualToString: @"NSApplication"])
	{
	  result = @"Application";
	}
      else if ([className isEqualToString: @"NSOwner"])
	{
	  result = @"File's Owner";
	}
      else if ([className isEqualToString: @"NSFirst"])
	{
	  result = @"First Responder";
	}
    }

  return result;
}

- (void) _createPlaceholderObjects: (NSXMLElement *)elem
{
  NSXMLElement *co = nil;
  NSXMLNode *attr = nil;
  GormFilesOwner *filesOwner = [_gormDocument filesOwner];
  NSString *ownerClassName = [filesOwner className];

  // Application...
  co = [NSXMLNode elementWithName: @"customObject"];
  attr = [NSXMLNode attributeWithName: @"id" stringValue: @"-3"];
  [co addAttribute: attr];

  attr = [NSXMLNode attributeWithName: @"userLabel" stringValue: @"Application"];
  [co addAttribute: attr];

  attr = [NSXMLNode attributeWithName: @"customClass" stringValue: @"NSObject"];
  [co addAttribute: attr];
  [elem addChild: co];

  // File's Owner...
  co = [NSXMLNode elementWithName: @"customObject"];
  attr = [NSXMLNode attributeWithName: @"id" stringValue: @"-2"];
  [co addAttribute: attr];

  attr = [NSXMLNode attributeWithName: @"userLabel" stringValue: @"File's Owner"];
  [co addAttribute: attr];

  attr = [NSXMLNode attributeWithName: @"customClass" stringValue: ownerClassName];
  [co addAttribute: attr];
  [elem addChild: co];
  [self _addAllConnections: co fromObject: filesOwner];

  // First Responder
  co = [NSXMLNode elementWithName: @"customObject"];
  attr = [NSXMLNode attributeWithName: @"id" stringValue: @"-1"];
  [co addAttribute: attr];

  attr = [NSXMLNode attributeWithName: @"userLabel" stringValue: @"First Responder"];
  [co addAttribute: attr];

  attr = [NSXMLNode attributeWithName: @"customClass" stringValue: @"FirstResponder"];
  [co addAttribute: attr];
  [elem addChild: co];
}

- (NSArray *) _propertiesFromMethods: (NSArray *)methods
			   forObject: (id)obj
{
  NSEnumerator *en = [methods objectEnumerator];
  NSString *name = nil;
  NSMutableArray *result = [NSMutableArray array];

  while ((name = [en nextObject]) != nil)
    {
      if ([name isEqualToString: @"set"] == NO) // this is the [NSFont set] method... skip...
	{
	  NSString *substring = [name substringToIndex: 3];
	  if ([substring isEqualToString: @"set"])
	    {
	      NSString *os = [[name substringFromIndex: 3]
			       stringByReplacingOccurrencesOfString: @":"
							 withString: @""];
	      NSString *s = [os lowercaseFirstCharacter];
	      NSString *iss = [NSString stringWithFormat: @"is%@", os];

	      if ([methods containsObject: s])
		{
		  SEL sel = NSSelectorFromString(s);
		  if (sel != NULL)
		    {
		      NSDebugLog(@"selector = %@",s);
		      // NSMethodSignature *sig = [obj methodSignatureForSelector: sel];

		      // NSLog(@"methodSignatureForSelector %@ -> %s", s, [sig methodReturnType]);
		      if ([obj respondsToSelector: sel]) // if it has a normal getting, fine...
			{
			  [result addObject: s];
			}
		    }
		}
	      else if ([methods containsObject: iss])
		{
		  NSDebugLog(@"***** retrying with getter name: %@", iss);
		  SEL sel = NSSelectorFromString(iss);
		  if (sel != nil)
		    {
		      if ([obj respondsToSelector: sel])
			{
			  NSDebugLog(@"Added... %@", iss);
			  [result addObject: iss];
			}
		    }
		}
	    }
	}
    }

  return result;
}

- (void) _addRect: (NSRect)r toElement: (NSXMLElement *)elem withName: (NSString *)name
{
  NSXMLElement *rectElem = [NSXMLNode elementWithName: @"rect"];
  NSXMLNode *attr = nil;

  attr = [NSXMLNode attributeWithName: @"key" stringValue: name];
  [rectElem addAttribute: attr];
  attr = [NSXMLNode attributeWithName: @"x" stringValue: [NSString stringWithFormat: @"%.1f",r.origin.x]];
  [rectElem addAttribute: attr];
  attr = [NSXMLNode attributeWithName: @"y" stringValue: [NSString stringWithFormat: @"%.1f",r.origin.y]];
  [rectElem addAttribute: attr];
  attr = [NSXMLNode attributeWithName: @"width" stringValue: [NSString stringWithFormat: @"%ld", (NSUInteger)r.size.width]];
  [rectElem addAttribute: attr];
  attr = [NSXMLNode attributeWithName: @"height" stringValue: [NSString stringWithFormat: @"%ld", (NSUInteger)r.size.height]];
  [rectElem addAttribute: attr];

  [elem addChild: rectElem];
}

- (void) _addSize: (NSSize)size toElement: (NSXMLElement *)elem withName: (NSString *)name
{
  NSXMLElement *rectElem = [NSXMLNode elementWithName: @"size"];
  NSXMLNode *attr = nil;

  attr = [NSXMLNode attributeWithName: @"key" stringValue: name];
  [rectElem addAttribute: attr];
  attr = [NSXMLNode attributeWithName: @"width" stringValue: [NSString stringWithFormat: @"%ld", (NSUInteger)size.width]];
  [rectElem addAttribute: attr];
  attr = [NSXMLNode attributeWithName: @"height" stringValue: [NSString stringWithFormat: @"%ld", (NSUInteger)size.height]];
  [rectElem addAttribute: attr];

  [elem addChild: rectElem];
}

- (void) _addKeyEquivalent: (NSString *)ke toElement: (NSXMLElement *)elem
{
  if ([ke isEqualToString: @""] == NO)
    {
      NSCharacterSet *cs = [NSCharacterSet alphanumericCharacterSet];
      unichar c = [ke characterAtIndex: 0];

      if ([cs characterIsMember: c])
	{
	  NSXMLNode *attr = [NSXMLNode attributeWithName: @"keyEquivalent" stringValue: ke];
	  [elem addAttribute: attr];
	}

      NSDebugLog(@"elem = %@", elem);
    }
}

- (void) _addKeyEquivalentModifierMask: (NSUInteger)mask toElement: (NSXMLElement *)elem
{
  NSXMLNode *attr = nil;

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wtautological-bitwise-compare"
  NSDebugLog(@"keyEquivalentModifierMask = %ld, element = %@", mask, elem);
  if ([elem attributeForName: @"keyEquivalent"] != nil)
    {
      if (mask | NSCommandKeyMask)
	{
	  attr = [NSXMLNode attributeWithName: @"command" stringValue: @"YES"];
	  [elem addAttribute: attr];
	}
      if (mask | NSShiftKeyMask)
	{
	  attr = [NSXMLNode attributeWithName: @"shift" stringValue: @"YES"];
	  [elem addAttribute: attr];
	}
      if (mask | NSControlKeyMask)
	{
	  attr = [NSXMLNode attributeWithName: @"control" stringValue: @"YES"];
	  [elem addAttribute: attr];
	}
      if (mask | NSAlternateKeyMask)
	{
	  attr = [NSXMLNode attributeWithName: @"option" stringValue: @"YES"];
	  [elem addAttribute: attr];
	}
    }
#pragma GCC diagnostic pop
}

- (void) _addWindowStyleMask: (NSUInteger)mask toElement: (NSXMLElement *)elem
{
  NSXMLNode *attr = nil;

  NSDebugLog(@"styleMask = %ld, element = %@", mask, elem);

  NSXMLElement *styleMaskElem = [NSXMLNode elementWithName: @"windowStyleMask"];

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wtautological-bitwise-compare"
  if (mask | NSWindowStyleMaskTitled)
    {
      attr = [NSXMLNode attributeWithName: @"titled" stringValue: @"YES"];
      [styleMaskElem addAttribute: attr];
    }
  if (mask | NSWindowStyleMaskClosable)
    {
      attr = [NSXMLNode attributeWithName: @"closable" stringValue: @"YES"];
      [styleMaskElem addAttribute: attr];
    }
  if (mask | NSWindowStyleMaskMiniaturizable)
    {
      attr = [NSXMLNode attributeWithName: @"miniaturizable" stringValue: @"YES"];
      [styleMaskElem addAttribute: attr];
    }
  if (mask | NSWindowStyleMaskResizable)
    {
      attr = [NSXMLNode attributeWithName: @"resizable" stringValue: @"YES"];
      [styleMaskElem addAttribute: attr];
    }
#pragma GCC diagnostic pop

  attr = [NSXMLNode attributeWithName: @"key" stringValue: @"styleMask"];
  [styleMaskElem addAttribute: attr];

  [elem addChild: styleMaskElem];
}

- (void) _addButtonType: (NSString *)buttonTypeString toElement: (NSXMLElement *)elem
{
  NSXMLNode *attr = nil;

  attr = [NSXMLNode attributeWithName: @"type" stringValue: buttonTypeString];
  [elem addAttribute: attr];

  if ([buttonTypeString isEqualToString: @"check"]
      || [buttonTypeString isEqualToString: @"radio"])
    {
      attr = [NSXMLNode attributeWithName: @"imagePosition" stringValue: @"left"];
      [elem addAttribute: attr];
    }
}

- (void) _addAlignment: (NSUInteger)alignment toElement: (NSXMLElement *)elem
{
  NSXMLNode *attr = nil;
  NSString *string = nil;

  switch (alignment)
    {
    case NSLeftTextAlignment:
      string = @"left";
      break;
    case NSRightTextAlignment:
      string = @"right";
      break;
    case NSCenterTextAlignment:
      string = @"center";
      break;
    case NSJustifiedTextAlignment:
      string = @"justified";
      break;
    case NSNaturalTextAlignment:
      string = @"natural";
      break;
    }

  attr = [NSXMLNode attributeWithName: @"alignment" stringValue: string];
  [elem addAttribute: attr];
}

- (void) _addBezelStyleForObject: (id)obj
		       toElement: (NSXMLElement *)elem
{
  NSString *result = nil;
  NSXMLNode *attr = nil;

  if ([obj isKindOfClass: [NSButtonCell class]])
    {
      NSBezelStyle bezel = (NSBezelStyle)[obj bezelStyle] - 1;
      NSArray *bezelTypeArray = [NSArray arrayWithObjects:
					   @"rounded",
					 @"regularSquare",
					 @"thick",
					 @"thicker",
					 @"disclosure",
					 @"shadowlessSquare",
					 @"circular",
					 @"texturedSquare",
					 @"helpButton",
					 @"smallSquare",
					 @"texturedRounded",
					 @"roundRect",
					 @"recessed",
					 @"roundedDisclosure",
					 @"next",
					 @"pushButton",
					 @"smallIconButton",
					 @"mediumIconButton",
					 @"largeIconButton", nil];
      if (bezel >= 0 && bezel <= 18)
	{
	  result = [bezelTypeArray objectAtIndex: bezel];
	}
    }
  else if ([obj isKindOfClass: [NSTextFieldCell class]])
    {
      NSTextFieldBezelStyle bezel = (NSTextFieldBezelStyle)[obj bezelStyle];
      NSArray *bezelTypeArray = [NSArray arrayWithObjects:
					   @"square",
					 @"rounded", nil];

      if (bezel >= 0 && bezel <= 1)
	{
	  result = [bezelTypeArray objectAtIndex: bezel];
	}
    }

  if (result != nil)
    {
      attr = [NSXMLNode attributeWithName: @"bezelStyle" stringValue: result];
      [elem addAttribute: attr];
    }
}

- (void) _addBorderStyle: (BOOL)bordered toElement: (NSXMLElement *)elem
{
  if (bordered)
    {
      NSXMLNode *attr = [NSXMLNode attributeWithName: @"borderStyle" stringValue: @"border"];
      [elem addAttribute: attr];
    }
}

- (void) _addAutoresizingMask: (NSAutoresizingMaskOptions)m toElement: (NSXMLElement *)elem
{
  if (m != 0)
    {
      NSXMLElement *autoresizingMaskElem = [NSXMLNode elementWithName: @"autoresizingMask"];
      NSXMLNode *attr = nil;

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wtautological-bitwise-compare"
      if (m | NSViewWidthSizable)
	{
	  attr = [NSXMLNode attributeWithName: @"widthSizable" stringValue: @"YES"];
	}
      if (m | NSViewHeightSizable)
	{
	  attr = [NSXMLNode attributeWithName: @"heightSizable" stringValue: @"YES"];
	}
      if (m | NSViewMaxXMargin)
	{
	  attr = [NSXMLNode attributeWithName: @"flexibleMaxX" stringValue: @"YES"];
	}
      if (m | NSViewMaxYMargin)
	{
	  attr = [NSXMLNode attributeWithName: @"flexibleMaxY" stringValue: @"YES"];
	}
      if (m | NSViewMinXMargin)
	{
	  attr = [NSXMLNode attributeWithName: @"flexibleMinX" stringValue: @"YES"];
	}
      if (m | NSViewMinYMargin)
	{
	  attr = [NSXMLNode attributeWithName: @"flexibleMinY" stringValue: @"YES"];
	}
#pragma GCC diagnostic pop

      [autoresizingMaskElem addAttribute: attr];
      attr = [NSXMLNode attributeWithName: @"key" stringValue: @"autoresizeMask"];
      [autoresizingMaskElem addAttribute: attr];

      [elem addChild: autoresizingMaskElem];
    }
}

- (void) _addTitlePosition: (NSTitlePosition)p toElement: (NSXMLElement *)elem
{
  NSString *result = nil;

  switch (p)
    {
    case NSNoTitle:
      result = @"noTitle";
      break;
    case NSAboveTop:
      result = @"aboveTop";
      break;
    case NSAtTop:
      break;
    case NSBelowTop:
      result = @"belowTop";
      break;
    case NSAboveBottom:
      result = @"aboveBottom";
      break;
    case NSAtBottom:
      result = @"atBottom";
      break;
    case NSBelowBottom:
      result = @"belowBottom";
      break;
    }

  if (result != nil)
    {
      NSXMLNode *attr = [NSXMLNode attributeWithName: @"titlePosition" stringValue: result];
      [elem addAttribute: attr];
    }
}

- (void) _addTableColumns: (NSArray *)cols toElement: (NSXMLElement *)elem
{
  if ([cols count] > 0)
    {
      NSXMLElement *tblColElem = [NSXMLNode elementWithName: @"tableColumns"];
      NSEnumerator *en = [cols objectEnumerator];
      id col = nil;

      // NSLog(@"cols = %@", cols);
      while ((col = [en nextObject]) != nil)
	{
	  [self _collectObjectsFromObject: col
			       withParent: tblColElem];
	}

      [elem addChild: tblColElem];
    }
}

- (void) _addBoolean: (BOOL)flag withName: (NSString *)name  toElement: (NSXMLElement *)elem
{
  if (flag == YES)
    {
      NSXMLNode *attr = [NSXMLNode attributeWithName: name
					 stringValue: @"YES"];
      [elem addAttribute: attr];

      // Somewhat kludgy fix for button border problem...
      if ([name isEqualToString: @"bordered"])
	{
	  attr = [NSXMLNode attributeWithName: @"borderStyle"
				  stringValue: @"border"];
	  [elem addAttribute: attr];
	}
    }
}

- (void) _addFloat: (CGFloat)f withName: (NSString *)name  toElement: (NSXMLElement *)elem
{
  NSString *val = [NSString stringWithFormat: @"%.1f",f];
  NSXMLNode *attr = [NSXMLNode attributeWithName: name
				     stringValue: val];
  [elem addAttribute: attr];
}

- (void) _addString: (NSString *)val withName: (NSString *)name  toElement: (NSXMLElement *)elem
{
  if (val != nil && [val isEqualToString: @""] == NO)
    {
      NSXMLNode *attr = [NSXMLNode attributeWithName: name
					 stringValue: val];
      [elem addAttribute: attr];
    }
}

- (void) _addCellsFromMatrix: (NSMatrix *)matrix toElement: (NSXMLElement *)elem
{
  NSRect rect = [matrix frame];
  NSSize cellSize = [matrix cellSize];
  NSSize inter = [matrix intercellSpacing];
  NSUInteger itemsPerCol = (rect.size.width + inter.width)   / cellSize.width;
  NSUInteger itemsPerRow = (rect.size.height + inter.height) / cellSize.height;
  NSUInteger c = 0;
  NSUInteger r = 0;
  NSArray *cells = [matrix cells];
  NSUInteger count = [cells count];
  NSUInteger i = 0;
  NSXMLElement *cellsElem = [NSXMLNode elementWithName: @"cells"];
  NSString *cellClass = nil;

  NSDebugLog(@"cells = %@\nelem = %@", [matrix cells], elem);
  NSLog(@"WARNING: NSMatrix is not fully supported by Xcode, this might cause it to crash or may not be reloadable by this application");

  if (count > 0)
    {
      [elem addChild: cellsElem];
      for (c = 0; c < itemsPerCol; c++)
	{
	  NSXMLElement *columnElem = [NSXMLNode elementWithName: @"column"];

	  for (r = 0; r < itemsPerRow; r++)
	    {
	      id cell = nil;

	      i = (c * itemsPerCol) + r;

	      // If we go past the end of the array...
	      if (i >= count)
		{
		  continue;
		}

	      cell = [cells objectAtIndex: i];
	      if (cellClass == nil)
		{
		  cellClass = NSStringFromClass([cell class]);
		}

	      [self _collectObjectsFromObject: cell
				   withParent: columnElem];
	    }
	  [cellsElem addChild: columnElem];
	}
    }

  // Add the cell class, so that it doesn't crash on reload...
  if (cellClass != nil)
    {
      NSXMLNode *attr = [NSXMLNode attributeWithName: @"cellClass" stringValue: cellClass];
      [elem addAttribute: attr];
    }
  else
    {
      NSXMLNode *attr = [NSXMLNode attributeWithName: @"cellClass" stringValue: @"NSButtonCell"];
      [elem addAttribute: attr];
    }
}

- (void) _addHoldingPrioritiesForSplitView: (NSSplitView *)sv toElement: (NSXMLElement *)elem
{
  NSUInteger count = [[sv subviews] count];
  NSXMLElement *holdingPrioritiesElement = [NSXMLNode elementWithName: @"holdingPriorities"];
  NSUInteger i = 0;

  for (i = 0; i < count; i++)
    {
      NSXMLElement *realElement = [NSXMLNode elementWithName: @"real"];
      NSXMLNode *attr = [NSXMLNode attributeWithName: @"value" stringValue: @"250"]; // default value

      [realElement addAttribute: attr];
      [holdingPrioritiesElement addChild: realElement];
    }

  [elem addChild: holdingPrioritiesElement];
}

- (void) _addProperty: (NSString *)name
	     withType: (NSString *)type
	    toElement: (NSXMLElement *)elem
	   fromObject: (id)obj
{
  NSString *objClassName = NSStringFromClass([obj class]);

  if ([_excludedKeys containsObject: name])
    {
      NSDebugLog(@"skipping %@", name);
      return; // do not process anything in the excluded key list...
    }

  if ([_skipClass containsObject: objClassName] || objClassName == nil)
    {
      return;
    }

  if ([name isEqualToString: @"cells"]
      && [obj isKindOfClass: [NSMatrix class]])
    {
      [self _addCellsFromMatrix: obj toElement: elem];
      return;
    }

  if ([type isEqualToString: @"id"]) // clz != nil) // type is a class
    {
      SEL s = NSSelectorFromString(name);

      // NSLog(@"%@ -> %@", name, type);
      if (s != NULL)
	{
	  if ([obj respondsToSelector: s])
	    {
	      id o = [obj performSelector: s];
	      if (o != nil)
		{
		  NSString *newName = [_methodToKeyName objectForKey: name];

		  if (newName != nil)
		    {
		      name = newName;
		    }

		  if ([o isKindOfClass: [NSString class]])
		    {
		      NSDebugLog(@"Adding string property %@ = %@", name, o);
		      if ([_valueMapping objectForKey: o] != nil)
			{
			  o = [_valueMapping objectForKey: o];
			}

		      if ([name isEqualToString: @"keyEquivalent"])
			{
			  [self _addKeyEquivalent: o
					toElement: elem];
			}
		      else if (o != nil && [o isEqualToString: @""] == NO)
			{
			  NSXMLNode *attr = [NSXMLNode attributeWithName: name
							     stringValue: o];

			  [elem addAttribute: attr];
			}
		    }
		  else
		    {
		      NSString *className = NSStringFromClass([o class]);

		      if ([_singletonObjects containsObject: className] == NO
			  || [_externallyReferencedClasses containsObject: className])
			{
			  NSString *ident = [self _createIdentifierForObject: o];
			  NSXMLNode *attr = [NSXMLNode attributeWithName: name
							     stringValue: ident];
			  [elem addAttribute: attr];
			}

		      if ([_skipCollectionForKey containsObject: name] == NO)
			{
			  [self _collectObjectsFromObject: o
						   forKey: name
					       withParent: elem];
			}
		    }
		}
	    }
	}
    }
  else if ([type isEqualToString: @"NSRect"])
    {
      SEL sel = NSSelectorFromString(name);
      if (sel != NULL)
	{
	  IMP imp = [obj methodForSelector: sel];

	  if (imp != NULL)
	    {
	      NSRect f = ((NSRect (*)(id, SEL))imp)(obj, sel);
	      [self _addRect: f toElement: elem withName: name];

	    }
	}
    }
  else if ([type isEqualToString: @"NSSize"])
    {
      if ([_allowedSizeKeys containsObject: name])
	{
	  SEL sel = NSSelectorFromString(name);
	  if (sel != NULL)
	    {
	      IMP imp = [obj methodForSelector: sel];

	      if (imp != NULL)
		{
		  NSSize s = ((NSSize (*)(id, SEL))imp)(obj, sel);
		  [self _addSize: s toElement: elem withName: name];

		}
	    }
	}
    }
  else if ([type isEqualToString: @"CGFloat"])
    {
      NSString *keyName = name;
      SEL sel = NSSelectorFromString(name);
      if (sel != NULL)
	{
	  IMP imp = [obj methodForSelector: sel];

	  if (imp != NULL)
	    {
	      CGFloat f = ((CGFloat (*)(id, SEL))imp)(obj, sel);

	      [self _addFloat: f
		     withName: keyName
		    toElement: elem];
	    }
	}
    }
  else if ([type isEqualToString: @"BOOL"])
    {
      NSString *keyName = name;

      if ([[name substringToIndex: 2] isEqualToString: @"is"])
	{
	  keyName = [name substringFromIndex: 2];
	  keyName = [keyName lowercaseString];
	}

      SEL sel = NSSelectorFromString(name);
      if (sel != NULL)
	{
	  IMP imp = [obj methodForSelector: sel];

	  if (imp != NULL)
	    {
	      BOOL f = ((BOOL (*)(id, SEL))imp)(obj, sel);

	      [self _addBoolean: f
		       withName: keyName
		      toElement: elem];
	    }
	}
    }
  else if ([name isEqualToString: @"keyEquivalentModifierMask"])
    {
      NSUInteger k = [obj keyEquivalentModifierMask];
      [self _addKeyEquivalentModifierMask: k toElement: elem];
    }
  else if ([name isEqualToString: @"buttonType"])
    {
      NSString *buttonTypeString = [obj buttonTypeString];
      [self _addButtonType: buttonTypeString
		 toElement: elem];
    }
  else if ([name isEqualToString: @"autoresizingMask"])
    {
      NSAutoresizingMaskOptions m = [obj autoresizingMask];
      [self _addAutoresizingMask: m
		       toElement: elem];
    }
  else if ([name isEqualToString: @"alignment"] && [obj respondsToSelector: @selector(cell)] == NO)
    {
      [self _addAlignment: [obj alignment]
		toElement: elem];
    }
  else if ([name isEqualToString: @"bezelStyle"] && [obj respondsToSelector: @selector(cell)] == NO)
    {
      [self _addBezelStyleForObject: obj
			  toElement: elem];
    }
  else if ([name isEqualToString: @"isBordered"] && [obj respondsToSelector: @selector(cell)] == NO)
    {
      BOOL bordered = [obj isBordered];
      NSDebugLog(@"Handling isBordered...");
      [self _addBorderStyle: bordered
		  toElement: elem];
    }
  else if ([name isEqualToString: @"titlePosition"])
    {
      NSTitlePosition p = [obj titlePosition];
      [self _addTitlePosition: p
		    toElement: elem];
    }
}

- (void) _addPropertiesFromArray: (NSArray *)props toElement: (NSXMLElement *)elem fromObject: (id)obj
{
  if ([props count] > 0)
    {
      NSEnumerator *en = [props objectEnumerator];
      NSString *name = nil;

      while ((name = [en nextObject]) != nil)
	{
	  SEL sel = NSSelectorFromString(name);
	  if (sel != NULL)
	    {
	      if ([obj respondsToSelector: sel] == NO)
		continue;

	      if ([_excludedKeys containsObject: name])
		continue;

	      NSMethodSignature *sig = [obj methodSignatureForSelector: sel];
	      if (sig != NULL)
		{
		  const char *ctype = [sig methodReturnType];
		  if (ctype != NULL)
		    {
		      NSString *ctypeString = [NSString stringWithCString: ctype
								 encoding: NSUTF8StringEncoding];
		      NSString *type = [_signatures objectForKey: ctypeString];

		      if (type != nil)
			{
			  [self _addProperty: name withType: type toElement: elem fromObject: obj];
			}
		    }
		}
	    }
	}
    }
}

- (void) _addAllProperties: (NSXMLElement *)elem fromObject: (id)obj
{
  NSArray *methods = GSObjCMethodNames(obj, YES);
  NSArray *props = [self _propertiesFromMethods: methods forObject: obj];

  [self _addPropertiesFromArray: props toElement: elem fromObject: obj];
  NSDebugLog(@"methods = %@", props);
}

- (void) _addAllNonProperties: (NSXMLElement *)elem fromObject: (id)obj
{
  NSString *className = NSStringFromClass([obj class]);
  if (className != nil)
    {
      NSArray *props = [_nonProperties objectForKey: className];

      [self _addPropertiesFromArray: props toElement: elem fromObject: obj];
    }
}

- (void) _addAllConnections: (NSXMLElement *)elem fromObject: (id)obj
{
  NSArray *connectors = [_gormDocument connectorsForSource: obj
						   ofClass: [NSNibControlConnector class]];
  if ([connectors count] > 0)
    {
      NSXMLElement *conns = [NSXMLNode elementWithName: @"connections"];
      NSEnumerator *en = [connectors objectEnumerator];
      NSNibControlConnector *action = nil;

      // Get actions...
      while ((action = [en nextObject]) != nil)
	{
	  NSString *targetId = [self _createIdentifierForObject: [action destination]];

	  if ([targetId isEqualToString: @""] == NO && targetId != nil)
	    {
	      NSDebugLog(@"action = %@", action);
	      NSXMLElement *actionElem = [NSXMLNode elementWithName: @"action"];
	      NSXMLNode *attr = [NSXMLNode attributeWithName: @"selector"
						 stringValue: [action label]];
	      [actionElem addAttribute: attr];

	      attr = [NSXMLNode attributeWithName: @"target"
				      stringValue: targetId];
	      [actionElem addAttribute: attr];

	      attr = [NSXMLNode attributeWithName: @"id"
				      stringValue: [[NSString randomHex] splitString]];
	      [actionElem addAttribute: attr];

	      [conns addChild: actionElem];
	    }
	}

      [elem addChild: conns];
    }

  connectors =[_gormDocument connectorsForSource: obj
					 ofClass: [NSNibOutletConnector class]];

  NSDebugLog(@"outlet connectors = %@, for obj = %@", connectors, obj);

  if ([connectors count] > 0)
    {
      NSXMLElement *conns = [NSXMLNode elementWithName: @"connections"];
      NSEnumerator *en = [connectors objectEnumerator];
      NSNibOutletConnector *outlet = nil;

      // Get actions...
      while ((outlet = [en nextObject]) != nil)
	{
	  NSString *destinationId = [self _createIdentifierForObject: [outlet destination]];

	  if([destinationId isEqualToString: @""] == NO && destinationId != nil)
	    {
	      NSDebugLog(@"outlet = %@", outlet);
	      NSXMLElement *outletElem = [NSXMLNode elementWithName: @"outlet"];
	      NSXMLNode *attr = [NSXMLNode attributeWithName: @"property"
						 stringValue: [outlet label]];
	      [outletElem addAttribute: attr];

	      attr = [NSXMLNode attributeWithName: @"destination"
				      stringValue: destinationId];
	      [outletElem addAttribute: attr];

	      attr = [NSXMLNode attributeWithName: @"id"
				      stringValue: [[NSString randomHex] splitString]];
	      [outletElem addAttribute: attr];

	      [conns addChild: outletElem];
	    }
	}

      [elem addChild: conns];
    }
}

// This method recursively navigates the entire object tree and emits XML
- (void) _collectObjectsFromObject: (id)obj
			    forKey: (NSString *)keyName
			withParent: (NSXMLElement *)pNode
{
  NSString *ident = [self _createIdentifierForObject: obj];

  if (ident != nil)
    {
      NSXMLElement *parentNode = pNode;
      NSString *className = NSStringFromClass([obj class]);

      if ([_skipClass containsObject: className])
	{
	  return;
	}

      NSString *elementName = [self _convertName: className];
      // NSLog(@"elementName = %@", elementName);
      NSXMLElement *elem = [NSXMLNode elementWithName: elementName];
      NSXMLNode *attr = nil;

      // If the object is a singleton, then there is no need for the id to be presented.
      if ([_singletonObjects containsObject: className] == NO)
	{
	  attr = [NSXMLNode attributeWithName: @"id" stringValue: ident];
	  [elem addAttribute: attr];
	}

      NSString *name = [_gormDocument nameForObject:  obj];
      NSString *userLabel = [self _userLabelForObject: obj];
      if (userLabel != nil)
	{
	  attr = [NSXMLNode attributeWithName: @"userLabel" stringValue: userLabel];
	  [elem addAttribute: attr];
	}

      // Add key to elem...
      if (keyName != nil && [keyName isEqualToString: @""] == NO)
	{
	  attr = [NSXMLNode attributeWithName: @"key" stringValue: keyName];
	  [elem addAttribute: attr];
	}

      if ([obj isKindOfClass: [GormObjectProxy class]] ||
	  [obj respondsToSelector: @selector(className)])
	{
	  if ([self _isSameClass: className and: [obj className]] == NO)
	    {
	      className = [obj className];
	      attr = [NSXMLNode attributeWithName: @"customClass" stringValue: className];
	      [elem addAttribute: attr];
	    }
	}

      // Add all of the connections for a given object...
      [self _addAllConnections: elem fromObject: obj];

      // Add all properties, then add the element to the parent...
      [self _addAllProperties: elem fromObject: obj];

      // Add some items that are not actually properties, but should be reflected in the XML...
      [self _addAllNonProperties: elem fromObject: obj];

      // Move this to its grandfather node... XIB files seem to expect this in the scroll view...
      if ([obj isKindOfClass: [NSScrollView class]])
	{
	  NSClipView *cv = [obj contentView];
	  NSArray *sv = [cv subviews];

	  if ([sv count] > 0)
	    {
	      id view = [[cv subviews] objectAtIndex: 0];

	      if ([view respondsToSelector: @selector(headerView)])
		{
		  id hv = [view headerView];
		  [self _collectObjectsFromObject: hv
					   forKey: nil
				       withParent: elem];
		}
	    }
	}

      // Don't add the MainMenu directly, since we need to wrap it.. NSMenu...
      if ([name isEqualToString: @"NSMenu"] == NO)
	{
	  [parentNode addChild: elem];
	}

      // For each different class, recurse through the structure as needed.

      // For NSMenu, there is a special case, since it needs to be contained in another menu.
      if ([obj isKindOfClass: [NSMenu class]])
	{
	  NSArray *items = [obj itemArray];
	  NSEnumerator *en = [items objectEnumerator];
	  id item = nil;

	  if ([name isEqualToString: @"NSMenu"])
	    {
	      NSXMLNode *systemMenuAttr = [NSXMLNode attributeWithName: @"systemMenu" stringValue: @"apple"];
	      [elem addAttribute: systemMenuAttr];

	      NSXMLElement *mainMenuElem = [NSXMLNode elementWithName: @"menu"];

	      attr = [NSXMLNode attributeWithName: @"id" stringValue: [[NSString randomHex] splitString]];
	      [mainMenuElem addAttribute: attr];

	      attr = [NSXMLNode attributeWithName: @"systemMenu" stringValue: @"main"];
	      [mainMenuElem addAttribute: attr];

	      attr = [NSXMLNode attributeWithName: @"title" stringValue: @"Main Menu"];
	      [mainMenuElem addAttribute: attr];

	      NSXMLElement *mainItemsElem = [NSXMLNode elementWithName: @"items"];
	      [mainMenuElem addChild: mainItemsElem];

	      NSXMLElement *mainMenuItem = [NSXMLNode elementWithName: @"menuItem"];
	      [mainItemsElem addChild: mainMenuItem];
	      attr = [NSXMLNode attributeWithName: @"id" stringValue: [[NSString randomHex] splitString]];
	      [mainMenuItem addAttribute: attr];
	      attr = [NSXMLNode attributeWithName: @"title" stringValue: [obj title]];

	      [mainMenuItem addChild: elem]; // Now add the node, since we have inserted the proper system menu

	      [parentNode addChild: mainMenuElem];
	    }

	  // Add submenu attribute...
	  attr = [NSXMLNode attributeWithName: @"key" stringValue: @"submenu"];
	  [elem addAttribute: attr];

	  // Add services menu...
	  if (obj == [_gormDocument servicesMenu])
	    {
	      attr = [NSXMLNode attributeWithName: @"systemMenu" stringValue: @"services"];
	      [elem addAttribute: attr];
	    }

	  NSXMLElement *itemsElem = [NSXMLNode elementWithName: @"items"];
	  while ((item = [en nextObject]) != nil)
	    {
	      [self _collectObjectsFromObject: item
				   withParent: itemsElem];
	    }
	  [elem addChild: itemsElem]; // Add to parent element...
	}

      if ([obj isKindOfClass: [NSMenuItem class]])
	{
	  NSMenu *sm = [obj submenu];
	  if (sm != nil)
	    {
	      [self _collectObjectsFromObject: sm
				   withParent: elem];
	    }
	}

      // Handle special case for popup, we need to add the selected item, and contain them
      // in a "menu" instance which doesn't exist on GNUstep...
      if ([obj isKindOfClass: [NSPopUpButtonCell class]])
	{
	  NSArray *items = [obj itemArray];
	  NSEnumerator *en = [items objectEnumerator];
	  id item = nil;
	  NSXMLElement *menuElem = [NSXMLNode elementWithName: @"menu"];
	  NSXMLElement *itemsElem = [NSXMLNode elementWithName: @"items"];
	  NSXMLNode *attr = nil;

	  attr = [NSXMLNode attributeWithName: @"key" stringValue: @"menu"];
	  [menuElem addAttribute: attr];

	  attr = [NSXMLNode attributeWithName: @"id" stringValue: [[NSString randomHex] splitString]];
	  [menuElem addAttribute: attr];

	  attr = [NSXMLNode attributeWithName: @"key" stringValue: @"cell"];
	  [elem addAttribute: attr];

	  id selectedItem = [obj selectedItem];
	  if (selectedItem != nil)
	    {
	      NSString *selectedItemId = [self _createIdentifierForObject: selectedItem];
	      attr = [NSXMLNode attributeWithName: @"selectedItem" stringValue: selectedItemId];
	      while ((item = [en nextObject]) != nil)
		{
		  [self _collectObjectsFromObject: item
				       withParent: itemsElem];
		}
	      [elem addAttribute: attr];
	    }

	  [menuElem addChild: itemsElem];
	  [elem addChild: menuElem]; // Add to parent element...
	}

      if ([obj isKindOfClass: [NSTableHeaderView class]])
	{
	  NSXMLNode *attr = [NSXMLNode attributeWithName: @"key" stringValue: @"headerView"];
	  [elem addAttribute: attr];
	}

      if ([obj isKindOfClass: [NSWindow class]])
	{
	  NSRect s = [[NSScreen mainScreen] frame];
	  NSRect c = [[obj contentView] frame];
	  NSUInteger m = [obj styleMask];

	  [self _addWindowStyleMask: m toElement: elem];
	  [self _addRect: c toElement: elem withName: @"contentRect"];
	  [self _addRect: s toElement: elem withName: @"screenRect"];
	  [self _collectObjectsFromObject: [obj contentView]
			       withParent: elem];
	}

      if ([obj isKindOfClass: [NSPanel class]])
	{
	  NSString *className = NSStringFromClass([obj class]);

	  if ([className isEqualToString: @"GormNSPanel"])
	    {
	      className = @"NSPanel";
	    }

	  NSXMLNode *attr = [NSXMLNode attributeWithName: @"customClass" stringValue: className];
	  [elem addAttribute: attr];
	}

      if ([obj isKindOfClass: [NSView class]]) // && [obj resondsToSelect: @selector(contentView)] == NO)
	{
	  id sv = [obj superview];

	  if (obj == [[obj window] contentView])
	    {
	      NSXMLNode *contentViewAttr = [NSXMLNode attributeWithName: @"key" stringValue: @"contentView"];
	      [elem addAttribute: contentViewAttr];
	    }

	  if ([sv respondsToSelector: @selector(contentView)])
	    {
	      if ([sv contentView] == obj)
		{
		  NSXMLNode *contentViewAttr = [NSXMLNode attributeWithName: @"key" stringValue: @"contentView"];
		  [elem addAttribute: contentViewAttr];
		}
	    }

	  if ([obj respondsToSelector: @selector(contentView)])
	    {
	      NSView *cv = [obj contentView];
	      [self _collectObjectsFromObject: cv
				   withParent: elem];
	    }
	  else
	    {
	      if ([obj isKindOfClass: [NSTabView class]] == NO)
		{
		  NSArray *subviews = [obj subviews];

		  if ([subviews count] > 0)
		    {
		      NSEnumerator *en = [subviews objectEnumerator];
		      id v = nil;
		      NSXMLElement *subviewsElement = [NSXMLNode elementWithName: @"subviews"];

		      while ((v = [en nextObject]) != nil)
			{
			  [self _collectObjectsFromObject: v
					       withParent: subviewsElement];
			}
		      [elem addChild: subviewsElement];
		    }
		}
	    }

	  if ([obj respondsToSelector: @selector(tabViewItems)])
	    {
	      NSArray *items = [obj tabViewItems];

	      if ([items count] > 0)
		{
		  NSEnumerator *en = [items objectEnumerator];
		  id v = nil;
		  NSXMLElement *itemsElement = [NSXMLNode elementWithName: @"tabViewItems"];

		  while ((v = [en nextObject]) != nil)
		    {
		      [self _collectObjectsFromObject: v
					   withParent: itemsElement];
		    }
		  [elem addChild: itemsElement];
		}
	    }
	}

      // Add the holding priorities for NSSplitView.  GNUstep doesn't have these so we need to generate it...
      if ([obj isKindOfClass: [NSSplitView class]])
	{
	  [self _addHoldingPrioritiesForSplitView: obj toElement: elem];
	}

      /* Cheap way to not encoding fake table columns to prevent crash on the mac when reading the XIB.
	 Not ideal, but it should work for now. */
      /*
	if ([obj respondsToSelector: @selector(tableColumns)])
	{
	[self _addTableColumns: [obj tableColumns]
	toElement: elem];
	}
      */
    }
}

- (void) _collectObjectsFromObject: (id)obj
			withParent: (NSXMLElement  *)node
{
  [self _collectObjectsFromObject: obj
			   forKey: nil
		       withParent: node];
}


- (void) _buildXIBDocumentWithParentNode: (NSXMLElement *)parentNode
{
  NSEnumerator *en = [[_gormDocument topLevelObjects] objectEnumerator];
  id o = nil;

  [_gormDocument deactivateEditors];
  while ((o = [en nextObject]) != nil)
    {
      [self _collectObjectsFromObject: o
			   withParent: parentNode];
    }
  [_gormDocument reactivateEditors];
}

- (NSData *) data
{
  NSString *plugInId = @"com.apple.InterfaceBuilder.CocoaPlugin";
  NSString *typeId = @"com.apple.InterfaceBuilder3.Cocoa.XIB";
  NSString *toolVersion = @"21507";

  // Build root element...
  NSXMLElement *rootElement = [NSXMLNode elementWithName: @"document"];
  NSXMLNode *attr = [NSXMLNode attributeWithName: @"type"
				     stringValue: typeId];
  [rootElement addAttribute: attr];

  attr = [NSXMLNode attributeWithName: @"version" stringValue: @"3.0"];
  [rootElement addAttribute: attr];

  attr = [NSXMLNode attributeWithName: @"toolsVersion" stringValue: toolVersion];
  [rootElement addAttribute: attr];

  attr = [NSXMLNode attributeWithName: @"targetRuntime" stringValue: @"MacOSX.Cocoa"];
  [rootElement addAttribute: attr];

  attr = [NSXMLNode attributeWithName: @"useAutolayout" stringValue: @"YES"];
  [rootElement addAttribute: attr];

  attr = [NSXMLNode attributeWithName: @"propertyAccessControl" stringValue: @"none"];
  [rootElement addAttribute: attr];

  attr = [NSXMLNode attributeWithName: @"customObjectInstantiationMethod" stringValue: @"direct"];
  [rootElement addAttribute: attr];

  // Build dependencies...
  NSXMLElement *dependencies = [NSXMLNode elementWithName: @"dependencies"];
  NSXMLElement *deployment = [NSXMLNode elementWithName: @"deployment"];
  attr = [NSXMLNode attributeWithName: @"identifier" stringValue: @"macosx"];
  [deployment addAttribute: attr];
  [dependencies addChild: deployment];

  NSXMLElement *plugIn = [NSXMLNode elementWithName: @"plugIn"];
  attr = [NSXMLNode attributeWithName: @"identifier" stringValue: plugInId];
  [plugIn addAttribute: attr];
  attr = [NSXMLNode attributeWithName: @"version" stringValue: toolVersion];
  [plugIn addAttribute: attr];
  [dependencies addChild: plugIn];

  NSXMLElement *capability = [NSXMLNode elementWithName: @"capability"];
  attr = [NSXMLNode attributeWithName: @"name" stringValue: @"documents saved in the Xcode 8 format"];
  [capability addAttribute: attr];
  attr = [NSXMLNode attributeWithName: @"minToolsVersion" stringValue: @"8"];
  [capability addAttribute: attr];
  [dependencies addChild: capability];
  [rootElement addChild: dependencies];

  NSXMLDocument *xibDocument = [NSXMLNode documentWithRootElement: rootElement];
  NSXMLElement *objects = [NSXMLNode elementWithName: @"objects"];

  // Add placeholder objects to XIB
  [self _createPlaceholderObjects: objects];

  // add body to document...
  [rootElement addChild: objects];

  // Recursively build the XIB document from the GormDocument...
  [self _buildXIBDocumentWithParentNode: objects];

  NSData *data = [xibDocument XMLDataWithOptions: NSXMLNodePrettyPrint | NSXMLDocumentTidyXML | NSXMLNodeCompactEmptyElement ];

  return data;
}

- (BOOL) exportXIBDocumentWithName: (NSString *)name
{
  BOOL result = NO;

  if (name != nil)
    {
      NSData *data = [self data];
      NSString *xmlString = [[NSString alloc] initWithBytes: [data bytes] length: [data length] encoding: NSUTF8StringEncoding];

      AUTORELEASE(xmlString);
      result = [xmlString writeToFile: name atomically: YES];
    }

  return result;
}

@end
