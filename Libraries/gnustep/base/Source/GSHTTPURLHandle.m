/** GSHTTPURLHandle.m - Class GSHTTPURLHandle
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by: 		Mark Allison <mark@brainstorm.co.uk>
   Integrated by:	Richard Frith-Macdonald <rfm@gnu.org>
   Date:		November 2000 		

   This file is part of the GNUstep Library.

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

#import "common.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSByteOrder.h"
#import "Foundation/NSData.h"
#import "Foundation/NSException.h"
#import "Foundation/NSFileHandle.h"
#import "Foundation/NSHost.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSPathUtilities.h"
#import "Foundation/NSProcessInfo.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSURL.h"
#import "Foundation/NSURLHandle.h"
#import "Foundation/NSValue.h"
#import "GNUstepBase/GSMime.h"
#import "GNUstepBase/GSTLS.h"
#import "GNUstepBase/NSData+GNUstepBase.h"
#import "GNUstepBase/NSString+GNUstepBase.h"
#import "GNUstepBase/NSURL+GNUstepBase.h"
#import "NSCallBacks.h"
#import "GSURLPrivate.h"
#import "GSPrivate.h"

#ifdef	HAVE_SYS_FILE_H
#  include <sys/file.h>
#endif

#if	defined(HAVE_SYS_FCNTL_H)
#  include <sys/fcntl.h>
#elif	defined(HAVE_FCNTL_H)
#  include <fcntl.h>
#endif

#ifdef	HAVE_SYS_SOCKET_H
#  include <sys/socket.h>		// For MSG_PEEK, etc
#endif

@interface GSMimeHeader (HTTPRequest)
- (void) addToBuffer: (NSMutableData*)buf
             masking: (NSMutableData**)masked;
@end

/*
 * Implement map keys for strings with case insensitive comparisons,
 * so we can have case insensitive matching of http headers (correct
 * behavior), but actually preserve case of headers stored and written
 * in case the remote server is buggy and requires particular
 * captialisation of headers (some http software is faulty like that).
 */
static NSUInteger
_id_hash(void *table, NSString* o)
{
  return [[o uppercaseString] hash];
}

static BOOL
_id_is_equal(void *table, NSString *o, NSString *p)
{
  return ([o caseInsensitiveCompare: p] == NSOrderedSame) ? YES : NO;
}

typedef NSUInteger (*NSMT_hash_func_t)(NSMapTable *, const void *);
typedef BOOL (*NSMT_is_equal_func_t)(NSMapTable *, const void *, const void *);
typedef void (*NSMT_retain_func_t)(NSMapTable *, const void *);
typedef void (*NSMT_release_func_t)(NSMapTable *, void *);
typedef NSString *(*NSMT_describe_func_t)(NSMapTable *, const void *);

static const NSMapTableKeyCallBacks writeKeyCallBacks =
{
  (NSMT_hash_func_t) _id_hash,
  (NSMT_is_equal_func_t) _id_is_equal,
  (NSMT_retain_func_t) _NS_id_retain,
  (NSMT_release_func_t) _NS_id_release,
  (NSMT_describe_func_t) _NS_id_describe,
  NSNotAPointerMapKey
};

static NSString	*httpVersion = @"1.1";

@interface GSHTTPURLHandle : NSURLHandle
{
  BOOL			tunnel;
  BOOL			debug;
  BOOL			keepalive;
  BOOL			returnAll;
  BOOL                  inResponse;
  id<GSLogDelegate>     ioDelegate;
  unsigned char		challenged;
  NSFileHandle          *sock;
  NSTimeInterval        cacheAge;
  NSString              *urlKey;
  NSURL                 *url;
  NSURL                 *u;
  NSURL                 *proxyURL;
  NSMutableData         *dat;
  GSMimeParser		*parser;
  GSMimeDocument	*document;
  NSMutableDictionary   *pageInfo;
  NSMapTable            *wProperties;
  NSData		*wData;
  NSMutableDictionary   *request;
  unsigned int          bodyPos;
  unsigned int		redirects;
  enum {
    idle,
    connecting,
    writing,
    reading,
  } connectionState;
@public
  NSString      *in;
  NSString      *out;
}
+ (void) setMaxCached: (NSUInteger)limit;
- (void) _tryLoadInBackground: (NSURL*)fromURL;
- (id<GSLogDelegate>) setDebugLogDelegate: (id<GSLogDelegate>)d;
@end

/**
 * <p>
 *   This is a <em>PRIVATE</em> subclass of NSURLHandle.
 *   It is documented here in order to give you information about the
 *   default behavior of an NSURLHandle created to deal with a URL
 *   that has either the <code>http</code> or <code>https</code> scheme.
 *   The name and/or other implementation details of this class
 *   may be changed at any time.
 * </p>
 * <p>
 *   A GSHTTPURLHandle instance is used to manage connections to
 *   <code>http</code> and <code>https</code> URLs.
 *    Secure connections are handled automatically
 *   (using openSSL) for URLs with the scheme <code>https</code>.
 *   Connection via proxy server is supported, as is proxy tunneling
 *   for secure connections.  Basic parsing of <code>http</code>
 *   headers is performed to extract <code>http</code> status
 *   information, cookies etc.  Cookies are
 *   retained and automatically sent during subsequent requests where
 *   the cookie is valid.
 * </p>
 * <p>
 *   Header information from the current page may be obtained using
 *   -propertyForKey and -propertyForKeyIfAvailable.  <code>HTTP</code>
 *   status information can be retrieved as by calling either of these
 *   methods specifying one of the following keys:
 * </p>
 * <list>
 *   <item>
 *     NSHTTPPropertyStatusCodeKey - numeric status code
 *   </item>
 *   <item>
 *     NSHTTPPropertyStatusReasonKey - text describing status
 *   </item>
 *   <item>
 *     NSHTTPPropertyServerHTTPVersionKey - <code>http</code>
 *     version supported by remote server
 *   </item>
 * </list>
 * <p>
 *   According to MacOS-X headers, the following should also
 *   be supported, but currently are not:
 * </p>
 * <list>
 *   <item>NSHTTPPropertyRedirectionHeadersKey</item>
 *   <item>NSHTTPPropertyErrorPageDataKey</item>
 * </list>
 * <p>
 *   The omission of these headers is not viewed as important at
 *   present, since the MacOS-X public beta implementation doesn't
 *   work either.
 * </p>
 * <p>
 *   Other calls to -propertyForKey and -propertyForKeyIfAvailable may
 *   be made specifying a <code>http</code> header field name.
 *   For example specifying a key name of &quot;Content-Length&quot;
 *   would return the value of the &quot;Content-Length&quot; header
 *   field.
 * </p>
 * <p>
 *   [GSHTTPURLHandle-writeProperty:forKey:]
 *   can be used to specify the parameters
 *   for the <code>http</code> request.  The default request uses the
 *   &quot;GET&quot; method when fetching a page, and the
 *   &quot;POST&quot; method when using -writeData:.
 *   This can be over-ridden by calling -writeProperty:forKey: with
 *   the key name &quot;GSHTTPPropertyMethodKey&quot; and specifying an
 *   alternative method (i.e &quot;PUT&quot;).
 * </p>
 * <p>
 *   A Proxy may be specified by calling -writeProperty:forKey: to set a
 *   URL as the value for either https_proxy or http_proxy.<br />
 *   For backward compatibility a proxy may also be specified by calling
 *   -writeProperty:forKey:
 *   with the keys &quot;GSHTTPPropertyProxyHostKey&quot; and
 *   &quot;GSHTTPPropertyProxyPortKey&quot; to set the host and port
 *   of the proxy server respectively.<br />
 *   The proxy property can specify either the IP address or the hostname of
 *   the proxy server.  If an attempt is made to load a page via a
 *   secure connection when a proxy is specified, GSHTTPURLHandle will
 *   attempt to open an SSL Tunnel through the proxy.
 * </p>
 * <p>
 *   Requests to the remote server may be forced to be bound to a
 *   particular local IP address by using the key
 *   &quot;GSHTTPPropertyLocalHostKey&quot;  which must contain the
 *   IP address of a network interface on the local host.
 * </p>
 */
