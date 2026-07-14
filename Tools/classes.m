/* Crude tool to compare classes in different version of library code to
 * look for possible compatiblity issues.
 *
 * This tools is very much subject to change!
 *
 * At present, the tool simply looks for the methods available in public
 * classes (excluding private methods).
 *
 * To check for public symbols of other kinds, use the 'nm' command on the
 * library with -g (public/external) and -U (defined symbols) options.
 * Filter the output to remove symbols we are not interested in.
 * eg.
 * nm -g -U Source/obj/libgnustep-base.so.1.31.0 | fgrep -v -e ' GS' -e ' NS' \
 *   -e ' ._OBJC' -e '  __objc' -e ' __odr_asan' >/tmp/result.txt
 *
 * Names beginning GS or NS are assumed to be intentionally public.
 * We probably arent intersted in classes, ivar offsets, or ASAN synbols.
 */
#import "Foundation/Foundation.h"
#import "GNUstepBase/GNUstep.h"
#import	"GNUstepBase/GSObjCRuntime.h"

static NSSet *
publicClasses()
{
  static NSSet	*set = nil;

  if (nil == set)
    {
      static char	*base[] = {
	"NSAffineTransform",
	"NSAppleEventDescriptor",
	"NSAppleEventManager",
	"NSAppleScript",
	"NSArchiver",
	"NSArray",
	"NSAssertionHandler",
	"NSAttributedString",
	"NSAutoreleasePool",
	"NSBackgroundActivityScheduler",
	"NSBlockOperation",
	"NSBundle",
	"NSByteCountFormatter",
	"NSCache",
	"NSCachedURLResponse",
	"NSCalendar",
	"NSCalendarDate",
	"NSCharacterSet",
	"NSClassDescription",
	"NSCoder",
	"NSComparisonPredicate",
	"NSCompoundPredicate",
	"NSCondition",
	"NSConditionLock",
	"NSConnection",
	"NSCountedSet",
	"NSData",
	"NSDate",
	"NSDateComponents",
	"NSDateComponentsFormatter",
	"NSDateFormatter",
	"NSDateInterval",
	"NSDateIntervalFormatter",
	"NSDecimalNumber",
	"NSDecimalNumberHandler",
	"NSDeserializer",
	"NSDictionary",
	"NSDimension",
	"NSDirectoryEnumerator",
	"NSDistantObject",
	"NSDistributedLock",
	"NSDistributedNotificationCenter",
	"NSEnergyFormatter",
	"NSEnumerator",
	"NSError",
	"NSException",
	"NSExpression",
	"NSExtensionContext",
	"NSExtensionItem",
	"NSFileAccessIntent",
	"NSFileCoordinator",
	"NSFileHandle",
	"NSFileManager",
	"NSFileVersion",
	"NSFileWrapper",
	"NSFormatter",
	"NSGarbageCollector",
	"NSHTTPCookie",
	"NSHTTPCookieStorage",
	"NSHTTPURLResponse",
	"NSHashTable",
	"NSHost",
	"NSISO8601DateFormatter",
	"NSIndexPath",
	"NSIndexSet",
	"NSInputStream",
	"NSInvocation",
	"NSInvocationOperation",
	"NSItemProvider",
	"NSItemProviderReadingWriting",
	"NSJSONSerialization",
	"NSKeyedArchiver",
	"NSKeyedUnarchiver",
	"NSLengthFormatter",
	"NSLinguisticTagger",
	"NSLocale",
	"NSLock",
	"NSMapTable",
	"NSMassFormatter",
	"NSMeasurement",
	"NSMeasurementFormatter",
	"NSMessagePort",
	"NSMessagePortNameServer",
	"NSMetadataItem",
	"NSMetadataQuery",
	"NSMetadataQueryAttributeValueTuple",
	"NSMetadataQueryResultGroup",
	"NSMethodSignature",
	"NSMutableArray",
	"NSMutableAttributedString",
	"NSMutableCharacterSet",
	"NSMutableData",
	"NSMutableDictionary",
	"NSMutableIndexSet",
	"NSMutableOrderedSet",
	"NSMutableSet",
	"NSMutableString",
	"NSMutableURLRequest",
	"NSNetService",
	"NSNetServiceBrowser",
	"NSNotification",
	"NSNotificationCenter",
	"NSNotificationQueue",
	"NSNull",
	"NSNumber",
	"NSNumberFormatter",
	"NSObject",
	"NSObjectScripting",
	"NSOperation",
	"NSOperationQueue",
	"NSOrderedSet",
	"NSOrthography",
	"NSOutputStream",
	"NSPersonNameComponents",
	"NSPersonNameComponentsFormatter",
	"NSPipe",
	"NSPointerArray",
	"NSPointerFunctions",
	"NSPort",
	"NSPortCoder",
	"NSPortMessage",
	"NSPortNameServer",
	"NSPredicate",
	"NSProcessInfo",
	"NSProgress",
	"NSPropertyListSerialization",
	"NSProtocolChecker",
	"NSProxy",
	"NSRecursiveLock",
	"NSRegularExpression",
	"NSRunLoop",
	"NSScanner",
	"NSScriptClassDescription",
	"NSScriptCoercionHandler",
	"NSScriptCommand",
	"NSScriptCommandDescription",
	"NSScriptExecutionContext",
	"NSScriptKeyValueCoding",
	"NSScriptObjectSpecifiers",
	"NSScriptStandardSuiteCommands",
	"NSScriptSuiteRegistry",
	"NSSerializer",
	"NSSet",
	"NSSocketPort",
	"NSSocketPortNameServer",
	"NSSortDescriptor",
	"NSSpellServer",
	"NSStream",
	"NSString",
	"NSTask",
	"NSTextCheckingResult",
	"NSThread",
	"NSTimeZone",
	"NSTimeZoneDetail",
	"NSTimer",
	"NSURL",
	"NSURLAuthenticationChallenge",
	"NSURLCache",
	"NSURLComponents",
	"NSURLConnection",
	"NSURLCredential",
	"NSURLCredentialStorage",
	"NSURLDownload",
	"NSURLHandle",
	"NSURLProtectionSpace",
	"NSURLProtocol",
	"NSURLQueryItem",
	"NSURLRequest",
	"NSURLResponse",
	"NSURLSession",
	"NSURLSessionConfiguration",
	"NSURLSessionDataTask",
	"NSURLSessionDownloadTask",
	"NSURLSessionStreamTask",
	"NSURLSessionTask",
	"NSURLSessionUploadTask",
	"NSUUID",
	"NSUbiquitousKeyValueStore",
	"NSUnarchiver",
	"NSUndoManager",
	"NSUnit",
	"NSUnitAcceleration",
	"NSUnitAngle",
	"NSUnitArea",
	"NSUnitConcentrationMass",
	"NSUnitConverter",
	"NSUnitConverterLinear",
	"NSUnitDispersion",
	"NSUnitDuration",
	"NSUnitElectricCharge",
	"NSUnitElectricCurrent",
	"NSUnitElectricPotentialDifference",
	"NSUnitElectricResistance",
	"NSUnitEnergy",
	"NSUnitFrequency",
	"NSUnitFuelEfficiency",
	"NSUnitIlluminance",
	"NSUnitLength",
	"NSUnitMass",
	"NSUnitPower",
	"NSUnitPressure",
	"NSUnitSpeed",
	"NSUnitTemperature",
	"NSUnitVolume",
	"NSUserActivity",
	"NSUserDefaults",
	"NSUserNotification",
	"NSUserNotificationCenter",
	"NSUserScriptTask",
	"NSValue",
	"NSValueTransformer",
	"NSXMLDTD",
	"NSXMLDTDNode",
	"NSXMLDocument",
	"NSXMLElement",
	"NSXMLNode",
	"NSXMLParser",
	"NSXPCConnection",
	"NSXPCInterface",
	"NSXPCListener",
	"NSXPCListenerEndpoint"
      };
      unsigned		count = sizeof(base)/sizeof(*base);
      unsigned		index;
      NSMutableSet	*m;

      ENTER_POOL
      m = [NSMutableSet setWithCapacity: count];
      for (index = 0; index < count; index++)
	{
	  [m addObject: [NSString stringWithUTF8String: base[index]]];
	}
      ASSIGNCOPY(set, m);
      LEAVE_POOL
    }
  return set;
}

