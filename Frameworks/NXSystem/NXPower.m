/*
 * NXPower.m - UPower and 'tuned' interactions.
 *
 * Copyright 2016, Serg Stoyan
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without 
 * modification, are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice, 
 * this list of conditions and the following disclaimer.
 * 
 * Redistributions in binary form must reproduce the above copyright notice, 
 * this list of conditions and the following disclaimer in the documentation 
 * and/or other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 */
#ifdef WITH_UPOWER

#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSString.h>

#include <upower.h>

#import "NXPower.h"

@implementation NXPower

//-------------------------------------------------------------------------------
// Battery
//-------------------------------------------------------------------------------

+ (unsigned int)batteryLife
{
  return 0;
}

+ (unsigned char)batteryPercent
{
  return 0;
}

+ (BOOL)isUsingBattery
{
  return NO;
}

//-------------------------------------------------------------------------------
// Laptop lid
//-------------------------------------------------------------------------------
+ (BOOL)hasLid
{
  UpClient *upower_client = up_client_new();
  BOOL     yn = up_client_get_lid_is_present(upower_client);

  g_object_unref(upower_client);
    
  return yn;
}

+ (BOOL)isLidClosed
{
  UpClient *upower_client = up_client_new();
  BOOL     yn = up_client_get_lid_is_closed(upower_client);

  g_object_unref(upower_client);
    
  return yn;
}

@end

#endif //WITH_UPOWER