@implementation GSHTTPURLHandle

static NSMutableDictionary	*urlCache = nil;
static NSMutableArray		*urlOrder = nil;
static NSLock			*urlLock = nil;
static NSUInteger               maxCached = 16;

static Class			sslClass = 0;

static void
debugRead(GSHTTPURLHandle *handle, NSData *data)
{
  int   	len = (int)[data length];
  const uint8_t	*ptr = (const uint8_t*)[data bytes];
  uint8_t       *hex;
  NSUInteger    hl;
  int           pos;

  hl = ((len + 2) / 3) * 4;
  hex = malloc(hl + 1);
  hex[hl] = '\0';
  GSPrivateEncodeBase64(ptr, (NSUInteger)len, hex);
  for (pos = 0; pos < len; pos++)
    {
      if (0 == ptr[pos])
        {
          char  *esc = [data escapedRepresentation: 0];

          NSLog(@"Read for %p %@ of %d bytes (escaped) - '%s'\n<[%s]>",
            handle, handle->in, len, esc, hex); 
          free(esc);
          free(hex);
          return;
        }
    }
  NSLog(@"Read for %p %@ of %d bytes - '%*.*s'\n<[%s]>",
    handle, handle->in, len, len, len, ptr, hex); 
  free(hex);
}
static void
debugWrite(GSHTTPURLHandle *handle, NSData *data)
{
  int	        len = (int)[data length];
  const uint8_t	*ptr = (const uint8_t*)[data bytes];
  uint8_t       *hex;
  NSUInteger    hl;
  int           pos;

  hl = ((len + 2) / 3) * 4;
  hex = malloc(hl + 1);
  hex[hl] = '\0';
  GSPrivateEncodeBase64(ptr, (NSUInteger)len, hex);
  for (pos = 0; pos < len; pos++)
    {
      if (0 == ptr[pos])
        {
          char  *esc = [data escapedRepresentation: 0];

          NSLog(@"Write for %p %@ of %d bytes (escaped) - '%s'\n<[%s]>",
            handle, handle->out, len, esc, hex); 
          free(esc);
          free(hex);
          return;
        }
    }
  NSLog(@"Write for %p %@ of %d bytes - '%*.*s'\n<[%s]>",
    handle, handle->out, len, len, len, ptr, hex); 
  free(hex);
}

+ (NSURLHandle*) cachedHandleForURL: (NSURL*)newUrl
{
  NSURLHandle	*obj = nil;
  NSString      *s = [newUrl scheme];

  if ([s caseInsensitiveCompare: @"http"] == NSOrderedSame
    || [s caseInsensitiveCompare: @"https"] == NSOrderedSame)
    {
      NSString	*k = [newUrl cacheKey];

      //NSLog(@"Lookup for handle for '%@'", newUrl);
      [urlLock lock];
      obj = RETAIN([urlCache objectForKey: k]);
      if (obj != nil)
        {
          ASSIGN(((GSHTTPURLHandle*)obj)->url, newUrl);
	  [urlOrder removeObjectIdenticalTo: obj];
	  [urlOrder addObject: obj];
	}
      [urlLock unlock];
      //NSLog(@"Found handle %@", obj);
    }
  return AUTORELEASE(obj);
}

+ (void) initialize
{
  if (self == [GSHTTPURLHandle class])
    {
      urlCache = [NSMutableDictionary new];
      [[NSObject leakAt: &urlCache] release];
      urlOrder = [NSMutableArray new];
      [[NSObject leakAt: &urlOrder] release];
      urlLock = [NSLock new];
      [[NSObject leakAt: &urlLock] release];
      sslClass = [NSFileHandle sslClass];
    }
}

+ (void) setMaxCached: (NSUInteger)limit
{
  maxCached = limit;
}

- (void) _disconnect
{
  if (sock)
    {
      NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];

      [nc removeObserver: self name: nil object: sock];
      [sock closeFile];
      DESTROY(sock);
    }
  DESTROY(in);
  DESTROY(out);
  connectionState = idle;
}

- (void) dealloc
{
  [self _disconnect];
  DESTROY(out);
  DESTROY(in);
  DESTROY(u);
  DESTROY(urlKey);
  DESTROY(url);
  DESTROY(proxyURL);
  DESTROY(dat);
  DESTROY(parser);
  DESTROY(document);
  DESTROY(pageInfo);
  DESTROY(wData);
  if (wProperties != 0)
    {
      NSFreeMapTable(wProperties);
    }
  DESTROY(request);
  [super dealloc];
}

- (id) initWithURL: (NSURL*)newUrl
	    cached: (BOOL)cached
{
  if ((self = [super initWithURL: newUrl cached: cached]) != nil)
    {
      debug = GSDebugSet(@"NSURLHandle");
      dat = [NSMutableData new];
      pageInfo = [NSMutableDictionary new];
      wProperties = NSCreateMapTable(writeKeyCallBacks,
	NSObjectMapValueCallBacks, 8);
      request = [NSMutableDictionary new];

      ASSIGN(url, newUrl);
      ASSIGN(urlKey, [newUrl cacheKey]);
      connectionState = idle;
      if (cached == YES)
        {
	  GSHTTPURLHandle	*obj;

	  [urlLock lock];
	  obj = [urlCache objectForKey: urlKey];
	  [urlCache setObject: self forKey: urlKey];
	  if (obj != nil)
	    {
	      [urlOrder removeObjectIdenticalTo: obj];
	    }
	  [urlOrder addObject: self];
	  while ([urlOrder count] > maxCached)
	    {
	      obj = [urlOrder objectAtIndex: 0];
              obj->cacheAge = 0.0;      // Not to be re-cached
	      [urlCache removeObjectForKey: obj->urlKey];
	      [urlOrder removeObjectAtIndex: 0];
	    }
	  [urlLock unlock];
	  //NSLog(@"Cache handle %p for '%@'", self, newUrl);
	}
    }
  return self;
}

+ (BOOL) canInitWithURL: (NSURL*)newUrl
{
  NSString      *scheme = [newUrl scheme];

  if ([scheme isEqualToString: @"http"]
    || [scheme isEqualToString: @"https"])
    {
      return YES;
    }
  return NO;
}