static BOOL
findClassMethod(NSString *mName, NSString *cName, NSDictionary *all)
{
  while (cName != nil)
    {
      NSDictionary	*info = [all objectForKey: cName];

      if ([[info objectForKey: @"classmethods"] containsObject: mName])
	{
	  return YES;
	}
      cName = [info objectForKey: @"superclass"];
    }
  return NO;
}

static BOOL
findInstanceMethod(NSString *mName, NSString *cName, NSDictionary *all)
{
  while (cName != nil)
    {
      NSDictionary	*info = [all objectForKey: cName];

      if ([[info objectForKey: @"instancemethods"] containsObject: mName])
	{
	  return YES;
	}
      cName = [info objectForKey: @"superclass"];
    }
  return NO;
}

static BOOL
doCompare(NSString *name, NSDictionary *oinfo, NSDictionary *all)
{
  NSDictionary	*ninfo = [all objectForKey: name];
  NSEnumerator	*e;
  id		n;
  id		o;
  BOOL		ok = YES;

  if (nil == ninfo)
    {
      NSLog(@"Class '%@' removed\n", name);
      return NO;
    }
  o = [oinfo objectForKey: @"superclass"];
  n = [ninfo objectForKey: @"superclass"];
  if (o != n && NO == [o isEqual: n])
    {
      NSLog(@"Class '%@' superclass changed from %@ to %@\n", name, o, n);
      ok = NO;
    }

  e = [[oinfo objectForKey: @"classmethods"] objectEnumerator];
  while ((o = [e nextObject]) != nil)
    {
      if (NO == findClassMethod(o, name, all))
	{
	  NSLog(@"Class '%@' class method '%@' removed\n", name, o);
	  ok = NO;
	}      
    }

  e = [[oinfo objectForKey: @"instancemethods"] objectEnumerator];
  while ((o = [e nextObject]) != nil)
    {
      if (NO == findInstanceMethod(o, name, all))
	{
	  NSLog(@"Class '%@' instance method '%@' removed\n", name, o);
	  ok = NO;
	}      
    }
  return ok;
}

