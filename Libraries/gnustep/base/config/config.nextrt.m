/* A function for testing if the compiler is using the NeXT Objective C
   runtime or not.

   With the NeXT runtime this file compiles and links.
   With the GNU runtime, this file does not link.
*/

#include "objc-common.g"

int libobjects_nextrt_checker ()
{
  id o = [[Object alloc] init];

  [o self];
  objc_msgSend(o, @selector(self));

  exit(0);
}