- (void) bgdApply: (NSString*)basic
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  NSMutableString	*s;
  NSString              *key;
  NSString		*val;
  NSMutableData		*buf;
  NSMutableData		*masked = nil;
  NSString		*version;
  NSMapEnumerator       enumerator;

  RETAIN(self);
  if (debug)
    {
      NSLog(@"%@ %p %@ %s",
        NSStringFromSelector(_cmd), self, out,
        (keepalive ? "re-used connection" : "initial connection"));
    }

  s = [basic mutableCopy];
  if ([[u query] length] > 0)
    {
      [s appendFormat: @"?%@", [u query]];
    }

  version = [request objectForKey: NSHTTPPropertyServerHTTPVersionKey];
  if (version == nil)
    {
      version = httpVersion;
    }
  [s appendFormat: @" HTTP/%@\r\n", version];

  if ((id)NSMapGet(wProperties, (void*)@"Host") == nil)
    {
      NSString  *s = [u scheme];
      id	p = [u port];
      id	h = [u host];

      if (h == nil)
	{
	  h = @"";	// Must use an empty host header
	}
      if (([s isEqualToString: @"http"] && [p intValue] == 80)
        || ([s isEqualToString: @"https"] && [p intValue] == 443))
        {
          /* Some buggy systems object to the port being in the Host
           * header when it's the default (optional) value.  To keep
           * them happy let's omit it in those cases.
           */
          p = nil;
        }
      if (nil == p)
	{
          NSMapInsert(wProperties, (void*)@"Host", (void*)h);
	}
      else
	{
          NSMapInsert(wProperties, (void*)@"Host",
	    (void*)[NSString stringWithFormat: @"%@:%@", h, p]);
	}
    }

  /* Ensure we set the correct content length (may be zero)
   */
  if ((id)NSMapGet(wProperties, (void*)@"Content-Length") == nil)
    {
      NSMapInsert(wProperties, (void*)@"Content-Length",
        (void*)[NSString stringWithFormat: @"%"PRIuPTR, [wData length]]);
    }

  if ([wData length] > 0)
    {
      /*
       * Assume content type if not specified.
       */
      if ((id)NSMapGet(wProperties, (void*)@"Content-Type") == nil)
	{
	  NSMapInsert(wProperties, (void*)@"Content-Type",
	    (void*)@"application/x-www-form-urlencoded");
	}
    }

  if ((id)NSMapGet(wProperties, (void*)@"Authorization") == nil)
    {
      NSURLProtectionSpace	*space;

      /*
       * If we have username/password stored in the URL, and there is a
       * known protection space for that URL, we generate an authentication
       * header.
       */
      if ([u user] != nil
	&& (space = [GSHTTPAuthentication protectionSpaceForURL: u]) != nil)
	{
	  NSString		*auth;
	  GSHTTPAuthentication	*authentication;
	  NSURLCredential	*cred;
	  NSString		*method;

	  /* Create credential from user and password stored in the URL.
	   * Returns nil if we have no username or password.
	   */
	  cred = [[NSURLCredential alloc]
	    initWithUser: [u user]
	    password: [u password]
	    persistence: NSURLCredentialPersistenceForSession];

	  if (cred == nil)
	    {
	      authentication = nil;
	    }
	  else
	    {
	      /* Create authentication from credential ... returns nil if
	       * we have no credential.
	       */
	      authentication = [GSHTTPAuthentication
		authenticationWithCredential: cred
		inProtectionSpace: space];
	      RELEASE(cred);
	    }

	  method = [request objectForKey: GSHTTPPropertyMethodKey];
	  if (method == nil)
	    {
	      if ([wData length] > 0)
		{
		  method = @"POST";
		}
	      else
		{
		  method = @"GET";
		}
	    }

	  auth = [authentication authorizationForAuthentication: nil
	    method: method
	    path: [u pathWithEscapes]];
	  /* If authentication is nil then auth will also be nil
	   */
	  if (auth != nil)
	    {
	      [self writeProperty: auth forKey: @"Authorization"];
	    }
	}
    }

  buf = [[s dataUsingEncoding: NSISOLatin1StringEncoding] mutableCopy];

  enumerator = NSEnumerateMapTable(wProperties);
  while (NSNextMapEnumeratorPair(&enumerator, (void **)(&key), (void**)&val))
    {
      GSMimeHeader      *h;

      h = [[GSMimeHeader alloc] initWithName: key value: val parameters: nil];
      if (debug || masked)
	{
	  [h addToBuffer: buf masking: &masked];
  	}
      else
	{
	  [h addToBuffer: buf masking: NULL];
	}
      RELEASE(h);
    }
  NSEndMapTableEnumeration(&enumerator);

  [buf appendBytes: "\r\n" length: 2];
  if (masked)
    {
      [masked appendBytes: "\r\n" length: 2];
    }

  /*
   * Append any data to be sent
   */
  if (wData != nil)
    {
      [buf appendData: wData];
      if (masked)
	{
	  [masked appendData: wData];
	}
    }

  /*
   * Watch for write completion.
   */
  [nc addObserver: self
         selector: @selector(bgdWrite:)
             name: GSFileHandleWriteCompletionNotification
           object: sock];
  connectionState = writing;

  /*
   * Send request to server.
   */
  if (debug)
    {
      if (nil == masked)
	{
	  masked = buf;		// Just log unmasked data
	}
      if (NO == [ioDelegate putBytes: [masked bytes]
                            ofLength: [masked length]
                            byHandle: self])
        {
          debugWrite(self, masked);
        }
    }
  [sock writeInBackgroundAndNotify: buf];
  RELEASE(buf);
  RELEASE(s);
  DESTROY(self);
}

