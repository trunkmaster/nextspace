/**
 * NSURLSessionConfiguration.m
 *
 * Copyright (C) 2017-2024 Free Software Foundation, Inc.
 *
 * Written by: Hugo Melder <hugo@algoriddim.com>
 * Date: May 2024
 * Author: Hugo Melder <hugo@algoriddim.com>
 *
 * This file is part of GNUStep-base
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * If you are interested in a warranty or support for this source code,
 * contact Scott Christley <scottc@net-community.com> for more information.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
 */

#import "Foundation/NSURLSession.h"
#import "Foundation/NSHTTPCookie.h"

// TODO: This is the old implementation. It requires a rewrite!

@implementation NSURLSessionConfiguration

static NSURLSessionConfiguration * def = nil;

+ (void) initialize
{
  if (nil == def)
    {
      def = [NSURLSessionConfiguration new];
    }
}

+ (NSURLSessionConfiguration *) defaultSessionConfiguration
{
  return AUTORELEASE([def copy]);
}

+ (NSURLSessionConfiguration *) ephemeralSessionConfiguration
{
  // return default session since we don't store any data on disk anyway
  return AUTORELEASE([def copy]);
}

+ (NSURLSessionConfiguration *) backgroundSessionConfigurationWithIdentifier:
  (NSString *)identifier
{
  NSURLSessionConfiguration * configuration = [def copy];

  configuration->_identifier = [identifier copy];
  return AUTORELEASE(configuration);
}

- (instancetype) init
{
  if (nil != (self = [super init]))
    {
      _protocolClasses = nil;
      _HTTPMaximumConnectionsPerHost = 6;
      _HTTPShouldUsePipelining = YES;
      _HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
      _HTTPCookieStorage = nil;
      _HTTPShouldSetCookies = NO;
      _HTTPAdditionalHeaders = nil;
      _HTTPMaximumConnectionLifetime = 0;   // Zero or less means default
      _timeoutIntervalForResource = 604800; // 7 days in seconds
      _timeoutIntervalForRequest = 60;      // 60 seconds
    }

  return self;
}

- (void) dealloc
{
  DESTROY(_identifier);
  DESTROY(_HTTPAdditionalHeaders);
  DESTROY(_HTTPCookieStorage);
  DESTROY(_protocolClasses);
  DESTROY(_URLCache);
  DESTROY(_URLCredentialStorage);
  [super dealloc];
}

- (NSString *) identifier
{
  return _identifier;
}

- (NSURLCache *) URLCache
{
  return _URLCache;
}

- (void) setURLCache: (NSURLCache *)cache
{
  ASSIGN(_URLCache, cache);
}

- (void) setURLCredentialStorage: (NSURLCredentialStorage *)storage
{
  ASSIGN(_URLCredentialStorage, storage);
}

- (NSURLRequestCachePolicy) requestCachePolicy
{
  return _requestCachePolicy;
}

- (void) setRequestCachePolicy: (NSURLRequestCachePolicy)policy
{
  _requestCachePolicy = policy;
}

- (NSArray *) protocolClasses
{
  return _protocolClasses;
}

- (NSTimeInterval) timeoutIntervalForRequest
{
  return _timeoutIntervalForRequest;
}

- (void) setTimeoutIntervalForRequest: (NSTimeInterval)interval
{
  _timeoutIntervalForRequest = interval;
}

- (NSTimeInterval) timeoutIntervalForResource
{
  return _timeoutIntervalForResource;
}

- (void) setTimeoutIntervalForResource: (NSTimeInterval)interval
{
  _timeoutIntervalForResource = interval;
}

- (NSInteger) HTTPMaximumConnectionsPerHost
{
  return _HTTPMaximumConnectionsPerHost;
}

- (void) setHTTPMaximumConnectionsPerHost: (NSInteger)n
{
  _HTTPMaximumConnectionsPerHost = n;
}

- (NSInteger) HTTPMaximumConnectionLifetime
{
  return _HTTPMaximumConnectionLifetime;
}

