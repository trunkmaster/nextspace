/**Interface for NSURLRequest for GNUstep
   Copyright (C) 2006 Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <frm@gnu.org>
   Date: 2006
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
   */ 

#ifndef __NSURLRequest_h_GNUSTEP_BASE_INCLUDE
#define __NSURLRequest_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_2,GS_API_LATEST) && GS_API_VERSION( 11300,GS_API_LATEST)

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSData;
@class NSDate;
@class NSDictionary;
@class NSInputStream;
@class NSString;
@class NSURL;

enum {
    NSURLRequestUseProtocolCachePolicy = 0,

    NSURLRequestReloadIgnoringLocalCacheData = 1,
    NSURLRequestReloadIgnoringLocalAndRemoteCacheData = 4,
    NSURLRequestReloadIgnoringCacheData = NSURLRequestReloadIgnoringLocalCacheData,

    NSURLRequestReturnCacheDataElseLoad = 2,
    NSURLRequestReturnCacheDataDontLoad = 3,

    NSURLRequestReloadRevalidatingCacheData = 5
};
/**
 * <deflist>
 *   <term>NSURLRequestUseProtocolCachePolicy</term>
 *   <desc>
 *     Says that any protocol specific cache policy should be
 *     used ... this is the default.
 *   </desc>
 *   <term>NSURLRequestReloadIgnoringCacheData</term>
 *   <desc>
 *     Says the data should be re-loaded from source rather
 *     than any cached data being used, irrespective of any
 *     protocol standard.
 *   </desc>
 *   <term>NSURLRequestReturnCacheDataElseLoad</term>
 *   <desc>
 *     Says to use cached data if any is available, but to
 *     load from source if the cache is empty.  Ignores any
 *     protocol specific logic (like cache aging).
 *   </desc>
 *   <term>NSURLRequestReturnCacheDataDontLoad</term>
 *   <desc>
 *     Says to use cached data if any is available, but to
 *     return nil without loading if the cache is empty.
 *   </desc>
 * </deflist>
 */
typedef NSUInteger NSURLRequestCachePolicy;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_7,GS_API_LATEST)
enum
{
    NSURLNetworkServiceTypeDefault    = 0,  // Standard internet traffic
    NSURLNetworkServiceTypeVoIP       = 1,  // Voice over IP control traffic
    NSURLNetworkServiceTypeVideo      = 2,  // Video traffic
    NSURLNetworkServiceTypeBackground = 3,  // Background traffic
    NSURLNetworkServiceTypeVoice      = 4,  // Voice data
#if OS_API_VERSION(MAC_OS_X_VERSION_10_12,GS_API_LATEST)
    NSURLNetworkServiceTypeCallSignaling = 11    // Call Signaling - enumeration cases
#endif
};
/**
 * <deflist>
 *   <term>NSURLNetworkServiceTypeDefault</term>
 *   <desc>
 *     Specifies standard network traffic. Most connections should be made using this service type
 *     this is the default.
 *   </desc>
 *   <term>NSURLNetworkServiceTypeVoIP</term>
 *   <desc>
 *     Specifies that the request is for VoIP traffic.
 *   </desc>
 *   <term>NSURLNetworkServiceTypeVideo</term>
 *   <desc>
 *     Specifies that the request is for video traffic.
 *   </desc>
 *   <term>NSURLNetworkServiceTypeBackground</term>
 *   <desc>
 *     Specifies that the request is for background traffic.
 *   </desc>
 *   <term>NSURLNetworkServiceTypeVoice</term>
 *   <desc>
 *     Specifies that the request is for voice traffic.
 *   </desc>
 *   <term>NSURLNetworkServiceTypeCallSignaling</term>
 *   <desc>
 *     Call Signaling - enumeration cases.
 *   </desc>
 * </deflist>
 */
typedef NSUInteger NSURLRequestNetworkServiceType;
#endif

/**
 * This class encapsulates information about a request to load a
 * URL, how to cache the results, and when to deal with a slow/hung
 * load process by timing out.
 */
GS_EXPORT_CLASS
@interface NSURLRequest : NSObject <NSCoding, NSCopying, NSMutableCopying>
{
#if	GS_EXPOSE(NSURLRequest)
  void *_NSURLRequestInternal;
#endif
}

/*
 * Returns an autoreleased instance initialised with the specified URL
 * and with the default cache policy (NSURLRequestUseProtocolCachePolicy)
 * and a sixty second timeout.
 */
+ (instancetype) requestWithURL: (NSURL *)URL;

/**
 * Returns an autoreleased instance initialised with the specified URL,
 * cachePolicy, and timeoutInterval.
 */
+ (instancetype) requestWithURL: (NSURL *)URL
                    cachePolicy: (NSURLRequestCachePolicy)cachePolicy
                timeoutInterval: (NSTimeInterval)timeoutInterval;

/**
 * Returns the cache policy associated with the receiver.
 */
- (NSURLRequestCachePolicy) cachePolicy;

/**
 * Initialises the reveiver with the specified URL
 * and with the default cache policy (NSURLRequestUseProtocolCachePolicy)
 * and a sixty second timeout.
 */
- (instancetype) initWithURL: (NSURL *)URL;

/**
 * Initialises the receiver with the specified URL,
 * cachePolicy, and timeoutInterval.
 */
- (instancetype) initWithURL: (NSURL *)URL
                 cachePolicy: (NSURLRequestCachePolicy)cachePolicy
             timeoutInterval: (NSTimeInterval)timeoutInterval;