- (void) bgdRead: (NSNotification*) not
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  NSDictionary		*dict = [not userInfo];
  NSData		*d;
  NSRange		r;
  unsigned		readCount;

  RETAIN(self);

  if (debug)
    NSLog(@"%@ %p %s", NSStringFromSelector(_cmd), self, keepalive?"K":"");
  d = [dict objectForKey: NSFileHandleNotificationDataItem];
  readCount = [d length];
  if (debug)
    {
      if (NO == [ioDelegate getBytes: [d bytes]
                            ofLength: readCount
                            byHandle: self])
        {
          debugRead(self, d);
        }
    }

  if (connectionState == idle)
    {
      /*
       * We received an event on a handle which is not in use ...
       * it should just be the connection being closed by the other
       * end because of a timeout etc.
       */
      if (debug)
	{
          NSUInteger    length = [d length];

          if (length > 0)
            {
              if (nil == ioDelegate)
                {
                  NSLog(@"%@ %p %s Unexpected data (%*.*s) from remote!",
                    NSStringFromSelector(_cmd), self, keepalive?"K":"",
                    (int)[d length], (int)[d length], (char*)[d bytes]);
                }
              else
                {
                  NSLog(@"%@ %p %s Unexpected data from remote!",
                    NSStringFromSelector(_cmd), self, keepalive?"K":"");
                  if (NO == [ioDelegate getBytes: [d bytes]
                                        ofLength: length
                                        byHandle: self])
                    {
                      NSLog(@"%@ %p %s (%*.*s)",
                        NSStringFromSelector(_cmd), self, keepalive?"K":"",
                        (int)[d length], (int)[d length], (char*)[d bytes]);
                    }
                }
            }
	}
      [self _disconnect];
    }
  else if (0 == readCount && NO == inResponse && YES == keepalive)
    {
      /* On a keepalive connection where the remote end
       * dropped the connection without responding.  We
       * should try again.
       */
      if (connectionState != idle)
        {
          [self _disconnect];
          if (debug)
            {
              NSLog(@"%@ %p restart on new connection",
                NSStringFromSelector(_cmd), self);
            }
          [self _tryLoadInBackground: u];
        }
    }
  else if ([parser parse: d] == NO && [parser isComplete] == NO)
    {
      inResponse = YES;
      if (debug)
	{
	  NSLog(@"HTTP parse failure - %@", parser);
	}
      [self endLoadInBackground];
      [self backgroundLoadDidFailWithReason: @"Response parse failed"];
    }
  else
    {
      BOOL	complete;

      inResponse = YES;
      complete = [parser isComplete];
      if (complete == NO && [parser isInHeaders] == NO)
	{
	  GSMimeHeader	*info;
	  NSString	*enc;
	  NSString	*len;
	  int		status;

	  info = [document headerNamed: @"http"];
	  status = [[info objectForKey: NSHTTPPropertyStatusCodeKey] intValue];
	  len = [[document headerNamed: @"content-length"] value];
	  enc = [[document headerNamed: @"content-transfer-encoding"] value];
	  if (enc == nil)
	    {
	      enc = [[document headerNamed: @"transfer-encoding"] value];
	    }

	  if (status == 204 || status == 304)
	    {
	      complete = YES;	// No body expected.
	    }
	  else if ([enc isEqualToString: @"chunked"] == YES)	
	    {
	      complete = NO;	// Read chunked body data
	    }
	  else if (nil != len && [len intValue] == 0)
	    {
	      complete = YES;	// content-length explicitly zero
	    }
	  if (complete == NO && [d length] == 0)
	    {
	      complete = YES;	// Had EOF ... terminate
	    }
	}
      if (complete == YES)
	{
	  GSMimeHeader	*info;
	  NSString	*val;
	  NSNumber	*num;
	  float		ver;
	  int		code;

	  connectionState = idle;
	  [nc removeObserver: self name: nil object: sock];

	  ver = [[[document headerNamed: @"http"] value] floatValue];
	  if (ver < 1.1)
	    {
              [self _disconnect];
	    }
	  else if (nil != (val = [[document headerNamed: @"connection"] value]))
	    {
	      val = [val lowercaseString];
	      if (YES == [val isEqualToString: @"close"])
		{
                  [self _disconnect];
		}
	      else if ([val length] > 5)
		{
		  NSEnumerator	*e;

		  e = [[val componentsSeparatedByString: @","]
		    objectEnumerator];
		  while (nil != (val = [e nextObject]))
		    {
		      val = [val stringByTrimmingSpaces];
		      if (YES == [val isEqualToString: @"close"])
			{
                          [self _disconnect];
			  break;
			}
		    }
		}
	    }

	  /*
	   * Retrieve essential keys from document
	   */
	  info = [document headerNamed: @"http"];
	  num = [info objectForKey: NSHTTPPropertyStatusCodeKey];
	  code = [num intValue];
	  if (code == 401 && self->challenged < 2)
	    {
	      GSMimeHeader	*ah;

	      self->challenged++;	// Prevent repeated challenge/auth
	      if ((ah = [document headerNamed: @"WWW-Authenticate"]) != nil)
		{
	          NSURLProtectionSpace	*space;
		  NSString		*ac;
		  GSHTTPAuthentication	*authentication;
		  NSString		*method;
		  NSString		*auth;

		  ac = [ah value];
		  space = [GSHTTPAuthentication
		    protectionSpaceForAuthentication: ac requestURL: url];
		  if (space == nil)
		    {
		      authentication = nil;
		    }
		  else
		    {
		      NSURLCredential	*cred;

		      /*
		       * Create credential from user and password
		       * stored in the URL.
		       * Returns nil if we have no username or password.
		       */
		      cred = [[NSURLCredential alloc]
			initWithUser: [url user]
			password: [url password]
			persistence: NSURLCredentialPersistenceForSession];

		      if (cred == nil)
		        {
			  authentication = nil;
			}
		      else
		        {
			  /*
			   * Get the digest object and ask it for a header
			   * to use for authorisation.
			   * Returns nil if we have no credential.
			   */
			  authentication = [GSHTTPAuthentication
			    authenticationWithCredential: cred
			    inProtectionSpace: space];
			  RELEASE(cred);
			}
		    }

		  method = [request objectForKey: GSHTTPPropertyMethodKey];
		  if (method == nil)
		    {
		      if ([wData length] > 0)
			{
			  method = @"POST";
			}
		      else
			{
			  method = @"GET";
			}
		    }

		  auth = [authentication authorizationForAuthentication: ac
		    method: method
		    path: [url pathWithEscapes]];
		  if (auth != nil)
		    {
		      [self writeProperty: auth forKey: @"Authorization"];
		      [self _tryLoadInBackground: u];
                      RELEASE(self);
		      return;	// Retrying.
		    }
		}
	    }
	  if (num != nil)
	    {
	      [pageInfo setObject: num forKey: NSHTTPPropertyStatusCodeKey];
	    }
	  val = [info objectForKey: NSHTTPPropertyServerHTTPVersionKey];
	  if (val != nil)
	    {
	      [pageInfo setObject: val
			   forKey: NSHTTPPropertyServerHTTPVersionKey];
	    }
	  val = [info objectForKey: NSHTTPPropertyStatusReasonKey];
	  if (val != nil)
	    {
	      [pageInfo setObject: val forKey: NSHTTPPropertyStatusReasonKey];
	    }
	  /*
	   * Tell superclass that we have successfully loaded the data.
	   */
	  d = [parser data];
	  r = NSMakeRange(bodyPos, [d length] - bodyPos);
	  bodyPos = 0;
	  DESTROY(wData);
	  NSResetMapTable(wProperties);
          connectionState = idle;       // Finished I/O
	  if (returnAll || (code >= 200 && code < 300))
	    {
	      [self didLoadBytes: [d subdataWithRange: r]
		    loadComplete: YES];
	    }
	  else
	    {
	      [self didLoadBytes: [d subdataWithRange: r]
		    loadComplete: NO];
	      [self cancelLoadInBackground];
	    }
	}
      else
	{
	  /*
	   * Report partial data if possible.
	   */
	  if ([parser isInBody])
	    {
	      d = [parser data];
	      r = NSMakeRange(bodyPos, [d length] - bodyPos);
	      bodyPos = [d length];
	      [self didLoadBytes: [d subdataWithRange: r]
		    loadComplete: NO];
	    }
	}

      if (complete == NO && readCount == 0)
        {
	  /* The read failed ... dropped, but parsing is not complete.
	   * The request was sent, so we can't know whether it was
	   * lost in the network or the remote end received it and
	   * the response was lost.
	   */
	  if (debug)
	    {
	      NSLog(@"HTTP response not received - %@", parser);
	    }
	  [self endLoadInBackground];
          [self backgroundLoadDidFailWithReason: @"Response parse failed"];
	}

      if (sock != nil && connectionState == reading)
	{
          if ([sock readInProgress] == NO)
	    {
	      [sock readInBackgroundAndNotify];
	    }
	}
    }
  DESTROY(self);
}

