/*
 *  Author: Sergei Golovin <svgdev@mail.ru>
 */

#import "SimpleWebServer.h"

/* the time step for the runloop */
#define TIMING 0.1

@interface SimpleWebServer (Private)
/**
 *  Starts listening. Returns NO if the instance can't listen.
 */
- (BOOL) _startListening;

/**
 *  Receives NSFileHandleConnectionAcceptedNotification.
 */
- (void) _accept:(NSNotification *)ntf;

/**
 *  Receives NSFileHandleReadCompletionNotification.
 */
- (void) _read:(NSNotification *)ntf;

/**
 *  Tries to recognise if the request's bytes have been read (HTTP message's
 *  headers and body) and if so then it proceeds the request and produces
 *  a response. If the response is ready it returns YES.
 */
- (BOOL)_tryCaptured;

/**
 *  Makes and sends response.
 */
- (void) _makeAndSendResponse;

/**
 *  Reset to prepare for the next request-response cycle.
 */
- (void)_resetCycle;

/**
 *  Closes IO
 */
- (void) _close;

@end /* SimpleWebServer (Private) */

@implementation SimpleWebServer

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  _delegate = nil;
  DESTROY(_capture);
  DESTROY(_request);
  DESTROY(_response);
  DESTROY(_cfh);
  DESTROY(_fh);
  DESTROY(_address);
  DESTROY(_port);
  DESTROY(_secure);
  [super dealloc];
}

- (id)init
{
  if ((self = [super init]) != nil)
    {
      _debug = NO;
      _delegate = nil;
      _isSecure = NO;
      _isRunning = NO;
      _isClose = NO;
    }

  return self;
}

/* getters */
- (NSString *)port
{
  if (nil !=_fh)
    {
      return _port;
    }

  return nil;
}
/* end of getters */

/* setters */
- (BOOL)setAddress:(NSString *)address
	      port:(NSString *)port
	    secure:(NSDictionary *)dict
{
  ASSIGN(_address, address);
  ASSIGN(_port, port);
  ASSIGN(_secure, dict);

  return [self _startListening];
}

- (void)setDebug:(BOOL)flag
{
  _debug = flag;
}

- (void)setDelegate:(id)delegate
{
  _delegate = delegate;
}

/* end of setters */

- (void)stop
{
  [[NSNotificationCenter defaultCenter] removeObserver: self
						  name: NSFileHandleConnectionAcceptedNotification
						object: _fh];
  [self _close];
  DESTROY(_fh);
  DESTROY(_address);
  DESTROY(_port);
  DESTROY(_secure);
  _isRunning = NO;
}

@end /* SimpleWebServer */

@implementation SimpleWebServer (Private)

- (BOOL) _startListening
{
  if (nil != _secure
      && [_secure objectForKey: @"CertificateFile"] != nil
      && [_secure objectForKey: @"KeyFile"] != nil)
    {
      Class sslClass = [NSFileHandle sslClass];

      _isSecure = YES;
      _fh = [sslClass fileHandleAsServerAtAddress: _address
					  service: _port
					 protocol: @"tcp"];
      [_fh sslSetOptions: _secure];
    }
  else
    {
      _fh = [NSFileHandle fileHandleAsServerAtAddress: _address
					      service: _port
					     protocol: @"tcp"];
    }
  RETAIN(_fh);

  [[NSNotificationCenter defaultCenter] addObserver: self
					  selector: @selector(_accept:)
					       name: NSFileHandleConnectionAcceptedNotification
					     object: _fh];

  [_fh acceptConnectionInBackgroundAndNotify];
  _isRunning = YES;

  return YES;
}

- (void) _accept:(NSNotification *)ntf
{
  if (_isRunning)
    {
      NSDictionary *info = [ntf userInfo];
      NSFileHandle *fh = [info objectForKey: NSFileHandleNotificationFileHandleItem];

      if (_cfh != nil)
	{
	  [self _close];
	}

      ASSIGN(_cfh, fh);

      [_fh acceptConnectionInBackgroundAndNotify];

      if (!_isSecure || (_isSecure && [_cfh sslAccept]))
	{
	  [[NSNotificationCenter defaultCenter] addObserver: self
						   selector: @selector(_read:)
						       name: NSFileHandleReadCompletionNotification
						     object: _cfh];

	  [_cfh readInBackgroundAndNotify];
	}
    }
}

