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
