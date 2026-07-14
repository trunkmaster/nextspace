/*
 *   Copyright (c) 2021 OpenCFNetwork Authors. All Rights Reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 *
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 *
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 *
 * @APPLE_LICENSE_HEADER_END@
 */

/**
 *   @file
 *     This file implements two error translation methods that, while
 *     defined in CoreFoundation, are preferentially
 *     dynamically-loaded and overridden from CFNetwork.
 *
 *     These implementations are roughly identical to those in
 *     CoreFoundation.
 *
 */

#include <AssertMacros.h>

#include <CFNetwork/CFNetwork.h>
#include <CoreFoundation/CFError.h>
#include <CoreFoundation/CFStream.h>

CF_EXPORT CFErrorRef    _CFErrorCreateWithStreamError(CFAllocatorRef allocator, CFStreamError *error);
CF_EXPORT CFStreamError _CFStreamErrorFromCFError(CFErrorRef error);

/**
 *  Translate and create a CFError from the provided CFStreamError.
 *
 *  @param[in]  allocator  The allocator to use to allocate memory
 *                         for the new error object. Pass NULL or
 *                         kCFAllocatorDefault to use the current
 *                         default allocator.
 *  @param[in]  error      The stream error to translate and create
 *                         a new error object from.
 *
 *  @returns
 *    A new CFError or NULL if there was a problem creating the
 *    object. Ownership follows the "The Create Rule".
 *
 */
CFErrorRef _CFErrorCreateWithStreamError(CFAllocatorRef allocator, CFStreamError *error)
{
  CFErrorRef result = NULL;

  if (error->domain == kCFStreamErrorDomainPOSIX) {
    result = CFErrorCreate(allocator, kCFErrorDomainPOSIX, error->error, NULL);
  } else if (error->domain == kCFStreamErrorDomainMacOSStatus) {
    result = CFErrorCreate(allocator, kCFErrorDomainOSStatus, error->error, NULL);
  } else if (error->domain == kCFStreamErrorDomainMach) {
    result = CFErrorCreate(allocator, kCFErrorDomainMach, error->error, NULL);
  } else {
    CFStringRef     key   = CFSTR("CFStreamErrorDomainKey");
    CFNumberRef     value = CFNumberCreate(allocator, kCFNumberCFIndexType, &error->domain);
    CFDictionaryRef dict  = CFDictionaryCreate(allocator, (const void **)(&key), (const void **)(&value), 1, &kCFTypeDictionaryKeyCallBacks,
                                               &kCFTypeDictionaryValueCallBacks);
    result                = CFErrorCreate(allocator, CFSTR("BogusCFStreamErrorCompatibilityDomain"), error->error, dict);
    CFRelease(value);
    CFRelease(dict);
  }

  return result;
}

/**
 *  Translate and create a CFStreamError from the provided CFError.
 *
 *  @param[in]  error  The error to translate and create a new
 *                     stream error object from.
 *
 *  @returns
 *    A new, translated CFstreamError.
 *
 */
CFStreamError _CFStreamErrorFromCFError(CFErrorRef error)
{
  CFStringRef   domain = CFErrorGetDomain(error);
  CFStreamError result;

  if (CFEqual(domain, kCFErrorDomainPOSIX)) {
    result.domain = kCFStreamErrorDomainPOSIX;
  } else if (CFEqual(domain, kCFErrorDomainOSStatus)) {
    result.domain = kCFStreamErrorDomainMacOSStatus;
  } else if (CFEqual(domain, kCFErrorDomainMach)) {
    result.domain = kCFStreamErrorDomainMach;
  } else {
    result.domain = kCFStreamErrorDomainCustom;
  }

  result.error = CFErrorGetCode(error);

  return result;
}