- (void) setHTTPMaximumConnectionLifetime: (NSInteger)n
{
  _HTTPMaximumConnectionLifetime = n;
}

- (BOOL) HTTPShouldUsePipelining
{
  return _HTTPShouldUsePipelining;
}

- (void) setHTTPShouldUsePipelining: (BOOL)flag
{
  _HTTPShouldUsePipelining = flag;
}

- (NSHTTPCookieAcceptPolicy) HTTPCookieAcceptPolicy
{
  return _HTTPCookieAcceptPolicy;
}

- (void) setHTTPCookieAcceptPolicy: (NSHTTPCookieAcceptPolicy)policy
{
  _HTTPCookieAcceptPolicy = policy;
}

- (NSHTTPCookieStorage *) HTTPCookieStorage
{
  return _HTTPCookieStorage;
}

- (void) setHTTPCookieStorage: (NSHTTPCookieStorage *)storage
{
  ASSIGN(_HTTPCookieStorage, storage);
}

- (BOOL) HTTPShouldSetCookies
{
  return _HTTPShouldSetCookies;
}

- (void) setHTTPShouldSetCookies: (BOOL)flag
{
  _HTTPShouldSetCookies = flag;
}

- (NSDictionary *) HTTPAdditionalHeaders
{
  return _HTTPAdditionalHeaders;
}

- (void) setHTTPAdditionalHeaders: (NSDictionary *)headers
{
  ASSIGN(_HTTPAdditionalHeaders, headers);
}

- (NSURLRequest *) configureRequest: (NSURLRequest *)request
{
  return [self setCookiesOnRequest: request];
}

- (NSURLRequest *) setCookiesOnRequest: (NSURLRequest *)request
{
  NSMutableURLRequest * r = AUTORELEASE([request mutableCopy]);

  if (_HTTPShouldSetCookies)
    {
      if (nil != _HTTPCookieStorage && nil != [request URL])
        {
          NSArray * cookies = [_HTTPCookieStorage cookiesForURL: [request URL]];
          if (nil != cookies && [cookies count] > 0)
            {
              NSDictionary * cookiesHeaderFields;
              NSString * cookieValue;

              cookiesHeaderFields =
                [NSHTTPCookie requestHeaderFieldsWithCookies: cookies];
              cookieValue = [cookiesHeaderFields objectForKey: @"Cookie"];
              if (nil != cookieValue && [cookieValue length] > 0)
                {
                  [r setValue: cookieValue forHTTPHeaderField: @"Cookie"];
                }
            }
        }
    }

  return AUTORELEASE([r copy]);
} /* setCookiesOnRequest */

- (NSURLCredentialStorage *) URLCredentialStorage
{
  return _URLCredentialStorage;
}

- (id) copyWithZone: (NSZone *)zone
{
  NSURLSessionConfiguration * copy = [[[self class] alloc] init];

  if (copy)
    {
      copy->_identifier = [_identifier copy];
      copy->_URLCache = [_URLCache copy];
      copy->_URLCredentialStorage = [_URLCredentialStorage copy];
      copy->_protocolClasses = [_protocolClasses copyWithZone: zone];
      copy->_HTTPMaximumConnectionsPerHost = _HTTPMaximumConnectionsPerHost;
      copy->_HTTPShouldUsePipelining = _HTTPShouldUsePipelining;
      copy->_HTTPCookieAcceptPolicy = _HTTPCookieAcceptPolicy;
      copy->_HTTPCookieStorage = [_HTTPCookieStorage retain];
      copy->_HTTPShouldSetCookies = _HTTPShouldSetCookies;
      copy->_HTTPAdditionalHeaders =
        [_HTTPAdditionalHeaders copyWithZone: zone];
      copy->_timeoutIntervalForRequest = _timeoutIntervalForRequest;
      copy->_timeoutIntervalForResource = _timeoutIntervalForResource;
    }

  return copy;
} /* copyWithZone */

@end