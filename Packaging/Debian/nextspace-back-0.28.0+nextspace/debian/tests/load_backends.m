/* -*- objc -*-

   Test loading of all backends.  This minimalistic program roughly
   mimics the backend loading procedure of the GNUstep GUI library,
   grossly simplified because there is no need to guess the
   installation details.  */

#import <Foundation/Foundation.h>

void
load_backend (NSString *bundleWithVersion)
{
  NSString *path;
  NSArray *libdir;
  NSBundle *theBundle;
  Class backend = Nil;

  libdir = NSSearchPathForDirectoriesInDomains (NSLibraryDirectory,
                                                NSSystemDomainMask, YES);
  path = [[libdir firstObject] stringByAppendingPathComponent: @"Bundles"];
  path = [path stringByAppendingPathComponent: bundleWithVersion];
  NSCAssert1 ([[NSFileManager defaultManager] fileExistsAtPath: path],
              @"File %@ does not exist", path);

  theBundle = [NSBundle bundleWithPath: path];
  NSCAssert1 (theBundle != nil,
              @"Cannot create NSBundle object for backend at path %@", path);
  NSCAssert1 ([theBundle load],
              @"Cannot load object file from backend at path %@", path);

  backend = NSClassFromString (@"GSBackend");
  NSCAssert1 (backend != Nil,
              @"Backend at path %@ doesn't contain the GSBackend class", path);
}

int
main (void)
{
  CREATE_AUTORELEASE_POOL (pool);
  NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
  NSString *bundleName, *bundleWithVersion;

  bundleName = [defs stringForKey: @"GSBackend"];
  /* The default backend must be cairo (enforced via the alternatives
     system); attempt to load it from the symlink.  */
  NSCAssert (bundleName == nil, @"GSBackend set while it shouldn't");
  bundleName = @"libgnustep-back";
  bundleWithVersion = [NSString stringWithFormat: @"%@-%s.bundle",
                                bundleName, VER];
  load_backend (bundleWithVersion);

  /* Now load all the backends directly.  */
  [defs setObject: @"libgnustep-cairo" forKey: @"GSBackend"];
  bundleName = [defs stringForKey: @"GSBackend"];
  bundleWithVersion = [NSString stringWithFormat: @"%@-%s.bundle",
                                bundleName, VER];
  load_backend (bundleWithVersion);

  [defs setObject: @"libgnustep-art" forKey: @"GSBackend"];
  bundleName = [defs stringForKey: @"GSBackend"];
  bundleWithVersion = [NSString stringWithFormat: @"%@-%s.bundle",
                                bundleName, VER];
  load_backend (bundleWithVersion);

  [defs setObject: @"libgnustep-xlib" forKey: @"GSBackend"];
  bundleName = [defs stringForKey: @"GSBackend"];
  bundleWithVersion = [NSString stringWithFormat: @"%@-%s.bundle",
                                bundleName, VER];
  load_backend (bundleWithVersion);

  RELEASE (pool);
  exit (EXIT_SUCCESS);
}
