
#include "objc-common.g"
#include <objc/objc-exception.h>

int main (void)
{
  objc_setUncaughtExceptionHandler (0);
  return 0;
}
