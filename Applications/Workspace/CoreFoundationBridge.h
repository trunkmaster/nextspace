
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFNumber.h>
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFNumber.h>
#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFDictionary.h>

#import <Foundation/NSValue.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>

// Core Foundation -> Foundation
//-----------------------------------------------------------------------------
NSNumber *convertCFtoNSNumber(CFNumberRef cfNumber);
NSString *convertCFtoNSString(CFStringRef cfString);
NSArray *convertCFtoNSArray(CFArrayRef cfArray);
NSDictionary *convertCFtoNSDictionary(CFDictionaryRef cfDictionary);
id convertCFtoNS(CFTypeRef value);

// Foundation -> Core Foundation
//-----------------------------------------------------------------------------
CFStringRef convertNStoCFString(NSString *nsString);
CFNumberRef convertNStoCFNumber(NSNumber *nsNumber);
CFArrayRef convertNStoCFArray(NSArray *nsArray);
CFDictionaryRef convertNStoCFDictionary(NSDictionary *dictionary);
CFTypeRef convertNStoCF(id value);