- (void) bgdTunnelRead: (NSNotification*) not
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  NSDictionary		*dict = [not userInfo];
  NSData		*d;
  GSMimeParser		*p;
  unsigned		readCount;

  RETAIN(self);
  if (debug)
    {
      NSLog(@"%@ %p %s", NSStringFromSelector(_cmd), self, keepalive?"K":"");
    }
  d = [dict objectForKey: NSFileHandleNotificationDataItem];
  readCount = [d length];
  if (debug)
    {
      if (NO == [ioDelegate getBytes: [d bytes]
                            ofLength: [d length]
                            byHandle: self])
        {
          debugRead(self, d);
        }
    }

  if (readCount > 0)
    {
      inResponse = YES;
      [dat appendData: d];
    }
  else if (NO == inResponse)
    {
      /* remote end dropped the connection without responding
       */
      [self _disconnect];
      if (debug)
        {
          NSLog(@"%@ %p restart on new connection",
            NSStringFromSelector(_cmd), self);
        }
      [self _tryLoadInBackground: u];
      DESTROY(self);
      return;
    }

  p = [GSMimeParser new];
  [p parse: dat];
  if ([p isInBody] == YES || [d length] == 0)
    {
      GSMimeHeader	*info;
      NSString		*val;
      NSNumber		*num;

      [p parse: nil];
      info = [[p mimeDocument] headerNamed: @"http"];
      val = [info objectForKey: NSHTTPPropertyServerHTTPVersionKey];
      if (val != nil)
	[pageInfo setObject: val forKey: NSHTTPPropertyServerHTTPVersionKey];
      num = [info objectForKey: NSHTTPPropertyStatusCodeKey];
      if (num != nil)
	[pageInfo setObject: num forKey: NSHTTPPropertyStatusCodeKey];
      val = [info objectForKey: NSHTTPPropertyStatusReasonKey];
      if (val != nil)
	[pageInfo setObject: val forKey: NSHTTPPropertyStatusReasonKey];
      [nc removeObserver: self
	            name: NSFileHandleReadCompletionNotification
                  object: sock];
      [dat setLength: 0];
      tunnel = NO;
    }
  else
    {
      if ([sock readInProgress] == NO)
	{
	  [sock readInBackgroundAndNotify];
	}
    }
  RELEASE(p);
  DESTROY(self);
}

- (void) loadInBackground
{
  self->challenged = 0;
  [self _tryLoadInBackground: nil];
}

- (void) endLoadInBackground
{
  DESTROY(wData);
  NSResetMapTable(wProperties);

  /* Socket must be removed from I/O notifications and connection state
   * marked idle, but the socket is already idle it may be re-used for
   * another request.
   */
  if (sock)
    {
      NSNotificationCenter      *nc = [NSNotificationCenter defaultCenter];

      [nc removeObserver: self name: nil object: sock];
      if (connectionState != idle)
	{
	  [sock closeFile];	// Close to cancel any I/O in progress
	  DESTROY(sock);
	}
    }
  connectionState = idle;
  [super endLoadInBackground];
}


- (void) _apply
{
  NSString	*method;
  NSString	*path;
  NSString	*s;

  /*
   * Set up request - differs for proxy version unless tunneling via ssl.
   */
  path = [[u pathWithEscapes] stringByTrimmingSpaces];
  if ([path length] == 0)
    {
      path = @"/";
    }

  method = [request objectForKey: GSHTTPPropertyMethodKey];
  if (method == nil)
    {
      if ([wData length] > 0)
	{
	  method = @"POST";
	}
      else
	{
	  method = @"GET";
	}
    }

  if (proxyURL
    && [[u scheme] isEqualToString: @"https"] == NO)
    {
      if ([u port] == nil)
	{
	  s = [[NSString alloc] initWithFormat: @"%@ http://%@%@",
	    method, [u host], path];
	}
      else
	{
	  s = [[NSString alloc] initWithFormat: @"%@ http://%@:%@%@",
	    method, [u host], [u port], path];
	}
    }
  else    // no proxy
    {
      s = [[NSString alloc] initWithFormat: @"%@ %@",
	method, path];
    }

  [self bgdApply: s];
  RELEASE(s);
}


