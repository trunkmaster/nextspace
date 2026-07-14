/** -*- objc -*-
 *
 * Author: Sergei Golovin <svgdev@mail.ru>
 *
 */

#import <Foundation/Foundation.h>
#import <GNUstepBase/GSMime.h>

/**
 *  Implements a simple web server with delegate interaction which mimic of
 *  the WebServer's delegate protocol.
 *
 *  The SimpleWebServer class currently has many limitations (deficiencies).
 *  The following is a list of most important ones:
 *     - supports only one connection simultaneously.
 *     - doesn't support any transfer-content-encoding (more precisely it uses
 *       only 'identity' transfer-content-encoding that is without any modification
 *       of the content/message);
 *     - the class uses UTF8 by default. It expects a request and produces responses 
 *       in that encoding;
 *     - it expects an explicit request for closing of the connection (that is
 *       the request's header 'Connection' must be 'close') or implicitly does it
 *       if no 'Connection' has been supplied;
 *     - doesn't support pipelining of requests;
 *
 *  Use the -[setDebug: YES] to raise verbosity.
 */
@interface SimpleWebServer : NSObject
{
  /* holds the file handler of connection */
  NSFileHandle            *_fh;
  /* holds the 'near' file handler of connection...
     see "Background Inter-Process Communication Using Sockets"
     of Low-Level File Management Programming Topics
  */
  NSFileHandle            *_cfh;

  /* the delegate ... NOT RETAINED...
   * see below the protocol SimpleWebServerDelegate */
  id                  _delegate;
  /* the debug mode */
  BOOL                   _debug;
  /* the address to bind with */
  NSString            *_address;
  /* the port to listen to */
  NSString               *_port;
  /* SSL configuration and options */
  NSDictionary         *_secure;
  /* whether to use a secure TLS/SSL connection */
  BOOL                _isSecure;
  /* the collector of received bytes from a client */
  NSMutableData	      *_capture;
  /* holds the current request */
  GSMimeDocument      *_request;
  /* holds the current response */
  GSMimeDocument     *_response;
  /* the flag the server wants to operate */
  BOOL _isRunning;
  /* to close the connection after sending the response */
  BOOL _isClose;
}
- (void)dealloc;

/* getters */
/**
 *  Returns the string of the port number if the instance is accepting
 *  connections (is started). Otherwise returns nil.
 */
- (NSString *)port;
/* end of getters */

/* setters */
/**
 *  Starts the simple web server listening on the supplied address and port.
 *  The dictionary 'dict' is supplied with additional configuration parameters.
 *  connections. The dictionary's keys are:
 *     CertificateFile
 *       the path to a certificate (if the web server should wait for HTTPS)
 *     KeyFile
 *       the path to a key (if the web server should wait for HTTPS)
 */
- (BOOL)setAddress:(NSString *)address
	      port:(NSString *)port
	    secure:(NSDictionary *)dict;
/**
 *  Sets the debug mode.
 */
- (void)setDebug:(BOOL)flag;

/**
 *  Sets the delegate responding to the selector -[processRequest:response:].
 */
- (void)setDelegate:(id)delegate;
/* end of setters */

/**
 *  Commands the web server to stop listening.
 */
- (void)stop;

@end /* SimpleWebServer */

@protocol SimpleWebServerDelegate
/**
 *  An implementor gets the supplied request for processing and
 *  modifies the supplied response which the supplied SimpleWebServer
 *  server should send back to it's peer if the return value is set
 *  to YES. Otherwise SimpleWebServer sends the predetermined response
 *  (TODO).
 */
- (BOOL)processRequest:(GSMimeDocument *)request
	      response:(GSMimeDocument *)response
		   for:(SimpleWebServer *)server;

@end /* SimpleWebServerDelegate */