static void
doMethods(Class class, NSMutableDictionary *info, BOOL instance)
{
  NSMutableArray	*ma = [NSMutableArray array];
  Method		*methods;
  unsigned int		count;

  if (instance)
    {
      methods = class_copyMethodList(class, &count);
    }
  else
    {
      methods = class_copyMethodList(object_getClass(class), &count);
    }
  if (methods)
    {
      NSString		*name;
      unsigned		i;

      for (i = 0; i < count; i++)
	{
	  SEL 		sel = method_getName(methods[i]);
	  const char	*n = sel_getName(sel);

	  if (0 == n || '_' == *n)
	    {
	      continue;
	    }
	  name = [NSString stringWithUTF8String: n];
	  if ([ma containsObject: name] == NO)
	    {
	      [ma addObject: name];
	    }
	}
      free(methods);
    }

  if ([ma count])
    {
      [ma sortUsingSelector: @selector(compare:)];
      if (instance)
	{
	  [info setObject: ma forKey: @"instancemethods"];
	}
      else
	{
	  [info setObject: ma forKey: @"classmethods"];
	}
    }
}

int
main(int argc, char *argv[])
{
  ENTER_POOL
  NSDictionary		*oldClasses;
  NSMutableDictionary	*newClasses;
//  Protocol      	**protocols;
  NSString		*signature;
  int			classCount;
  NSDictionary		*locale;
  NSString		*name;
  Class			class;
  NSSet			*set;

  locale = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];

  oldClasses = [NSDictionary dictionaryWithContentsOfFile: @"OldClasses.plist"];

  set = publicClasses();
  classCount = [set count];
  if (0 == classCount)
    {
      /* No expected classes ... try to get all classes instead.
       */
      classCount = objc_getClassList(NULL, 0);
      set = nil;
    }
  if (classCount > 0)
    {
      Class	buf[classCount];
      int	ci;

      if (set)
	{
	  NSEnumerator	*e = [set objectEnumerator];

	  ci = 0;
	  while ((name = [e nextObject]) != nil)
	    {
	      class = NSClassFromString(name);
	      if (Nil == class)
		{
		  NSLog(@"Expected class '%@' not found.", name);
		}
	      else
		{
		  buf[ci++] = class;
		}
	    }
	}
      else
 	{
	  ci = objc_getClassList(buf, classCount);
	  NSCAssert(ci == classCount, NSInternalInconsistencyException);
	}
      classCount = ci;

      newClasses = [NSMutableDictionary dictionaryWithCapacity: ci];
      for (ci = 0; ci < classCount; ci++)
	{
	  Class			superClass;
	  NSMutableDictionary	*classDescription;
	  const char		*n;

	  class = buf[ci]; 
	  if (class_isMetaClass(class))
	    {
	      continue;
	    }
	  n = class_getName(class);
	  if (0 == n || '_' == *n)
	    {
	      continue;
	    }
	  name = [NSString stringWithUTF8String: class_getName(class)];
	  if (set && nil == [set member: name])
	    {
	      NSLog(@"Unexpected class '%@' ignored", name);
	      continue;
	    }

	  classDescription = [NSMutableDictionary dictionaryWithCapacity: 4];
	  [newClasses setObject: classDescription forKey: name];

	  superClass = class_getSuperclass(class);
	  if (superClass != Nil)
	    {
	      n = class_getName(superClass);
	      name = [NSString stringWithUTF8String: n];
	      [classDescription setObject: name forKey: @"superclass"];
	    }

	  doMethods(class, classDescription, YES);
	  doMethods(class, classDescription, NO);
	}
    }
  else
    {
      NSLog(@"Failed to find any classes");
      exit(1);
    }
  signature = [newClasses descriptionWithLocale: locale indent: 0];
  [signature writeToFile: @"NewClasses.plist" atomically: NO];

  if (oldClasses)
    {
      NSEnumerator	*e = [oldClasses keyEnumerator];
      BOOL		ok = YES;

      while ((name = [e nextObject]) != nil)
	{
	  NSDictionary	*oinfo = [oldClasses objectForKey: name];

	  if (NO == doCompare(name, oinfo, newClasses))
	    {
	      ok = NO;
	    }
	}
      if (ok)
	{
	  NSLog(@"Old and new class signature match.");
	}
      else
	{
	  NSLog(@"Old and new class signature differ.");
	}
    }

  LEAVE_POOL
  return 0;
}