- (void) bgdConnect: (NSNotification*)notification
{
  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];
  NSDictionary          *userInfo = [notification userInfo];
  NSString		*e;

  [nc removeObserver: self
                name: GSFileHandleConnectCompletionNotification
              object: sock];

  /*
   * See if the connection attempt caused an error.
   */
  e = [userInfo objectForKey: GSFileHandleNotificationError];
  if (e != nil)
    {
      NSLog(@"Unable to connect to %@:%@ via socket ... %@",
	[sock socketAddress], [sock socketService], e);
      /*
       * Tell superclass that the load failed - let it do housekeeping.
       */
      [self endLoadInBackground];
      [self backgroundLoadDidFailWithReason:
	[NSString stringWithFormat: @"Failed to connect: %@", e]];
      return;
    }

  ASSIGN(in, ([NSString stringWithFormat: @"(%@:%@ <-- %@:%@)",
    [sock socketLocalAddress], [sock socketLocalService],
    [sock socketAddress], [sock socketService]]));
  ASSIGN(out, ([NSString stringWithFormat: @"(%@:%@ --> %@:%@)",
    [sock socketLocalAddress], [sock socketLocalService],
    [sock socketAddress], [sock socketService]]));

  if (debug)
    {
      NSLog(@"%@ %p", NSStringFromSelector(_cmd), self);
    }

  /*
   * If SSL via proxy, set up tunnel first
   */
  if (proxyURL && [[u scheme] isEqualToString: @"https"])
    {
      NSRunLoop		*loop = [NSRunLoop currentRunLoop];
      NSString		*cmd;
      NSTimeInterval	last = 0.0;
      NSTimeInterval	limit = 0.01;
      NSData		*buf;
      NSDate		*when;
      int		status;
      NSString		*version;

      version = [request objectForKey: NSHTTPPropertyServerHTTPVersionKey];
      if (version == nil)
	{
	  version = httpVersion;
	}
      if ([u port] == nil)
	{
	  cmd = [NSString stringWithFormat: @"CONNECT %@:443 HTTP/%@\r\n\r\n",
	    [u host], version];
	}
      else
	{
	  cmd = [NSString stringWithFormat: @"CONNECT %@:%@ HTTP/%@\r\n\r\n",
	    [u host], [u port], version];
	}

      /*
       * Set up default status for if connection is lost.
       */
      [pageInfo setObject: @"1.0" forKey: NSHTTPPropertyServerHTTPVersionKey];
      [pageInfo setObject: [NSNumber numberWithInt: 503]
		   forKey: NSHTTPPropertyStatusCodeKey];
      [pageInfo setObject: @"Connection dropped by proxy server"
		   forKey: NSHTTPPropertyStatusReasonKey];

      tunnel = YES;
      [nc addObserver: self
	     selector: @selector(bgdWrite:)
                 name: GSFileHandleWriteCompletionNotification
               object: sock];

      buf = [cmd dataUsingEncoding: NSASCIIStringEncoding];
      if (debug)
        {
          if (NO == [ioDelegate putBytes: [buf bytes]
                                ofLength: [buf length]
                                byHandle: self])
            {
              debugWrite(self, buf);
            }
        }
      [sock writeInBackgroundAndNotify: buf];

      when = [NSDate alloc];
      while (tunnel == YES)
	{
	  if (limit < 1.0)
	    {
	      NSTimeInterval	tmp = limit;

	      limit += last;
	      last = tmp;
	    }
          when = [when initWithTimeIntervalSinceNow: limit];
	  [loop runUntilDate: when];
	}
      RELEASE(when);

      status = [[pageInfo objectForKey: NSHTTPPropertyStatusCodeKey] intValue];
      if (status != 200)
	{
	  [self endLoadInBackground];
	  [self backgroundLoadDidFailWithReason: @"Failed proxy tunneling"];
	  return;
	}
    }
  if ([[u scheme] isEqualToString: @"https"])
    {
      static NSArray            *keys = nil;
      NSMutableDictionary       *opts;
      NSUInteger                count;
      BOOL			success = NO;

      /* If we are an https connection, negotiate secure connection.
       * Make sure we are not an observer of the file handle while
       * it is connecting...
       */
      [nc removeObserver: self name: nil object: sock];

      if (nil == keys)
        {
          keys = [[NSArray alloc] initWithObjects:
            GSTLSCAFile,
            GSTLSCertificateFile,
            GSTLSCertificateKeyFile,
            GSTLSCertificateKeyPassword,
            GSTLSDebug,
            GSTLSIssuers,
            GSTLSOwners,
            GSTLSPriority,
            GSTLSRemoteHosts,
            GSTLSRevokeFile,
            GSTLSServerName,
            GSTLSVerify,
            nil];
        }
      count = [keys count];
      opts = [[NSMutableDictionary alloc] initWithCapacity: count];
      while (count-- > 0)
        {
          NSString      *key = [keys objectAtIndex: count];
          NSString      *str = [request objectForKey: key];

          if (nil != str)
            {
              [opts setObject: str forKey: key];
            }
        }

      /* If there is no value set for the server name, and the host in the
       * URL is a domain name rather than an address, we use that.
       */
      if (nil == [opts objectForKey: GSTLSServerName])
        {
          NSString      *host = [u host];
          unichar       c = [host length] == 0 ? 0 : [host characterAtIndex: 0];

          if (c != 0 && c != ':' && !isdigit(c))
            {
              [opts setObject: host forKey: GSTLSServerName];
            }
        }

      if (debug) [opts setObject: @"YES" forKey: GSTLSDebug];
      [sock sslSetOptions: opts];
      RELEASE(opts);
      if ([sock sslHandshakeEstablished: &success outgoing: YES])
	{
	  if (NO == success)
	    {
	      if (debug)
		NSLog(@"%@ %p %s Failed to make ssl connect",
		  NSStringFromSelector(_cmd), self, keepalive?"K":"");
	      [self endLoadInBackground];
	      [self backgroundLoadDidFailWithReason:
		@"Failed to make ssl connect"];
	      return;
	    }
	}
      else
	{
	  [nc addObserver: self
	         selector: @selector(bgdHandshake:)
		     name: NSFileHandleDataAvailableNotification
	           object: sock];
	  [sock waitForDataInBackgroundAndNotify];
	  return;
	}
    }

  [self _apply];
}

- (void) bgdHandshake: (NSNotification*)notification
{
  BOOL	success = NO;

  if ([sock sslHandshakeEstablished: &success outgoing: YES])
    { 
      if (success)
	{
	  NSNotificationCenter	*nc = [NSNotificationCenter defaultCenter];

	  [nc removeObserver: self
			name: NSFileHandleDataAvailableNotification
		      object: sock];
	  [self _apply];
	}
      else
	{ 
	  if (debug)
	    NSLog(@"%@ %p %s Failed to make ssl connect",
	      NSStringFromSelector(_cmd), self, keepalive?"K":"");
	  [self endLoadInBackground];
	  [self backgroundLoadDidFailWithReason:
	    @"Failed to make ssl connect"];
	}
    }
  else
    {
      [sock waitForDataInBackgroundAndNotify];
    }
}

- (void) bgdWrite: (NSNotification*)notification
{
  NSNotificationCenter	*nc;
  NSDictionary    	*userInfo = [notification userInfo];
  NSString        	*e;

  RETAIN(self);
  if (debug)
    NSLog(@"%@ %p %s", NSStringFromSelector(_cmd), self, keepalive?"K":"");
  e = [userInfo objectForKey: GSFileHandleNotificationError];
  if (e != nil)
    {
      tunnel = NO;
      if (keepalive == YES)
	{
	  /*
	   * The write failed ... connection dropped ... and we
	   * are re-using an existing connection (keepalive = YES)
	   * then we may try again with a new connection.
	   */
          [self _disconnect];
	  if (debug)
            {
              NSLog(@"%@ %p restart on new connection",
                NSStringFromSelector(_cmd), self);
            }
	  [self _tryLoadInBackground: u];
          RELEASE(self);
	  return;
	}
      NSLog(@"Failed to write command to socket - %@ %p %s",
	e, self, keepalive?"K":"");
      /*
       * Tell superclass that the load failed - let it do housekeeping.
       */
      [self endLoadInBackground];
      [self backgroundLoadDidFailWithReason:
	[NSString stringWithFormat: @"Failed to write request: %@", e]];
      DESTROY(self);
      return;
    }
  else
    {
      /*
       * Don't watch for write completions any more.
       */
      nc = [NSNotificationCenter defaultCenter];
      [nc removeObserver: self
		    name: GSFileHandleWriteCompletionNotification
		  object: sock];

      /*
       * Ok - write completed, let's read the response.
       */
      if (tunnel == YES)
	{
	  [nc addObserver: self
	         selector: @selector(bgdTunnelRead:)
		     name: NSFileHandleReadCompletionNotification
	           object: sock];
	}
      else
	{
	  bodyPos = 0;
	  [nc addObserver: self
	         selector: @selector(bgdRead:)
		     name: NSFileHandleReadCompletionNotification
	           object: sock];
	}
      if ([sock readInProgress] == NO)
	{
	  [sock readInBackgroundAndNotify];
	}
      connectionState = reading;
    }
  DESTROY(self);
}

/**
 *  If necessary, this method calls -loadInForeground to send a
 *  request to the webserver, and get a page back.  It then returns
 *  the property for the specified key -
 * <list>
 *   <item>
 *     NSHTTPPropertyStatusCodeKey - numeric status code returned
 *     by the last request.
 *   </item>
 *   <item>
 *     NSHTTPPropertyStatusReasonKey - text describing status of
 *     the last request
 *   </item>
 *   <item>
 *     NSHTTPPropertyServerHTTPVersionKey - <code>http</code>
 *     version supported by remote server
 *   </item>
 *   <item>
 *     Other keys are taken to be the names of <code>http</code>
 *     headers and the corresponding header value (or nil if there
 *     is none) is returned.
 *   </item>
 * </list>
 */