- (void) _read:(NSNotification *)ntf
{
  if (_isRunning)
    {
      NSDictionary *info = [ntf userInfo];

      if([info objectForKey: GSFileHandleNotificationError])
	{
	  [self _close];
	  return;
	}
      if([[ntf name] isEqual: NSFileHandleReadCompletionNotification])
	{
	  NSData *hunk = [info objectForKey: NSFileHandleNotificationDataItem];
	  if (nil != hunk && [hunk length] > 0)
	    {
	      if (nil == _capture)
		{
		  _capture = [NSMutableData new];
		}
	      [_capture appendData: hunk];
	      if ([self _tryCaptured]) // <- the _request and _response are allocated
		{
		  [self _makeAndSendResponse];
		  // ready for another request-response cycle
		  [self _resetCycle]; // <- the _request and _response are deallocated

		  if (_isClose)
		    {
		      // if the client didn't supply the header 'Connection' or explicitly stated
		      // to close the current connection
		      [self _close];
		      return;
		      // BEWARE: it can left the socket busy for HTTP after server stopping (for HTTPS is OK)
		      //         so consequent tests are failed bc their server can't bind
		    } 
		}
	      [_cfh readInBackgroundAndNotify];
	    }
	  else
	    {
	      [self _close];
	      return;
	    }
	}
    }
}

