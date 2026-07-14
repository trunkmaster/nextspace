/* Code to start up a helper and wait for it to confirm it's ready to proceed
 * The helper must write someting to stdout to indicate its readiness.
 */
#if     GNUSTEP

@interface HelperListener : NSObject
{
@public
  BOOL	done;
  BOOL	active;
}
- (void) helperRead: (NSNotification*)n;
@end
@implementation	HelperListener
- (void) helperRead: (NSNotification*)n
{
  NSDictionary	*u = [n userInfo];
  NSData        *d;

  d = [u objectForKey: NSFileHandleNotificationDataItem];
  if ([d length] > 0)
    {
      active = YES;
    }
  done = YES;
}
@end

@interface NSTask (TestHelper)
+ (NSTask*) launchedHelperWithLaunchPath: (NSString*)_path
			       arguments: (NSArray*)_args
				 timeout: (NSTimeInterval)_wait;
@end

@implementation NSTask (TestHelper)
+ (NSTask*) launchedHelperWithLaunchPath: (NSString*)_path
			       arguments: (NSArray*)_args
				 timeout: (NSTimeInterval)_wait
{
  NSTask		*t = [NSTask new];
  ENTER_POOL
  NSNotificationCenter	*c = [NSNotificationCenter defaultCenter];
  NSPipe		*p = [NSPipe pipe];
  NSFileHandle		*h = [p fileHandleForReading];
  HelperListener	*l = AUTORELEASE([HelperListener new]);
  NSDate		*d;

  if (_wait <= 0.0)
    {
      _wait = 5.0;
    }
  d = [NSDate dateWithTimeIntervalSinceNow: _wait];
  [t setLaunchPath: _path];
  [t setArguments: _args];
  [t setStandardOutput: p];
  [t launch];
  [c addObserver: l
	selector: @selector(helperRead:)
	    name: NSFileHandleReadCompletionNotification
	  object: h];
  [h readInBackgroundAndNotify];
  while (NO == l->done && [d timeIntervalSinceNow] > 0.0)
    {
      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
			       beforeDate: d];
    }
  [c removeObserver: l
	       name: NSFileHandleReadCompletionNotification
	     object: h];
  [h closeFile];
  if (NO == l->done)
    {
      NSLog(@"Helper task %@ failed to start up in time.", _path);
      [t terminate];
      [t waitUntilExit];
      t = nil;
    }
  else if (NO == l->active)
    {
      NSLog(@"Helper task %@ failed to start (and ended).", _path);
      [t terminate];
      [t waitUntilExit];
      t = nil;
    }
  LEAVE_POOL
  return AUTORELEASE(t);
}
@end

#endif	/* GNUSTEP */