- (id) propertyForKey: (NSString*) propertyKey
{
  if (document == nil)
    [self loadInForeground];
  return [self propertyForKeyIfAvailable: propertyKey];
}

- (id) propertyForKeyIfAvailable: (NSString*) propertyKey
{
  id	result = [pageInfo objectForKey: propertyKey];

  if (result == nil)
    {
      NSString	*key = [propertyKey lowercaseString];
      NSArray	*array = [document headersNamed: key];

      if ([array count] == 0)
	{
	  return nil;
	}
      else if ([array count] == 1)
	{
	  GSMimeHeader	*hdr = [array objectAtIndex: 0];

	  result = [hdr value];
	}
      else
	{
	  NSEnumerator	*enumerator = [array objectEnumerator];
	  GSMimeHeader	*val;

	  result = [NSMutableArray arrayWithCapacity: [array count]];
	  while ((val = [enumerator nextObject]) != nil)
	    {
	      [result addObject: [val value]];
	    }
	}
    }
  return result;
}

- (int) setDebug: (int)flag
{
  int   old = debug;

  debug = flag ? YES : NO;
  return old;
}

- (id<GSLogDelegate>) setDebugLogDelegate: (id<GSLogDelegate>)d
{
  id<GSLogDelegate>     old = ioDelegate;

  NSAssert(nil == d || [d conformsToProtocol: @protocol(GSLogDelegate)],
    NSInvalidArgumentException);
  ioDelegate  = d;
  return old;
}

- (void) setReturnAll: (BOOL)flag
{
  returnAll = flag;
}

- (void) setURL: (NSURL*)newUrl
{
  NSAssert(connectionState == idle, NSInternalInconsistencyException);
  NSAssert([newUrl isKindOfClass: [NSURL class]], NSInvalidArgumentException);

  if (NO == [newUrl isEqual: url])
    {
      NSString      *k = [newUrl cacheKey];

      if (NO == [k isEqual: urlKey])
        {
          /* Changing the URL of a handle to one that's not cache-compatible
           * implies that the handle must be removed from the cache and also
           * that the underlying network connection can no longer be used.
           */
          [urlLock lock];
          if (self == [urlCache objectForKey: urlKey])
            {
              [urlCache removeObjectForKey: urlKey];
              [urlOrder removeObjectIdenticalTo: self];
            }
          [urlLock unlock];
          [self _disconnect];
          ASSIGN(urlKey, k);
        }
      ASSIGN(url, newUrl);
    }
}

- (void) _tryLoadInBackground: (NSURL*)fromURL
{
  NSNotificationCenter	*nc;
  NSString		*host = nil;
  NSString		*port = nil;
  NSString		*s;

  /*
   * Don't start a load if one is in progress.
   */
  if (connectionState != idle)
    {
      NSLog(@"Attempt to load an http handle which is not idle ... ignored");
      return;
    }

  inResponse = NO;
  [dat setLength: 0];
  RELEASE(document);
  RELEASE(parser);
  [pageInfo removeAllObjects];
  parser = [GSMimeParser new];
  document = RETAIN([parser mimeDocument]);

  /*
   * First time round, fromURL is nil, so we use the url ivar and
   * we notify that the load is begining.  On retries we get a real
   * value in fromURL to use.
   */
  if (fromURL == nil)
    {
      redirects = 0;
      ASSIGN(u, url);
      [self beginLoadInBackground];
    }
  else
    {
      ASSIGN(u, fromURL);
    }

  host = [u host];
  port = (id)[u port];
  if (port != nil)
    {
      port = [NSString stringWithFormat: @"%u", [port intValue]];
    }
  else
    {
      port = [u scheme];
    }
  if ([port isEqualToString: @"https"])
    {
      port = @"443";
    }
  else if ([port isEqualToString: @"http"])
    {
      port = @"80";
    }

  /* An existing socket with keepalive may have been closed by the other
   * end.
   * On unix systems we can simply peek on the file descriptor for a much
   * more efficient check.
   * On windows we use the same system, it is noted to be inefficient but
   * we don't care because we peek rare enough at each HTTP request.
   */
  if (sock != nil)
    {
      int fd = [sock fileDescriptor];

      if (debug)
        {
	  NSLog(@"%@ %p check for reusable socket",
	    NSStringFromSelector(_cmd), self);
	}
      if (fd >= 0)
        {
	  int		result;
	  unsigned char	c;

#if     !defined(MSG_DONTWAIT)
#define MSG_DONTWAIT    0
#endif
	  result = recv(fd, (void *)&c, 1, MSG_PEEK | MSG_DONTWAIT);
	  if (result == 0 || (result < 0 && errno != EAGAIN && errno != EINTR))
	    {
	      DESTROY(sock);
	    }
	}
      else
        {
	  DESTROY(sock);
	}
      if (debug)
	{
	  if (sock == nil)
	    {
	      NSLog(@"%@ %p socket closed by remote",
		NSStringFromSelector(_cmd), self);
	    }
	  else
	    {
	      NSLog(@"%@ %p socket is still open",
		NSStringFromSelector(_cmd), self);
	    }
	}
    }

  if (sock == nil)
    {
      NSURLProtectionSpace      *space;
      NSURL                     *proxy = nil;
      NSString                  *proxyStr = nil;

      keepalive = NO;	// New connection
      /*
       * If we have a local address specified,
       * tell the file handle to bind to it.
       */
      s = [request objectForKey: GSHTTPPropertyLocalHostKey];
      if ([s length] > 0)
	{
	  s = [NSString stringWithFormat: @"bind-%@", s];
	}
      else
	{
	  s = @"tcp";	// Bind to any.
	}

      space = [GSHTTPAuthentication protectionSpaceForURL: u];
      if ([space isProxy])
	{ 
          proxyStr = [NSString stringWithFormat: @"%@://%@:%u/",
            [u scheme], [space host], (unsigned)[space port]];
        }
      else
        {
          NSString      *ph;
          NSString      *pp;

          ph = [request objectForKey: GSHTTPPropertyProxyHostKey];
          pp = [request objectForKey: GSHTTPPropertyProxyPortKey];
          if (ph)
            {
              if (pp)
                {
                  proxyStr = [NSString stringWithFormat: @"%@://%@:%@/",
                    [u scheme], ph, pp];
                }
              else
                {
                  proxyStr = [NSString stringWithFormat: @"%@://%@/",
                    [u scheme], ph];
                }
            }

          /* The preferred proxy specification is by a URL set as a property
           */
          if ([[u scheme] isEqualToString: @"https"])
            {
              proxy = [request objectForKey: @"https_proxy"];
            }
          else
            {
              proxy = [request objectForKey: @"http_proxy"];
            }
        }
      if ([proxy isKindOfClass: [NSString class]])
        {
          proxyStr = (NSString*)proxy;
          proxy = nil;
        }

      /* A generic fallback for the entire process can come from
       * environment variables.
       */
      if (nil == proxy && nil == proxyStr)
        {
          NSDictionary  *env;
          NSString      *key;
  
          env = [[NSProcessInfo processInfo] environment];
          key = [[u scheme] stringByAppendingString: @"_proxy"];
          if (nil == (proxyStr = [env objectForKey: key]))
            {
              proxyStr = [env objectForKey: [key uppercaseString]];
            }
        }
      if (nil == proxy)
        {
          /* We make the proxy URL from a supplied string unless that is empty;
           * An empty string in the request can be used to disable the process
           * wide settings for that request..
           */
          if ([proxyStr length])
            {
              proxy = [NSURL URLWithString: proxyStr];
            }
        }

      /* Make sure the proxy URL has a port specified. The default port
       * depends on the scheme of the request (4430 for TLS, 8080 unencrypted).
       */
      if (proxy && [[proxy port] intValue] == 0)
        {
          NSURLComponents       *c;

          c = [NSURLComponents componentsWithURL: proxy
                         resolvingAgainstBaseURL: NO];
          
          if ([[u scheme] isEqualToString: @"https"])
            {
              [c setPort: [NSNumber numberWithInteger: 4430]];
            }
          else
            {
              [c setPort: [NSNumber numberWithInteger: 8080]];
            }
          proxy = [c URL];
        }
      ASSIGN(proxyURL, proxy);

      if (nil == proxyURL)
	{
	  if ([[u scheme] isEqualToString: @"https"])
	    {
	      NSString	*cert;
              NSString	*key;
              NSString	*pwd;

	      if (sslClass == 0)
		{
		  [self backgroundLoadDidFailWithReason: @"https not supported"
		    @" ... needs gnustep-base built with GNUTLS"];
		  return;
		}
	      sock = [sslClass fileHandleAsClientInBackgroundAtAddress: host
							       service: port
							      protocol: s];

              /* Map old SSL keys onto new.
               */
	      cert = [request objectForKey: GSHTTPPropertyCertificateFileKey];
	      if (nil != cert)
		{
                  [request setObject: cert
                              forKey: GSTLSCertificateFile];
                }
              key = [request objectForKey: GSHTTPPropertyKeyFileKey];
              if (nil != key)
                {
                  [request setObject: key
                              forKey: GSTLSCertificateKeyFile];
                }
              pwd = [request objectForKey: GSHTTPPropertyPasswordKey];
              if (nil != pwd)
                {
                  [request setObject: pwd
                              forKey: GSTLSCertificateKeyPassword];
                }
	    }
	  else
	    {
	      sock = [NSFileHandle fileHandleAsClientInBackgroundAtAddress: host
								   service: port
								  protocol: s];
	    }
	}
      else
	{
          port = [[proxyURL port] description];
          host = [proxyURL host];
          
	  if ([[u scheme] isEqualToString: @"https"])
	    {
	      if (sslClass == 0)
		{
		  [self backgroundLoadDidFailWithReason: @"https not supported"
		    @" ... needs gnustep-base built with GNUTLS"];
		  return;
		}
	      sock = [sslClass fileHandleAsClientInBackgroundAtAddress: host
							       service: port
							      protocol: s];
	    }
	  else
	    {
	      sock = [NSFileHandle
		fileHandleAsClientInBackgroundAtAddress: host
						service: port
					       protocol: s];
	    }
	}
      if (sock == nil)
	{
	  /*
	   * Tell superclass that the load failed - let it do housekeeping.
	   */
	  [self backgroundLoadDidFailWithReason:
	    [NSString stringWithFormat: @"Unable to connect to %@:%@ ... %@",
	    host, port, [NSError _last]]];
	  return;
	}
      RETAIN(sock);
      nc = [NSNotificationCenter defaultCenter];
      [nc addObserver: self
	     selector: @selector(bgdConnect:)
		 name: GSFileHandleConnectCompletionNotification
	       object: sock];
      connectionState = connecting;
      if (debug)
        {
          NSLog(@"%@ %p start connect to %@:%@",
	    NSStringFromSelector(_cmd), self, host, port);
	}
    }
  else
    {
      NSString	*method;
      NSString	*path;
      NSString	*basic;

      // Stop waiting for connection to be closed down.
      nc = [NSNotificationCenter defaultCenter];
      [nc removeObserver: self
		    name: NSFileHandleReadCompletionNotification
		  object: sock];

      /* Reusing a connection. Set flag to say that it has been kept
       * alive and we don't know if the other end has dropped it
       * until we write to it and read some response.
       */
      keepalive = YES;
      method = [request objectForKey: GSHTTPPropertyMethodKey];
      if (method == nil)
	{
	  if ([wData length] > 0)
	    {
	      method = @"POST";
	    }
	  else
	    {
	      method = @"GET";
	    }
	}
      path = [[u pathWithEscapes] stringByTrimmingSpaces];
      if ([path length] == 0)
	{
	  path = @"/";
	}
      basic = [NSString stringWithFormat: @"%@ %@", method, path];
      [self bgdApply: basic];
    }
}