- (BOOL) _tryCaptured
{
  BOOL ret = NO;
  NSRange r1;
  NSRange r2;
  NSString *headers;
  NSString *tmp1;
  NSString *tmp2;
  NSUInteger contentLength = 0;

  // the following chunk ensures that the captured data are written only
  // when all request's bytes are read... it waits for full headers and
  // reads the Content-Length's value then waits for the number of bytes
  // equal to that value is read
  tmp1 = [[NSString alloc] initWithData: _capture
			       encoding: NSUTF8StringEncoding];
  // whether the headers are read
  if ((r1 = [tmp1 rangeOfString: @"\r\n\r\n"]).location != NSNotFound)
    {
      headers = [tmp1 substringToIndex: r1.location + 2];
      if ((r2 = [[headers lowercaseString] rangeOfString: @"content-length:"]).location != NSNotFound)
	{
	  tmp2 = [headers substringFromIndex: r2.location + r2.length]; // content-length:<tmp2><end of headers>
	  if ((r2 = [tmp2 rangeOfString: @"\r\n"]).location != NSNotFound)
	    {
	      // full line with content-length is present
	      tmp2 = [tmp2 substringToIndex: r2.location]; // number of content's bytes
	      contentLength = [tmp2 intValue];
	    }
	}
      else
	{
	  contentLength = 0; // no header 'content-length'
	}
      if (r1.location + 4 + contentLength == [_capture length]) // Did we get headers + body?
	{
	  // The request has been received
	  NSString *method = @"";
	  NSString *query = @"";
	  NSString *version = @"";
	  NSString *scheme = _isSecure ? @"https" : @"http";
	  NSString *path = @"";
	  NSData   *data;

	  // TODO: currently no checks
	  r2 = [headers rangeOfString: @"\r\n"];
	  while (r2.location == 0)
	    {
	      // ignore an empty line before the request line
	      headers = [headers substringFromIndex: 2];
	      r2 = [headers rangeOfString: @"\r\n"];
	    }
	  // the request line has been caught
	  tmp2 = [tmp1 substringFromIndex: r2.location + 2]; // whole request without the first line
	  data = [tmp2 dataUsingEncoding: NSUTF8StringEncoding];
	  _request = [GSMimeParser documentFromData: data];
	  RETAIN(_request);

	  // x-http-...
	  tmp2 = [headers substringToIndex: r2.location]; // the request line
	  tmp2 = [tmp2 stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];

	  // find the method
	  r2 = [tmp2 rangeOfString: @" "];
	  method = [[tmp2 substringToIndex: r2.location] uppercaseString];
	  tmp2 = [[tmp2 substringFromIndex: r2.location + 1]
		   stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];

	  r2 = [tmp2 rangeOfString: @"?"]; // path?query
	  if (r2.location != NSNotFound)
	    {
	      // path?query
	      path = [tmp2 substringToIndex: r2.location];
	      tmp2 = [tmp2 substringFromIndex: r2.location + 1]; // without '?'
	      r2 = [tmp2 rangeOfString: @" "];
	      query = [tmp2 substringToIndex: r2.location];
	    }
	  else
	    {
	      // only path
	      r2 = [tmp2 rangeOfString: @" "];
	      path = [tmp2 substringToIndex: r2.location];
	    }
	  tmp2 = [[tmp2 substringFromIndex: r2.location + 1]
		       stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
	  // tmp2 == 'HTTP/<version>'
	  version = [tmp2 substringFromIndex: 5];


	  [_request setHeader: @"x-http-method"
			value: method
		   parameters: nil];

	  [_request setHeader: @"x-http-path"
			value: path
		   parameters: nil];

	  [_request setHeader: @"x-http-query"
			value: query
		   parameters: nil];

	  [_request setHeader: @"x-http-scheme"
			value: scheme
		   parameters: nil];

	  [_request setHeader: @"x-http-version"
			value: version
		   parameters: nil];

	  NSDebugLog(@"%@: got request\n%@", self, _request);

	  _response = [GSMimeDocument new];

	  if (nil != _delegate && [_delegate respondsToSelector: @selector(processRequest:response:for:)])
	    {
	      ret = [_delegate processRequest: _request response: _response for: self];
	    }
	  if (!ret)
	    {
	      DESTROY(_response);
	      _response = [GSMimeDocument new];
	      [_response setHeader: @"HTTP" value: @"HTTP/1.1 204 No Content" parameters: nil];
	      [_response setHeader: @"Content-Length" value: @"0" parameters: nil];
	      ret = YES;
	    }
	}
    }
  DESTROY(tmp1);

  return ret;
}

- (void) _makeAndSendResponse
{
  NSMutableData *data;
  NSString      *status;
  NSData        *statusData;
  char          *crlf = "\r\n";
  id            content;
  NSData        *contentData = nil;
  NSUInteger    cLength = 0; // content-length
  NSString      *connection;

  // adding the 'Connection' to the response
  connection = [[_request headerNamed: @"connection"] value];
  // if the client didn't supply the header 'Connection' or
  // explicitly stated to close the current connection
  _isClose = (nil == connection ||
	   [[connection lowercaseString] isEqualToString: @"close"]);

  // adding the 'Content-Length' to the response
  content = [_response content];
  if ([content isKindOfClass: [NSString class]])
    {
      contentData = [(NSString *)content
			dataUsingEncoding: NSUTF8StringEncoding];
    }
  else if ([content isKindOfClass: [NSData class]])
    {
      contentData = (NSData *)content;
    }
  else
    {
      // yet unsupported
    }
  if (nil != content)
    {
      cLength = [contentData length];
      if (cLength > 0)
	{
	  NSString  *l;

	  l = [NSString stringWithFormat: @"%u", (unsigned)cLength];
	  [_response setHeader: @"Content-Length"
			 value: l
		    parameters: nil];
	}
    }
  if (cLength == 0)
    {
      [_response setHeader: @"Content-Length"
		     value: @"0"
		parameters: nil];
    }

  // adding the status line
  status = [[_response headerNamed: @"http"] value];
  statusData = [status dataUsingEncoding: NSUTF8StringEncoding];
  data = [[NSMutableData alloc] initWithData: statusData];
  [_response deleteHeaderNamed: @"http"];
  [data appendBytes: crlf length: 2];

  // actual sending
  [data appendData: [_response rawMimeData]];

  NSDebugLog(@"%@: about to send response\n%@", self, _response);

  [_cfh writeData: data];
  RELEASE(data);
}

- (void)_resetCycle
{
  DESTROY(_response);
  DESTROY(_request);
  DESTROY(_capture);
}

- (void) _close
{
  [[NSNotificationCenter defaultCenter] removeObserver: self
						  name: NSFileHandleReadCompletionNotification
						object: _cfh];
  if(_isSecure)
    {
      [_cfh sslDisconnect];
    }
  DESTROY(_cfh);
}

@end /* SimpleWebServer (Private) */
