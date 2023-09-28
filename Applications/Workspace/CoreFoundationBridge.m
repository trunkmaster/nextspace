/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2023-present Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import "CoreFoundationBridge.h"

// Core Foundation -> Foundation
//-----------------------------------------------------------------------------
NSNumber *convertCFtoNSNumber(CFNumberRef cfNumber)
{
  int value;
  CFNumberGetValue(cfNumber, CFNumberGetType(cfNumber), &value);
  return [NSNumber numberWithInt:value];
}
NSString *convertCFtoNSString(CFStringRef cfString)
{
  const char *stringPtr;
  stringPtr = CFStringGetCStringPtr(cfString, CFStringGetSystemEncoding());
  if (!stringPtr) {
    return @"";
  } else {
    return [NSString stringWithCString:stringPtr];
  }
}
NSArray *convertCFtoNSArray(CFArrayRef cfArray)
{
  NSMutableArray *nsArray = [NSMutableArray new];
  CFIndex cfCount = CFArrayGetCount(cfArray);

  for (CFIndex i = 0; i < cfCount; i++) {
    [nsArray addObject:convertCFtoNS(CFArrayGetValueAtIndex(cfArray, i))];
  }

  return [nsArray autorelease];
}
NSDictionary *convertCFtoNSDictionary(CFDictionaryRef cfDictionary)
{
  NSMutableDictionary *nsDictionary = nil;
  const void *keys;
  const void *values;

  if (cfDictionary == NULL) {
    return nil;
  }

  nsDictionary = [NSMutableDictionary new];
  CFDictionaryGetKeysAndValues(cfDictionary, &keys, &values);
  for (int i = 0; i < CFDictionaryGetCount(cfDictionary); i++) {
    [nsDictionary setObject:convertCFtoNS(&values[i])
                     forKey:convertCFtoNSString(&keys[i])];  // always CFStringRef
  }

  return nsDictionary;
}
id convertCFtoNS(CFTypeRef value)
{
  CFTypeID valueType = CFGetTypeID(value);
  id returnValue = @"(null)";

  if (valueType == CFStringGetTypeID()) {
    returnValue = convertCFtoNSString(value);
  } else if (valueType == CFNumberGetTypeID()) {
    returnValue = convertCFtoNSNumber(value);
  } else if (valueType == CFArrayGetTypeID()) {
    returnValue = convertCFtoNSArray(value);
  } else if (valueType == CFDictionaryGetTypeID()) {
    returnValue = convertCFtoNSDictionary(value);
  }

  return returnValue;
}

// Foundation -> Core Foundation
//-----------------------------------------------------------------------------
CFStringRef convertNStoCFString(NSString *nsString)
{
  CFStringRef cfString;
  cfString = CFStringCreateWithCString(kCFAllocatorDefault, [nsString cString],
                                       CFStringGetSystemEncoding());
  return cfString;
}
CFNumberRef convertNStoCFNumber(NSNumber *nsNumber)
{
  CFNumberRef cfNumber;
  int number = [nsNumber intValue];
  cfNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &number);
  return cfNumber;
}
CFArrayRef convertNStoCFArray(NSArray *nsArray)
{
  CFMutableArrayRef cfArray = CFArrayCreateMutable(kCFAllocatorDefault, [nsArray count], NULL);

  for (id object in nsArray) {
    CFArrayAppendValue(cfArray, convertNStoCF(object));
  }

  return cfArray;
}
CFDictionaryRef convertNStoCFDictionary(NSDictionary *dictionary)
{
  CFMutableDictionaryRef cfDictionary;
  CFDictionaryRef returnedDictionary;
  CFStringRef keyCFString;
  CFTypeRef valueCF;

  cfDictionary =
      CFDictionaryCreateMutable(kCFAllocatorDefault, [[dictionary allKeys] count],
                                &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  for (NSString *key in [dictionary allKeys]) {
    keyCFString = convertNStoCFString(key);
    // NSLog(@"Converted key: %@", key);
    valueCF = convertNStoCF([dictionary objectForKey:key]);
    // NSLog(@"Converted value: %@", [dictionary objectForKey:key]);
    CFDictionaryAddValue(cfDictionary, keyCFString, valueCF);
    CFRelease(keyCFString);
    CFRelease(valueCF);
  }
  returnedDictionary = CFDictionaryCreateCopy(kCFAllocatorDefault, cfDictionary);
  CFRelease(cfDictionary);

  return returnedDictionary;
}

CFTypeRef convertNStoCF(id value)
{
  CFTypeRef returnValue = "(CoreFoundation NULL)";

  if ([value isKindOfClass:[NSString class]]) {
    returnValue = convertNStoCFString(value);
  } else if ([value isKindOfClass:[NSNumber class]]) {
    returnValue = convertNStoCFNumber(value);
  } else if ([value isKindOfClass:[NSArray class]]) {
    returnValue = convertNStoCFArray(value);
  } else if ([value isKindOfClass:[NSDictionary class]]) {
    returnValue = convertNStoCFDictionary(value);
  }

  return returnValue;
}