/**
 * Writes the specified data as the body of an <code>http</code>
 * or <code>https</code> request to the web server.
 * Returns YES on success,
 * NO on failure.  By default, this method performs a POST operation.
 * On completion, the resource data for this handle is set to the
 * page returned by the request.
 */
- (BOOL) writeData: (NSData*)d
{
  ASSIGN(wData, d);
  return YES;
}

/**
 * Sets a property to be used in the next request made by this handle.
 * The property is set as a header in the next request, unless it is
 * one of the following -
 * <list>
 *   <item>
 *     GSHTTPPropertyBodyKey - set an NSData item to be sent to
 *     the server as the body of the request.
 *   </item>
 *   <item>
 *     GSHTTPPropertyMethodKey - override the default method of
 *     the request (eg. &quot;PUT&quot;).
 *   </item>
 *   <item>
 *     GSHTTPPropertyProxyHostKey - specify the name or IP address
 *     of a host to proxy through.  Obsolete ... use
 *     https_proxy or http_proxy to specify the URL of the proxy
 *   </item>
 *   <item>
 *     GSHTTPPropertyProxyPortKey - specify the port number to
 *     connect to on the proxy host.  If not give, this defaults
 *     to 8080 for <code>http</code> and 4430 for <code>https</code>.
 *     Obsolete ... use https_proxy or http_proxy to specify the URL
 *     of the proxy.
 *   </item>
 *   <item>
 *     Any GSTLS... key to control TLS behavior
 *   </item>
 *   <item>
 *     Any NSHTTPProperty... key
 *   </item>
 * </list>
 */
- (BOOL) writeProperty: (id) property forKey: (NSString*) propertyKey
{
  if (propertyKey == nil
    || [propertyKey isKindOfClass: [NSString class]] == NO)
    {
      [NSException raise: NSInvalidArgumentException
        format: @"%@ %p with invalid key", NSStringFromSelector(_cmd), self];
    }
  if ([propertyKey hasPrefix: @"GSHTTPProperty"]
    || [propertyKey hasPrefix: @"GSTLS"]
    || [propertyKey hasPrefix: @"NSHTTPProperty"])
    {
      if (property == nil)
	{
	  [request removeObjectForKey: propertyKey];
	}
      else
	{
	  [request setObject: property forKey: propertyKey];
	}
    }
  else
    {
      if (property == nil)
	{
	  NSMapRemove(wProperties, (void*)propertyKey);
	}
      else
	{
	  NSMapInsert(wProperties, (void*)propertyKey, (void*)property);
	}
    }
  return YES;
}

@end