/**
 * Returns the main document URL for the receiver.<br />
 * Currently unused.<br />
 * This is intended for use with frames and similar situations where
 * a main document has a large number of subsidiary documents.
 */
- (NSURL *) mainDocumentURL;

/**
 * Returns the timeout interval associated with the receiver.<br />
 * This is a value in seconds specifying how long the load process
 * may be inactive (waiting for data to arrive from the server)
 * before the load is mconsidered to have failed due to a timeout.
 */
- (NSTimeInterval) timeoutInterval;

/**
 * Returns the URL associated with the receiver.
 */
- (NSURL *) URL;

@end


/**
 */
GS_EXPORT_CLASS
@interface NSMutableURLRequest : NSURLRequest

/**
 * Sets the receiver's cache policy.
 */
- (void) setCachePolicy: (NSURLRequestCachePolicy)cachePolicy;

/**
 * Sets the receiver's main document.
 */
- (void) setMainDocumentURL: (NSURL *)URL;

/**
 * Sets the receiver's timeout policy.
 */
- (void) setTimeoutInterval: (NSTimeInterval)seconds;

/**
 * Sets the receiver's URL
 */
- (void) setURL: (NSURL *)URL;

@end



/**
 * HTTP specific additions to NSURLRequest
 */
@interface NSURLRequest (NSHTTPURLRequest)

/**
 * Returns a dictionary of the HTTP header fields associated with the
 * receiver.
 */
- (NSDictionary *) allHTTPHeaderFields;

/**
 * Returns the body of the reques ... this is the data sent in a POST
 * request.
 */
- (NSData *) HTTPBody;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_4,GS_API_LATEST)
/**
 * Returns the currently set stream (if any) to be used to provide data
 * to send as the request body.<br />
 * Of course, any attempt to modify this stream may mess up the load
 * operation in progress.
 */
- (NSInputStream *) HTTPBodyStream;
#endif

/**
 * Returns the HTTP method assiciated with the receiver.
 */
- (NSString *) HTTPMethod;

/**
 * Returns a flag indicating whether this request should use standard
 * cookie handling (sending of cookies with the request and storing
 * any cookies returned in the response.
 */
- (BOOL) HTTPShouldHandleCookies;

/**
 * Returns the value for a particular HTTP header field (by case
 * insensitive comparison) or nil if no such header is set.
 */
- (NSString *) valueForHTTPHeaderField: (NSString *)field;

#if OS_API_VERSION(MAC_OS_VERSION_11_0, GS_API_LATEST)
/**
 * Indicates whether the URL loading system assumes the host is HTTP/3 capable.
 *
 * This method returns the current assumption of the URL loading system regarding
 * the server's HTTP capabilities.
 */
- (BOOL) assumesHTTP3Capable;
#endif

@end



/**
 */
@interface NSMutableURLRequest (NSMutableHTTPURLRequest)

/**
 * Appends the value to the specified header field, automatically inserting
 * a comman field delimiter if necessary.
 */
- (void) addValue: (NSString *)value forHTTPHeaderField: (NSString *)field;

/**
 * Sets all the string values in the supplied headerFields
 * dictionary as header values in the receiver.<br />
 * Non-string values are ignored.
 */
- (void) setAllHTTPHeaderFields: (NSDictionary *)headerFields;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_4,GS_API_LATEST)
/**
 * Sets the request body to be the contents of the given stream.<br />
 * The stream should be unopened when it is set, and the load process
 * for the request will open the stream and read its entire content
 * forwarding it to the remote server.<br />
 * Clears any value previously set by -setHTTPBody: or -setHTTPBodyStream:
 */
- (void) setHTTPBodyStream: (NSInputStream *)inputStream;
#endif

/**
 * Sets the data to be sent as the body of the HTTP request.<br />
 * Clears any value previously set by -setHTTPBodyStream: or -setHTTPBody:
 */
- (void) setHTTPBody: (NSData *)data;

/**
 * Sets the method of the receiver.
 */
- (void) setHTTPMethod: (NSString *)method;

/**
 * Sets a flag to say whether cookies should automatically be added
 * to the request and whether cookies in the response should be used.
 */
- (void) setHTTPShouldHandleCookies: (BOOL)should;

/**
 * Sets the value for the specified header field, replacing any
 * previously set value. Setting a nil value deletes a previously set
 * header field.
 */
- (void) setValue: (NSString *)value forHTTPHeaderField: (NSString *)field;

#if OS_API_VERSION(MAC_OS_VERSION_11_0, GS_API_LATEST)
/**
 * Sets whether the URL loading system should assume the host is HTTP/3 capable.
 *
 * This method configures the URL loading system's assumptions about the
 * server's HTTP capabilities, optimizing the connection process if HTTP/3 is
 * supported.
 */
- (void) setAssumesHTTP3Capable: (BOOL)capable;
#endif

@end

@protocol GSLogDelegate;
@interface NSMutableURLRequest (GNUstep)

/** Sets a flag to turn on low level debug logging for this request and the
 * corresponding response.  The previous vaue of the setting is returned.
 */
- (int) setDebug: (int)d;

/** Sets a delegate object to override logging of low level I/O of the
 * request as it is sent and the corresponding response as it arrives.<br />
 * The delegate object is not retained, so it is the responsibility of the
 * caller to ensure that it persists until all I/O has completed.<br />
 * This has no effect unless debug is turned on, but if debug is turned on
 * it permits the delegate to override the default behavior of writing the
 * data to stderr.
 */
- (id<GSLogDelegate>) setDebugLogDelegate: (id<GSLogDelegate>)d;
@end

#if	defined(__cplusplus)
}
#endif

#endif

#endif
